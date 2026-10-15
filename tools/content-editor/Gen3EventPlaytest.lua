local M={}
function M.request(S,script,mapId,event,actor)
  local Map=require("Gen3Map")
  local layout,err=Map.layout(S.data,mapId,S.project)
  if not layout then return nil,err end
  local map=(S.project.maps or {})[mapId] or (S.data.maps or {})[mapId] or {}
  local x,y=event.x or 0,event.y or 0
  local candidates=actor and {{x,y+1},{x,y-1},{x-1,y},{x+1,y}} or {{x,y}}
  for _,position in ipairs(candidates) do
    local px,py=position[1],position[2]
    local occupied=false
    for _,object in ipairs(map.objects or {}) do if object.x==px and object.y==py then occupied=true;break end end
    if px>=0 and py>=0 and px<layout.width and py<layout.height and not occupied then
      local cell=Map.cell(S.project,mapId,layout,px,py)
      local source=(S.project.layeredMaps or {})[mapId]
      local mode=source and (source.collision or {})[py*layout.width+px+1]
        or cell and require("Gen3Collision").mode(cell.coll or 0)
      if mode=="walk" or mode=="grass" then
        local facing=py>y and "up" or py<y and "down" or px<x and "right" or "left"
        return {script=script,map=mapId,actor=actor,x=px,y=py,facing=facing}
      end
    end
  end
  return nil,"No open tile beside this event. Move the character or adjust the map collision before playtesting."
end
function M.source(request)
  assert(type(request.script)=="string" and type(request.map)=="string","Choose an attached event")
  assert(type(request.x)=="number" and type(request.y)=="number","Event position missing")
  return "local target="..require("ModWriter").encodeLua(request).."\n"..M.driver
end
M.driver=[=[
return function(game)
  assert(game.generation==3 and game._enterField,"Event playtest requires the Gen 3 runtime")
  local Save=require("src.core.SaveData")
  local Schema=require("src.core.game3.save_schema_firered")
  local raw=Save.load()
  local session=raw and raw.engine=="game3" and Schema.fromSaveTable(raw) or Schema.newGame()
  session=require("src.mods.Merge").deepCopy(session)
  -- Prevent manual, scripted and automatic writes to the player's save slots.
  local function noSave() return false,"Saving is disabled during event playtest" end
  Save.save=noSave;Save.writeSlot=noSave;Save.writeCartSlot=noSave
  game.saveGame=noSave
  session.map=target.map;session.x=target.x;session.y=target.y;session.facing=target.facing or "up"
  local map=assert(game.data.maps[target.map],"Event map is unavailable")
  -- Map-entry scripts must not compete with the explicitly selected event.
  local entry=map.mapScripts;map.mapScripts={}
  local ok,err=pcall(game._enterField,game,session,"event_playtest")
  map.mapScripts=entry
  assert(ok,err)
  local Space=require("src.core.game3.scripting.space")
  assert(Space.vm,"Event interpreter did not initialize")
  if Space.vm:isRunning() then Space.vm:halt(true) end
  assert(Space.startScript(target.script,target.actor,2),"Could not start selected event: "..target.script)
  love.window.setTitle("Event playtest - "..target.script.." (saving disabled)")
  -- The runtime updates and handles real keyboard/controller input between yields.
  while true do coroutine.yield() end
end
]=]
local serial=0
function M.prepare(request)
  local source=M.source(request)
  local fs=love.filesystem
  local directory="event-playtests"
  local ok,err=fs.createDirectory(directory)
  if not ok then return nil,"Could not create playtest directory: "..tostring(err) end
  serial=serial+1
  local stamp=string.format("%.0f",love.timer.getTime()*1000000)
  local relative=directory.."/event-"..os.time().."-"..stamp.."-"..serial..".lua"
  ok,err=fs.write(relative,source)
  if not ok then return nil,"Could not write playtest driver: "..tostring(err) end
  return fs.getSaveDirectory():gsub("[/\\]+$","").."/"..relative
end
function M.command(command,path,windows)
  -- The environment applies only to the launched child process.
  if windows then
    assert(not path:find('["%%!\r\n]'),"Unsafe driver path")
    return 'set "POKEPORT_DRIVER='..path..'" && '..command
  end
  local quoted="'"..path:gsub("'","'\\''").."'"
  return 'export POKEPORT_DRIVER='..quoted..'; '..command
end
return M
