-- Cache bytes are deflated by newer runtimes; mod asset bytes remain raw.
local M = {}
function M.decode(path, bytes)
  if bytes == nil then return nil end
  -- Older imports stored native indexed atlases directly. Their SVMI header
  -- identifies the format unambiguously; native_pack validates the contents
  -- when the tileset is loaded. Do not swallow failed compressed decodes.
  if type(path) == "string" and path:match("%.idx$")
      and type(bytes) == "string" and bytes:sub(1, 4) == "SVMI" then
    return bytes
  end
  local ok, Blob = pcall(require, "src.import.CacheBlob")
  if ok then return Blob.decode(path, bytes) end
  return bytes
end
return M
