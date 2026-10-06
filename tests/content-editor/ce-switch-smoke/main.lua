local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local ffi=require("ffi");ffi.cdef("int PHYSFS_mount(const char*,const char*,int);")
assert(ffi.load(root.."/love/love.dll").PHYSFS_mount(root,"",1)~=0)
local function report(s) local f=assert(io.open(root.."/tests/content-editor/ce-switch-smoke/result.txt","wb"));f:write(s);f:close() end
love.errorhandler=function(e) report(debug.traceback(tostring(e)));return function() return 1 end end
function love.load()
 local source=love.filesystem.getSource
 if not os.getenv("CE_TEST_FALLBACK") then love.filesystem.getSource=function() return root end end
 local Mount=require("tools.content-editor.RuntimeMount")
 assert(Mount.mount())
 love.filesystem.getSource=function() return root end
 love.filesystem.setRequirePath("tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;tools/save-editor/panels/?.lua;"..love.filesystem.getRequirePath())
 local DS=require("DataSource")
 DS.loadPrefs=function() return {mode="recomp",recompRoot=assert(os.getenv("CE_LINKED_ROOT")),lastVersion="red",useGbcPalettes=true} end
 DS.savePrefs=function() return true end
 local Save=require("src.core.SaveData")
 local options=Save.defaultOptions();Save.loadOptions=function() return options end;Save.saveOptions=function() return true end
 local App=require("App");App.load(nil,{version="red"})
 -- Reproduce a linked data mount that shares the bootstrap runtime directory.
 local codeRoot=os.getenv("CE_TEST_FALLBACK") and assert(os.getenv("CE_LINKED_ROOT")) or root.."/runtime/gen1recomp"
 assert(DS.mountRecomp(codeRoot));DS.unmountLinked()
 assert(love.filesystem.getInfo("src/core/game3/dataset.lua"),"runtime source was unmounted")
 package.loaded["src.core.game3.dataset"]=nil
 assert(require("src.core.game3.dataset").cache)
 love.errorhandler=function(e) report(debug.traceback(tostring(e)));return function() return 1 end end
 local count=0
 local K=require("Kit")
 for _,version in ipairs({"ruby","sapphire","emerald","firered","leafgreen","ruby","sapphire"}) do
  report("RUNNING: switching "..version)
  assert(App.setGameVersion(version))
  local S=App.getState();assert(S.version==version)
  assert(S.data.maps[require("Generation").gen3MapPrefix(S)..((version=="firered" or version=="leafgreen") and "PALLET_TOWN" or "LITTLEROOT_TOWN")],"Selected game maps missing")
  S.project=require("State").blankProject("switch_"..version);S.project.game=version
  for _,tab in ipairs({"project","pokemon","moves","items","trainers","encounters","maps","dialog","events","ui","player"}) do
   S.tab=tab
   K.layout(1360,860)
   report("RUNNING: "..version.." "..tab)
   local ok,err=xpcall(App.draw,debug.traceback);assert(ok,err)
   count=count+1
  end
  S.tab="ui"
  for _,mode in ipairs({"credits","intro","oak","menus","bag","party","summary","backgrounds","minigames","battle","town","fonts","dex","trainer","naming","overworld","banners","all"}) do
   S.g3UiMode=mode
   report("RUNNING: "..version.." UI "..mode)
   local ok,err=xpcall(App.draw,debug.traceback);assert(ok,err)
   count=count+1
  end
 end
 report("PASS: actual CE startup, shared-runtime unlink and lazy dataset require, repeated Ruby/Sapphire/Emerald/FRLG switching, "..count.." editor tab draws")
 love.event.quit()
end
