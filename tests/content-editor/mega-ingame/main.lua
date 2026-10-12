local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local run=root.."/tests/content-editor/mega-ingame"
local runtime=root.."/runtime/gen1recomp"
local cache=assert(os.getenv("POKEPORT_GEN3_CACHE")):gsub("\\","/")
local function report(msg)
  local f=assert(io.open(run.."/result.log","ab"));f:write(tostring(msg),"\n");f:close()
end
print=function(...) local t={};for i=1,select('#',...) do t[i]=tostring(select(i,...)) end;report(table.concat(t," ")) end
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/save-editor/?.lua;"..runtime.."/?.lua;"..package.path
local ffi=require("ffi")
ffi.cdef("int PHYSFS_mount(const char*,const char*,int); int PHYSFS_setWriteDir(const char*);")
local lib=ffi.load(root.."/love/love.dll")
assert(lib.PHYSFS_setWriteDir(run.."/save")~=0)
assert(lib.PHYSFS_mount(run.."/save","",0)~=0)
assert(lib.PHYSFS_mount(runtime,"",1)~=0)
assert(lib.PHYSFS_mount(root,"",1)~=0)
assert(lib.PHYSFS_mount(cache,"sapphire",0)~=0)
assert(lib.PHYSFS_mount(cache,"",0)~=0)
assert(lib.PHYSFS_mount(cache.."/data/generated","data/generated",0)~=0)
lib.PHYSFS_mount(cache.."/assets/generated","assets/generated",0)
love.filesystem.getSaveDirectory=function() return run.."/save" end
require("src.core.GameVersion").set("sapphire")
local getItems=love.filesystem.getDirectoryItems
love.filesystem.getDirectoryItems=function(path) if path=="mods" then return {"Megas"} end;return getItems(path) end
dofile(runtime.."/main.lua")
