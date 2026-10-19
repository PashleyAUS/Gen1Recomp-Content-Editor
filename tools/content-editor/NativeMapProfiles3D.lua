-- Editor-owned rules inferred from native art and passages. No third-party code.
local M={VERSION=1}
local O=require('MapObjects3D')
local function generated(o) return o.profileGenerated or o.interiorGenerated or o.environmentGenerated end
local function rgb(r,g,b) return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5) end
function M.category(source,def)
  local mt=tonumber((def or {}).mapType)
  if mt==5 then return 'underwater' end
  if mt==4 then return 'cave' end
  local environment=require('Environment3D').kind(source)
  if environment then return environment end
  if mt==1 or mt==2 or mt==3 or mt==6 then return 'outdoor' end
  local pair=source.baseTileset or ''
  if pair:match('^general__') or pair:find('outdoor',1,true) then return 'outdoor' end
  return 'interior'
end
-- Cache measurements, not extracted art, across a bulk build's tileset pairs.
function M.measure(S,pair,context)
  context=context or {};context.metrics=context.metrics or {}
  if context.metrics[pair] then return context.metrics[pair] end
  local descriptor=assert(require('Gen3Workspace').descriptor(S,pair),'Native tileset unavailable: '..tostring(pair))
  local count=descriptor.count
  assert(count>0 and count<=4096,'Native tileset has invalid metatile count')
  local g=love.graphics;local canvas=g.newCanvas(128,math.ceil(count/8)*16)
  g.push('all');g.setCanvas(canvas);g.origin();g.setScissor();g.clear(0,0,0,0)
  for tile=0,count-1 do require('Gen3Workspace').drawTile(S,descriptor,tile,(tile%8)*16,math.floor(tile/8)*16,16,1) end
  g.pop()
  local pixels=canvas:newImageData();canvas:release()
  local result={}
  for tile=0,count-1 do
    local colors,visible,bright={},0,0
    for y=0,15 do for x=0,15 do
      local r,b,c,a=pixels:getPixel((tile%8)*16+x,math.floor(tile/8)*16+y)
      if a>.01 then
        local k=rgb(r,b,c);colors[k]=(colors[k] or 0)+1;visible=visible+1
        if math.max(r,b,c)>.08 then bright=bright+1 end
      end
    end end
    local sorted={};for key,n in pairs(colors) do sorted[#sorted+1]={key,n} end
    table.sort(sorted,function(a,b) return a[2]==b[2] and a[1]<b[1] or a[2]>b[2] end)
    local palette={};for i=1,math.min(16,#sorted) do palette[i]=sorted[i][1] end
    result[tile]={void=visible==0 or bright<4,colors=palette}
  end
  pixels:release();context.metrics[pair]=result;return result
end
function M.apply(source,def,metrics)
  def=def or {};metrics=metrics or {}
  assert(source.cellWidth>0 and source.cellHeight>0,'Map has no cells')
  local width,height=source.cellWidth,source.cellHeight
  local cells=source.layers[1].cells
  local function info(x,y)
    local c=x>=0 and y>=0 and x<width and y<height and cells[y*width+x+1]
    return c and metrics[c.tile],c
  end
  local function void(x,y)
    local m,c=info(x,y);return not c or (m and m.void) or false
  end
  local manual={}
  for _,o in ipairs(source.visualObjects or {}) do if not generated(o) then manual[#manual+1]=o end end
  source.visualObjects=manual
  -- Remove only terrain still equal to our previous generated value.
  for i,z in pairs(source.visualProfileHeights or {}) do
    if (source.visualHeights or {})[i]==z and not (source.visualShapes or {})[i] then source.visualHeights[i]=nil end
  end
  source.visualProfileHeights={}
  local category=M.category(source,def)
  source.visualPlayable=true;source.visualNativeProfile={version=M.VERSION,category=category,counts={},fallbackCells=0}
  source.visualProfileVersion=M.VERSION
  source.visualPerspective=source.visualPerspective or .5
  source.visualCamera=source.visualCamera or {angle=0,pitch=.75,scale=16}
  if category=='cave' or category=='underwater' then
    source.visualEnvironment=category
    require('Environment3D').apply(source,def)
    for i in pairs(source.visualEnvironmentHeights or {}) do
      local x,y=(i-1)%width,math.floor((i-1)/width)
      if void(x,y) then source.visualHeights[i]=nil;source.visualEnvironmentHeights[i]=nil end
    end
    if category=='underwater' then
      local votes,floor={},nil
      for i,c in ipairs(cells) do
        if source.collision[i]=='water' and not ((metrics[c.tile] or {}).void) then
          votes[c.tile]=(votes[c.tile] or 0)+1
          if not floor or votes[c.tile]>floor.count then floor={x=(i-1)%width,y=math.floor((i-1)/width),tile=c.tile,count=votes[c.tile]} end
        end
      end
      if floor then
        for _,o in ipairs(source.visualObjects) do if o.environmentGenerated and o.style=='native_underwater_plant' then
          o.style='native_profile_voxel';o.profileThickness=.05
          o.cutoutColors=(metrics[floor.tile] or {}).colors or {}
          o.groundDX,o.groundDY=floor.x-o.x,floor.y-o.y;source.visualNativeCutouts=true
        end end
      end
    end
    source.visualNativeProfile.counts[category]=1
    source.visualNativeProfile.fallbackCells=0
    return source
  end
  source.visualInterior=category=='interior' or nil
  local objects,occupied={},{}
  local function claim(o)
    for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do occupied[y*width+x+1]=true end end
  end
  for _,o in ipairs(manual) do claim(o) end
  local function add(o,class,overlap)
    for _,m in ipairs(manual) do if O.overlaps(o,m) and (o.style~='native_room_wall' or m.kind=='none') then return end end
    if not overlap then
      for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do if occupied[y*width+x+1] then return end end end
    end
    o.profileGenerated=true;o.profileClass=class;o.profileBaseStyle=o.style;o.automatic=nil
    objects[#objects+1]=o;claim(o)
    local counts=source.visualNativeProfile.counts;counts[class]=(counts[class] or 0)+1
    return o
  end
  -- Prefer actual walkable art for the floor exposed beneath lifted objects.
  local votes,ground={},nil
  for i,c in ipairs(cells) do
    local mode=(source.collision or {})[i];local m=metrics[c.tile]
    if (mode=='walk' or mode=='grass') and not (m and m.void) then
      votes[c.tile]=(votes[c.tile] or 0)+1
      if not ground or votes[c.tile]>ground.count then ground={x=(i-1)%width,y=math.floor((i-1)/width),tile=c.tile,count=votes[c.tile]} end
    end
  end
  local colors=ground and metrics[ground.tile] and metrics[ground.tile].colors or {}
  source.visualProfileColors=colors
  local function mask(o)
    o.cutoutColors=colors
    if ground then o.groundDX,o.groundDY=ground.x-o.x,ground.y-o.y end
    if category=='interior' then
      -- A room can have wood AND a rug. Use the actual floor surrounding
      -- this object, so its rug pixels do not become an upright blue wall.
      local palette,seen,localVotes,localGround={},{},{},nil
      for _,k in ipairs(colors) do seen[k]=true;palette[#palette+1]=k end
      for y=math.max(0,o.y-1),math.min(height-1,o.y+o.height) do
        for x=math.max(0,o.x-1),math.min(width-1,o.x+o.width) do
          local i=y*width+x+1;local mode=source.collision[i];local c=cells[i]
          if mode=='walk' or mode=='grass' then
            for _,k in ipairs((metrics[c.tile] or {}).colors or {}) do if not seen[k] then seen[k]=true;palette[#palette+1]=k end end
            if x<o.x or y<o.y or x>=o.x+o.width or y>=o.y+o.height then
              localVotes[c.tile]=(localVotes[c.tile] or 0)+1
              if not localGround or localVotes[c.tile]>localGround.count then localGround={x=x,y=y,count=localVotes[c.tile]} end
            end
          end
        end
      end
      o.cutoutColors=palette
      if localGround then o.groundDX,o.groundDY=localGround.x-o.x,localGround.y-o.y end
    end
    source.visualNativeCutouts=true
    return o
  end
  local panel,panelVotes=nil,{}
  if category=='interior' and height>1 then
    for x=0,width-1 do
      local m,c=info(x,1)
      if c and not (m and m.void) and source.collision[width+x+1]=='solid' then
        panelVotes[c.tile]=(panelVotes[c.tile] or 0)+1
        if not panel or panelVotes[c.tile]>panel.count then panel={x=x,y=1,tile=c.tile,count=panelVotes[c.tile]} end
      end
    end
  end
  local precise=false
  if category=='interior' then
    -- Reusable, guarded room recipes. The Center's original-art treatment
    -- follows the tileset signature wherever the game places that layout.
    local recipeDef={warps=def.warps,nativeArtworkProfiles=true}
    local pair=source.baseTileset
    if pair=='building__pokemon_center' or pair=='building__lab' or source.id=='EM_ABANDONED_SHIP_CAPTAINS_OFFICE' then
      require('Interior3D').apply(source,recipeDef)
    else
      source.visualObjects=O.detectProps(source)
      for _,o in ipairs(source.visualObjects) do o.interiorGenerated=true end
    end
    for _,o in ipairs(source.visualObjects) do
      if o.interiorGenerated and o.style~='fixture' and o.style~='wall' then
        if not o.style or o.style=='clock' then
          local palette={};for _,k in ipairs(colors) do palette[#palette+1]=k end
          if panel then for _,k in ipairs((metrics[panel.tile] or {}).colors or {}) do palette[#palette+1]=k end end
          o.style='native_profile_voxel';o.profileThickness=.06;mask(o);o.cutoutColors=palette
          if o.kind=='wall_decor' then o.anchorDepth=.2 end
        end
        add(o,o.style=='native_room_wall' and 'wall' or o.style=='native_fixture' and 'counter' or 'prop',true)
        if o.style=='native_room_wall' or o.style=='native_fixture' or o.style=='native_cutout' then precise=true end
      end
    end
    source.visualObjects=manual
  else
    if (source.id or ''):match('^FR_') then source.visualNativeObjects='frlg' end
    for _,o in ipairs(O.detect(source)) do
      if o.kind=='building' then
        o.style='native_building_surfaces';o.roofRows=o.roofRows or math.max(1,math.floor(o.height*.6))
        if source.id=='EM_LITTLEROOT_TOWN' and o.x==2 and o.y==4 then o.style='littleroot_native_surfaces' end
        if source.id=='EM_LITTLEROOT_TOWN' and o.x==3 and o.y==12 then o.style='littleroot_lab_native_surfaces' end
      else
        o.style='native_profile_voxel';o.size=o.size or o.height;o.lean=o.kind=='tree' and 45 or (o.lean or 0)
        o.profileThickness=o.kind=='tree' and .12 or .08;mask(o)
      end
      add(o,o.kind)
    end
  end
  -- FR/LG's standard Center is a shared native pattern, not a map-ID rule.
  if category=='interior' and source.baseTileset=='network' and width==16 and height==10
      and cells[1].tile==672 and cells[3*width+5].tile==697 then
    precise=true
    local wall=add({kind='wall_decor',style='native_room_wall',x=0,y=0,width=15,height=2,size=2,
      wallClearRects={{1,0,3,2},{4,1,7,1},{11,0,1,2}},wallFill={4,.25,1,.75},wallTopFill={4,0,1,1}},'wall',true)
    local background={};for _,k in ipairs(colors) do background[#background+1]=k end
    for _,k in ipairs((metrics[644] or {}).colors or {}) do background[#background+1]=k end
    local function card(x,y,w,h,class)
      local o=mask({kind='furniture',style='native_profile_voxel',x=x,y=y,width=w,height=h,size=h,
        profileThickness=.08,rotation=0})
      o.cutoutColors=background;return add(o,class,true)
    end
    card(1,0,1,3,'plant');card(2,0,2,3,'bookcase')
    card(5,1,2,2,'equipment');card(9,1,1,2,'equipment');card(11,0,1,3,'equipment')
    for _,x in ipairs({4,10}) do
      add({kind='furniture',style='native_fixture',x=x,y=1,width=1,height=2,size=.7,
        surfaceTopRows=1.5,surfaceTopRect={0,.6,1,2},surfaceDepth=2},'counter',true)
    end
    add({kind='furniture',style='native_fixture',x=4,y=3,width=7,height=2,size=.7,
      surfaceTopRows=.45,surfaceFrontRect={0,.45,7,1},surfaceDepth=1},'counter',true)
    card(11,6,2,2,'table')
    for y=3,height-1 do for x=0,width-1 do
      local tile=cells[y*width+x+1].tile
      if tile==757 or tile==765 then card(x,y,1,1,'stool') end
    end end
  end
  -- An entrance is a useful anchor for a building whose roof tile IDs are
  -- not in the shared outdoor signature list. Find its bounded solid facade.
  local directions={{1,0},{-1,0},{0,1},{0,-1}}
  local function solid(x,y)
    return x>=0 and y>=0 and x<width and y<height and not void(x,y)
      and not occupied[y*width+x+1] and source.collision[y*width+x+1]=='solid'
  end
  local function region(x,y,seen)
    local q={{x,y}};local head=1;seen[y*width+x+1]=true
    local r={x0=x,x1=x,y0=y,y1=y,cells={}}
    while q[head] do
      local p=q[head];head=head+1;r.cells[#r.cells+1]=p
      r.x0,r.x1=math.min(r.x0,p[1]),math.max(r.x1,p[1]);r.y0,r.y1=math.min(r.y0,p[2]),math.max(r.y1,p[2])
      for _,d in ipairs(directions) do
        local nx,ny=p[1]+d[1],p[2]+d[2];local i=ny*width+nx+1
        if solid(nx,ny) and not seen[i] then seen[i]=true;q[#q+1]={nx,ny} end
      end
    end
    return r
  end
  if category=='outdoor' then
    local seen={}
    for _,w in ipairs(def.warps or {}) do
      if w.destMap and w.destMap~=source.id and solid(w.x,w.y-1) and not seen[(w.y-1)*width+w.x+1] then
        local r=region(w.x,w.y-1,seen)
        local rw,rh=r.x1-r.x0+1,w.y-r.y0+1
        if rw>=2 and rw<=16 and rh>=2 and rh<=10 and r.y1<=w.y+1 then
          add({kind='building',style='native_building_surfaces',x=r.x0,y=r.y0,width=rw,height=rh,
            roofRows=math.max(1,math.floor(rh*.6)),rotation=0},'building')
        end
      end
    end
  end
  -- Generic interiors get a rear wall and whole connected props rather than
  -- a field of unrelated one-tile boxes. Specific recipes above take priority.
  local wall
  if category=='interior' and not precise then
    for y=0,math.min(5,height-1) do
      local n=0;for x=0,width-1 do if solid(x,y) then n=n+1 end end
      if n>=width*.6 then
        local start,finish
        for x=0,width-1 do if not void(x,y) then start=start or x;finish=x end end
        if start and finish>start then
          wall=add({kind='wall_decor',style='native_room_wall',x=start,y=y,width=finish-start+1,
            height=math.min(2,height-y),size=math.min(2,height-y),rotation=0},'wall',true)
        end
        break
      end
    end
  end
  if wall and panel then
    for _,o in ipairs(objects) do
      if o~=wall and o.kind=='wall_decor' and O.overlaps(o,wall) then
        wall.wallClearRects=wall.wallClearRects or {}
        wall.wallClearRects[#wall.wallClearRects+1]={o.x-wall.x,math.max(0,o.y-wall.y),o.width,math.min(o.height,wall.height)}
        wall.wallFill={panel.x-wall.x,panel.y-wall.y,1,1}
      end
    end
  end
  local protected={}
  for _,w in ipairs(def.warps or {}) do for dy=-1,1 do for dx=-1,1 do
    local px,py=w.x+dx,w.y+dy
    if px>=0 and py>=0 and px<width and py<height then protected[py*width+px+1]=true end
  end end end
  local seen={}
  for y=0,height-1 do for x=0,width-1 do
    if solid(x,y) and not seen[y*width+x+1] then
      local r=region(x,y,seen);local rw,rh=r.x1-r.x0+1,r.y1-r.y0+1
      local nearExit=false
      for _,p in ipairs(r.cells) do if protected[p[2]*width+p[1]+1] then nearExit=true;break end end
      if not nearExit and rw<=8 and rh<=6 and #r.cells>=rw*rh*.4 then
        local top=r.y0
        if wall and top==wall.y+wall.height then top=math.max(wall.y+1,top-1) end
        local h=r.y1-top+1
        local o=mask({kind='furniture',style='native_profile_voxel',x=r.x0,y=top,width=rw,height=h,
          size=h,anchorDepth=h,profileThickness=.08,rotation=0})
        -- Original wall art behind a lifted prop becomes a plain native panel.
        if wall and top<wall.y+wall.height then
          local panel=wall.x
          local counts={};local best
          for wx=wall.x,wall.x+wall.width-1 do
            local c=cells[(wall.y+1)*width+wx+1]
            if c then counts[c.tile]=(counts[c.tile] or 0)+1;if not best or counts[c.tile]>best.n then best={n=counts[c.tile],x=wx} end end
          end
          panel=best and best.x or panel
          wall.wallFill={panel-wall.x,1,1,1}
          wall.wallClearRects=wall.wallClearRects or {};wall.wallClearRects[#wall.wallClearRects+1]={r.x0-wall.x,top-wall.y,rw,wall.y+wall.height-top}
        end
        add(o,'prop',wall~=nil)
      else
        -- Long walls/cliffs are terrain relief. Keep authored heights/slopes.
        source.visualHeights=source.visualHeights or {}
        for _,p in ipairs(r.cells) do
          local i=p[2]*width+p[1]+1
          if not protected[i] and source.visualHeights[i]==nil and not (source.visualShapes or {})[i] then
            source.visualHeights[i]=2;source.visualProfileHeights[i]=2
          end
        end
        source.visualNativeProfile.fallbackCells=source.visualNativeProfile.fallbackCells+#r.cells
      end
    end
  end end
  if ground then for _,o in ipairs(objects) do if o.groundDX==nil then o.groundDX,o.groundDY=ground.x-o.x,ground.y-o.y end end end
  for _,o in ipairs(manual) do objects[#objects+1]=o end
  source.visualObjects=objects;source.visualAutoObjects=false
  source.visualBackground=source.visualBackground or (category=='interior' and {.035,.035,.045} or {.07,.12,.22})
  return source
end
function M.build(S,id,context)
  local source=assert(require('LayeredMap').convertMap(S,id))
  local def={};for k,v in pairs(S.project.maps[id] or {}) do def[k]=v end
  for k,v in pairs(require('Gen3MapProperties').resolve(S,def)) do if def[k]==nil then def[k]=v end end
  return M.apply(source,def,M.measure(S,source.baseTileset,context))
end
function M.connect(S)
  local maps=S.project.layeredMaps or {};local seen={}
  local ids={};for id,s in pairs(maps) do if s.visualNativeProfile then ids[#ids+1]=id end end;table.sort(ids)
  for _,id in ipairs(ids) do
    if not seen[id] then
      local queue={id};seen[id]=true;local n=1
      while queue[n] do
        local mid=queue[n];n=n+1
        local def=(S.project.maps or {})[mid] or (S.data.maps or {})[mid] or {}
        for _,row in ipairs(require('Gen3Connections').each(def.connections)) do
          local dest=row[2].map or row[2].mapId
          if maps[dest] and maps[dest].visualNativeProfile and not seen[dest] then seen[dest]=true;queue[#queue+1]=dest end
        end
      end
      if #queue>1 then
        local anchor=queue[1]
        for _,mid in ipairs(queue) do
          local s=maps[mid]
          if s.visualWorldAnchor and maps[s.visualWorldAnchor] then anchor=s.visualWorldAnchor;break end
        end
        for _,mid in ipairs(queue) do maps[mid].visualWorldAnchor=anchor end
      end
    end
  end
end
function M.start(S,App)
  if S.nativeProfileJob then return end
  local ids,seen={},{}
  for _,bag in ipairs({S.data.maps or {},S.project.maps or {}}) do for id in pairs(bag) do
    if not seen[id] then seen[id]=true;ids[#ids+1]=id end
  end end
  table.sort(ids)
  S.nativeProfileJob={ids=ids,index=1,context={},errors={},done=0,App=App,project=S.project,data=S.data}
  if App.beginEditBatch then App.beginEditBatch() end
end
function M.finish(S)
  local job=S.nativeProfileJob;if not job then return end
  M.connect(S)
  S.nativeProfileReport={built=job.done,total=#job.ids,errors=job.errors,cancelled=job.cancelled or false}
  if job.done>0 and job.App.markDirty then job.App.markDirty() end
  if job.App.endEditBatch then job.App.endEditBatch() end
  S.status=string.format('3D profiles: %d/%d maps, %d errors%s',job.done,#job.ids,#job.errors,job.cancelled and ' (stopped)' or '')
  S.nativeProfileJob=nil
end
function M.update(S)
  local job=S.nativeProfileJob;if not job then return end
  if job.project~=S.project or job.data~=S.data then S.nativeProfileJob=nil;S.status='3D build stopped: project changed';return end
  local deadline=love.timer.getTime()+.008
  repeat
    local id=job.ids[job.index]
    if not id or job.cancelled then M.finish(S);return end
    local ok,err=pcall(M.build,S,id,job.context)
    if ok then job.done=job.done+1;if job.done==1 and job.App.markDirty then job.App.markDirty() end else job.errors[#job.errors+1]={id=id,message=tostring(err)} end
    job.index=job.index+1
    S.status=string.format('Building 3D profiles: %d/%d — %s',job.index-1,#job.ids,id)
  until love.timer.getTime()>=deadline
end
return M
