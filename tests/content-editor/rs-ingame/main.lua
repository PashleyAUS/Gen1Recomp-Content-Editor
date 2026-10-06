local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local runtime=root.."/runtime/gen1recomp"
local gameId=assert(os.getenv("RS_TEST_GAME"))
local output=root.."/tests/content-editor/rs-ingame/"..gameId
local cache=assert(os.getenv("POKEPORT_RS_CACHE")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/content-editor/panels/?.lua;"..root.."/tools/save-editor/?.lua;"..runtime.."/?.lua;"..package.path
local ffi=require("ffi");ffi.cdef("int PHYSFS_mount(const char*,const char*,int);")
local lib=ffi.load(root.."/love/love.dll")
assert(lib.PHYSFS_mount(root,"",1)~=0)
assert(lib.PHYSFS_mount(runtime,"",1)~=0)
assert(lib.PHYSFS_mount(cache,"",1)~=0)
assert(lib.PHYSFS_mount(cache.."/"..gameId,"",0)~=0)
local function report(s) local f=assert(io.open(output.."-result.txt","wb"));f:write(s);f:close() end
love.errorhandler=function(e) report(debug.traceback(tostring(e)));return function() return 1 end end
local game,frame,passed,shot= nil,0,false,nil
local starterShown=false
function love.load()
 local GV=require("src.core.GameVersion");GV.set(gameId)
 local IO=require("ModIO");local G=require("Gen3");local data={}
 G.load(data,function(path) return IO.readText(cache.."/"..gameId.."/"..path) end)
 local prefix=require("Generation").gen3MapPrefix({version=gameId})
 local map=prefix.."LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB"
 local project=require("State").blankProject("rs_ingame_"..gameId,"RS In-game Edit Check")
 project.game=gameId
 project.gen3={pokemon={TREECKO={baseStats={hp=77,specialAttack=88}}},moves={POUND={power=69,pp=23}},items={POTION={price=321}},text={EDITOR_RS_MESSAGE="CE "..gameId:upper().." EDITS WORK!"},map_scripts={EDITOR_RS_CHECK={{op="lock"},{op="message",ptr="EDITOR_RS_MESSAGE"},{op="waitmessage"},{op="waitbuttonpress"},{op="closemessage"},{op="release"},{op="end"}}}}
 project.gen3Modes={text={EDITOR_RS_MESSAGE="register"},map_scripts={EDITOR_RS_CHECK="register"}}
 require("Gen3StartersPanel").add({version=gameId,project=project,data=data},"starters")
 project.gen3Starters[1].species="MEW";project.gen3Starters[1].level=28;project.gen3Starters[1].nickname="EDITOR"
 project.gen3.map_scripts.EDITOR_RS_STARTER={{op="special",id=156},{op="end"}}
 project.gen3Modes.map_scripts.EDITOR_RS_STARTER="register"
 project.gen3Terrain={[map]={[1025]={mid=1,coll=0,elev=3}}}
 local dir=root.."/tests/content-editor/rs-ingame/mod-"..gameId
 assert(IO.ensureDirectory(dir))
 assert(IO.writeText(dir.."/manifest.json",require("src.link.Json").encode({id=project.id,name=project.name,version="1.0.0",games={gameId},entry="main.lua"})))
 IO._emitBaseData=data;assert(IO.save(dir,project))
 assert(lib.PHYSFS_mount(dir,"mods/"..project.id,0)~=0)
 local getItems=love.filesystem.getDirectoryItems
 love.filesystem.getDirectoryItems=function(path) if path=="mods" then return {project.id} end;return getItems(path) end
 local Save=require("src.core.SaveData");local opts=Save.defaultOptions()
 opts.mods={[project.id]=true};opts.modsByVersion={[gameId]={[project.id]=true}}
 Save.loadOptions=function() return opts end;Save.saveOptions=function() return true end
 Save.load=function() return nil end;Save.save=function() return true end
 Save.writeSlot=function() return true end;Save.writeCartSlot=function() return true end
 game=require("src.core.Game3").new();game:load()
 assert(game.mods and game.mods.mods[project.id] and game.mods.mods[project.id].state=="loaded",require("ModWriter").encodeLua(game.modStatus))
 game:_handleBootAction({action="new_game",name="CE TEST",gender=0,start={map=map,x=5,y=5,facing="down"}})
 assert(game.phase=="field" and require("src.core.game3.runtime").isActive())
 local Space=require("src.core.game3.scripting.space");if Space.vm and Space.vm:isRunning() then Space.vm:halt(true) end
 local stats=require("src.core.game3.pokemon").stats(277)
 assert(stats.hp==77 and stats.spa==88,"in-game Pokemon stats were not patched")
 local move=require("src.core.game3.battle.moves").get("POUND")
 assert(move.power==69 and move.pp==23,"in-game move was not patched")
 local item=require("src.core.game3.items_data").info("POTION")
 assert(item and item.price==321,"in-game item price was not patched")
 local layout=assert(game.data.maps[map].midLayout)
 assert(layout:midAt(1,1)==1 and layout:elevAt(1,1)==3,"in-game terrain was not patched")
 require("src.core.game3.party").giveMonToPlayer(game.session,277,20)
 assert(game.session.party[1].species==277)
 report("RUNNING: real Game3 field loaded with CE export")
end
function love.update(dt)
 frame=frame+1
 if frame>350 and frame<650 then
  if frame%30==0 then game.input:keypressed("z") end
  if frame%30==1 then game.input:keyreleased("z") end
 end
 game:fixedUpdate(1/60)
 if frame==90 then shot="field" end
 if frame==100 then
  local Space=require("src.core.game3.scripting.space")
  if Space.vm and Space.vm:isRunning() then Space.vm:halt(true) end
  assert(Space.startScript("EDITOR_RS_CHECK",nil,2),"edited script did not start")
 end
 if frame==200 then assert(require("src.ui.game3.message").isOpen(),"edited message was not displayed");shot="dialogue" end
 if frame==215 then
  require("src.ui.game3.message").close()
  local Space=require("src.core.game3.scripting.space");Space.vm:halt(true)
  game.session.party={}
  assert(Space.startScript("EDITOR_RS_STARTER",nil,2))
 end
 if frame>215 and frame<600 then
  local screen=require("src.ui.game3.rse.starter_choose").active()
  if screen then
   if screen.state=="input" then
    screen.selection=0;screen:frame({new={a=true},held={}})
   elseif screen.state=="confirm" then
    if not starterShown then shot="starter";starterShown=true
    elseif frame%5==0 then screen:frame({new={a=true},held={}}) end
   end
  end
 end
 if frame==1100 then
  assert(game.phase=="field")
  assert(starterShown,"native starter selection was not displayed")
  local mon=assert(game.session.party[1],"native RS starter was not given")
  assert(mon.species==151 and mon.level==28 and mon.nickname=="EDITOR","native RS starter bypassed CE edits")
  assert(require("src.core.game3.battle").isActive(),"first battle did not start")
  shot="battle"
 end
 if frame==1115 then
  report("PASS: "..gameId.." real Game3 load, exported mod, field update/draw, patched Pokemon stats and move power/PP, item price and native terrain, party creation, edited dialogue script, native starter selection gives edited Mew Lv28 nickname EDITOR and starts first battle; screenshots captured")
  love.event.quit()
 end
end
function love.draw()
 game:draw()
 if shot then
  local name=shot;shot=nil
  love.graphics.captureScreenshot(function(img)
   local f=assert(io.open(output.."-"..name..".png","wb"));f:write(img:encode("png"):getString());f:close()
  end)
 end
end
