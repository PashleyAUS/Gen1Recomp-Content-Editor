return function(path)
  local E=require("Gen3GlyphEditor")
  local IO=require("ModIO")
  local p={gen3Fonts={drawn={_blank=true,image="assets/font/blank.png",base=256,
    glyphsPerRow=2,cellWidth=8,cellHeight=8,advance=7,charmap={{seq="A",code=256}}}}}
  local S={project=p,path=path}
  local e=E.open(S,"drawn",1)
  E.checkpoint(e);E.line(e,0,0,7,7,false)
  for i=0,7 do local _,_,_,a=e.foreground:getPixel(i,i);assert(a==1) end
  e.layer="shadow";E.checkpoint(e);E.paint(e,1,0,false)
  assert(E.undo(e));local _,_,_,a=e.shadow:getPixel(1,0);assert(a==0)
  assert(E.undo(e,true));_,_,_,a=e.shadow:getPixel(1,0);assert(a==1)
  E.checkpoint(e);E.paint(e,1,0,true);_,_,_,a=e.shadow:getPixel(1,0);assert(a==0)
  E.undo(e);E.apply(S,e)
  local page=p.gen3Fonts.drawn
  assert(page.image~=page.shadowImage and not page._blank)
  local original=assert(IO.readText(path.."/"..page.image))
  local originalPath=page.image
  page.charmap[2]={seq="B",code=258,advance=5}
  e=E.open(S,"drawn",2)
  assert(e.sheets.foreground:getHeight()==16,"new rows must expand the sheet")
  E.checkpoint(e);E.paint(e,7,0,false);E.apply(S,e)
  assert(page.image~=originalPath and IO.readText(path.."/"..originalPath)==original,"original sheet must stay unchanged")
  e=E.open(S,"drawn",1)
  for i=0,7 do local _,_,_,v=e.foreground:getPixel(i,i);assert(v==1,"neighbor glyph changed") end
  _,_,_,a=e.shadow:getPixel(1,0);assert(a==1,"shadow lost on round trip")
  e=E.open(S,"drawn",2);_,_,_,a=e.foreground:getPixel(7,0);assert(a==1)
  local old=page.image
  E.paint(e,0,0,false);S.g3GlyphEditor=nil
  e=E.open(S,"drawn",2);_,_,_,a=e.foreground:getPixel(0,0);assert(a==0,"Cancel must discard pixels")
  local write=IO.writeText;IO.writeText=function() return false,"test write failure" end
  local ok=pcall(E.apply,S,e);IO.writeText=write
  assert(not ok and page.image==old and S.g3GlyphEditor==e,"Failed apply must preserve project and pending pixels")
  local W=require("ModWriter")
  local restored=assert(loadstring(W.serializeProject(p)))()
  assert(restored.gen3Fonts.drawn.charmap[2].advance==5)
  require("Gen3FontsRuntime").build(restored.gen3Fonts,function(rel)
    return love.graphics.newImage(love.filesystem.newFileData(assert(IO.readText(path.."/"..rel)),"font.png"))
  end,love.graphics.newQuad)
  print("PASS glyph pixel editor: blank sheets, both layers, interpolated strokes, erase, undo/redo, grow, neighbor preservation, cancel, write failure, save/runtime roundtrip")
end
