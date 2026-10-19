local M={}
function M.capture(id,name,draw,native)
 local w,h=love.graphics.getDimensions()
 local canvas=love.graphics.newCanvas(w,h)
 love.graphics.push('all');love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(0.03,0.04,0.07,1)
 if native then love.graphics.scale(math.min(w/240,h/160)) end
 draw();love.graphics.pop()
 local path=assert(os.getenv('EDITOR_TEST_ROOT'))..'/tests/content-editor/rules-ingame/gameplay-'..id..'-'..name..'.png'
 local f=assert(io.open(path,'wb'));f:write(canvas:newImageData():encode('png'):getString());f:close()
 return path
end
return M
