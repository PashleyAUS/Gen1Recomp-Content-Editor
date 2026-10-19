-- Roofless native rooms: visual volumes never rewrite collision or script data.
local M={}
function M.apply(source,def)
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
  local function fixture(x,y,w,h,style,height)
    local model={kind='furniture',x=x,y=y,width=w,height=h,size=h,style=style,
      interiorGenerated=true,allowOverlap=true,rotation=0}
    for _,o in ipairs(manual) do if require('MapObjects3D').overlaps(o,model) then return end end
    source.visualObjects[#source.visualObjects+1]=model
  end
  if source.baseTileset=='building__lab' and source.cellWidth==14 and source.cellHeight==14
    and cells[1] and cells[1].tile==528 and cells[2].tile==529 then
    -- The native artwork contains tops, fronts and objects stacked above them.
    -- Keep each complete native fixture together on one artwork card.
    fixture(0,0,2,3,'bookcase',1.7)
    fixture(3,0,2,3,'computer_desk',.85)
    fixture(5,1,6,2,'workbench',.85)
    fixture(0,5,2,4,'bookcase_items',1.5)
    fixture(2,5,2,4,'bookcase_items',1.5)
    fixture(9,3,2,3,'item_table',.9)
    fixture(10,6,3,3,'machine',1.3)
  end
  for y=0,source.cellHeight-1 do for x=0,source.cellWidth-1 do
    local i=y*source.cellWidth+x+1
    if source.collision[i]=='solid' and not protected[i] and cells[i] and cells[i].tile~=void then
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
