local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local runtime=assert(os.getenv("POKEPORT_RECOMP")):gsub("\\","/")
local cache=assert(os.getenv("POKEPORT_GEN3_CACHE")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/content-editor/panels/?.lua;"
  ..root.."/tools/save-editor/?.lua;"..runtime.."/?.lua;"..package.path
local function report(message)
  local f=assert(io.open(root.."/tests/content-editor/terrain3d-towns/result.txt","wb"));f:write(message);f:close()
end
love.errorhandler=function(err) report(debug.traceback(tostring(err)));return function() return 1 end end
function love.load()
  local ffi=require("ffi");ffi.cdef("int PHYSFS_mount(const char*, const char*, int);")
  local lib=ffi.load(root.."/love/love.dll")
  assert(lib.PHYSFS_mount(root,"",1)~=0);assert(lib.PHYSFS_mount(runtime,"",1)~=0)
  assert(lib.PHYSFS_mount(cache,"event-cache",1)~=0)
  -- Read-only native dataset/UI assets, including route-name popups.
  assert(lib.PHYSFS_mount(cache:gsub("/[^/]+$",""),"",0)~=0)
  require("src.core.game3.dataset").cacheRootOverride=cache.."/data/generated/gba"
  require("src.core.game3.items_data").installPack(dofile(cache.."/data/generated/gba/items/pack.lua"))
  require("src.core.GameVersion").set(os.getenv("POKEPORT_VERSION") or "firered")
  local data={}
  require("Gen3").load(data,function(path)
    local f=io.open(cache.."/"..path,"rb");if not f then return end
    local bytes=f:read("*a");f:close();return require("src.import.CacheBlob").decode(path,bytes)
  end,function(path)
    local entries={}
    for _,name in ipairs(love.filesystem.getDirectoryItems("event-cache/"..path)) do
      entries[#entries+1]={name=name,type=love.filesystem.getInfo("event-cache/"..path.."/"..name).type}
    end
    return entries
  end)
  local output=root.."/tests/content-editor/terrain3d-towns"
  local drawGame=dofile(root.."/tests/content-editor/test_town_3d_game.lua")(data,root,output,os.getenv("POKEPORT_VERSION") or "firered")
  love.draw=function()
    if not drawGame() then return end
    love.graphics.captureScreenshot(function(pixels)
      local f=assert(io.open(output.."/"..os.getenv("POKEPORT_VERSION").."-in-game.png","wb"));f:write(pixels:encode("png"):getString());f:close()
      report("PASS: native 3D town walking, slopes, camera and entrances")
      love.event.quit()
    end)
    love.draw=function() end
  end
end
