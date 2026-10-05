local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/save-editor/?.lua;"..root.."/runtime/gen1recomp/?.lua;"..package.path
function love.load()
  local read=love.filesystem.read
  love.filesystem.read=function(path,...)
    if path:match("^tools/") then
      local f=io.open(root.."/"..path,"rb")
      if f then local bytes=f:read("*a");f:close();return bytes end
    end
    return read(path,...)
  end
  local ok,err=xpcall(function() dofile(root.."/tests/content-editor/"..(os.getenv("EDITOR_FRAME_TEST") or "test_gen3_pokemon_frames.lua")) end,debug.traceback)
  local f=assert(io.open(root.."/tests/content-editor/frames-smoke/result.txt","w"))
  f:write(ok and "PASS" or err);f:close()
  if not ok then love.event.quit(1) else love.event.quit(0) end
end
