-- Author relief from native passage data without changing the game's passages.
local M={}
function M.kind(source)
  local pair=source.baseTileset or ''
  local id=source.id or ''
  if source.visualEnvironment=='cave' or source.visualEnvironment=='underwater' then return source.visualEnvironment end
  if pair:find('underwater',1,true) or id:match('^EM_UNDERWATER_') then return 'underwater' end
  if pair:find('cave',1,true) then return 'cave' end
  -- FR/LG imports identify some tilesets by ROM address rather than name.
  if id:match('^FR_') then
    for _,name in ipairs({'MT_MOON','ROCK_TUNNEL','SEAFOAM','DIGLETTS_CAVE','CERULEAN_CAVE',
        'VICTORY_ROAD','ALTERING_CAVE','ICEFALL_CAVE','LOST_CAVE'}) do
      if id:find(name,1,true) then return 'cave' end
    end
  end
end
function M.apply(source,def)
  local kind=assert(M.kind(source))
  local protected={}
  for _,w in ipairs(def.warps or {}) do
    for y=math.max(0,w.y-1),math.min(source.cellHeight-1,w.y+1) do
      for x=math.max(0,w.x-1),math.min(source.cellWidth-1,w.x+1) do protected[y*source.cellWidth+x+1]=true end
    end
  end
  source.visualHeights=source.visualHeights or {}
  for i,z in pairs(source.visualEnvironmentHeights or {}) do
    if source.visualHeights[i]==z and not (source.visualShapes or {})[i] then source.visualHeights[i]=nil end
  end
  local generated,objects={},{}
  for _,o in ipairs(source.visualObjects or {}) do
    if not o.environmentGenerated and not o.interiorGenerated then objects[#objects+1]=o end
  end
  local manualCount=#objects
  for i,cell in ipairs(source.layers[1].cells) do
    local x,y=(i-1)%source.cellWidth,math.floor((i-1)/source.cellWidth)
    if not protected[i] and source.collision[i]=='solid' and source.visualHeights[i]==nil
        and not (source.visualShapes or {})[i] then
      source.visualHeights[i]=2;generated[i]=2
    end
    if kind=='underwater' and source.baseTileset=='general__underwater' and not protected[i]
        and (cell.tile==641 or cell.tile==681) and source.collision[i]=='water' then
      local plant={kind='furniture',style='native_underwater_plant',x=x,y=y,width=1,height=1,
        size=.45,rotation=0,lean=45,environmentGenerated=true}
      local covered=false
      for n=1,manualCount do if require('MapObjects3D').overlaps(objects[n],plant) then covered=true;break end end
      if not covered then objects[#objects+1]=plant end
    end
  end
  source.visualEnvironmentHeights=generated;source.visualObjects=objects
  source.visualAutoObjects=false;source.visualPlayable=true;source.visualInterior=true
  source.visualEnvironment=kind
  source.visualTreeStyle=kind=='underwater' and 'sprite' or nil
  source.visualTint={1,1,1};source.visualPerspective=.7
  source.visualBackground=kind=='underwater' and {.025,.035,.12} or {.04,.03,.02}
  source.visualCamera=source.visualCamera or {angle=0,pitch=.7,scale=16}
  return source
end
return M
