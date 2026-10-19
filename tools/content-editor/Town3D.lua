-- Author the original town records; native events, connections and interiors survive.
local M={}
function M.build(S)
  local L,Models,N,T=require('LayeredMap'),require('MapObjects3D'),require('MapNavigation3D'),require('MapPreview3D')
  local id=S.version=='emerald' and 'EM_LITTLEROOT_TOWN' or 'FR_PALLET_TOWN'
  local source=assert(L.convertMap(S,id))
  local def=assert(S.project.maps[id])
  local objects=Models.objects(source)
  local buildings={}
  for i,o in ipairs(objects) do
    if o.kind=='building' then buildings[#buildings+1]=o
    elseif o.kind=='tree' then Models.place(source,{x0=o.x,y0=o.y,x1=o.x+o.width-1,y1=o.y+o.height-1},'tree',3,0,45)
    else
      source.visualObjects=source.visualObjects or {}
      source.visualObjects[#source.visualObjects+1]=o
    end
  end
  -- Prefer diagonals, then other 45-degree steps to retain native walking routes.
  local walkModes={walk=true,grass=true,door=true,carpet=true,panel=true}
  local nativeActors={}
  for _,o in ipairs(def.objects or {}) do if (o.flag or 0)==0 then nativeActors[o.y*1024+o.x]=true end end
  local nativeDoors={}
  for _,w in ipairs(def.warps) do nativeDoors[w.y*1024+w.x]=true end
  local function routes(nav)
    if #nav.errors>0 then return end
    local function floor(x,y)
      if x<0 or y<0 or x>=source.cellWidth or y>=source.cellHeight then return false end
      if nativeDoors[y*1024+x] then return true end
      if nativeActors[y*1024+x] or x<1 or y<1 or x>=source.cellWidth-1 or y>=source.cellHeight-2 then return false end
      local i=y*source.cellWidth+x+1
      if nav.cells[i]~=nil then return nav.cells[i]==0 end
      return walkModes[source.collision[i]]==true
    end
    local first=nav.byWarp[1] or def.warps[1];if not first then return end
    local directions={down={0,1},up={0,-1},right={1,0},left={-1,0}}
    local outward=directions[first.outward or 'down']
    local sx,sy=first.x+outward[1],first.y+outward[2]
    local queue={{sx,sy}};local seen={[sy*1024+sx]=true};local head=1
    while head<=#queue do
      local p=queue[head];head=head+1
      for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0}}) do
        local x,y=p[1]+d[1],p[2]+d[2];local key=y*1024+x
        local ex,ey=(x+p[1])/2+.5,(y+p[2])/2+.5
        local before=T.surface(source,ex-d[1]*.0001,ey-d[2]*.0001)
        local after=T.surface(source,ex+d[1]*.0001,ey+d[2]*.0001)
        if floor(x,y) and not seen[key] and not N.blocked(nav,p[1],p[2],x,y) and math.abs(before-after)<.01 then
          seen[key]=true
          if not nav.entries[key] and not nativeDoors[key] then queue[#queue+1]={x,y} end
        end
      end
    end
    for i,w in ipairs(def.warps) do
      local e=nav.byWarp[i] or w
      if not seen[e.y*1024+e.x] then return end
      local d=directions[e.outward or 'down']
      if not seen[(e.y+d[2])*1024+e.x+d[1]] then return end
    end
    return seen,floor
  end
  for _,o in ipairs(buildings) do
    Models.place(source,{x0=o.x,y0=o.y,x1=o.x+o.width-1,y1=o.y+o.height-1},'building',o.height,0)
    for _,model in ipairs(source.visualObjects) do
      if model.kind=='building' and model.x==o.x and model.y==o.y then
        model.roofRows,model.roofInset=o.roofRows,o.roofInset
        model.lean=45
        model.style=o.width>5 and 'flat_lab' or 'native_house'
        model.chimneySide=S.version=='emerald' and 'left' or 'right'
        -- Keep the sample house and lab on native flat roofs and upright walls.
        if S.version=='emerald' and model.x==2 and model.y==4 then
          model.style='littleroot_native_surfaces'
          model.lean=0
        elseif S.version=='emerald' and model.x==3 and model.y==12 then
          model.style='littleroot_lab_native_surfaces'
          model.lean=0
        end
      end
    end
  end
  source.visualTreeStyle='sprite'
  source.visualForestBorder=8
  source.visualTint={1,1,1}
  source.visualPerspective=1.2
  local nav=N.prepare(source,def.warps,Models.objects(source))
  -- Native, forward-facing doors retain the game's original trigger and return step.
  local seen,floor=routes(nav)
  assert(seen,'No connected native building plan for '..id)
  local occupied={}
  for _,o in ipairs(Models.objects(source)) do
    for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do occupied[y*1024+x]=true end end
  end
  for _,e in pairs(def.warps) do
    for y=e.y-1,e.y+1 do for x=e.x-1,e.x+1 do occupied[y*1024+x]=true end end
  end
  for _,o in ipairs(def.objects or {}) do occupied[o.y*1024+o.x]=true end
  local slope,slopeScore
  for y=2,source.cellHeight-4 do
    for x=2,source.cellWidth-5 do
      local clear=true
      for cy=y+1,y+1 do for cx=x-1,x+3 do
        if occupied[cy*1024+cx] or not seen[cy*1024+cx] or not floor(cx,cy) then clear=false end
      end end
      local score=(x+1-source.cellWidth/2)^2+(y+1-source.cellHeight/2)^2
      if clear and (not slopeScore or score<slopeScore) then
        source.visualHeights={};source.visualShapes={}
        T.paint(source,x,y+1,0,'east');T.paint(source,x+1,y+1,1);T.paint(source,x+2,y+1,0,'west')
        if routes(nav) then slope,slopeScore={x=x,y=y},score end
        source.visualHeights={};source.visualShapes={}
      end
    end
  end
  assert(slope,'No safe town slope area found')
  for y=slope.y+1,slope.y+1 do
    T.paint(source,slope.x,y,0,'east');T.paint(source,slope.x+1,y,1)
    T.paint(source,slope.x+2,y,0,'west')
  end
  source.visualPlayable=true
  source.visualCamera={angle=0,pitch=.8,scale=14}
  source.visualWorldAnchor=id
  local connected={}
  for _,c in ipairs(require('src.core.game3.connections').each(def)) do
    local route=assert(L.convertMap(S,c.map))
    route.visualPlayable=true;route.visualWorldAnchor=id
    route.visualTreeStyle=source.visualTreeStyle;route.visualCamera=source.visualCamera
    route.visualTint=source.visualTint;route.visualPerspective=source.visualPerspective
    route.visualForestBorder=0
    route.visualNativeObjects=S.version=='emerald' and 'emerald' or 'frlg'
    connected[#connected+1]={id=c.map,dir=c.dir,offset=c.offset,source=route}
  end
  local entry=def.warps[1]
  local interiors=require('Interior3D').town(S,id)
  return {id=id,source=source,def=def,nav=nav,slope=slope,start={x=entry.x,y=entry.y},buildings=#buildings,connected=connected,interiors=interiors}
end
return M
