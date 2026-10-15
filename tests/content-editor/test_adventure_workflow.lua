-- Run with bundled LuaJIT from the repository root. No ROM required.
package.path="tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;"..package.path
love=love or {filesystem={read=function(path)
  local f=io.open(path,"rb") or io.open("runtime/gen1recomp/"..path,"rb")
  if not f then return nil end
  local bytes=f:read("*a");f:close();return bytes
end}}
local Writer=require("ModWriter")
local IO=require("ModIO")
local G=require("Gen3")
local B=require("Gen3EventBuilder")
local Preview=require("Gen3CutscenePreview")
local Flags=require("src.core.game3.scripting.flags")
local Vm=require("src.core.game3.scripting.vm")
-- This fixture suite tests control flow, not ROM-backed glyph metrics.
local font=require("src.ui.game3.frlg_font");local measure=font.measure
font.measure=function(text) return #text*6 end
local output=assert(os.getenv("ADVENTURE_TEST_OUTPUT"),"Set ADVENTURE_TEST_OUTPUT to a disposable directory"):gsub("\\","/")
assert(IO.ensureDirectory(output))
for _,game in ipairs({"firered","leafgreen","ruby","sapphire","emerald"}) do
  require("src.core.GameVersion").set(game)
  local data={};G.load(data,function() return "return {}" end)
  local S={data=data,version=game,project=require("State").blankProject("adventure_"..game),path=output.."/"..game}
  S.project.game=game;assert(IO.ensureDirectory(S.path))
  assert(IO.writeText(S.path.."/manifest.json",require("src.link.Json").encode({id=S.project.id,name="Adventure",version="1.0.0",api="1",entry="main.lua",games={game}})))
  require("Gen3Workspace").prepare(S)
  local source=assert(require("LayeredMap").createMap(S,"ADVENTURE",8,6,"test_pair"))
  local d={kind="branch",map=source.id,place=true,x=2,y=2,graphics=19,text="Help me?",yes="Yes path!",no="No path!"}
  local key=assert(B.create(S,d));local object=S.project.maps[source.id].objects[1]
  source=S.project.layeredMaps[source.id]
  assert(object.scriptKey==key and object.graphicsId==19 and object.localId==1)
  local Playtest=require("Gen3EventPlaytest")
  local request=assert(Playtest.request(S,key,source.id,object,1))
  assert(request.x==2 and request.y==3 and request.facing=="up")
  source.collision[3*source.cellWidth+2+1]="solid"
  request=assert(Playtest.request(S,key,source.id,object,1));assert(request.y==1 and request.facing=="down")
  source.collision[3*source.cellWidth+2+1]="walk"
  local before=Writer.encodeLua(S.project)
  assert(not B.create(S,d),"Overlapping characters must be rejected")
  assert(Writer.encodeLua(S.project)==before,"Failed placement changed the project")
  d.x=99;assert(not B.create(S,d));d.x=3;d.yes=""
  assert(not B.create(S,d));assert(Writer.encodeLua(S.project)==before)
  d.yes="Yes path!"
  assert(require("LayeredMap").compileProject(S))
  assert(S.project.gen3.maps[source.id].objects[1].scriptKey==key)
  assert(IO.save(S.path,S.project))
  S.project=assert(IO.load(S.path))
  assert(S.project.maps[source.id].objects[1].scriptKey==key)
  local scripts=S.project.gen3.map_scripts
  for _,yes in ipairs({true,false}) do
    local messages={}
    local a=require("src.core.game3.scripting.adapters").stub({
      openMessageStay=function(text,done) messages[#messages+1]=text;if done then done() end end,
      onMessage=function(text) messages[#messages+1]=text end,
      askYesNo=function(cb) cb(yes) end,
    })
    local vm=Vm.new({store=Flags.newStore(),scripts=scripts,text=S.project.text,adapters=a})
    assert(vm:startTalk(key,1,1))
    for _=1,150 do vm:tick();if not vm:isRunning() then break end end
    assert(not vm:isRunning(),"Branch did not finish")
    local text=table.concat(messages," ")
    assert(text:find(yes and "Yes path!" or "No path!",1,true),text)
    assert(not text:find(yes and "No path!" or "Yes path!",1,true),text)
    local p=Preview.new(scripts[key],S.project.maps[source.id],function(row) return require("Gen3EventActions").text(S,row) end,1,function(id) return scripts[id] end,key)
    local chosen=false;local seen=false
    for _=1,80 do
      Preview.step(p)
      if p.prompt then assert(p.prompt.kind=="choice");Preview.answer(p,yes);chosen=true end
      if p.dialogue and p.dialogue:find(yes and "Yes path!" or "No path!",1,true) then seen=true end
      if p.done then break end
    end
    assert(chosen and seen and p.done and #p.warnings==0,"Preview did not follow the chosen answer")
  end
  local locations=require("Gen3CutsceneMaps").locations({},S.project.maps,scripts,key.."_Yes")
  assert(#locations==1 and locations[1].actor==1,"Branch lost its map/character binding")
  local driver=require("Gen3EventPlaytest").source({map=source.id,script=key,actor=1,x=2,y=3})
  assert(loadstring(driver));assert(driver:find("Saving is disabled",1,true))
  -- The generated runtime module must contain all branch scripts.
  local emitted=assert(IO.readText(S.path.."/main.lua"))
  assert(loadstring(emitted));assert(emitted:find(key.."_Yes",1,true) and emitted:find(key.."_No",1,true))
  local valid,report=require("Gen3WorkflowValidation").validate(S);assert(valid,report)
  local row=scripts[key][#scripts[key]];local savedTarget=row.target
  row.target="MISSING_WORKFLOW_SCRIPT"
  valid,report=require("Gen3WorkflowValidation").validate(S)
  assert(not valid and report:find("MISSING_WORKFLOW_SCRIPT",1,true),report)
  row.target=savedTarget
  print("PASS: "..game.." map + character + both VM/preview branches + compile + save/reopen + runtime export")
end
font.measure=measure
local Share=require("ModShare")
assert(not Share.include("assets/generated",true));assert(Share.include("data",true))
assert(not Share.include("rom.gba",false));assert(not Share.include("progress.sav",false))
assert(Share.include("assets/custom.png",false));assert(Share.include("mapbuilder_transforms.lua",false))
assert(not pcall(Share.zip,{{name="../bad",data="bad"}}))
local zip=Share.zip({{name="adventure/main.lua",data="return function() end"},{name="adventure/assets/custom.bin",data=string.char(0,128,255)}})
assert(IO.writeText(output.."/archive.zip",zip))
print("ZIP_CHECK="..output.."/archive.zip")
