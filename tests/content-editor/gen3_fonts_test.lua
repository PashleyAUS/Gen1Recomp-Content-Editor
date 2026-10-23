package.path = "tools/content-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
local R = require("Gen3FontsRuntime")
local page = {image="assets/font/test.png", base=256, glyphsPerRow=4, advance=9,
  cellWidth=16, cellHeight=16,
  charmap={{seq="é",code=256},{seq="あ",code=257},{seq="sh",code=258},{seq=" ",code=259}}}
local pages = {language=page}
local image = {getDimensions=function() return 64,16 end, setFilter=function() end}
local draws = {}
love = {graphics={newQuad=function(...) return {...} end,
  setColor=function() end, rectangle=function() end,
  draw=function(img,q,x,y) draws[#draws+1]={image=img,quad=q,x=x,y=y} end},
  filesystem={read=function(path) local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end}}
local glyphs, match = R.build(pages,function() return image end,love.graphics.newQuad)
assert(match("shé",1)=="sh" and match("shé",3)=="é")
assert(glyphs["あ"].quad[1]==16 and glyphs["あ"].advance==9)
local function fails(fn) assert(not pcall(fn),"expected validation failure") end
page.charmap[1].code=260; fails(function() R.build(pages,function() return image end,love.graphics.newQuad) end);page.charmap[1].code=256
page.charmap[1].seq=string.char(0xED,0xA0,0x80);fails(function() R.validate(pages) end);page.charmap[1].seq="é"
page.image="assets/../font.png";fails(function() R.validate(pages) end);page.image="assets/font/test.png"
local hooks, enabled = {}, true
package.loaded["src.mods.Runtime"]={call=function(name,base,...)
  if enabled and hooks[name] then return hooks[name](base,...) end
  return base(...)
end}
local F=require("src.ui.game3.frlg_font")
local mod={assets={image=function() return image end},hooks={wrap=function(_,name,fn) hooks[name]=fn end}}
R.install(mod,pages)
local id=F.glyphId("あ")
assert(id==0x100101 and F.advance(id)==9)
assert(F.measure("éあsh")==27)
assert(F.measure("éあsh",{small=true})==27)
assert(F.wrap("é あ sh",18)=="é\nあ\nsh")
assert(F.countChars("éあsh")==3)
local tokens=F.scanTokens("é\n{COLOR RED}あ")
assert(tokens()=="char");assert(tokens()=="nl");assert(tokens()=="ctrl");assert(tokens()=="char")
-- Supply native faces without requiring a ROM cache; exercise the real draw loop.
local face={name="normal",fg={},quads={},widths={[0]=6},pitch=16}
for i=1,100 do
  local name=debug.getupvalue(F.draw,i)
  if not name then break end
  if name=="faceFor" then debug.setupvalue(F.draw,i,function() return face end);break end
end
for _, native in ipairs({false,true}) do
  face.nativeIndexed=native
  draws={}
  local count,x=F.draw("éあsh",0,0,{maxWidth=27})
  assert(count==3 and x==27 and #draws==3)
  assert(draws[2].image==image and draws[2].x==9)
  draws={};F.draw("éあsh",0,0,{limitChars=2});assert(#draws==2)
end
assert(F.drawGlyph(id,0,0,{small=true})==9)
enabled=false;assert(F.customGlyph(id)==nil and F.customMatch("あ",1)==nil)
enabled=true;assert(F.customGlyph(id).advance==9)
local W=require("ModWriter")
local project={gen3Fonts=pages}
local restored=assert(loadstring(W.serializeProject(project)))()
assert(restored.gen3Fonts.language.charmap[2].seq=="あ")
local out={};require("Gen3Fonts").emit(project,W.encodeLua,out)
local exported=assert(loadstring("return function(mod)\n"..table.concat(out,"\n").."\nend"))()
hooks={};exported(mod)
assert(F.measure("éあsh")==27,"exported runtime must install the saved mappings")
print("Gen 3 font validation, rendering, wrapping, lifecycle and export tests passed")
