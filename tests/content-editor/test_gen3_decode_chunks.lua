local runtime=assert(os.getenv("POKEPORT_RECOMP"))
package.path="tools/content-editor/?.lua;"..runtime.."/?.lua;"..package.path
local Decode=require("Gen3Decode")
local limits={allowArray=true,allowComments=true}
local chunked=table.concat({
  "local T = {}",
  "do (function(T)",
  'T["EM_ROUTE101"] = {',
  "    objects = { { localId = 1, x = 4 } },",
  "  }",
  'T["EM_ROUTE102"] = { music = "MUS_ROUTE101" }',
  "end)(T) end",
  "do (function(T)",
  'T["Text_Hi"] = { { t = "text", s = "end)(T) end" }, { t = "eos" } }',
  "end)(T) end",
  "return T",
},"\n")
local value=assert(Decode.decode(chunked,limits))
assert(value.EM_ROUTE101.objects[1].x==4 and value.EM_ROUTE102.music=="MUS_ROUTE101")
assert(value.Text_Hi[1].s=="end)(T) end","Chunk markers inside strings are data")
assert(Decode.decode(chunked:gsub("\n","\r\n"),limits).EM_ROUTE102,"CRLF chunks")
local function rejects(bytes,why) assert(Decode.decode(bytes,limits)==nil,why) end
rejects("local T = {}\ndo (function(T)\nT[\"x\"] = os.exit()\nend)(T) end\nreturn T","Calls are not data")
rejects("local T = {}\nprint(1)\nreturn T","Unknown statements are rejected")
rejects("local T = {}\nreturn T\nos.exit()","Nothing may follow return T")
rejects("local T = {}\nT[\"x\"] = {}","A chunked file must end with return T")
assert(Decode.decode("return { a = 1 }",limits).a==1,"Plain tables still decode")
print("PASS: chunked Gen 3 caches decode as data; code is rejected")

local quoted=assert(Decode.decode([=[return {layout='rs',label='Birch\'s "Pokemon"',slash='a\\b',double="player's",nilValue=nil}]=],limits))
assert(quoted.layout=="rs" and quoted.label==[[Birch's "Pokemon"]] and quoted.slash==[[a\b]] and quoted.double=="player's" and quoted.nilValue==nil)
assert(Decode.decode([==[--[=[ an unmatched ' in a comment ]=]
return {layout='rs'}]==],limits).layout=="rs")
rejects("return {layout='rs',evil=os.exit()}","Single quotes must not allow executable code")
rejects("return {layout='unterminated}","Unterminated strings rejected")
print("PASS: single-quoted RS manifests, escaped quotes, nil fields and code rejection")
