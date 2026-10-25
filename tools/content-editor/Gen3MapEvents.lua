-- Native event fields within the shared Map Builder selection/drawer workflow.
local M={}
local groups={objects={"Objects","mapObjectIndex"},signs={"Signs","mapSignIndex"},
  coordEvents={"Triggers","g3CoordIndex"},warps={"Warps","mapWarpIndex"}}
function M.place(S,tool,x,y,App)
  if tool=="item" then return require("Gen3MapTemplates").place(S,x,y,App,"pickup") end
  local kind=({object="objects",sign="signs",trigger="coordEvents",warp="warps"})[tool]
  if not kind then return false end
  if kind=="objects" and require("Gen3MapTemplates").place(S,x,y,App) then return true end
  local source=assert(require("Gen3Workspace").convert(S,S.mapId))
  local map=S.project.maps[S.mapId]
  local rows=map[kind] or {};map[kind]=rows
  local index=#rows+1
  local script="EDITOR_"..S.mapId.."_"..kind.."_"..index
  local ev={x=x,y=y,elevation=(source.gen3Elevation or {})[y*source.cellWidth+x+1] or 3,scriptKey=script}
  if kind=="objects" then
    local max=0;for _,r in ipairs(rows) do max=math.max(max,r.localId or r.index or 0) end
    ev.localId=max+1;ev.index=max+1;ev.graphicsId=1;ev.graphics=1;ev.movement="STAY";ev.movementType=9;ev.flag=0
  elseif kind=="signs" then ev.kind=0
  elseif kind=="coordEvents" then ev.var=16384;ev.value=0
  else ev={x=x,y=y,destMap=S.mapId,destWarp=index} end
  rows[index]=ev
  if kind=="warps" then require("LayeredMap").adoptWarpRecord(S.project,S.mapId,ev)
  else
    S.project.gen3=S.project.gen3 or {};S.project.gen3.map_scripts=S.project.gen3.map_scripts or {}
    S.project.gen3.map_scripts[script]={{op="end"}}
    S.project.gen3Modes=S.project.gen3Modes or {};S.project.gen3Modes.map_scripts=S.project.gen3Modes.map_scripts or {}
    S.project.gen3Modes.map_scripts[script]="register"
  end
  S.mapSection=kind;S[groups[kind][2]]=index;S.mapEditMode="events"
  App.markDirty()
  require("Gen3EventWindow").request(S,S.mapId,kind,index)
  return true
end
local function scriptUsed(project,script)
  for _,map in pairs(project.maps or {}) do
    if type(map)=="table" then
      for _,kind in ipairs({"objects","signs","coordEvents"}) do
        for _,row in ipairs(map[kind] or {}) do
          if row.scriptKey==script or row.touchScriptKey==script then return true end
        end
      end
    end
  end
end
local function dropEditorScript(project,script)
  if type(script)~="string" or script:sub(1,7)~="EDITOR_" then return end
  if scriptUsed(project,script) then return end
  local scripts=project.gen3 and project.gen3.map_scripts
  if type(scripts)~="table" then return end
  local modes=project.gen3Modes and project.gen3Modes.map_scripts
  local drop={}
  for key in pairs(scripts) do
    if key==script or key:sub(1,#script+1)==script.."_" then drop[#drop+1]=key end
  end
  for _,key in ipairs(drop) do
    scripts[key]=nil
    if type(modes)=="table" then modes[key]=nil end
    local text=project.text
    if type(text)=="table" then text[key.."_Text"]=nil end
  end
end
function M.remove(S,kind,index,App)
  if not groups[kind] then return false end
  local mapId=S.mapId
  assert(require("Gen3Workspace").convert(S,mapId))
  local map=S.project.maps[mapId]
  local rows=map[kind] or {}
  local ev=rows[index]
  if type(ev)~="table" then return false end
  local scripts={ev.scriptKey,ev.touchScriptKey}
  if kind=="warps" then
    if not require("LayeredMap").removeWarpAt(S.project,mapId,ev.x,ev.y) then
      table.remove(rows,index)
    end
  else
    table.remove(rows,index)
    if kind=="objects" or kind=="signs" then
      local owner=kind.."/"..tostring(ev.localId or index)
      local coords=map.coordEvents
      if type(coords)=="table" then
        for i=#coords,1,-1 do
          local row=coords[i]
          if row._editorTriggerOwner==owner then
            scripts[#scripts+1]=row.scriptKey
            table.remove(coords,i)
          end
        end
      end
    end
  end
  for _,script in ipairs(scripts) do dropEditorScript(S.project,script) end
  if kind=="objects" then
    local State=require("State")
    local label=State.mapLabel(S,mapId)
    local bucket=S.project.trainer_headers and S.project.trainer_headers[label]
    local idx=ev.index or index
    local hdr=type(bucket)=="table" and bucket[idx]
    if type(hdr)=="table" then
      if type(S.project.text)=="table" then
        for _,key in ipairs({"battle","won","after"}) do
          local tid=hdr[key]
          if type(tid)=="string" and tid:sub(1,1)=="_" then S.project.text[tid]=nil end
        end
      end
      bucket[idx]=nil
      if not next(bucket) then S.project.trainer_headers[label]=nil end
      State.rebuildEventFlags(S.project)
    end
  end
  local left=#(map[kind] or {})
  S[groups[kind][2]]=left>0 and math.min(index,left) or 1
  S._g3EventIdentity=nil
  if App then App.markDirty() end
  S.status="Removed "..groups[kind][1]:lower():gsub("s$","").."."
  return true
end
local function drawContent(S,x,y,w,App)
  local Kit=require("Kit")
  local s=Kit.scale
  local map=require("Maps").resolveMap(S,S.mapId)
  if not map then return y end
  if S._g3NameMap~=S.mapId then S._g3NameMap=S.mapId;S.g3MapNameDraft=map.label or map.name or S.mapId end
  Kit.caption(x,y,"Display name")
  S.g3MapNameDraft=Kit.textfield("g3MapName",x,y+22*s,w,28*s,S.g3MapNameDraft,"Map name",
    "Displayed map name. Renaming keeps the map ID, warps and script references unchanged.")
  if Kit.button(x,y+56*s,w,27*s,"Rename display name",{kind="accent",tooltip="Apply this display name. Save editors and warps identify the map by its unchanged internal ID."}) then
    local changed,err=require("Gen3Workspace").rename(S,S.mapId,S.g3MapNameDraft)
    if changed then App.markDirty();S.status="Renamed map to "..S.project.maps[S.mapId].name;map=S.project.maps[S.mapId]
    elseif err then S.status=err end
  end
  y=y+94*s
  Kit.text("micro",Kit.ellipsize("micro","Map ID: "..S.mapId,w),x,y,require("Theme").PAL.muted)
  Kit.offerTooltip(x,y,w,18*s,"Internal ID: "..S.mapId..". Used by saves and warps; renaming the display name does not change it.")
  y=y+24*s
  if map._isNew then
    if S._g3IdMap~=S.mapId then S._g3IdMap=S.mapId;S.g3MapIdDraft=S.mapId end
    S.g3MapIdDraft=Kit.textfield("g3MapId",x,y,w,27*s,S.g3MapIdDraft,"MAP_ID",
      "Change this new map's internal ID. Existing saves still reference the old ID.")
    if Kit.button(x,y+32*s,w,27*s,"Change map ID",{kind="accent",
        tooltip="Update exact map references in this project. Existing save files and external mods are not migrated."}) then
      local changed,err=require("Gen3MapIdentity").rename(S,S.mapId,S.g3MapIdDraft)
      if changed then App.markDirty();map=S.project.maps[S.mapId];S.status="Map ID changed to "..S.mapId
      else S.status=err end
    end
    y=y+67*s
  end
  y=require("Gen3MapProperties").draw(S,map,x,y,w,App)
  if Kit.button(x,y,w,27*s,S.g3ShowConnections and "Show events" or "Map connections",{tooltip="Add or edit multiple connections per side, each with its own offset."}) then S.g3ShowConnections=not S.g3ShowConnections end
  y=y+36*s
  if S.g3ShowConnections then return require("Gen3ConnectionEditor").draw(S,S.mapId,x,y,w,0,App,true) end
  local bx,by=x,y
  for _,kind in ipairs({"objects","signs","coordEvents","warps"}) do
    local bw=(w-6*s)/2
    if Kit.button(bx,by,bw,26*s,groups[kind][1],{kind=S.mapSection==kind and "primary" or "ghost"}) then S.mapSection=kind end
    if bx>x then bx=x;by=by+31*s else bx=x+bw+6*s end
  end
  local kind=groups[S.mapSection] and S.mapSection or "objects"
  local rows=map[kind] or {};local key=groups[kind][2]
  S[key]=math.max(1,math.min(S[key] or 1,#rows))
  y=by+8*s
  Kit.caption(x,y,groups[kind][1].." "..S[key].." / "..#rows)
  if Kit.button(x,y+25*s,45*s,25*s,"<",{}) then S[key]=math.max(1,S[key]-1) end
  if Kit.button(x+50*s,y+25*s,45*s,25*s,">",{}) then S[key]=math.min(#rows,S[key]+1) end
  local ev=rows[S[key]]
  if not ev then return y+50*s end
  local identity=S.mapId..kind..S[key]
  if S._g3EventIdentity~=identity or S._g3EventValue~=ev then
    S._g3EventIdentity,S._g3EventValue=identity,ev
    S._g3EventDraft={value=require("ModWriter").encodeLua(ev)}
    S._g3Expanded=S._g3Expanded or {};S._g3Expanded.value=true
  end
  if S.g3MapEventAdvanced==true and Kit.button(x+102*s,y+25*s,90*s,25*s,"Apply",{kind="primary"}) then
    local decoded,err=require("Gen3Decode").decode("return {value="..S._g3EventDraft.value.."}",{allowArray=true})
    if decoded and type(decoded.value)=="table" and type(decoded.value.x)=="number" and type(decoded.value.y)=="number" then
      require("Gen3Workspace").convert(S,S.mapId)
      S.project.maps[S.mapId][kind][S[key]]=decoded.value
      if kind=="warps" then require("LayeredMap").syncMapWarps(S,S.project.maps[S.mapId]) end
      App.markDirty()
    else S.status=err or "Event needs numeric x and y coordinates" end
  end
  local delW=90*s
  if Kit.button(x,y+57*s,math.max(40*s,w-delW-6*s),27*s,"Open event window",{}) then
    require("Gen3EventWindow").request(S,S.mapId,kind,S[key])
  end
  if Kit.button(x+w-delW,y+57*s,delW,27*s,"Delete",{kind="danger",
      tooltip="Remove this event from the map"}) then
    M.remove(S,kind,S[key],App)
    return y+90*s
  end
  local fieldTop=y+92*s
  if kind~="warps" then
    local scripts=require("RegList").mergeIds((S.project.gen3 or {}).map_scripts or {},require("Gen3").catalog(S.data,"map_scripts"))
    require("ChoicePicker").field(S,{x=x,y=fieldTop,w=w,h=27*s,ids=scripts,current=ev.scriptKey or "",emptyLabel="Assign event script",title="EVENT SCRIPT",
      onPick=function(id)
        require("Gen3Workspace").convert(S,S.mapId)
        S.project.maps[S.mapId][kind][S[key]].scriptKey=id
        S._g3EventIdentity=nil;App.markDirty()
      end})
    fieldTop=fieldTop+35*s
  end
  local controlsTop=fieldTop
  if kind~="warps" then controlsTop=require("Gen3RpgEventEditor").drawQuick(S,ev,x,controlsTop,w,App) end
  local advanced=S.g3MapEventAdvanced==true
  if Kit.button(x,controlsTop,w,27*s,advanced and "Show simple controls" or "Advanced fields",{}) then S.g3MapEventAdvanced=not advanced end
  local ending
  if advanced then ending=require("Gen3Fields").draw(S,identity,x,controlsTop+35*s,w,S._g3EventDraft,{})
  else ending=require("Gen3MapEventForm").draw(S,ev,kind,key,x,controlsTop+35*s,w,App) end
  return ending
end
function M.draw(S,x,y,w,h,App)
  local Pane=require("FormPane")
  Pane.track(S,"g3MapEventScroll",S.mapId)
  local top,view=Pane.begin(S,"g3MapEventScroll",x,y,w,math.max(0,h))
  local ending=drawContent(S,x,top,view.contentW,App)
  Pane.finish(S,"g3MapEventScroll",top,ending,view)
end
return M
