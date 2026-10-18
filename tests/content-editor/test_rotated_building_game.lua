-- Runs exported mods in the actual Gen3 field/update/warp/display pipeline.
-- Input is a deterministic virtual controller; no map-load or warp stubs.
return function(data,root,output,game)
  assert(game=='emerald' or game=='firered' or game=='leafgreen')
  output=output..'/'..game;assert(require('ModIO').ensureDirectory(output))
  local prefix=game=='emerald' and 'EM_' or 'FR_'
  local L,IO=require('LayeredMap'),require('ModIO')
  local Models,N=require('MapObjects3D'),require('MapNavigation3D')
  local S={data=data,version=game,project=require('State').blankProject('rotated_doors_'..game)}
  S.project.game=game;S.path=output..'/project';IO.ensureDirectory(S.path)
  IO.writeText(S.path..'/manifest.json','{"id":"rotated_doors_'..game..'","name":"Rotated doorway game test","version":"1.0.0","entry":"main.lua","games":["'..game..'"]}')
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local town=assert(L.convertMap(S,game=='emerald' and 'EM_LITTLEROOT_TOWN' or 'FR_PALLET_TOWN'))
  local nativeWarp,footprint
  for _,w in ipairs(S.project.maps[town.id].warps) do
    for _,o in ipairs(Models.objects(town)) do
      if o.kind=='building' and w.x>=o.x and w.x<o.x+o.width and w.y>=o.y and w.y<o.y+o.height then
        nativeWarp,footprint=w,o;break
      end
    end
    if nativeWarp then break end
  end
  assert(nativeWarp,'Native house footprint/warp missing')
  local nativeHouse=assert(nativeWarp.destMap)
  local house=assert(L.convertMap(S,nativeHouse))
  local houseWarps=S.project.maps[nativeHouse].warps
  local clone=require('src.mods.Merge').deepCopy
  local cases={}
  for _,angle in ipairs({45,135,225,315}) do
    local src,outside=L.createMap(S,prefix..'ROTATED_DOOR_'..angle,24,24,town.baseTileset)
    for y=0,23 do for x=0,23 do
      L.setCell(src,1,x,y,{source=L.runtimeSourceId(town.baseTileset),tile=1})
      L.setCollision(src,x,y,'walk')
    end end
    for y=0,footprint.height-1 do for x=0,footprint.width-1 do
      local old=(y+footprint.y)*town.cellWidth+x+footprint.x+1;local i=(y+8)*24+x+9
      src.layers[1].cells[i]=clone(town.layers[1].cells[old])
      src.collision[i]=town.collision[old]
      src.gen3Collision[i]=town.gen3Collision[old]
      src.gen3Elevation[i]=town.gen3Elevation[old]
    end end
    local Terrain=require('MapPreview3D')
    Terrain.paint(src,18,18,0,'east');Terrain.paint(src,19,18,1);Terrain.paint(src,20,18,1)
    Models.place(src,{x0=8,y0=8,x1=8+footprint.width-1,y1=8+footprint.height-1},'building',3,angle)
    local inner,inside=L.createMap(S,prefix..'ROTATED_INTERIOR_'..angle,house.cellWidth,house.cellHeight,house.baseTileset)
    for _,key in ipairs({'layers','collision','gen3Collision','gen3Elevation','gen3Behavior','gen3Border'}) do
      inner[key]=clone(house[key])
    end
    inner.visualPlayable=false
    inside.mapType=8;inside.objects={};inside.coordEvents={};inside.mapScripts={}
    inside.warps={}
    for i,w in ipairs(houseWarps) do
      inside.warps[i]={x=w.x,y=w.y,destMap=outside.id,destWarp=1}
    end
    -- Preserve the native door column within the copied house footprint.
    outside.warps={{x=8+nativeWarp.x-footprint.x,y=8+nativeWarp.y-footprint.y,destMap=inside.id,destWarp=nativeWarp.destWarp or 1}}
    L.syncMapWarps(S,outside);L.syncMapWarps(S,inside)
    cases[#cases+1]={angle=angle,source=src,outside=outside.id,inside=inside.id}
  end
  assert(L.compileProject(S));assert(IO.save(S.path,S.project))
  local fresh={};require('Gen3').load(fresh,data._gen3Read)
  local loader=assert(require('Gen3Mod').load(fresh,S.path))
  assert(require('Gen3Map').tileset(fresh,town.baseTileset))
  assert(require('Gen3Map').tileset(fresh,house.baseTileset))
  local Bus=require('src.mods.Runtime');Bus.install(loader.events,loader.hooks,loader.errors)
  local held,pressed
  local input={isDown=function(_,key) return held==key end,wasPressed=function(_,key) return pressed==key end}
  local session={version=game,map=cases[1].outside,x=17,y=18,facing='up',party={},
    bag=require('src.core.game3.bag').new(),dex=require('src.core.game3.dex').new(),
    flags={},vars={},options={},money=0,gender='male'}
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
  local pendingShot,recording
  local function shot(label) pendingShot=label;coroutine.yield() end
  local function tick(dir)
    held,pressed=dir,dir~=held and dir or nil
    Core.update(1/60);pressed=nil;tickCount=tickCount+1
    if recording and tickCount%6==0 then pendingShot=string.format('walk45-%04d',tickCount) end
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
  local function walkTo(tx,ty)
    local start=P.cellY*1024+P.cellX
    local queue={{P.cellX,P.cellY}};local head=1;local previous={[start]=false}
    while head<=#queue do
      local item=queue[head];head=head+1
      if item[1]==tx and item[2]==ty then break end
      for _,d in ipairs(dirs) do
        local x,y=item[1]+d[2],item[2]+d[3];local key=y*1024+x
        if x>=0 and y>=0 and x<C._widthCells and y<C._heightCells and previous[key]==nil
            and ((x==tx and y==ty) or not C.warpAt(x,y))
            and C.canEnter(g,x,y,{fromX=item[1],fromY=item[2],dir=d[1]}) then
          previous[key]={from=item[2]*1024+item[1],dir=d[1],x=x,y=y};queue[#queue+1]={x,y}
        end
      end
    end
    local steps={};local key=ty*1024+tx
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
  local play=coroutine.create(function()
  for _,case in ipairs(cases) do
    Map.load(host,g,case.outside,{x=17,y=18,facing='up'});settle()
    -- Walk uphill/downhill through the normal gameplay loop before the door run.
    walkTo(20,18)
    local view=require('src.core.game3.field_view')
    assert(math.abs(assert(view._editor3DLast).z-.5)<.001,'In-game slope did not raise player')
    walkTo(17,18)
    assert(math.abs(view._editor3DLast.z)<.001,'In-game downhill did not restore ground height')
    local def=fresh.maps[case.outside]
    local e=assert(N.prepare(case.source,S.project.maps[case.outside].warps,Models.objects(case.source)).byWarp[1])
    assert(def.warps[1].x==e.x and def.warps[1].y==e.y,'Export did not relocate the indexed entrance')
    assert(not C.warpAt(e.oldX,e.oldY),'Old doorway remained active')
    assert(C.warpAt(e.x,e.y),'Rotated doorway is not registered')
    assert(not C.canEnter(g,10,10,{fromX=10,fromY=11,dir='up'}),'Player can walk through the house')
    -- Approach from the outward side so directional input actually enters.
    local outward=assert(({up={0,-1},down={0,1},left={-1,0},right={1,0}})[e.outward])
    walkTo(e.x+outward[1],e.y+outward[2]);assert(Map.current==case.outside)
    recording=case.angle==45
    shot('angle-'..case.angle..'-before')
    walkTo(e.x,e.y);settle()
    assert(Map.current==case.inside,'Walking onto the rotated doorway did not enter the interior')
    shot('angle-'..case.angle..'-inside')
    local inside=fresh.maps[case.inside];local iw=inside.warps[nativeWarp.destWarp or 1]
    walkTo(iw.x,iw.y-1);assert(Map.current==case.inside)
    -- The native carpet/door-exit handling is driven by DOWN, not a test warp.
    for _=1,360 do tick('down');if Map.current==case.outside then break end end
    held=nil;settle()
    assert(Map.current==case.outside,'Walking out did not return to the exterior: '..Map.current..' at '..P.cellX..','..P.cellY..' behavior='..tostring(C.behavior(P.cellX,P.cellY)))
    assert(P.cellX==e.x and P.cellY==e.y,'Exit spawned the player at the old doorway or inside a wall')
    assert(P.facing==e.outward,'Exit facing did not follow building rotation')
    shot('angle-'..case.angle..'-returned')
    walkTo(e.x+outward[1],e.y+outward[2]);assert(Map.current==case.outside,'Exit immediately re-entered')
    recording=false
    -- Find a reachable wall edge and press into it through the real controller.
    local queue={{P.cellX,P.cellY}};local seen={[P.cellY*1024+P.cellX]=true};local head=1
    local bump
    while head<=#queue and not bump do
      local p=queue[head];head=head+1
      for _,d in ipairs(dirs) do
        local x,y=p[1]+d[2],p[2]+d[3];local key=y*1024+x
        if x>=0 and y>=0 and x<24 and y<24 and not C.warpAt(x,y) then
          local allowed,reason=C.canEnter(g,x,y,{fromX=p[1],fromY=p[2],dir=d[1]})
          if reason=='3d_building' then bump={x=p[1],y=p[2],dir=d[1]};break end
          if allowed and not seen[key] then seen[key]=true;queue[#queue+1]={x,y} end
        end
      end
    end
    assert(bump,'No reachable rotated wall to test')
    walkTo(bump.x,bump.y)
    for _=1,20 do tick(bump.dir) end
    tick(nil)
    assert(not P.moving and P.cellX==bump.x and P.cellY==bump.y,'Controller walked through rotated wall')
    print('PASS in game '..case.angle..' degrees: controller walk in, native fade/map load, controller walk out, correct return cell/facing')
  end
  for _,message in ipairs(loader:status().errors or {}) do error(tostring(message)) end
  assert(tickCount>200,'Test did not run the real gameplay update loop')
  print('PASS: '..tickCount..' '..game..' runtime ticks; rotated walls, original-door removal, four diagonal entrances, safe exits and controller-driven slopes')
  end)
  return function()
    if coroutine.status(play)~='dead' then
      local ok,message=coroutine.resume(play)
      assert(ok,message)
    end
    assert(Display.present(g,800,600) and not Display.planesBroken,'Actual game display fell back')
    if pendingShot then
      local label=pendingShot;pendingShot=nil
      love.graphics.captureScreenshot(function(pixels)
        local f=assert(io.open(output..'/'..label..'.png','wb'));f:write(pixels:encode('png'):getString());f:close()
      end)
    end
    return coroutine.status(play)=='dead'
  end
end
