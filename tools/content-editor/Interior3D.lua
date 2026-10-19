-- Roofless native rooms: visual volumes never rewrite collision or script data.
local M={}
function M.apply(source,def)
  if require('Environment3D').kind(source) then return require('Environment3D').apply(source,def) end
  local protected={}
  for _,w in ipairs(def.warps or {}) do
    for y=math.max(0,w.y-1),math.min(source.cellHeight-1,w.y+1) do
      for x=math.max(0,w.x-1),math.min(source.cellWidth-1,w.x+1) do protected[y*source.cellWidth+x+1]=true end
    end
  end
  source.visualInterior=true
  source.visualPlayable=true
  source.visualAutoObjects=false
  local manual={}
  for _,o in ipairs(source.visualObjects or {}) do if not o.interiorGenerated then manual[#manual+1]=o end end
  source.visualObjects={}
  source.visualPerspective=.5
  source.visualBackground={.035,.035,.045}
  source.visualCamera=source.visualCamera or {angle=0,pitch=.9,scale=math.min(16,210/source.cellWidth,165/source.cellHeight)}
  local cells=source.layers[1].cells
  local corner=cells[source.cellWidth*source.cellHeight]
  local void=corner and corner.tile
  local props=require('MapObjects3D').detectProps(source)
  for _,prop in ipairs(props) do
    local overlap=false
    for _,o in ipairs(manual) do if require('MapObjects3D').overlaps(o,prop) then overlap=true;break end end
    for y=prop.y,prop.y+prop.height-1 do for x=prop.x,prop.x+prop.width-1 do
      if protected[y*source.cellWidth+x+1] then overlap=true end
    end end
    if not overlap then prop.interiorGenerated=true;prop.allowOverlap=true;source.visualObjects[#source.visualObjects+1]=prop end
  end
  local function fixture(x,y,w,h,style,height,topRows,kind)
    local model={kind=kind or 'furniture',x=x,y=y,width=w,height=h,
      size=(style=='native_fixture' or style=='native_cutout') and height or h,style=style,surfaceTopRows=topRows,
      interiorGenerated=true,allowOverlap=true,rotation=0}
    if style=='native_fixture' or style=='native_cutout' then
      local lastSolid
      for cy=y,y+h-1 do for cx=x,x+w-1 do
        if source.collision[cy*source.cellWidth+cx+1]=='solid' then lastSolid=cy-y end
      end end
      model.surfaceDepth=lastSolid and lastSolid+1 or h
      if style=='native_cutout' then model.anchorDepth=model.surfaceDepth end
    end
    for _,o in ipairs(manual) do
      if require('MapObjects3D').overlaps(o,model) and (kind~='wall_decor' or o.kind=='none') then return end
    end
    for cy=y,y+h-1 do for cx=x,x+w-1 do if protected[cy*source.cellWidth+cx+1] then return end end end
    source.visualObjects[#source.visualObjects+1]=model
    return model
  end
  local captain=source.id=='EM_ABANDONED_SHIP_CAPTAINS_OFFICE' and source.cellWidth==10
    and source.cellHeight==8 and cells[1] and cells[1].tile==760 and void==513
  if captain then
    -- Native wall panels, windows and mounted phone remain one upright strip.
    -- Complete fixtures split only at the native top/front artwork boundary.
    local wall=fixture(0,0,9,2,'native_room_wall',2,nil,'wall_decor')
    if wall then
      -- Remove baked-in fixture heads behind their raised replacements, using
      -- the native plain wall margin beside the phone as the backing material.
      wall.wallClearRects={{3,1,2,1},{7,1,2,1}}
      wall.wallFill={6.875,1,.125,1}
    end
    fixture(3,1,2,2,'native_fixture',1.5,.5) -- paired cabinets
    fixture(7,1,2,2,'native_fixture',.8,1.1) -- model-ship display counter
    fixture(0,3,1,2,'native_fixture',1.75,.25) -- tall cabinet
    fixture(3,5,2,2,'native_fixture',.65,1.4) -- chart desk
  end
  if source.baseTileset=='building__lab' and source.cellWidth==14 and source.cellHeight==14
    and cells[1] and cells[1].tile==528 and cells[2].tile==529 then
    -- The native artwork contains tops, fronts and objects stacked above them.
    -- Keep each complete native fixture together on one artwork card.
    fixture(0,0,2,3,'native_fixture',1.7,.6)
    fixture(3,0,2,3,'native_fixture',1.2,.6)
    fixture(5,1,6,2,'native_fixture',.85,1)
    fixture(0,5,2,4,'native_fixture',1.5,1.2)
    fixture(2,5,2,4,'native_fixture',1.5,1.2)
    fixture(9,3,2,3,'native_fixture',.9,1.2)
    fixture(10,6,3,3,'native_fixture',1.3,1)
  end
  local center=source.baseTileset=='building__pokemon_center' and source.cellWidth==14 and source.cellHeight==10
      and cells[1].tile==520 and cells[3*14+5].tile==600 and cells[4*14+5].tile==608
  if center then
    local reviewedCenter=source.id=='EM_OLDALE_TOWN_POKEMON_CENTER_1F' or def.nativeArtworkProfiles
    local wall=fixture(0,0,14,2,'native_room_wall',2,nil,'wall_decor')
    if wall then
      wall.wallClearRects={{4,1,6,1}}
      wall.wallFill={5,0,1,1}
      if reviewedCenter then
        wall.wallClearRects={{1,0,1,2},{2,1,2,1},{4,1,6,1},{10,0,1,2}}
        wall.wallFill={4,.25,1,.75};wall.wallTopFill={4,0,1,1}
      end
    end
    if reviewedCenter then
      source.visualNativeCutouts=true
      local function cutout(x,y,w,h)
        local o=fixture(x,y,w,h,'native_cutout',h)
        if o then o.cutoutBackgrounds={{3,5,1,1},{4.25,.25,.5,.75}} end
        return o
      end
      cutout(1,0,1,3) -- complete native plant, including its pot
      cutout(2,1,2,2)
      cutout(5,1,2,2)
      cutout(8,1,1,2)
      cutout(10,0,1,3)
      for _,x in ipairs({4,9}) do
        local side=fixture(x,1,1,2,'native_fixture',.7,1.5)
        if side then side.surfaceTopRect={0,.6,1,2} end
      end
      local counter=fixture(4,3,6,2,'native_fixture',.7,.45)
      if counter then counter.surfaceFrontRect={0,.45,6,1} end
      for y=2,source.cellHeight-2 do for x=0,source.cellWidth-1 do
        local tile=cells[y*source.cellWidth+x+1] and cells[y*source.cellWidth+x+1].tile
        if tile==550 or tile==564 then
          cutout(x,y,1,1)
        end
      end end
    else
      fixture(4,1,6,2,'healing_station',2)
      fixture(4,3,6,2,'native_fixture',.9,1)
    end
    if cells[6*14+12].tile==573 and cells[7*14+12].tile==581 then
      local tableArt=fixture(11,6,2,2,reviewedCenter and 'native_cutout' or 'native_fixture',reviewedCenter and 2 or .6,1.2)
      if tableArt and tableArt.style=='native_cutout' then tableArt.cutoutBackgrounds={{3,5,1,1}} end
    end
  end
  for y=0,source.cellHeight-1 do for x=0,source.cellWidth-1 do
    local i=y*source.cellWidth+x+1
    if not captain and not center and source.collision[i]=='solid' and not protected[i] and cells[i] and cells[i].tile~=void then
      local model={kind='furniture',x=x,y=y,width=1,height=1,interiorGenerated=true,
        size=y==0 and 1.6 or .65,style=y==0 and 'wall' or 'fixture',rotation=0}
      local overlap=false
      for _,o in ipairs(manual) do if require('MapObjects3D').overlaps(o,model) then overlap=true;break end end
      for _,o in ipairs(source.visualObjects) do if require('MapObjects3D').overlaps(o,model) then overlap=true;break end end
      if not overlap then source.visualObjects[#source.visualObjects+1]=model end
    end
  end end
  for _,o in ipairs(manual) do source.visualObjects[#source.visualObjects+1]=o end
  return source
end
function M.town(S,town)
  local L=require('LayeredMap')
  local queue,seen,result,buildings={},{[town]=true},{},{}
  local function add(id)
    local inside=false
    for _,prefix in ipairs(buildings) do if id and id:sub(1,#prefix)==prefix then inside=true end end
    if inside and not seen[id] then
      seen[id]=true;queue[#queue+1]=id
    end
  end
  for _,w in ipairs(S.project.maps[town].warps or {}) do
    if w.destMap then buildings[#buildings+1]=w.destMap:gsub('_%dF$','') end
  end
  for _,w in ipairs(S.project.maps[town].warps or {}) do add(w.destMap) end
  local head=1
  while queue[head] do
    local id=queue[head];head=head+1
    local source=assert(L.convertMap(S,id))
    local def=assert(S.project.maps[id])
    M.apply(source,def);result[#result+1]=id
    for _,w in ipairs(def.warps or {}) do add(w.destMap) end
  end
  return result
end
return M
