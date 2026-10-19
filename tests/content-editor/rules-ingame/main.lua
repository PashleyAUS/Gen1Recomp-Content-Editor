local root=assert(os.getenv('EDITOR_TEST_ROOT')):gsub('\\','/')
local runtime=root..'/runtime/gen1recomp'
local gameId=assert(os.getenv('RULE_TEST_GAME'))
local cache=assert(os.getenv('APPDATA')):gsub('\\','/')..'/LOVE/pokemon-love2d'
package.path=root..'/tools/content-editor/?.lua;'..root..'/tools/content-editor/panels/?.lua;'..root..'/tools/save-editor/?.lua;'..runtime..'/?.lua;'..package.path
local ffi=require('ffi');ffi.cdef('int PHYSFS_mount(const char*,const char*,int);')
local lib=ffi.load(root..'/love/love.dll')
for _,p in ipairs({root,runtime,cache}) do assert(lib.PHYSFS_mount(p,'',1)~=0) end
assert(lib.PHYSFS_mount(cache..'/'..gameId,'',0)~=0)
local function report(s)
 local suffix=os.getenv('RULE_TEST_GAMEPLAY')=='1' and '-gameplay-result.txt' or '-result.txt'
 local path=root..'/tests/content-editor/rules-ingame/'..gameId..suffix
 local f,err
 for attempt=1,100 do
  f,err=io.open(path,'wb')
  if f then break end
  love.timer.sleep(0.005)
 end
 assert(f,err);f:write(s);f:close()
end
love.errorhandler=function(e) report(debug.traceback(tostring(e)));return function() return 1 end end
local game,frame
function love.load()
 require('src.core.GameVersion').set(gameId)
 local IO=require('ModIO')
 local project=require('State').blankProject('rules_audit_'..gameId)
 project.game=gameId
 local gen=require('Generation').num({version=gameId})
 if gen==3 then project.gen3BattleRules={shinyBelow=65536} end
 local dir=root..'/tests/content-editor/rules-ingame/mod-'..gameId
 assert(IO.ensureDirectory(dir));assert(IO.writeText(dir..'/manifest.json',require('src.link.Json').encode({id=project.id,name=project.id,version='1.0.0',games={gameId},entry='main.lua'})));assert(IO.save(dir,project))
 assert(lib.PHYSFS_mount(dir,'mods/'..project.id,0)~=0)
 local items=love.filesystem.getDirectoryItems
 love.filesystem.getDirectoryItems=function(p) if p=='mods' then return {project.id} end return items(p) end
 local Save=require('src.core.SaveData');local opts=Save.defaultOptions()
 opts.mods={[project.id]=true};opts.modsByVersion={[gameId]={[project.id]=true}}
 Save.loadOptions=function() return opts end;Save.saveOptions=function() return true end
 Save.load=function() return nil end;Save.save=function() return true end
 Save.writeSlot=function() return true end;Save.writeCartSlot=function() return true end
 if gen~=3 then
  if gen==2 then
   game=require('src.core.Game2').new();game:load();game.stack:clear();assert(game:startWorld(),tostring(game.status))
  else
   game=require('src.core.Game');game:load();game:startNewGame({intro=false})
  end
  assert(game.mods.mods[project.id].state=='loaded')
  package.path=root..'/tests/content-editor/?.lua;'..package.path
  if os.getenv('RULE_TEST_GAMEPLAY')=='1' then require('GameplayRules').run(game,gameId,root,report) else require('AllRulesLive').run(game,gameId,root,report) end
  love.update=function() love.event.quit() end
  return
 end
 game=require('src.core.Game3').new();game:load()
 assert(game.mods.mods[project.id].state=='loaded',require('ModWriter').encodeLua(game.modStatus))
 local map=(gameId=='firered' or gameId=='leafgreen') and 'PALLET_TOWN' or 'LITTLEROOT_TOWN'
 map=require('Generation').gen3MapPrefix({version=gameId})..map
 game:_handleBootAction({action='new_game',name='RULE TEST',gender=0,start={map=map,x=5,y=5,facing='down'}})
 assert(game.phase=='field')
 local Space=require('src.core.game3.scripting.space');if Space.vm and Space.vm:isRunning() then Space.vm:halt(true) end
 assert(require('src.core.game3.pokemon').SHINY_BELOW==65536,'shiny rule not applied')
  assert(require('src.core.game3.pokemon').isShiny(require('src.core.game3.battle.trainer_rs').prepareMon({personality=0})), 'trainer preparation with 100% shinies')
 if os.getenv('RULE_TEST_ALL')=='1' then
  package.path=root..'/tests/content-editor/?.lua;'..package.path
  if os.getenv('RULE_TEST_GAMEPLAY')=='1' then require('GameplayRules').run(game,gameId,root,report) else require('AllRulesLive').run(game,gameId,root,report) end
  love.update=function() love.event.quit() end
  return
 end
 local R=require('Gen3BattleRules');local W=require('ModWriter');local count=0
 for _,row in ipairs(R.fields) do
  for _,n in ipairs({row.min,row.max}) do
   local values={[row.key]=n}
   if row.key=='damageRollMax' then values.damageRollMin=n end
   if row.key=='partialTrapMinTurns' then values.partialTrapMaxTurns=n end
   if row.key=='partialTrapMaxTurns' then values.partialTrapMinTurns=n end
   local out={};R.emit({game=gameId,gen3BattleRules=values},W.encodeLua,out)
   local f=assert(loadstring(table.concat(out,'\n')))
   setfenv(f,setmetatable({mod={hooks={wrap=function(_,name,fn) return require('src.mods.Runtime').hooks:wrap(name,fn,0,'rule_boundary_audit') end}}},{__index=_G}))
   assert(pcall(f),gameId..' '..row.key)
   game:fixedUpdate(1/60);game:draw()
   local reset={};R.emit({game=gameId,gen3BattleRules={[row.key]=row.default}},W.encodeLua,reset)
   local restore=assert(loadstring(table.concat(reset,'\n')));setfenv(restore,getfenv(f));restore()
   require('src.mods.Runtime').hooks:removeOwner('rule_boundary_audit')
   count=count+1
  end
 end
 report('RUNNING: '..count..' rule boundary changes in Game3')
 frame=0
end
function love.update()
 frame=frame+1;game:fixedUpdate(1/60)
 if frame==10 then report('PASS: '..gameId..' exported shiny rule, 178 battle rule boundary changes, Game3 boot and field update/draw');love.event.quit() end
end
function love.draw() game:draw() end






