-- Fixed connection offsets keep the camera and geometry in one coordinate space.
local M={}
function M.place(maps,anchor,connections)
  local placed={[anchor]={x=0,y=0}};local queue={anchor};local head=1
  while queue[head] do
    local id=queue[head];head=head+1
    local source,p=maps[id],placed[id]
    for _,c in ipairs(connections(id)) do
      local other=maps[c.map]
      if other and not placed[c.map] then
        local x,y=p.x,p.y;local offset=c.offset or 0
        if c.dir=='north' then x,y=x+offset,y-other.cellHeight
        elseif c.dir=='south' then x,y=x+offset,y+source.cellHeight
        elseif c.dir=='west' then x,y=x-other.cellWidth,y+offset
        elseif c.dir=='east' then x,y=x+source.cellWidth,y+offset end
        placed[c.map]={x=x,y=y};queue[#queue+1]=c.map
      end
    end
  end
  return placed,queue
end
function M.build(maps,placed,ids,objects,cx,cy,span)
  span=span or 80
  local left,top=math.floor((cx-span/2)/8+.5)*8,math.floor((cy-span/2)/8+.5)*8
  local first=maps[ids[1]]
  local view={cellWidth=span,cellHeight=span,layers={{cells={}}},collision={},visualHeights={},visualShapes={},
    visualObjects={},visualAutoObjects=false,visualTreeStyle=first.visualTreeStyle,
    visualTint=first.visualTint,visualPerspective=first.visualPerspective,baseTileset=first.baseTileset}
  local owners={};local ground,tree
  for _,id in ipairs(ids) do
    local src=maps[id]
    if src.visualNativeCutouts then view.visualNativeCutouts=true end
    if src.visualProfileVersion then view.visualProfileVersion=src.visualProfileVersion end
    if not ground then
      for i,mode in ipairs(src.collision) do
        if mode=='walk' or (mode=='water' and src.visualEnvironment=='underwater') then ground={id=id,x=(i-1)%src.cellWidth,y=math.floor((i-1)/src.cellWidth)};break end
      end
    end
    -- Emerald border trees omit the crown row. Prefer a complete, taller sprite.
    for _,o in ipairs(objects[id]) do
      if o.kind=='tree' and (not tree or o.height>tree.o.height) then tree={id=id,o=o} end
    end
    local p=placed[id]
    for y=math.max(0,top-p.y),math.min(src.cellHeight-1,top+span-1-p.y) do
      for x=math.max(0,left-p.x),math.min(src.cellWidth-1,left+span-1-p.x) do
        local sx,sy=x+p.x-left,y+p.y-top
        local i=sy*span+sx+1;local original=y*src.cellWidth+x+1
        owners[i]={id=id,x=x,y=y}
        view.layers[1].cells[i]=src.layers[1].cells[original]
        view.collision[i]=src.collision[original]
        view.visualHeights[i]=(src.visualHeights or {})[original]
        view.visualShapes[i]=(src.visualShapes or {})[original]
      end
    end
    for _,o in ipairs(objects[id]) do
      local x,y=o.x+p.x-left,o.y+p.y-top
      if x>=0 and y>=0 and x+o.width<=span and y+o.height<=span then
        local item={};for k,v in pairs(o) do item[k]=v end
        item.x,item.y=x,y;view.visualObjects[#view.visualObjects+1]=item
      end
    end
  end
  assert(ground,'Connected scene needs a ground sample')
  for i=1,span*span do
    if not owners[i] then owners[i]=ground;view.collision[i]='solid' end
  end
  -- A reserved strip supplies tree UVs even when its native map is off-screen.
  if tree then
    local o=tree.o
    view.visualTreeKeyRect={x=0,y=0,width=o.width,height=o.height}
    for y=0,o.height-1 do for x=0,o.width-1 do
      owners[y*span+x+1]={id=tree.id,x=o.x+x,y=o.y+y}
    end end
    for _,item in ipairs(view.visualObjects) do
      if item.kind=='tree' and not item.textureX then
        item.textureX,item.textureY=0,0
        item.textureW,item.textureH=o.width,o.height
      end
    end
    for y=0,span-2,2 do for x=0,span-2,2 do
      local gap=true
      for dy=0,1 do for dx=0,1 do if owners[(y+dy)*span+x+dx+1]~=ground then gap=false end end end
      if gap then view.visualObjects[#view.visualObjects+1]={kind='tree',virtual=true,x=x,y=y,width=2,height=2,
        size=3,lean=45,textureX=0,textureY=0,textureW=o.width,textureH=o.height} end
    end end
  end
  return view,owners,left,top
end
return M
