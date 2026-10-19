-- Exercises original town IDs and original interior warp destinations as real mods.
return function(data,root,output,game)
  local IO,L=require('ModIO'),require('LayeredMap')
  local Models,N=require('MapObjects3D'),require('MapNavigation3D')
  local houseReview=os.getenv('POKEPORT_HOUSE_REVIEW')=='1'
  local interiorReview=os.getenv('POKEPORT_INTERIOR_REVIEW')=='1'
  local requestedRoom=os.getenv('POKEPORT_INTERIOR_MAP')
  local reviewPrefix=requestedRoom and 'scene' or 'captains-office'
  output=output..'/'..game..(interiorReview and (requestedRoom and '-review-'..requestedRoom:lower() or '-interior-review') or houseReview and '-house-review' or '');IO.ensureDirectory(output)
  local modId='town3d_'..game
  local S={data=data,version=game,project=require('State').blankProject(modId,game=='emerald' and 'Littleroot Town 3D' or 'Pallet Town 3D')}
  S.project.game=game;S.path=output..'/mod';IO.ensureDirectory(S.path)
  IO.writeText(S.path..'/manifest.json','{"id":"'..modId..'","name":"3D native town","version":"1.0.0","entry":"main.lua","games":["'..game..'"]}')
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local town=require('Town3D').build(S)
  local reviewRoom
  if interiorReview then
    reviewRoom=requestedRoom or 'EM_ABANDONED_SHIP_CAPTAINS_OFFICE'
    require('Interior3D').apply(assert(L.convertMap(S,reviewRoom)),S.project.maps[reviewRoom])
    if os.getenv('POKEPORT_CUSTOM_MODEL_REVIEW')=='1' then dofile(root..'/tests/content-editor/custom_model_review.lua')(S,S.project.layeredMaps[reviewRoom],root) end
  end
  if os.getenv('POKEPORT_NATIVE_PROFILE_REVIEW')=='1' then
    local profiles=require('NativeMapProfiles3D');local context={}
    profiles.build(S,town.id,context)
    if reviewRoom then profiles.build(S,reviewRoom,context) end
  end
  local signs,fences=0,0
  for _,o in ipairs(Models.objects(town.source)) do
    if o.kind=='sign' then signs=signs+1 elseif o.kind=='fence' then fences=fences+1 end
  end
  assert(signs>0 and (game=='emerald' or fences>0),'Native outdoor signs/fences were not modeled')
  local clocks,plants=0,0
  for _,id in ipairs(town.interiors) do for _,o in ipairs(Models.objects(S.project.layeredMaps[id])) do
    if o.kind=='wall_decor' then clocks=clocks+1 elseif o.kind=='potted_plant' then plants=plants+1 end
  end end
  assert(plants>0 and (game~='emerald' or clocks==2),'Native clocks/plants were not modeled as complete props')
  assert(town.buildings==3,'Native town buildings were not all modeled')
  for _,model in ipairs(Models.objects(town.source)) do
    if model.kind=='building' then assert(model.rotation==0 and model.style,'Town house lost its authored forward-facing geometry') end
  end
  assert(town.source.visualTreeStyle=='sprite' and town.source.visualForestBorder>0,'Town forest presentation missing')
  local profileMod=os.getenv('POKEPORT_PROFILE_MOD')
  if profileMod and profileMod~='' then S.path=profileMod
  else assert(L.compileProject(S));assert(IO.save(S.path,S.project)) end
  local fresh={};require('Gen3').load(fresh,data._gen3Read)
  local loader=assert(require('Gen3Mod').load(fresh,S.path))
  if reviewRoom then
    local def=assert(fresh.maps[reviewRoom])
    def.midLayout=def.midLayout or assert(require('Gen3Map').layout(fresh,reviewRoom))
    def.width,def.height=def.midLayout.width,def.midLayout.height
    assert(require('Gen3Map').tileset(fresh,def.pair))
  end
  assert(require('Gen3Map').tileset(fresh,town.source.baseTileset))
  -- Interior maps are exported too; keep their compiled native layouts intact.
  for _,w in ipairs(town.def.warps) do
    local def=assert(fresh.maps[w.destMap])
    def.midLayout=def.midLayout or assert(require('Gen3Map').layout(fresh,w.destMap))
    def.width,def.height=def.midLayout.width,def.midLayout.height
    assert(require('Gen3Map').tileset(fresh,def.pair))
  end
  local Bus=require('src.mods.Runtime');Bus.install(loader.events,loader.hooks,loader.errors)
  local held,pressed
  local input={isDown=function(_,key) return held==key end,wasPressed=function(_,key) return pressed==key end}
  local session={version=game,map=town.id,x=town.slope.x-1,y=town.slope.y+1,facing='up',party={},
    bag=require('src.core.game3.bag').new(),dex=require('src.core.game3.dex').new(),
    flags={},vars={},options={},money=0,gender='male'}
  -- An isolated post-introduction save; the exported mod keeps native story data.
  local constants=require('src.core.game3.scripting.flags').forVersion(game)
  for name,id in pairs(constants.VAR_IDS) do
    if name:find('SCENE') or name:find('LITTLEROOT') or name:find('PALLET') or name:find('STARTER') or name:find('ROUTE') then session.vars[tostring(id)]=999 end
  end
  for name,id in pairs(constants.IDS) do
    if name:find('SYS_POKEMON_GET') or name:find('SYS_POKEDEX_GET') or name:find('RECEIVED_STARTER') or name:find('HIDE_LITTLEROOT') or name:find('HIDE.*TRUCK') then session.flags[tostring(id)]=true end
    if name:find('HOUSE_RIVAL_MOM') then session.flags[tostring(id)]=false end
  end
  if interiorReview then
    -- Isolated traversal test save: trainers have already been defeated, so
    -- their native sight scripts cannot interrupt the camera/warp checks.
    for trainer=1,1024 do session.flags[tostring(0x500+trainer)]=true end
  end
  local g={data=fresh,session=session,save={position={},party={}},input=input,options={}}
  local cache={read=function(_,p) return data._gen3Read((p:gsub('^'..game..'/',''))) end,
    write=function() return false end}
  local host={cache=cache,game=g,log={info=function() end,warn=function() end},
    storage={load=function() return nil end,save=function() return true end}}
  for _,e in ipairs(loader.events.listeners['game.ready'] or {}) do e.callback({game=g}) end
  local Core,Map,P,C=require('src.core.game3.runtime'),require('src.core.game3.map'),require('src.core.game3.player'),require('src.core.game3.collision')
  require('src.core.game3.ow_sprites').install(cache)
  Core.start(host,g,session,{alreadyOnMap=true})
  local Display=require('src.core.game3.display')
  local tickCount=0
  local pendingShot,recording,monitorConnections,previousWorld
  local expectedMode='3d'
  local function shot(label) pendingShot=label;coroutine.yield() end
  local function tick(dir)
    held,pressed=dir,dir~=held and dir or nil
    Core.update(1/60);pressed=nil;tickCount=tickCount+1
    if recording and tickCount%6==0 then pendingShot=string.format(monitorConnections and 'connection-%05d' or 'town-walk-%05d',tickCount) end
    coroutine.yield()
  end
  local function settle()
    local Warp=require('src.core.game3.warp')
    for _=1,1000 do
      tick(nil)
      local Field=require('src.core.game3.field')
      if not Warp.isBusy() and not require('src.ui.game3.fade').isActive()
          and not P.moving and not Field.locked then return end
    end
    error('Field/warp did not settle on '..tostring(Map.current))
  end
  local dirs={{'up',0,-1},{'down',0,1},{'left',-1,0},{'right',1,0}}
  local function walkTo(tx,ty,probe,retries)
    local start=P.cellY*1024+P.cellX
    local queue={{P.cellX,P.cellY}};local head=1;local previous={[start]=false}
    while head<=#queue do
      local item=queue[head];head=head+1
      if item[1]==tx and item[2]==ty then break end
      for _,d in ipairs(dirs) do
        local x,y=item[1]+d[2],item[2]+d[3];local key=y*1024+x
        local authored=true
        if Map.current==town.id then
          local i=y*town.source.cellWidth+x+1;local mode=town.source.collision[i]
          authored=(town.nav.cells[i]==0 or (town.nav.cells[i]==nil and (mode=='walk' or mode=='grass' or (P.surfing and (mode=='water' or mode=='shore')))))
        end
        if authored and x>=0 and y>=0 and x<C._widthCells and y<C._heightCells and previous[key]==nil
            and ((x==tx and y==ty) or not C.warpAt(x,y))
            and C.canEnter(g,x,y,{fromX=item[1],fromY=item[2],dir=d[1]}) then
          previous[key]={from=item[2]*1024+item[1],dir=d[1],x=x,y=y};queue[#queue+1]={x,y}
        end
      end
    end
    local steps={};local key=ty*1024+tx
    if probe then return previous[key]~=nil end
    if previous[key]==nil and Map.current==town.id then
      for y=0,town.source.cellHeight-1 do
        local row={}
        for x=0,town.source.cellWidth-1 do
          local i=y*town.source.cellWidth+x+1;local mode=town.source.collision[i]
          row[#row+1]=previous[y*1024+x]~=nil and 'o' or ((town.nav.cells[i]==0 or (town.nav.cells[i]==nil and (mode=='walk' or mode=='grass'))) and '.' or '#')
        end
        print(y..': '..table.concat(row))
      end
      print('Failed path from '..P.cellX..','..P.cellY..' to '..tx..','..ty)
    end
    assert(previous[key]~=nil,'No in-game walking path to '..tx..','..ty)
    while key~=start do local e=previous[key];table.insert(steps,1,e);key=e.from end
    for _,step in ipairs(steps) do
      local from=Map.current
      for _=1,45 do
        if P.moving then tick(nil) else tick(step.dir) end
        if Map.current~=from then held=nil;settle();return end
        if P.cellX==step.x and P.cellY==step.y and not P.moving then break end
      end
      if (P.cellX~=step.x or P.cellY~=step.y) and (retries or 0)<3 then
        local pass,why=C.canEnter(g,step.x,step.y,{fromX=P.cellX,fromY=P.cellY,dir=step.dir,elevation=P.elevation})
        if pass or why=='entity' then
          -- Native NPCs keep moving while the controller follows a planned
          -- path. Wait and replan when one steps into it; never alter the NPC.
          held=nil;for _=1,60 do tick(nil) end
          return walkTo(tx,ty,false,(retries or 0)+1)
        end
      end
      assert(P.cellX==step.x and P.cellY==step.y,'Controller failed '..step.dir..' to '..step.x..','..step.y..' at '..P.cellX..','..P.cellY..' moving='..tostring(P.moving)..' locked='..tostring(require('src.core.game3.field').locked)..' map='..tostring(Map.current))
      held=nil
      if require('src.core.game3.warp').isBusy() then settle();return end
    end
  end
  local exteriorFrames=0
  local function switchMode(mode,label)
    local before={Map.current,P.px,P.py,P.targetX,P.targetY,P.moving}
    local function event(phase)
      Bus.call('input.key',function() error('View toggle was not handled') end,g,{phase=phase,key='f6'})
    end
    event('pressed');event('pressed') -- OS key repeat must not immediately switch back.
    assert(Map.current==before[1] and P.px==before[2] and P.py==before[3]
      and P.targetX==before[4] and P.targetY==before[5] and P.moving==before[6],'View toggle changed player movement or map')
    event('released');expectedMode=mode;previousWorld=nil;tick(nil)
    assert(require('src.core.game3.field_view')._editor3DLast.mode==mode,'View toggle selected the wrong renderer')
    if label then shot(label) end
  end
  local play=coroutine.create(function()
    if os.getenv('POKEPORT_PROFILE_CONNECTIONS')=='1' then
      Map.load(host,g,town.id,{x=town.slope.x-1,y=town.slope.y+1,facing='up'});settle();tick(nil)
      local View=require('src.core.game3.field_view')
      local opposite={up='down',down='up',left='right',right='left'}
      Bus.call('input.key',function() error('Native profile camera input fell through') end,g,{phase='pressed',key=']'})
      tick(nil)
      local gameplayAngle,gameplayPitch=View._editor3DLast.cameraAngle,View._editor3DLast.cameraPitch
    local directions={north='up',south='down',east='right',west='left'}
    for _,connection in ipairs(town.connected) do
      assert(Map.current==town.id)
      local dir=assert(directions[connection.dir])
      if connection.dir=='south' then
        local shore
        for y=C._heightCells-2,1,-1 do
          for x=1,C._widthCells-2 do
            if not C.isWater(x,y) and C.isWater(x,y+1) and walkTo(x,y,true) then shore={x,y};break end
          end
          if shore then break end
        end
        assert(shore,'No reachable Surf shore in the native town')
        walkTo(shore[1],shore[2]);for _=1,10 do tick('down') end
        assert(P.startSurfing(g),'Native Surf hop failed');settle()
        assert(P.surfing,'Surf state was not retained after the native hop')
      end
      local edge,landing
      local w,h=C._widthCells,C._heightCells
      local span=(dir=='up' or dir=='down') and w or h
      local candidates={};for n=0,span-1 do candidates[#candidates+1]=n end
      table.sort(candidates,function(a,b) return math.abs(a-span/2)<math.abs(b-span/2) end)
      for _,n in ipairs(candidates) do
        local x,y
        if dir=='up' then x,y=n,0 elseif dir=='down' then x,y=n,h-1
        elseif dir=='left' then x,y=0,n else x,y=w-1,n end
        local def=fresh.maps[connection.id]
        local lx,ly=C.connectionLanding(def,{dir=connection.dir,map=connection.id,offset=connection.offset},dir,x,y)
        if lx and (not P.surfing or C.isWater(x,y)) and walkTo(x,y,true)
            and (not C.isWaterOn(def,lx,ly) or P.surfing)
            and not require('src.core.game3.ghosts').blocksOn(connection.id,def,lx,ly) then
          edge,landing={x=x,y=y},{x=lx,y=ly};break
        end
      end
      assert(edge,'No reachable native connection to '..connection.id)
      walkTo(edge.x,edge.y)
      shot('connection-'..connection.id..'-before')
      local before=assert(require('src.core.game3.field_view')._editor3DLast)
      assert(before.connected and before.visibleMaps[connection.id],'Route was not rendered before crossing')
      if connection==town.connected[1] then switchMode('2d') end
      monitorConnections=true;previousWorld=nil
      for _=1,120 do tick(dir);if Map.current~=town.id then break end end
      held=nil
      assert(Map.current==connection.id,'Directional input did not cross into '..connection.id..' at '..P.cellX..','..P.cellY..' surfing='..tostring(P.surfing)..' elevation='..tostring(P.elevation))
      settle()
      assert(P.cellX==landing.x and P.cellY==landing.y,'Native connection offset changed the landing')
      if connection==town.connected[1] then
        assert(View._editor3DLast.mode=='2d','Crossing a route reset the view preference')
        shot('toggle-route-2d');switchMode('3d','toggle-route-3d')
      end
      shot('connection-'..connection.id..'-entered')
      assert(View._editor3DLast.cameraAngle==gameplayAngle and View._editor3DLast.cameraPitch==gameplayPitch,'Camera settings were lost crossing a map connection')
      for _=1,120 do tick(opposite[dir]);if Map.current==town.id then break end end
      held=nil;settle()
      assert(Map.current==town.id and P.cellX==edge.x and P.cellY==edge.y,'Reverse connection did not return to its original boundary')
      shot('connection-'..connection.id..'-returned')
      monitorConnections=false;previousWorld=nil
      print('PASS native connection '..town.id..' <-> '..connection.id..': controller round trip, preserved offsets, 3D on both sides, continuous camera, no fade')
    end
      return
    end
    if reviewRoom then
      local source=S.project.layeredMaps[reviewRoom]
      local function passable(x,y)
        if x<0 or y<0 or x>=source.cellWidth or y>=source.cellHeight then return false end
        local mode=source.collision[y*source.cellWidth+x+1]
        return mode=='walk' or mode=='grass' or (source.visualEnvironment=='underwater' and mode=='water')
      end
      local sx,sy,best
      for y=2,source.cellHeight-2 do for x=2,source.cellWidth-2 do
        local distance=(x-source.cellWidth/2)^2+(y-source.cellHeight/2)^2
        local warp=false
        for _,w in ipairs(fresh.maps[reviewRoom].warps or {}) do if math.abs(x-w.x)+math.abs(y-w.y)<3 then warp=true end end
        if passable(x,y) and passable(x+1,y) and passable(x-1,y) and not warp and (not best or distance<best) then sx,sy,best=x,y,distance end
      end end
      assert(sx,'No safe native review starting cell')
      Map.load(host,g,reviewRoom,{x=sx,y=sy,facing='right'});settle()
      if source.visualEnvironment=='underwater' then assert(P.underwater,'Native underwater avatar was lost') end
      if os.getenv('POKEPORT_CUSTOM_MODEL_REVIEW')=='1' then
        assert(require('src.core.game3.field_view')._editor3DLast.customModels==3,'Exported mod did not render all three textured model formats')
      end
      shot(reviewPrefix..'-in-game')
      local walked=false
      for _,d in ipairs(dirs) do
        if walkTo(sx+d[2],sy+d[3],true) then walkTo(sx+d[2],sy+d[3]);walked=true;break end
      end
      assert(walked,'Could not walk through the authored scene')
      shot(reviewPrefix..'-walking')
      Bus.call('input.key',function() error('Interior camera not handled') end,g,{phase='pressed',key=']'})
      tick(nil);shot(reviewPrefix..'-camera')
      switchMode('2d',reviewPrefix..'-2d')
      switchMode('3d',reviewPrefix..'-3d')
      local function useWarp(w)
        local from=Map.current
        for _,d in ipairs(dirs) do
          local x,y=w.x-d[2],w.y-d[3]
          if x>=0 and y>=0 and x<C._widthCells and y<C._heightCells and walkTo(x,y,true) then
            walkTo(x,y)
            for _=1,180 do tick(d[1]);if Map.current~=from then break end end
            if Map.current~=from then break end
          end
        end
        held=nil;settle()
        assert(Map.current==w.destMap,'Office native warp failed: '..Map.current)
      end
      local exit=fresh.maps[reviewRoom].warps[1]
      -- FRLG Centers expose several doorway coordinates; use the native arrow
      -- tile rather than an adjacent decorative carpet cell.
      for _,w in ipairs(fresh.maps[reviewRoom].warps or {}) do
        if C.arrowWarpDir(C.behavior(w.x,w.y)) then exit=w;break end
      end
      if exit then
      useWarp(exit);shot(reviewPrefix..'-outside')
      local back=assert(fresh.maps[Map.current].warps[exit.destWarp or 1])
      assert(back.destMap==reviewRoom,'Office return warp changed')
      useWarp(back);shot(reviewPrefix..'-return')
      assert(require('src.core.game3.field_view')._editor3DLast.interior,'Returning to office lost 3D')
      end
      for _,message in ipairs(loader:status().errors or {}) do error(tostring(message)) end
      print('PASS: exported '..reviewRoom..', native movement, camera'..(exit and ' and entry/exit round trip' or ' (no native doorway warps)'))
      return
    end
    Map.load(host,g,town.id,{x=town.slope.x-1,y=town.slope.y+1,facing='right'});settle()
    recording=true
    shot('town-start')
    walkTo(town.slope.x+1,town.slope.y+1)
    local View=require('src.core.game3.field_view')
    assert(math.abs(View._editor3DLast.z-.5)<.001,'Town slope did not raise player')
    shot('town-slope')
    walkTo(town.slope.x+3,town.slope.y+1)
    assert(math.abs(View._editor3DLast.z)<.001,'Town downhill did not return to ground')
    local originalCamera=View._editor3DLast
    local function cameraKey(key,expectedPass)
      local passed=false
      Bus.call('input.key',function() passed=true end,g,{phase='pressed',key=key})
      assert(passed==(expectedPass or false),'Camera input was consumed incorrectly: '..key)
      tick(nil)
    end
    input.captureArmed=true;cameraKey(']',true);input.captureArmed=nil
    assert(View._editor3DLast.cameraAngle==originalCamera.cameraAngle,'Camera moved while rebinding controls')
    input.keyBindings={ [']']='a' };cameraKey(']',true);input.keyBindings=nil
    assert(View._editor3DLast.cameraAngle==originalCamera.cameraAngle,'Camera stole a bound gameplay key')
    input.captureArmed=true;cameraKey('f6',true);input.captureArmed=nil
    input.keyBindings={f6='a'};cameraKey('f6',true);input.keyBindings=nil
    assert(View._editor3DLast.mode=='3d','View toggle stole a bound or captured key')
    cameraKey(']');cameraKey(']');cameraKey(']')
    assert(math.abs(View._editor3DLast.cameraAngle-math.pi/4)<.001,'In-game orbit did not rotate 45 degrees')
    shot('camera-rotated')
    cameraKey('pageup');cameraKey('=')
    assert(View._editor3DLast.cameraPitch>originalCamera.cameraPitch and View._editor3DLast.cameraScale>originalCamera.cameraScale,'In-game tilt/zoom did not change')
    shot('camera-tilted')
    cameraKey('home')
    if houseReview then
      assert(game=='emerald','House review requires Emerald')
      walkTo(4,9)
      cameraKey('-');cameraKey('-')
      shot('house-front-in-game')
      for _=1,2 do cameraKey('pagedown') end
      shot('house-front-low-angle-in-game')
      cameraKey('home');cameraKey('-');cameraKey('-')
      walkTo(8,9)
      cameraKey(']');cameraKey(']')
      shot('house-angle-in-game')
      cameraKey('home')
      if os.getenv('POKEPORT_HOUSE_CAPTURE_ONLY')=='1' then return end
    end
    assert(View._editor3DLast.cameraAngle==originalCamera.cameraAngle and View._editor3DLast.cameraPitch==originalCamera.cameraPitch and View._editor3DLast.cameraScale==originalCamera.cameraScale,'Camera reset did not restore authored defaults')
    cameraKey(']');cameraKey('pagedown')
    local gameplayAngle,gameplayPitch=View._editor3DLast.cameraAngle,View._editor3DLast.cameraPitch
    switchMode('2d','toggle-town-2d')
    local walking=false
    for _,d in ipairs(dirs) do
      local x,y=P.cellX+d[2],P.cellY+d[3]
      if not C.warpAt(x,y) and C.canEnter(g,x,y,{fromX=P.cellX,fromY=P.cellY,dir=d[1]}) then
        for _=1,12 do tick(d[1]);if P.moving then walking=true;break end end
        if walking then break end
      end
    end
    assert(walking,'2D view did not allow native walking')
    switchMode('3d','toggle-town-3d');settle()
    walkTo(town.slope.x+3,town.slope.y+1)
    assert(View._editor3DLast.cameraAngle==gameplayAngle and View._editor3DLast.cameraPitch==gameplayPitch,'Switching views reset the camera')
    for index,w in ipairs(town.def.warps) do
      local e=town.nav.byWarp[index] or {x=w.x,y=w.y,outward='down'}
      local outward=assert(({up={0,-1},down={0,1},left={-1,0},right={1,0}})[e.outward])
      walkTo(e.x+outward[1],e.y+outward[2])
      assert(Map.current==town.id,'Walk around town changed maps unexpectedly')
      shot('door-'..index..'-before')
      if index==1 then switchMode('2d') end
      if town.nav.byWarp[index] then walkTo(e.x,e.y)
      else
        for _=1,120 do tick('up');if Map.current~=town.id then break end end
        held=nil
      end
      settle()
      if Map.current==town.id then
        local inward=({up='down',down='up',left='right',right='left'})[e.outward]
        for _=1,120 do tick(inward);if Map.current~=town.id then break end end
        held=nil;settle()
      end
      assert(Map.current==w.destMap,'Door '..index..' did not reach its original native interior: '..tostring(Map.current)..' pos='..P.cellX..','..P.cellY..' gate='..e.x..','..e.y..' warp='..tostring(C.warpAt(e.x,e.y))..' running='..tostring(require('src.core.game3.scripting.space').vm:isRunning()))
      assert(S.project.layeredMaps[Map.current].visualInterior,'Native interior was not converted to 3D')
      if index==1 then
        assert(View._editor3DLast.mode=='2d','Entering a building reset the view preference')
        shot('toggle-interior-2d');switchMode('3d','toggle-interior-3d')
      end
      shot('door-'..index..'-inside')
      do
        local d=fresh.maps[Map.current];local ts=require('src.core.game3.tileset_native').get(d.pair)
        assert(d.pair==S.project.layeredMaps[Map.current].baseTileset,'Native interior scripts were given compact atlas IDs')
        for y=0,d.midLayout.height-1 do for x=0,d.midLayout.width-1 do
          assert(ts.midToSlot[d.midLayout:midAt(x,y)]~=nil,'Native interior script wrote a tile absent from its atlas')
        end end
      end
      local roomId=Map.current
      if index==1 then
        Bus.call('input.key',function() error('Interior camera control fell through') end,g,{phase='pressed',key=']'})
        tick(nil);shot('interior-camera-rotated')
        assert(require('src.core.game3.field_view')._editor3DLast.cameraAngle>0,'Interior camera did not orbit')
        Bus.call('input.key',function() end,g,{phase='pressed',key='home'});tick(nil)
        local talked=false
        for _,npc in ipairs(require('src.core.game3.objects').forDraw()) do
          if npc.def and npc.def.scriptKey then
            for _,d in ipairs(dirs) do
              local x,y=npc.cellX-d[2],npc.cellY-d[3]
              if walkTo(x,y,true) then
                walkTo(x,y);tick(d[1]);tick(nil);tick('a')
                local Message=require('src.ui.game3.message')
                for _=1,120 do if Message.isOpen() then break end;tick(nil) end
                if Message.isOpen() then
                  talked=true;shot('interior-dialogue')
                  local passed=false
                  Bus.call('input.key',function() passed=true end,g,{phase='pressed',key='f6'})
                  assert(passed,'View toggle consumed dialogue input')
                  for n=1,1200 do
                    if not Message.isOpen() and not require('src.core.game3.field').locked then break end
                    local waiting=Message.isOpen() or require('src.ui.game3.choice').isOpen()
                    tick(waiting and n%2==0 and 'a' or nil)
                  end
                  assert(not Message.isOpen() and not require('src.core.game3.field').locked,'Native dialogue did not return control')
                  break
                end
              end
            end
          end
          if talked then break end
        end
        assert(talked,'No native NPC dialogue was exercised in the 3D interior')
        print('PASS native interior NPC dialogue: directional approach, A-button talk and return to walking')
      end
      for _,stair in ipairs(fresh.maps[roomId].warps or {}) do
        if stair.destMap~=town.id and S.project.layeredMaps[stair.destMap]
            and S.project.layeredMaps[stair.destMap].visualInterior then
          local function useStair(w)
            local from=Map.current;local approached=false
            for _,d in ipairs(dirs) do
              local x,y=w.x-d[2],w.y-d[3]
              if x>=0 and y>=0 and x<C._widthCells and y<C._heightCells and walkTo(x,y,true) then
                walkTo(x,y);approached=true
                for _=1,180 do tick(d[1]);if Map.current~=from then break end end
                if Map.current~=from then break end
              end
            end
            assert(approached and Map.current==w.destMap,'Native interior stairs did not reach '..w.destMap)
            held=nil;settle()
          end
          useStair(stair)
          shot('door-'..index..'-upstairs')
          assert(require('src.core.game3.field_view')._editor3DLast.interior,'Upstairs fell back to 2D')
          local back=assert(fresh.maps[Map.current].warps[stair.destWarp or 1])
          assert(back.destMap==roomId,'Upstairs exit points elsewhere')
          useStair(back)
          shot('door-'..index..'-downstairs')
          assert(Map.current==roomId,'Downstairs did not return to the same house')
          print('PASS native interior stairs '..roomId..' <-> '..stair.destMap..': controller input and 3D on both floors')
        end
      end
      local inner=assert(fresh.maps[Map.current]);local iw=assert(inner.warps[w.destWarp or 1])
      assert(iw.destMap==town.id,'Native exit points to a different exterior')
      print('Native exit '..iw.x..','..iw.y..' index '..tostring(w.destWarp)..' behavior '..tostring(C.behavior(iw.x,iw.y)))
      if index==1 then switchMode('2d') end
      walkTo(iw.x,iw.y-1)
      for _=1,360 do tick('down');if Map.current==town.id then break end end
      held=nil;settle()
      assert(Map.current==town.id,'Native interior exit failed: '..Map.current..' at '..P.cellX..','..P.cellY..' behavior='..tostring(C.behavior(P.cellX,P.cellY))..' warp='..tostring(C.warpAt(P.cellX,P.cellY)))
      if index==1 then
        assert(View._editor3DLast.mode=='2d','Leaving a building reset the view preference')
        switchMode('3d','toggle-returned-3d')
      end
      assert(P.cellX==e.x and (P.cellY==e.y or P.cellY==e.y+1) and P.facing==e.outward,'Native exit did not return to the forward-facing town door')
      local ok,reason=C.canEnter(g,e.x+outward[1],e.y+outward[2],{fromX=e.x,fromY=e.y,dir=e.outward})
      print('Exit gate '..e.x..','..e.y..' outward '..e.outward..' immediate step '..tostring(ok)..' reason='..tostring(reason)..' targetwarp='..tostring(C.warpAt(e.x+outward[1],e.y+outward[2])))
      shot('door-'..index..'-returned')
      assert(View._editor3DLast.cameraAngle==gameplayAngle and View._editor3DLast.cameraPitch==gameplayPitch,'Camera settings were lost inside a building')
      walkTo(e.x+outward[1],e.y+outward[2])
      assert(Map.current==town.id,'Walking away from native door re-entered the house')
      print('PASS native town door '..index..' -> '..w.destMap..': controller walk in/out, native warp index and forward-facing return')
    end
    local opposite={up='down',down='up',left='right',right='left'}
    local directions={north='up',south='down',east='right',west='left'}
    for _,connection in ipairs(town.connected) do
      assert(Map.current==town.id)
      local dir=assert(directions[connection.dir])
      if connection.dir=='south' then
        local shore
        for y=C._heightCells-2,1,-1 do
          for x=1,C._widthCells-2 do
            if not C.isWater(x,y) and C.isWater(x,y+1) and walkTo(x,y,true) then shore={x,y};break end
          end
          if shore then break end
        end
        assert(shore,'No reachable Surf shore in the native town')
        walkTo(shore[1],shore[2]);for _=1,10 do tick('down') end
        assert(P.startSurfing(g),'Native Surf hop failed');settle()
        assert(P.surfing,'Surf state was not retained after the native hop')
      end
      local edge,landing
      local w,h=C._widthCells,C._heightCells
      local span=(dir=='up' or dir=='down') and w or h
      local candidates={};for n=0,span-1 do candidates[#candidates+1]=n end
      table.sort(candidates,function(a,b) return math.abs(a-span/2)<math.abs(b-span/2) end)
      for _,n in ipairs(candidates) do
        local x,y
        if dir=='up' then x,y=n,0 elseif dir=='down' then x,y=n,h-1
        elseif dir=='left' then x,y=0,n else x,y=w-1,n end
        local def=fresh.maps[connection.id]
        local lx,ly=C.connectionLanding(def,{dir=connection.dir,map=connection.id,offset=connection.offset},dir,x,y)
        if lx and (not P.surfing or C.isWater(x,y)) and walkTo(x,y,true)
            and (not C.isWaterOn(def,lx,ly) or P.surfing)
            and not require('src.core.game3.ghosts').blocksOn(connection.id,def,lx,ly) then
          edge,landing={x=x,y=y},{x=lx,y=ly};break
        end
      end
      assert(edge,'No reachable native connection to '..connection.id)
      walkTo(edge.x,edge.y)
      shot('connection-'..connection.id..'-before')
      local before=assert(require('src.core.game3.field_view')._editor3DLast)
      assert(before.connected and before.visibleMaps[connection.id],'Route was not rendered before crossing')
      if connection==town.connected[1] then switchMode('2d') end
      monitorConnections=true;previousWorld=nil
      for _=1,120 do tick(dir);if Map.current~=town.id then break end end
      held=nil
      assert(Map.current==connection.id,'Directional input did not cross into '..connection.id..' at '..P.cellX..','..P.cellY..' surfing='..tostring(P.surfing)..' elevation='..tostring(P.elevation))
      settle()
      assert(P.cellX==landing.x and P.cellY==landing.y,'Native connection offset changed the landing')
      if connection==town.connected[1] then
        assert(View._editor3DLast.mode=='2d','Crossing a route reset the view preference')
        shot('toggle-route-2d');switchMode('3d','toggle-route-3d')
      end
      shot('connection-'..connection.id..'-entered')
      assert(View._editor3DLast.cameraAngle==gameplayAngle and View._editor3DLast.cameraPitch==gameplayPitch,'Camera settings were lost crossing a map connection')
      for _=1,120 do tick(opposite[dir]);if Map.current==town.id then break end end
      held=nil;settle()
      assert(Map.current==town.id and P.cellX==edge.x and P.cellY==edge.y,'Reverse connection did not return to its original boundary')
      shot('connection-'..connection.id..'-returned')
      monitorConnections=false;previousWorld=nil
      print('PASS native connection '..town.id..' <-> '..connection.id..': controller round trip, preserved offsets, 3D on both sides, continuous camera, no fade')
    end
    walkTo(town.slope.x-1,town.slope.y+1)
    shot('town-finish');recording=false
    local previousRevision=require('src.core.game3.field_view')._editor3DLast.atlasRevision
    local originalW,originalH,originalFlags=love.window.getMode()
    assert(love.window.setMode(1280,720,{resizable=true,vsync=0}))
    tick(nil)
    local hd=assert(require('src.core.game3.field_view')._editor3DLast)
    assert(hd.hd and hd.width>=1280 and hd.height>=720,'Resizing did not rebuild the HD world canvas')
    assert(hd.atlasRevision>previousRevision,'Resize kept the cleared texture canvas')
    shot('town-hd-wide')
    assert(love.window.setMode(originalW,originalH,originalFlags));tick(nil)
    assert(exteriorFrames>100,'Town camera was not checked while walking')
    for _,message in ipairs(loader:status().errors or {}) do error(tostring(message)) end
    print('PASS: '..game..' original town '..town.id..', '..#town.connected..' native connection round trips, all 3 native interiors, sprite trees and authored forward-facing buildings, uphill/downhill, centered follow camera across '..exteriorFrames..' frames and '..tickCount..' game ticks')
  end)
  return function()
    if coroutine.status(play)~='dead' then
      local ok,message=coroutine.resume(play)
      assert(ok,message)
    end
    assert(Display.present(g,800,600) and not Display.planesBroken,'Actual game display fell back')
    if S.project.layeredMaps[Map.current] then
      local info=assert(require('src.core.game3.field_view')._editor3DLast)
      assert(info.mode==expectedMode,'Unexpected 2D/3D mode during gameplay')
      if expectedMode=='2d' then
        assert(require('src.render.Renderer').worldOverride==nil,'2D mode retained a stale 3D frame')
        assert(info.mapId==Map.current,'2D mode retained a stale map')
      else
      local rect=require('src.render.Renderer'):frameRects()
      assert(info.hd and info.width==math.floor(rect.pw+.5) and info.height==math.floor(rect.ph+.5),'3D town is still rendered through the low-resolution framebuffer')
      assert(info.canvasWidth==info.width and info.canvasHeight==info.height,'HD dimensions do not match the actual world canvas')
      local ui=require('src.render.Renderer').canvas
      assert(ui:getWidth()==240 and ui:getHeight()==160,'HD world changed native UI resolution')
      assert(info.mapId==Map.current and (info.objects>0 or S.project.layeredMaps[Map.current].visualEnvironment),'Connected map 3D scene missing')
      if monitorConnections then
        assert(info.connected and info.worldX and info.worldY,'Connection fell back to a local or 2D camera')
        assert(not require('src.ui.game3.fade').isActive() and not require('src.core.game3.warp').isBusy(),'Native connection introduced a fade or warp')
        if previousWorld then assert(math.abs(info.worldX-previousWorld.x)+math.abs(info.worldY-previousWorld.y)<=.126,'Camera snapped while crossing a map connection') end
        previousWorld={x=info.worldX,y=info.worldY}
      end
      assert(math.abs(info.localX-(P.px/16+.5))<.001 and math.abs(info.localY-(P.py/16+.5))<.001,'Camera did not track moving player')
      if info.interior then
        assert(info.screenX>0 and info.screenX<info.width and info.screenY>0 and info.screenY<info.height,'Indoor camera lost the player')
      else
        assert(math.abs(info.screenX-info.width/2)<.001 and math.abs(info.screenY-info.height/2)<.001,'Player feet left screen center')
      end
      exteriorFrames=exteriorFrames+1
      end
    end
    if pendingShot then
      local label=pendingShot;pendingShot=nil
      love.graphics.captureScreenshot(function(pixels)
        if label:match('^toggle%-') then
          local width,height=pixels:getDimensions();local colors={};local count=0
          for y=8,height-1,16 do for x=8,width-1,16 do
            local r,g,b=pixels:getPixel(x,y)
            local key=math.floor(r*31)*1024+math.floor(g*31)*32+math.floor(b*31)
            if not colors[key] then colors[key]=true;count=count+1 end
          end end
          assert(count>12,'View toggle produced a blank or missing-atlas frame: '..label)
        end
        if label=='town-hd-wide' then
          local width,height=pixels:getDimensions();local green,total=0,0
          for y=8,height-1,16 do for x=8,width-1,16 do
            local r,g,b=pixels:getPixel(x,y);total=total+1
            if g>.22 and g>r*1.1 then green=green+1 end
          end end
          assert(green>total*.15,'Resized frame lost its ground and forest textures')
        end
        local f=assert(io.open(output..'/'..label..'.png','wb'));f:write(pixels:encode('png'):getString());f:close()
      end)
    end
    return coroutine.status(play)=='dead'
  end
end
