local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local output=assert(os.getenv("ADVENTURE_TEST_OUTPUT")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/content-editor/panels/?.lua;"
  ..root.."/tools/save-editor/?.lua;"..root.."/runtime/gen1recomp/?.lua;"..package.path
local ffi=require("ffi")
ffi.cdef("int PHYSFS_mount(const char*,const char*,int); int PHYSFS_setWriteDir(const char*);")
local phys=ffi.load(root.."/love/love.dll")
assert(phys.PHYSFS_mount(root,"",1)~=0)
assert(phys.PHYSFS_mount(root.."/runtime/gen1recomp","",1)~=0)
local function report(text)
  local f=assert(io.open(root.."/tests/content-editor/adventure-smoke/result.txt","wb"));f:write(text);f:close()
end
love.errorhandler=function(err) report(debug.traceback(tostring(err)));return function() return 1 end end
function love.load()
  local IO=require("ModIO");assert(IO.ensureDirectory(output))
  assert(phys.PHYSFS_setWriteDir(output)~=0)
  love.filesystem.getSaveDirectory=function() return output end
  require("src.core.GameVersion").set("firered")
  local data={};require("Gen3").load(data,function() return "return {}" end)
  local S={data=data,version="firered",project=assert(IO.load(output.."/firered")),path=output.."/firered"}
  local K=require("Kit");local App={markDirty=function() error("Browsing changed project") end}
  S.g3EventMode="workflow"
  local before=require("ModWriter").encodeLua(S.project)
  for _,size in ipairs({{1360,860},{720,540}}) do
    local canvas=love.graphics.newCanvas(size[1],size[2])
    love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(.04,.06,.12,1)
    K.layout(size[1],size[2]);K.beginFrame(0,0,false,0)
    require("Gen3Events").draw(S,20,80,size[1]-40,size[2]-100,App)
    K.endFrame();love.graphics.setCanvas()
    assert(IO.writeText(output.."/workflow-"..size[1]..".png",canvas:newImageData():encode("png"):getString()))
  end
  assert(require("ModWriter").encodeLua(S.project)==before)
  -- Exercise the actual create button, then the branch-editor navigation.
  S.adventure.map=next(S.project.maps);S.adventure.x="4";S.adventure.y="2"
  local originalButton=K.button;local clicked=false;local dirty=0
  App.markDirty=function() dirty=dirty+1 end
  K.button=function(x,y,w,h,label,opts)
    if label=="Create and attach cutscene" and not clicked then clicked=true;return true end
    return originalButton(x,y,w,h,label,opts)
  end
  local canvas=love.graphics.newCanvas(1360,860)
  love.graphics.setCanvas({canvas,stencil=true});K.layout(1360,860);K.beginFrame(0,0,false,0)
  require("AdventureWorkflow").draw(S,20,80,1320,740,App);K.endFrame();love.graphics.setCanvas()
  K.button=originalButton
  assert(dirty==1 and S.adventure.created and not S.adventure.place)
  assert(S.project.maps[S.adventure.map].objects[2].scriptKey==S.adventure.created)
  K.button=function(x,y,w,h,label,opts)
    if label=="Edit Yes path" then return true end
    return originalButton(x,y,w,h,label,opts)
  end
  love.graphics.setCanvas({canvas,stencil=true});K.beginFrame(0,0,false,0)
  require("AdventureWorkflow").draw(S,20,80,1320,740,App);K.endFrame();love.graphics.setCanvas()
  K.button=originalButton
  assert(S.g3EventMode=="cutscenes" and S.g3CutsceneId==S.adventure.created.."_Yes")
  assert(require("LayeredMap").compileProject(S));assert(IO.save(S.path,S.project))
  assert(IO.ensureDirectory(S.path.."/assets"));assert(IO.writeText(S.path.."/assets/custom.txt","custom asset"))
  assert(IO.ensureDirectory(S.path.."/data"));assert(IO.writeText(S.path.."/data/settings.lua","return {}"))
  assert(IO.writeText(S.path.."/rom.gba","excluded fixture"))
  assert(IO.ensureDirectory(S.path.."/assets/generated"));assert(IO.writeText(S.path.."/assets/generated/cache.bin","excluded fixture"))
  local Share=require("ModShare")
  local exported,omitted=Share.export(S.path,S.project)
  assert(exported,omitted);assert(#omitted==2,table.concat(omitted,"\n"))
  assert(IO.writeText(output.."/export-path.txt",exported))
  -- Real PhysFS archive mounting and versioned unpacking, without a ROM.
  local runtimeZip=Share.zip({
    {name="main.lua",data="-- POKEPORT_DRIVER fixture\nfunction love.load() end"},
    {name="conf.lua",data="function love.conf(t) t.identity='fixture' end"},
    {name="src/nested/file.lua",data="return 42"},
  })
  assert(IO.writeText(output.."/runtime.love",runtimeZip))
  local Runtime=require("PlaytestRuntime")
  local unpacked=assert(Runtime.unpack(output.."/runtime.love"))
  assert(IO.readText(unpacked.."/src/nested/file.lua")=="return 42")
  assert(Runtime.unpack(output.."/runtime.love")==unpacked,"Unchanged runtime was unpacked twice")
  assert(IO.writeText(output.."/runtime.love",Share.zip({{name="main.lua",data="-- changed runtime"}})))
  local changed=assert(Runtime.unpack(output.."/runtime.love"));assert(changed~=unpacked)
  assert(IO.readText(changed.."/main.lua")=="-- changed runtime")
  assert(IO.writeText(output.."/fused.exe","MZ"..string.rep("\0",126)..runtimeZip))
  local fused=assert(Runtime.unpack(output.."/fused.exe"))
  assert(IO.readText(fused.."/src/nested/file.lua")=="return 42","Fused executable could not be unpacked")
  assert(IO.writeText(output.."/broken.love",Share.zip({{name="oops.txt",data="no main"}})))
  local bad,err=Runtime.unpack(output.."/broken.love");assert(not bad and err:find("no main.lua",1,true))
  report("PASS: workflow UI at 1360/720, read-only browsing, real ZIP export, filtering, editable project, runtime unpack/cache/versioning/failure")
  love.event.quit()
end
