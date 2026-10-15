-- Unpack a pinned .love runtime once into a writable, versioned playtest tree.
-- Linked source checkouts can be launched directly.
local M={}
function M.unpack(archive)
  local fs=love.filesystem
  local f,err=io.open(archive,"rb");if not f then return nil,err end
  local bytes,readErr=f:read("*a");f:close()
  if not bytes then return nil,readErr or "Could not read runtime archive" end
  local digest=love.data.encode("string","hex",love.data.hash("sha256",bytes))
  local root="playtest-runtimes/"..digest
  local absolute=fs.getSaveDirectory():gsub("\\","/").."/"..root
  if fs.getInfo(root.."/.complete","file") then return absolute end
  -- The original archive may already be mounted by RuntimeMount. PhysFS
  -- cannot mount it twice at different points, so use a private copy.
  local copy="playtest-runtimes/"..digest..".love"
  local mount="_playtest_runtime_"..digest
  local created,createErr=fs.createDirectory("playtest-runtimes")
  if not created then return nil,createErr end
  local ok,why=fs.write(copy,bytes);if not ok then return nil,why end
  local copyPath=fs.getSaveDirectory():gsub("\\","/").."/"..copy
  local Mount=require("RuntimeMount")
  ok,why=Mount.mountAt(copyPath,mount)
  if not ok then fs.remove(copy);return nil,why end
  local success,result=pcall(function()
    assert(fs.getInfo(mount.."/main.lua","file"),"Runtime archive has no main.lua")
    local function walk(relative,depth)
      assert(depth<64,"Runtime folders are nested too deeply")
      assert(fs.createDirectory(root..relative))
      for _,name in ipairs(fs.getDirectoryItems(mount..relative)) do
        assert(name~=".." and name~="." and not name:find("[/\\:]"),"Invalid runtime path")
        local rel=relative.."/"..name
        local info=assert(fs.getInfo(mount..rel))
        if info.type=="directory" then walk(rel,depth+1)
        elseif info.type=="file" then assert(fs.write(root..rel,assert(fs.read(mount..rel)))) end
      end
    end
    walk("",0);assert(fs.write(root.."/.complete",digest))
    return absolute
  end)
  Mount.unmountData(copyPath);fs.remove(copy)
  if not success then return nil,tostring(result) end
  return result
end
return M
