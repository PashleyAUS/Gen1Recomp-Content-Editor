-- Edits one tile at a time. Apply writes new sheets so imported assets and
-- older project/undo snapshots keep their original pixel data.
local M = {}
local function copy(data)
  local w,h=data:getDimensions()
  local result=love.image.newImageData(w,h)
  result:paste(data,0,0,0,0,w,h)
  return result
end
local function snapshot(e)
  return {foreground=copy(e.foreground),shadow=copy(e.shadow)}
end
function M.checkpoint(e)
  e.undo[#e.undo+1]=snapshot(e)
  if #e.undo>50 then table.remove(e.undo,1) end
  e.redo={}
end
function M.undo(e,redo)
  local from,to=redo and e.redo or e.undo,redo and e.undo or e.redo
  if #from==0 then return false end
  to[#to+1]=snapshot(e)
  local old=table.remove(from)
  e.foreground,e.shadow=old.foreground,old.shadow
  e.changed=true;return true
end
function M.paint(e,x,y,erase)
  if x<0 or y<0 or x>=e.cw or y>=e.ch then return false end
  local data=e[e.layer]
  local r,g,b,a=data:getPixel(x,y)
  local alpha=erase and 0 or 1
  if a==alpha and (alpha==0 or r==1 and g==1 and b==1) then return false end
  data:setPixel(x,y,1,1,1,alpha);e.changed=true;return true
end
function M.line(e,x0,y0,x1,y1,erase)
  local dx,dy=math.abs(x1-x0),math.abs(y1-y0)
  local sx,sy=x0<x1 and 1 or -1,y0<y1 and 1 or -1
  local err=dx-dy
  while true do
    M.paint(e,x0,y0,erase)
    if x0==x1 and y0==y1 then break end
    local v=2*err
    if v>-dy then err=err-dy;x0=x0+sx end
    if v<dx then err=err+dx;y0=y0+sy end
  end
end
function M.open(S,id,index)
  assert(S.path,"Save the project to a folder before drawing glyphs")
  local page=assert(S.project.gen3Fonts[id])
  local row=assert(page.charmap[index])
  local cw,ch=page.cellWidth or 8,page.cellHeight or 8
  local cols=page.glyphsPerRow or 16
  local tile=row.code-page.base
  assert(cw>=1 and cw<=32 and ch>=1 and ch<=32 and cols>=1 and cols<=256
    and cw%1==0 and ch%1==0 and cols%1==0 and tile>=0 and tile%1==0 and tile<=65535,"Invalid tile dimensions or glyph code")
  local height=(math.floor(tile/cols)+1)*ch
  assert(cols*cw*height<=16777216,"Font sheet is too large; use a new page")
  local function load(path,optional)
    if not path or path=="" then assert(optional,"No foreground sheet");return end
    local bytes=require("ModIO").readText(S.path.."/"..path)
    if not bytes and page._blank and optional then return end
    assert(bytes,"Cannot read "..path)
    local data=love.image.newImageData(love.filesystem.newFileData(bytes,"font.png"))
    local w,h=data:getDimensions()
    assert(w==cols*cw and h%ch==0,"Sheet dimensions do not match the font's tile settings")
    return data
  end
  local fg=load(page.image,page._blank==true)
  local sh=load(page.shadowImage,true)
  if fg and sh then assert(fg:getHeight()==sh:getHeight(),"Foreground and shadow sheets must have identical dimensions") end
  height=math.max(height,fg and fg:getHeight() or 0,sh and sh:getHeight() or 0)
  assert(cols*cw*height<=16777216,"Font sheet is too large")
  local function expand(data)
    local out=love.image.newImageData(cols*cw,height)
    if data then out:paste(data,0,0,0,0,data:getDimensions()) end
    return out
  end
  local e={project=S.project,page=page,id=id,index=index,seq=row.seq,code=row.code,
    cw=cw,ch=ch,cols=cols,sx=tile%cols*cw,sy=math.floor(tile/cols)*ch,
    sheets={foreground=expand(fg),shadow=expand(sh)},layer="foreground",undo={},redo={}}
  for _,layer in ipairs({"foreground","shadow"}) do
    e[layer]=love.image.newImageData(cw,ch)
    e[layer]:paste(e.sheets[layer],0,0,e.sx,e.sy,cw,ch)
  end
  S.g3GlyphEditor=e;return e
end
function M.apply(S,e)
  assert(S.project==e.project and S.project.gen3Fonts[e.id]==e.page,"Font page changed; reopen the glyph")
  local IO=require("ModIO")
  assert(IO.ensureDirectory(S.path.."/assets/font"))
  local paths={}
  for _,layer in ipairs({"foreground","shadow"}) do
    local sheet=copy(e.sheets[layer])
    sheet:paste(e[layer],e.sx,e.sy,0,0,e.cw,e.ch)
    local rel=IO.uniqueAssetPath(S.path,"assets/font/"..e.id:gsub("[^%w_-]","_").."-"..layer..".png")
    local ok,err=IO.writeText(S.path.."/"..rel,sheet:encode("png"):getString())
    assert(ok,err);paths[layer]=rel
  end
  e.page.image,e.page.shadowImage=paths.foreground,paths.shadow
  e.page._blank=nil
  S._gen3FontPreview=nil;S.g3GlyphEditor=nil
  return true
end
function M.draw(S,x,y,w,h,App)
  local e=S.g3GlyphEditor
  local K=require("Kit");local s=K.scale
  if e.project~=S.project then S.g3GlyphEditor=nil;return end
  K.caption(x,y,"Draw glyph: "..e.seq.."  (code "..e.code..")");y=y+30*s
  local bx=x
  local function button(label,width,fn,on)
    if K.button(bx,y,width*s,28*s,label,{kind=on and "primary" or "ghost"}) then fn() end
    bx=bx+(width+8)*s
  end
  button("Foreground",110,function() e.layer="foreground";e.stroke=nil end,e.layer=="foreground")
  button("Shadow",90,function() e.layer="shadow";e.stroke=nil end,e.layer=="shadow")
  button("Pencil",75,function() e.erase=false end,not e.erase)
  button("Eraser",75,function() e.erase=true end,e.erase)
  button(e.solo and "Active layer" or "Both layers",110,function() e.solo=not e.solo end,e.solo)
  y=y+38*s;bx=x
  button("Undo",70,function() M.undo(e);App.markDirty() end)
  button("Redo",70,function() M.undo(e,true);App.markDirty() end)
  button("Clear layer",100,function()
    M.checkpoint(e);e[e.layer]=love.image.newImageData(e.cw,e.ch);e.changed=true;App.markDirty()
  end)
  button("Apply glyph",110,function()
    local ok,err=pcall(M.apply,S,e)
    if ok then App.markDirty();S.status="Glyph applied. Save the project to export it."
    else S.status=tostring(err) end
  end)
  button("Cancel",75,function() S.g3GlyphEditor=nil end)
  y=y+42*s
  K.text("small","Paint white pixels; the game supplies the colors. Apply glyph, then Save.",x,y)
  y=y+26*s
  local cell=math.max(2,math.floor(math.min(24*s,(w-180*s)/e.cw,(h-150*s)/e.ch)))
  local gw,gh=cell*e.cw,cell*e.ch
  local function pixels(px,py,size,grid)
    for cy=0,e.ch-1 do for cx=0,e.cw-1 do
      local _,_,_,fa=e.foreground:getPixel(cx,cy)
      local _,_,_,sa=e.shadow:getPixel(cx,cy)
      if grid and e.solo then
        if e.layer=="foreground" then sa=0 else fa=0 end
      end
      local bg=(cx+cy)%2==0 and .94 or .86
      love.graphics.setColor(bg,bg,bg,1);love.graphics.rectangle("fill",px+cx*size,py+cy*size,size,size)
      if sa>0 then love.graphics.setColor(.35,.55,.85,sa);love.graphics.rectangle("fill",px+cx*size,py+cy*size,size,size) end
      if fa>0 then love.graphics.setColor(.12,.12,.15,fa);love.graphics.rectangle("fill",px+cx*size,py+cy*size,size,size) end
      if grid then love.graphics.setColor(.4,.4,.4,.3);love.graphics.rectangle("line",px+cx*size,py+cy*size,size,size) end
    end end
    love.graphics.setColor(1,1,1,1)
  end
  if not K.mouseDown then e.stroke=nil end
  if K.hit(x,y,gw,gh) then
    local cx,cy=math.floor((K.mouseX-x)/cell),math.floor((K.mouseY-y)/cell)
    if K.mouseClicked then M.checkpoint(e);e.stroke=true;e.lastX,e.lastY=nil,nil end
    if e.stroke and (K.mouseClicked or K.mouseDown) then
      M.line(e,e.lastX or cx,e.lastY or cy,cx,cy,e.erase)
      e.lastX,e.lastY=cx,cy;App.markDirty()
    end
  else e.lastX,e.lastY=nil,nil end
  pixels(x,y,cell,true)
  K.text("small","Combined preview",x+gw+18*s,y)
  pixels(x+gw+18*s,y+28*s,math.min(4*s,140*s/e.cw),false)
  K.text("micro","Blue = shadow",x+gw+18*s,y+40*s+e.ch*math.min(4*s,140*s/e.cw))
end
return M
