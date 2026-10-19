-- Native artwork surfaces shared by the editor and in-game renderer.
local Objects=require('MapObjects3D')
local M={}

function M.build(source,terrain,cols,rows)
  local vertices={}
  local transform
  local atlasH=rows*16+4
  local function uv(x0,y0,x1,y1)
    -- Half-pixel inset prevents neighboring tiles bleeding across model seams.
    return {{(x0*16+.5)/(cols*16),(y0*16+.5)/atlasH},
      {(x1*16-.5)/(cols*16),(y0*16+.5)/atlasH},
      {(x1*16-.5)/(cols*16),(y1*16-.5)/atlasH},
      {(x0*16+.5)/(cols*16),(y1*16-.5)/atlasH}}
  end
  local white={.5/(cols*16),(rows*16+1)/atlasH}
  local function polygon(points,tex,color,diagonal)
    color=color or {1,1,1}
    local indices=#points==3 and {1,2,3} or diagonal and {1,2,4,2,3,4} or {1,2,3,1,3,4}
    for _,i in ipairs(indices) do
      local p=points[i];local t=tex and tex[i] or white
      if transform then p=transform(p) end
      vertices[#vertices+1]={p[1],p[2],p[3],t[1],t[2],color[1],color[2],color[3],color[4] or 1}
    end
  end
  local function quad(a,b,c,d,tex,shade)
    polygon({a,b,c,d},tex,shade and {shade,shade,shade})
  end
  local function materialQuad(a,b,c,d,tex,shade)
    local function length(p,q) return math.sqrt((p[1]-q[1])^2+(p[2]-q[2])^2+(p[3]-q[3])^2) end
    local nu,nv=math.max(1,math.ceil(length(a,b))),math.max(1,math.ceil(length(a,d)))
    local function point(u,v)
      local p={}
      for i=1,3 do p[i]=a[i]*(1-u)*(1-v)+b[i]*u*(1-v)+c[i]*u*v+d[i]*(1-u)*v end
      return p
    end
    for v=0,nv-1 do for u=0,nu-1 do
      quad(point(u/nu,v/nv),point((u+1)/nu,v/nv),point((u+1)/nu,(v+1)/nv),point(u/nu,(v+1)/nv),tex,shade)
    end end
  end
  local objects={}
  for _,original in ipairs(Objects.objects(source)) do
    local item={};for k,v in pairs(original) do item[k]=v end
    objects[#objects+1]=item
  end
  local treeSample
  for _,o in ipairs(objects) do
    if o.kind=='tree' and (not treeSample or o.height>treeSample.height) then treeSample=o end
  end
  if source.visualTreeStyle=='sprite' and treeSample then
    for _,o in ipairs(objects) do
      if o.kind=='tree' and not o.textureX then
        o.textureX,o.textureY=treeSample.x,treeSample.y
        o.textureW,o.textureH=treeSample.width,treeSample.height
      end
    end
  end
  local border=source.visualForestBorder or 0
  if border>0 then
    local sample=treeSample
    if sample then
      for y=-border,rows+border-1,2 do for x=-border,cols+border-1,2 do
        if x<0 or y<0 or x>=cols or y>=rows then
          objects[#objects+1]={kind='tree',x=x,y=y,width=2,height=2,size=3,lean=45,
            textureX=sample.x,textureY=sample.y,textureW=sample.width,textureH=sample.height,virtual=true}
        end
      end end
    end
  end
  local covered={}
  local visible={}
  for _,o in ipairs(objects) do
    if o.virtual or (o.x>=0 and o.y>=0 and o.x+o.width<=cols and o.y+o.height<=rows) then
      visible[#visible+1]=o
      if not o.virtual then for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do covered[y*source.cellWidth+x+1]=o end end end
    end
  end
  -- Replace the flattened sprite below a raised model with nearby ground.
  local ground={}
  for _,o in ipairs(visible) do
    local best,dist
    for y=math.max(0,o.y-3),math.min(rows-1,o.y+o.height+3) do
      for x=math.max(0,o.x-3),math.min(cols-1,o.x+o.width+3) do
        local i=y*source.cellWidth+x+1;local collision=(source.collision or {})[i]
        if not covered[i] and (collision=='walk' or collision=='grass') then
          local d=(x-o.x-o.width/2)^2+(y-o.y-o.height/2)^2
          if not dist or d<dist then best,dist={x,y},d end
        end
      end
    end
    ground[o]=best
  end
  local function corners(x,y)
    if x<0 or y<0 or x>=cols or y>=rows then return {{x,y,0},{x+1,y,0},{x+1,y+1,0},{x,y+1,0}} end
    local z=terrain.corners(source,x,y)
    return {{x,y,z[1]},{x+1,y,z[2]},{x+1,y+1,z[3]},{x,y+1,z[4]}}
  end
  local neighborCorners={{4,3},{1,4},{2,1},{3,2}}
  local directions={{0,-1},{1,0},{0,1},{-1,0}}
  local floorSample
  for _,v in pairs(ground) do floorSample=v;break end
  for y=-border,rows+border-1 do for x=-border,cols+border-1 do
    local o=covered[y*source.cellWidth+x+1]
    local sample=(x<0 or y<0 or x>=cols or y>=rows) and floorSample or (o and ground[o])
    local tex=sample and uv(sample[1],sample[2],sample[1]+1,sample[2]+1) or uv(x,y,x+1,y+1)
    if o and o.kind=='wall_decor' then
      -- Sample the plain wall at the art's left margin, not nearby floorboards.
      tex=uv(o.x+.01,o.y+.2,o.x+.09,o.y+.4)
    end
    local p=corners(x,y)
    local shape=x>=0 and y>=0 and x<cols and y<rows and (source.visualShapes or {})[y*source.cellWidth+x+1]
    polygon(p,tex,nil,shape=='corner_nw' or shape=='corner_se')
    for edge,dir in ipairs(directions) do
      local nx,ny=x+dir[1],y+dir[2]
      local neighbor=nx>=0 and ny>=0 and nx<cols and ny<rows and corners(nx,ny)
      local a,b=p[edge],p[edge%4+1]
      local loA=neighbor and neighbor[neighborCorners[edge][1]][3] or -.5
      local loB=neighbor and neighbor[neighborCorners[edge][2]][3] or -.5
      if a[3]>loA or b[3]>loB then
        -- Clip crossing edges to the exposed portion rather than adding a wall
        -- through the neighboring slope.
        local da,db=a[3]-loA,b[3]-loB
        if da*db<0 then
          local t=da/(da-db)
          local cross={a[1]+(b[1]-a[1])*t,a[2]+(b[2]-a[2])*t,a[3]+(b[3]-a[3])*t}
          if da<0 then a=cross;loA=cross[3] else b=cross;loB=cross[3] end
        end
        quad(a,b,{b[1],b[2],math.min(b[3],loB)},{a[1],a[2],math.min(a[3],loA)},tex,edge%2==0 and .72 or .85)
      end
    end
  end end
  -- Objects are complete native artwork cards, never reconstructed meshes.
  -- Keep their source rectangle intact: crowns, roof silhouettes, pots and posts
  -- are already drawn by the game artist and must not be synthesized here.
  for _,o in ipairs(visible) do
    local cx,cy=o.x+o.width/2,o.y+o.height-.1
    local base=o.virtual and 0 or terrain.surface(source,cx,cy)
    base=base+(o.mount or 0)
    local height=o.size or o.height
    local tilt=math.rad(o.lean or (o.kind=='tree' and 45 or 0))
    local yaw=math.rad(o.rotation or 0)
    local tx,ty=o.textureX or o.x,o.textureY or o.y
    local tex=uv(tx,ty,tx+(o.textureW or o.width),ty+(o.textureH or o.height))
    local function point(dx,dz)
      local dy=-dz*math.sin(tilt)
      return {cx+dx*math.cos(yaw)-dy*math.sin(yaw),
        cy+dx*math.sin(yaw)+dy*math.cos(yaw),base+dz*math.cos(tilt)}
    end
    if o.kind=='building' and (o.style=='littleroot_native_surfaces' or o.style=='littleroot_lab_native_surfaces') then
      -- Match the card lean while keeping the ground footprint anchored.
      transform=function(p)
        local dx,dy,dz=p[1]-cx,p[2]-cy,p[3]-base
        dy=dy-dz*math.sin(tilt)
        return {cx+dx*math.cos(yaw)-dy*math.sin(yaw),
          cy+dx*math.sin(yaw)+dy*math.cos(yaw),base+dz*math.cos(tilt)}
      end
      -- Opt-in Littleroot buildings. Every surface samples its existing map
      -- artwork; no replacement textures, flat-color fills or added windows.
      local x,y=o.x,o.y
      local front,back=y+o.height-.1,y+.1
      local lab=o.style=='littleroot_lab_native_surfaces'
      local width=o.width
      local roofRows=lab and 3 or 3.375
      local top=base+o.height-roofRows
      -- Front artwork becomes one upright wall, retaining its native door.
      local facade=uv(tx,ty+roofRows,tx+width,ty+o.height)
      polygon({{x,front,base},{x+width,front,base},{x+width,front,top},{x,front,top}},
        {facade[4],facade[3],facade[2],facade[1]})
      -- A single complete front-wall tile (under the window, no door) repeats
      -- along each side. Keep one vertical course, preserving its base trim.
      local sideTile=lab and 1 or 2
      local wall=uv(tx+sideTile,ty+o.height-1,tx+sideTile+1,ty+o.height)
      local wallUV={wall[4],wall[3],wall[2],wall[1]}
      local function repeatWall(ax,ay,bx,by)
        local count=math.ceil(math.sqrt((bx-ax)^2+(by-ay)^2))
        for n=0,count-1 do
          local x0,y0=ax+(bx-ax)*n/count,ay+(by-ay)*n/count
          local x1,y1=ax+(bx-ax)*(n+1)/count,ay+(by-ay)*(n+1)/count
          quad({x0,y0,base},{x1,y1,base},{x1,y1,top},{x0,y0,top},wallUV,1)
        end
      end
      repeatWall(x,back,x,front)
      repeatWall(x+width,front,x+width,back)
      repeatWall(x+width,back,x,back)
      -- Original roof artwork laid horizontally, with no raised/pitched sections.
      quad({x,back,top},{x+width,back,top},{x+width,front,top},{x,front,top},
        uv(tx,ty,tx+width,ty+roofRows),1)
      transform=nil
    else
    polygon({point(-o.width/2,0),point(o.width/2,0),
      point(o.width/2,height),point(-o.width/2,height)},
      {tex[4],tex[3],tex[2],tex[1]},o.kind=='tree' and {1,1,1,2} or nil)
    end
  end
  transform=nil
  return vertices,visible
end

return M
