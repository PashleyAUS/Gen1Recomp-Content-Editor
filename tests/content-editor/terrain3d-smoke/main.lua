local root = assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\", "/")
package.path = root .. "/tools/content-editor/?.lua;" .. package.path
local function report(s)
 local f=assert(io.open(root.."/tests/content-editor/terrain3d-smoke/result.txt","w"));f:write(s);f:close()
end
love.errorhandler=function(e) report(debug.traceback(tostring(e)));return function() return 1 end end
function love.load()
 local M=require("MapPreview3D")
 local source={id="test",cellWidth=12,cellHeight=12,layers={{cells={}}},collision={"water"},gen3Elevation={7}}
 assert(not M.paint(source,-1,0,2));assert(not M.paint(source,0,0,16))
 assert(not M.paint(source,0,0,0));assert(M.paint(source,0,0,4));assert(not M.paint(source,0,0,4))
 assert(source.collision[1]=="water" and source.gen3Elevation[1]==7)
 for y=0,11 do for x=0,11 do
   M.paint(source,x,y,math.max(0,5-math.floor(math.max(math.abs(x-5),math.abs(y-5)))))
   source.layers[1].cells[y*12+x+1]={source="test",tile=(x+y)%2}
 end end
 local texts={}
 package.loaded.Kit={scale=1,mouseX=0,mouseY=0,button=function() return false end,hit=function() return false end,text=function(_,s) assert(type(s)=="string");texts[#texts+1]=s end}
 package.loaded.LayeredMap={sourceResolver=function() return function() return {} end end,
 drawSourceTile=function(_,_,tile,x,y,size)
  love.graphics.setColor(tile==0 and 0.28 or 0.35,0.65,0.25,1);love.graphics.rectangle("fill",x,y,size,size)
  love.graphics.setColor(0.4,0.3,0.15,1);love.graphics.rectangle("line",x,y,size,size)
 end}
 local S={}
 local canvas=love.graphics.newCanvas(800,600)
 love.graphics.setCanvas(canvas);love.graphics.clear(0.1,0.1,0.1,1)
 M.draw(S,source,0,0,800,600)
 M.paint(source,5,5,15)
 M.draw(S,source,0,0,800,600)
 love.graphics.setCanvas()
 local bytes=canvas:newImageData():encode("png")
 local f=assert(io.open(root.."/tests/content-editor/terrain3d-smoke/preview.png","wb"));f:write(bytes:getString());f:close()
 assert(#texts==2)
 S.mapHide3D=true;assert(M.draw(S,source,0,0,800,600)==32)
 report("PASS: real LÖVE canvas/mesh rendering, live height edits, bounds, passage isolation and hide toggle")
 love.event.quit()
end
