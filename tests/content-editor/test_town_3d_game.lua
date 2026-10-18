-- Exercises original town IDs and original interior warp destinations as real mods.
return function(data,root,output,game)
  local IO,L=require('ModIO'),require('LayeredMap')
  local Models,N=require('MapObjects3D'),require('MapNavigation3D')
  output=output..'/'..game;IO.ensureDirectory(output)
  local modId='town3d_'..game
  local S={data=data,version=game,project=require('State').blankProject(modId,game=='emerald' and 'Littleroot Town 3D' or 'Pallet Town 3D')}
  S.project.game=game;S.path=output..'/mod';IO.ensureDirectory(S.path)
  IO.writeText(S.path..'/manifest.json','{"id":"'..modId..'","name":"3D native town","version":"1.0.0","entry":"main.lua","games":["'..game..'"]}')
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local town=require('Town3D').build(S)
  assert(town.buildings==3,'Native town buildings were not all modeled')
  for _,model in ipairs(Models.objects(town.source)) do
    if model.kind=='building' then assert(model.rotation==0 and model.style,'Town house lost its authored forward-facing geometry') end
  end
  assert(town.source.visualTreeStyle=='sprite' and town.source.visualForestBorder>0,'Town forest presentation missing')
  assert(L.compileProject(S));assert(IO.save(S.path,S.project))
  local fresh={};require('Gen3').load(fresh,data._gen3Read)
  local loader=assert(require('Gen3Mod').load(fresh,S.path))
  assert(require('Gen3Map').tileset(fresh,town.source.baseTileset))
  -- Hydrate untouched interiors from the actual imported ROM cache, as Dataset does.
  for _,w in ipairs(town.def.warps) do
    local def=assert(fresh.maps[w.destMap])
    def.midLayout=assert(require('Gen3Map').layout(fresh,w.destMap))
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
  local function walkTo(tx,ty,probe)
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
      assert(P.cellX==step.x and P.cellY==step.y,'Controller failed '..step.dir..' to '..step.x..','..step.y..' at '..P.cellX..','..P.cellY..' moving='..tostring(P.moving)..' locked='..tostring(require('src.core.game3.field').locked)..' map='..tostring(Map.current))
      held=nil
      if require('src.core.game3.warp').isBusy() then settle();return end
    end
  end
  local exteriorFrames=0
  local play=coroutine.create(function()
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
    cameraKey(']');cameraKey(']');cameraKey(']')
    assert(math.abs(View._editor3DLast.cameraAngle-math.pi/4)<.001,'In-game orbit did not rotate 45 degrees')
    shot('camera-rotated')
    cameraKey('pageup');cameraKey('=')
    assert(View._editor3DLast.cameraPitch>originalCamera.cameraPitch and View._editor3DLast.cameraScale>originalCamera.cameraScale,'In-game tilt/zoom did not change')
    shot('camera-tilted')
    cameraKey('home')
    assert(View._editor3DLast.cameraAngle==originalCamera.cameraAngle and View._editor3DLast.cameraPitch==originalCamera.cameraPitch and View._editor3DLast.cameraScale==originalCamera.cameraScale,'Camera reset did not restore authored defaults')
    cameraKey(']');cameraKey('pagedown')
    local gameplayAngle,gameplayPitch=View._editor3DLast.cameraAngle,View._editor3DLast.cameraPitch
    for index,w in ipairs(town.def.warps) do
      local e=town.nav.byWarp[index] or {x=w.x,y=w.y,outward='down'}
      local outward=assert(({up={0,-1},down={0,1},left={-1,0},right={1,0}})[e.outward])
      walkTo(e.x+outward[1],e.y+outward[2])
      assert(Map.current==town.id,'Walk around town changed maps unexpectedly')
      shot('door-'..index..'-before')
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
      shot('door-'..index..'-inside')
      local inner=assert(fresh.maps[Map.current]);local iw=assert(inner.warps[w.destWarp or 1])
      assert(iw.destMap==town.id,'Native exit points to a different exterior')
      print('Native exit '..iw.x..','..iw.y..' index '..tostring(w.destWarp)..' behavior '..tostring(C.behavior(iw.x,iw.y)))
      walkTo(iw.x,iw.y-1)
      for _=1,360 do tick('down');if Map.current==town.id then break end end
      held=nil;settle()
      assert(Map.current==town.id,'Native interior exit failed: '..Map.current..' at '..P.cellX..','..P.cellY..' behavior='..tostring(C.behavior(P.cellX,P.cellY))..' warp='..tostring(C.warpAt(P.cellX,P.cellY)))
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
      monitorConnections=true;previousWorld=nil
      for _=1,120 do tick(dir);if Map.current~=town.id then break end end
      held=nil
      assert(Map.current==connection.id,'Directional input did not cross into '..connection.id..' at '..P.cellX..','..P.cellY..' surfing='..tostring(P.surfing)..' elevation='..tostring(P.elevation))
      settle()
      assert(P.cellX==landing.x and P.cellY==landing.y,'Native connection offset changed the landing')
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
      local rect=require('src.render.Renderer'):frameRects()
      assert(info.hd and info.width==math.floor(rect.pw+.5) and info.height==math.floor(rect.ph+.5),'3D town is still rendered through the low-resolution framebuffer')
      assert(info.canvasWidth==info.width and info.canvasHeight==info.height,'HD dimensions do not match the actual world canvas')
      local ui=require('src.render.Renderer').canvas
      assert(ui:getWidth()==240 and ui:getHeight()==160,'HD world changed native UI resolution')
      assert(info.mapId==Map.current and info.objects>0,'Connected map 3D scene missing')
      if monitorConnections then
        assert(info.connected and info.worldX and info.worldY,'Connection fell back to a local or 2D camera')
        assert(not require('src.ui.game3.fade').isActive() and not require('src.core.game3.warp').isBusy(),'Native connection introduced a fade or warp')
        if previousWorld then assert(math.abs(info.worldX-previousWorld.x)+math.abs(info.worldY-previousWorld.y)<=.126,'Camera snapped while crossing a map connection') end
        previousWorld={x=info.worldX,y=info.worldY}
      end
      assert(math.abs(info.localX-(P.px/16+.5))<.001 and math.abs(info.localY-(P.py/16+.5))<.001,'Camera did not track moving player')
      assert(math.abs(info.screenX-info.width/2)<.001 and math.abs(info.screenY-info.height/2)<.001,'Player feet left screen center')
      exteriorFrames=exteriorFrames+1
    end
    if pendingShot then
      local label=pendingShot;pendingShot=nil
      love.graphics.captureScreenshot(function(pixels)
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
