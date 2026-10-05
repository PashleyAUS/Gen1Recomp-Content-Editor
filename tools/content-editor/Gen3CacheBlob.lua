-- Cache bytes are deflated by newer runtimes; mod asset bytes remain raw.
local M = {}
function M.decode(path, bytes)
  if bytes == nil then return nil end
  local ok, Blob = pcall(require, "src.import.CacheBlob")
  if ok then return Blob.decode(path, bytes) end
  return bytes
end
return M
