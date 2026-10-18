-- CPU geometry shared by the renderer and deterministic model tests.
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
  local function box(x0,y0,x1,y1,z0,z1,color)
    local a,b,c,d={x0,y0,z1},{x1,y0,z1},{x1,y1,z1},{x0,y1,z1}
    polygon({a,b,c,d},nil,color)
    polygon({{x0,y1,z0},{x1,y1,z0},c,d},nil,color)
    polygon({{x1,y0,z0},{x0,y0,z0},a,b},nil,color)
    polygon({{x0,y0,z0},{x0,y1,z0},d,a},nil,color)
    polygon({{x1,y1,z0},{x1,y0,z0},b,c},nil,color)
  end
  for _,o in ipairs(visible) do
    local base,lowest=0,math.huge
    for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do
      for _,z in ipairs(terrain.corners(source,x,y)) do base=math.max(base,z);lowest=math.min(lowest,z) end
    end end
    local size=o.size or 3
    local centerX,centerY=o.x+o.width/2,o.y+o.height/2
    local root=o.kind=='tree' and terrain.surface(source,centerX,centerY) or base
    local angle=math.rad(o.rotation or 0)
    local lean=o.kind=='tree' and math.rad(o.lean or 0) or 0
    transform=function(p)
      local dx,dy,dz=p[1]-centerX,p[2]-centerY,p[3]-root
      dy=dy-dz*math.sin(lean)
      return {centerX+dx*math.cos(angle)-dy*math.sin(angle),
        centerY+dx*math.sin(angle)+dy*math.cos(angle),root+dz*math.cos(lean)}
    end
    if o.kind=='building' and o.style then
      local x0,y0,x1,y1=o.x,o.y,o.x+o.width,o.y+o.height
      local rows=o.roofRows or 2
      local wall=base+(o.style=='front_gable' and 2.8 or 2.4)
      local ridge=wall+1.5
      local front=uv(x0,y0+rows,x1,y1)
      local facade={front[4],front[3],front[2],front[1]}
      local side=uv(x0,y0+rows,x0+.6,y1)
      polygon({{x0+.3,y0+.5,base+.012},{x1+.3,y0+.5,base+.012},
        {x1+.3,y1+.5,base+.012},{x0+.3,y1+.5,base+.012}},nil,{.06,.12,.12,.3})
      quad({x0,y1,base},{x1,y1,base},{x1,y1,wall},{x0,y1,wall},facade,1)
      quad({x1,y0,base},{x0,y0,base},{x0,y0,wall},{x1,y0,wall},facade,.78)
      quad({x0,y0,base},{x0,y1,base},{x0,y1,wall},{x0,y0,wall},{side[4],side[3],side[2],side[1]},.72)
      quad({x1,y1,base},{x1,y0,base},{x1,y0,wall},{x1,y1,wall},{side[4],side[3],side[2],side[1]},.84)
      local roof=uv(x0+1,y0+.75,x1-1,y0+math.max(.9,rows-.35))
      if o.style=='flat_lab' then
        roof=uv(x0+4.1,y0+1.1,x0+4.9,y0+1.9)
        materialQuad({x0-.15,y0-.15,wall},{x1+.15,y0-.15,wall},{x1+.15,y1+.15,wall},{x0-.15,y1+.15,wall},roof,.9)
        local rim={.35,.37,.4}
        box(x0-.2,y0-.2,x1+.2,y0+.05,wall,wall+.2,rim)
        box(x0-.2,y1-.05,x1+.2,y1+.2,wall,wall+.2,rim)
        box(x0-.2,y0,x0+.05,y1,wall,wall+.2,rim)
        box(x1-.05,y0,x1+.2,y1,wall,wall+.2,rim)
        box(x1-1.3,y0+.4,x1-.5,y0+1.3,wall,wall+1.2,{.48,.22,.2})
        box(x1-1.45,y0+.3,x1-.35,y0+1.4,wall+1.1,wall+1.3,{.35,.17,.17})
      else
        local cx=(x0+x1)/2
        local mid=(y0+y1)/2
        local left,right=x0+.6,x1-.6
        local front=y1+.22
        roof=uv(x0+1.1,y0+1.1,x0+1.8,y0+1.7)
        -- A side-to-side main roof, with a forward-facing cross gable.
        materialQuad({x0-.2,y0-.2,wall},{x1+.2,y0-.2,wall},{x1+.2,mid,ridge},{x0-.2,mid,ridge},roof,.8)
        materialQuad({x0-.2,mid,ridge},{x1+.2,mid,ridge},{x1+.2,y1+.2,wall},{x0-.2,y1+.2,wall},roof,.95)
        materialQuad({left,mid,ridge+.02},{cx,mid,ridge+.02},{cx,front,ridge+.02},{left,front,wall+.02},roof,.85)
        materialQuad({cx,mid,ridge+.02},{right,mid,ridge+.02},{right,front,wall+.02},{cx,front,ridge+.02},roof,1)
        polygon({{left,front,wall},{right,front,wall},{cx,front,ridge}},nil,{.72,.72,.74})
        polygon({{left-.12,front+.02,wall},{cx,front+.02,ridge+.12},{cx,front+.02,ridge-.08},{left+.12,front+.02,wall}},nil,{.58,.24,.2})
        polygon({{cx,front+.02,ridge+.12},{right+.12,front+.02,wall},{right-.12,front+.02,wall},{cx,front+.02,ridge-.08}},nil,{.65,.28,.22})
        -- Independent upper windows and timber trim keep the gable off the roof texture.
        local win=uv(x0+o.width*.55,y1-1.35,x0+o.width*.8,y1-.4)
        for _,wx in ipairs({cx-1,cx+.25}) do
          quad({wx,front+.03,wall+.18},{wx+.75,front+.03,wall+.18},
            {wx+.75,front+.03,wall+.85},{wx,front+.03,wall+.85},
            {win[4],win[3],win[2],win[1]},.95)
        end
        box(x0-.15,y1-.05,x1+.15,y1+.08,wall-.08,wall+.06,{.45,.31,.27})

      end
    elseif o.kind=='tree' and source.visualTreeStyle=='sprite' then
      transform=nil
      local cx,cy=o.x+o.width/2,o.y+o.height-.1
      local z=o.virtual and 0 or terrain.surface(source,cx,cy)
      local height=3;local tilt=math.rad(o.lean or 45)
      local topY,topZ=cy-height*math.sin(tilt),z+height*math.cos(tilt)
      local tx,ty=o.textureX or o.x,o.textureY or o.y
      local tex=uv(tx,ty,tx+(o.textureW or o.width),ty+(o.textureH or o.height))
      polygon({{cx-.65,cy-.1,z+.012},{cx+.8,cy-.1,z+.012},{cx+.9,cy+.5,z+.012},{cx-.6,cy+.5,z+.012}},nil,{.05,.12,.1,.22})
      polygon({{cx-o.width/2,cy,z},{cx+o.width/2,cy,z},{cx+o.width/2,topY,topZ},{cx-o.width/2,topY,topZ}},
        {tex[4],tex[3],tex[2],tex[1]},{1,1,1,2})
    elseif o.kind=='building' then
      local x0,y0,x1,y1=o.x,o.y,o.x+o.width,o.y+o.height
      if lowest<base then box(x0,y0,x1,y1,lowest,base,{.43,.43,.36}) end
      local roofRows=o.roofRows or math.max(1,math.floor(o.height*.55))
      roofRows=math.min(o.height-.25,roofRows)
      local wall=base+size*.65;local ridge=wall+size*.4
      local mid=(y0+y1)/2
      local front=uv(x0,y0+roofRows,x1,y1)
      -- Bottom-to-top geometry receives bottom-to-top facade texture.
      local frontUV={front[4],front[3],front[2],front[1]}
      quad({x0,y1,base},{x1,y1,base},{x1,y1,wall},{x0,y1,wall},frontUV,1)
      quad({x1,y0,base},{x0,y0,base},{x0,y0,wall},{x1,y0,wall},frontUV,.8)
      local side=uv(x0,y0+roofRows,math.min(x0+1,x1),y1)
      local sideUV={side[4],side[3],side[2],side[1]}
      quad({x0,y0,base},{x0,y1,base},{x0,y1,wall},{x0,y0,wall},sideUV,.8)
      quad({x1,y1,base},{x1,y0,base},{x1,y0,wall},{x1,y1,wall},sideUV,.7)
      local roof=uv(x0,y0+(o.roofInset or 0),x1,y0+roofRows)
      quad({x0,mid,ridge},{x1,mid,ridge},{x1,y1,wall},{x0,y1,wall},roof,1)
      quad({x0,y0,wall},{x1,y0,wall},{x1,mid,ridge},{x0,mid,ridge},roof,.83)
      polygon({{x0,y0,wall},{x0,y1,wall},{x0,mid,ridge}},nil,{.65,.58,.4})
      polygon({{x1,y1,wall},{x1,y0,wall},{x1,mid,ridge}},nil,{.75,.68,.48})
    else
      local cx,cy=o.x+o.width/2,o.y+o.height/2
      base=terrain.surface(source,cx,cy)
      box(cx-.17,cy-.17,cx+.17,cy+.17,base,base+size*.5,{.46,.29,.13})
      -- Octagonal rings give each tree a closed, faceted canopy from all angles.
      local rings={{.26,.25},{.36,.48},{.62,.52},{.85,.34},{1,.05}}
      for ring=1,#rings-1 do
        local lo,hi=rings[ring],rings[ring+1]
        for side=0,7 do
          local angle=side*math.pi/4;local nextAngle=(side+1)*math.pi/4
          local function point(a,r) return {cx+math.cos(a)*o.width*r[2],cy+math.sin(a)*math.min(o.width,o.height)*r[2],base+size*r[1]} end
          -- Sample the interior foliage, excluding the sprite's grass border.
          local tex=uv(o.x+o.width*.2,o.y+.3,o.x+o.width*.8,o.y+.9)
          local shade=.82+.16*math.cos(angle+.8)
          quad(point(angle,hi),point(nextAngle,hi),point(nextAngle,lo),point(angle,lo),tex,shade)
        end
      end
      local top={cx,cy,base+size*1.03}
      for side=0,7 do
        local a,b=side*math.pi/4,(side+1)*math.pi/4
        local r=rings[#rings]
        polygon({top,{cx+math.cos(a)*o.width*r[2],cy+math.sin(a)*math.min(o.width,o.height)*r[2],base+size},
          {cx+math.cos(b)*o.width*r[2],cy+math.sin(b)*math.min(o.width,o.height)*r[2],base+size}},nil,{.27,.55,.14})
        local bottom=rings[1]
        polygon({{cx,cy,base+size*bottom[1]},
          {cx+math.cos(a)*o.width*bottom[2],cy+math.sin(a)*math.min(o.width,o.height)*bottom[2],base+size*bottom[1]},
          {cx+math.cos(b)*o.width*bottom[2],cy+math.sin(b)*math.min(o.width,o.height)*bottom[2],base+size*bottom[1]}},nil,{.2,.4,.12})
      end
    end
  end
  transform=nil
  return vertices,visible
end

return M
