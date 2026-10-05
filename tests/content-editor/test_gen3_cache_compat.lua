package.path="tools/content-editor/?.lua;"..package.path
local Blob=require("Gen3CacheBlob")
package.preload["src.import.CacheBlob"]=function() error("old runtime") end
assert(Blob.decode("firered/test.rgba","raw")=="raw")
package.loaded["src.import.CacheBlob"]=nil
package.preload["src.import.CacheBlob"]=function()
  return {decode=function(path,bytes)
    assert(path=="ruby/test.idx" and bytes=="deflated")
    return "decoded"
  end}
end
assert(Blob.decode("ruby/test.idx","deflated")=="decoded")
assert(Blob.decode("ruby/missing.rgba",nil)==nil)
package.loaded["src.core.GameVersion"]={cachePrefix=function(id) return id.."/" end,
  revisions=function() return {{sha1="abcd"}} end}
package.loaded["src.import.CacheContract"]={VERSION_FORMAT={firered="rom-cache-v25-firered:",leafgreen="rom-cache-v10-leafgreen:",emerald="rom-cache-v5-emerald:"}}
for _,case in ipairs({{"Gen3FrLinkRuntime","firered",25},{"Gen3EmLinkRuntime","emerald",5}}) do
  local R=require(case[1])
  local function reader(v) return function(path)
    if path==case[2].."/rom-cache.complete" then return "rom-cache-v"..v.."-"..case[2]..":abcd" end
  end end
  assert(R.find(reader(case[3])))
  assert(not R.find(reader(case[3]-1)))
end
package.loaded["src.core.game3.profile"]={of=function(id)
  return {map={enginePrefix=({ruby="RU_",sapphire="SA_",emerald="EM_",firered="FR_"})[id]}}
end}
local Generation=require("Generation")
assert(Generation.gen3MapPrefix({version="ruby"})=="RU_")
assert(Generation.gen3MapPrefix({version="sapphire"})=="SA_")
print("ok cache decode compatibility, stale foreign caches and RS map prefixes")
