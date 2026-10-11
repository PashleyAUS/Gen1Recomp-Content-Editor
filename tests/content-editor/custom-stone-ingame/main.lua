local version=os.getenv("POKEPORT_GAME") or "firered"
local function report(msg)
 local path=os.getenv("EDITOR_TEST_ROOT").."/tests/content-editor/custom-stone-ingame/"..version.."/result.log"
 local f=assert(io.open(path,"ab"));f:write(tostring(msg),"\n");f:close()
end
print=function(...) local t={};for i=1,select('#',...) do t[i]=tostring(select(i,...)) end;report(table.concat(t,' ')) end
local ok,err=xpcall(function()
local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local runtime=root.."/runtime/gen1recomp"
local run=root.."/tests/content-editor/custom-stone-ingame/"..version
local cache=assert(os.getenv("POKEPORT_GEN3_CACHE")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/save-editor/?.lua;"..runtime.."/?.lua;"..package.path
local ffi=require("ffi")
ffi.cdef("int PHYSFS_mount(const char*,const char*,int); int PHYSFS_setWriteDir(const char*);")
local lib=ffi.load(root.."/love/love.dll")
assert(lib.PHYSFS_setWriteDir(run.."/save")~=0)
assert(lib.PHYSFS_mount(run.."/save","",0)~=0)
assert(lib.PHYSFS_mount(runtime,"",1)~=0)
assert(lib.PHYSFS_mount(root,"",1)~=0)
assert(lib.PHYSFS_mount(cache,version,0)~=0)
assert(lib.PHYSFS_mount(cache,"",0)~=0)
assert(lib.PHYSFS_mount(cache.."/data/generated","data/generated",0)~=0)
lib.PHYSFS_mount(cache.."/assets/generated","assets/generated",0)
love.filesystem.getSaveDirectory=function() return run.."/save" end
local function write(path,bytes) local f=assert(io.open(path,"wb"));f:write(bytes);f:close() end
require("src.core.GameVersion").set(version)
local generation=require("Generation").num({version=version})
if generation==3 then
local data={}
require("Gen3").load(data,function(path) local f=io.open(cache.."/"..path,"rb");if not f then return end;local b=f:read("*a");f:close();return b end)
local A=require("Gen3ContentAdapter")
local S={data=data,project=require("State").blankProject("custom_stone_test"),version=version,path=run.."/save/mods/custom_stone_test"}
S.project.game=version
A.prepare(S)
local stone=require("Gen3Create").create(S,"items","FIRE_STONE")
stone.name="TEST STONE"
local mon=require("src.mods.Merge").deepCopy(S.data.pokemon.NIDORINA)
mon.evolutions={{method="EVO_ITEM",item=stone.id,species="NIDOQUEEN"}}
S.project.pokemon.NIDORINA=mon
write(run.."/stone-index.txt",tostring(stone.index))
write(S.path.."/main.lua",require("Gen3").emit(S.project,require("ModWriter").encodeLua))
write(S.path.."/manifest.json",[[{"id":"custom_stone_test","name":"Custom Stone Test","version":"0.1.0","api":2,"entry":"main.lua","profile":"content","games":["]]..version..[["],"permissions":["engine_internals"]}]])
write(run.."/save/options.lua",'return {mods={custom_stone_test=true},modsByVersion={["'..version..'"]={custom_stone_test=true}}}')
else
 local p=require("State").blankProject("custom_stone_test");p.game=version
 p.items.CUSTOM_STONE={id="CUSTOM_STONE",name="TEST STONE",price=300,_isNew=true,effectTemplate="stone",pocket="ITEM",pocketId=1,canToss=true,canSelect=false,fieldMenu="ITEMMENU_PARTY",battleMenu="ITEMMENU_NOUSE",tossable=true,needsTarget=true}
 p.pokemon.WEEPINBELL={_isNew=false,evolutions={{method=generation==2 and "EVOLVE_ITEM" or "ITEM",item="CUSTOM_STONE",[generation==2 and "into" or "species"]="VICTREEBEL"}}}
 write(run.."/save/mods/custom_stone_test/main.lua",require("ModWriter").emitMain(p))
 write(run.."/save/mods/custom_stone_test/manifest.json",require("src.link.Json").encode({id=p.id,name="Custom Stone Test",version="0.1.0",api=2,entry="main.lua",profile="content",games={version},permissions={"engine_internals"}}))
 write(run.."/save/options.lua",'return {mods={custom_stone_test=true},modsByVersion={["'..version..'"]={custom_stone_test=true}}}')
end
local getItems=love.filesystem.getDirectoryItems
love.filesystem.getDirectoryItems=function(path) if path=="mods" then return {"custom_stone_test"} end;return getItems(path) end
print("Export complete, loading runtime")
dofile(runtime.."/main.lua")
local load=love.load;love.load=function(...) print("Starting game");return load(...) end
love.errorhandler=function(err) report(debug.traceback(tostring(err)));return function() return 1 end end

end,debug.traceback)
if not ok then report(err);love.event.quit(1) end









