return function(data,root,output,game)
  assert(game=='emerald' or game=='firered' or game=='leafgreen')
  local townId=game=='emerald' and 'EM_LITTLEROOT_TOWN' or 'FR_PALLET_TOWN'
  output=output..'/'..game;require('ModIO').ensureDirectory(output)
  local L,IO=require('LayeredMap'),require('ModIO')
  local Terrain,Models=require('MapPreview3D'),require('MapObjects3D')
  local S={data=data,version=game,project=require('State').blankProject('terrain3d_playable_test')}
  S.project.game=game;S.path=output..'/project';IO.ensureDirectory(S.path)
  assert(IO.writeText(S.path..'/manifest.json','{"id":"terrain3d_playable_test","name":"Playable 3D test","version":"1.0.0","entry":"main.lua","games":["'..game..'"]}'))
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local town=assert(L.convertMap(S,townId))
  local source,map=assert(L.createMap(S,game=='emerald' and 'EM_3D_RUNTIME_TEST' or 'FR_3D_RUNTIME_TEST',12,10,town.baseTileset))
  for y=0,9 do for x=0,11 do
    L.setCell(source,1,x,y,{source=L.runtimeSourceId(town.baseTileset),tile=1})
    L.setCollision(source,x,y,'walk')
  end end
  Terrain.paint(source,3,4,0,'east');Terrain.paint(source,4,4,1);Terrain.paint(source,5,4,1)
  for y=0,4 do for x=0,4 do
    L.setCell(source,1,x+7,y+1,town.layers[1].cells[(y+4)*town.cellWidth+x+3])
    L.setCollision(source,x+7,y+1,'solid')
  end end
  Models.place(source,{x0=7,y0=1,x1=11,y1=5},'building',3,45)
  for y=0,1 do for x=0,1 do
    L.setCell(source,1,x,y,town.layers[1].cells[y*town.cellWidth+x+1])
    L.setCollision(source,x,y,'solid')
  end end
  Models.place(source,{x0=0,y0=0,x1=1,y1=1},'tree',3,45,45)
  map.warps={{x=10,y=8,destMap=townId,destWarp=1}}
  L.setCollision(source,10,8,'panel')
  -- Register through the same stable warp endpoints used by the editor.
  L.syncMapWarps(S,map)
  assert(L.compileProject(S));assert(IO.save(S.path,S.project))
  local generated=assert(IO.readText(S.path..'/main.lua'))
  assert(generated:find('editor.gen3.scene.draw',1,true),'Save omitted the playable renderer')
  local fresh={};require('Gen3').load(fresh,data._gen3Read)
  local loader=assert(require('Gen3Mod').load(fresh,S.path))
  assert(require('Gen3Map').tileset(fresh,source.baseTileset),'Runtime native tileset cache was not initialized')
  local Runtime=require('src.mods.Runtime');Runtime.install(loader.events,loader.hooks,loader.errors)
  local g={data=fresh,session={map=map.id,gender='male'},save={position={}}}
  for _,entry in ipairs(loader.events.listeners['game.ready'] or {}) do entry.callback({game=g}) end
  for _,message in ipairs(loader:status().errors or {}) do error(tostring(message)) end
  local P,C,Map=require('src.core.game3.player'),require('src.core.game3.collision'),require('src.core.game3.map')
  local View=require('src.core.game3.field_view')
  local sprites=require('src.core.game3.ow_sprites')
  sprites.install({read=function(_,p) return data._gen3Read(p) end})
  local def=assert(fresh.maps[map.id]);assert(def.midLayout,'Exported map was not compiled by game.ready')
  Map.current=map.id;Map._def=def;C.bindMap(g,map.id,def)
  require('src.core.game3.objects').loadMap(g,map.id,def)
  P.cellX,P.cellY,P.px,P.py=2,4,32,64;P.elevation=3;P.moving=false;P.facing='right'
  P.turnTimer=0;P.turnArmed=false;P.surfing=false;P.boulderPush=nil;P.setVisible(true)
  local canvas=love.graphics.newCanvas(480,320)
  local function render(label)
    love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(0,0,0,1)
    View.draw(g,480,320,{})
    love.graphics.setCanvas()
    local info=assert(View._editor3DLast,'Field renderer did not enter exported 3D mode')
    assert(info.mapId==Map.current and info.actors>=1,'Native player sprite is missing')
    if label then
      local f=assert(io.open(output..'/'..label..'.png','wb'));f:write(canvas:newImageData():encode('png'):getString());f:close()
    end
    return info
  end
  assert(render('start').z==0)
  for _,target in ipairs({3,4,5}) do
    P.tryMove('right',g,false);assert(P.moving,'Slope movement did not start')
    local previous=-1
    for tick=1,16 do
      P.tick(g)
      local info=render()
      assert(info.z>=previous,'Player height jumped down while walking uphill')
      previous=info.z
    end
    assert(P.cellX==target and P.cellY==4,'Real player step did not finish')
  end
  assert(math.abs(render('plateau').z-.5)<.001,'Player did not rise onto the slope plateau')
  local allowed,reason=C.canEnter(g,4,5,{fromX=4,fromY=4,dir='down'})
  assert(not allowed and reason=='3d_cliff','Player could walk off a visual cliff')
  assert(not C.canEnter(g,0,0,{fromX=0,fromY=1,dir='up'}),'Tree native collision was lost')
  P.facing='left';P.turnTimer=0;P.turnArmed=false
  for _,target in ipairs({4,3,2}) do
    P.tryMove('left',g,false);assert(P.moving,'Downhill movement was blocked')
    for tick=1,16 do P.tick(g) end
    assert(P.cellX==target)
  end
  assert(render('downhill').z==0)
  assert(C.warpAt(10,8),'Exported warp disappeared in 3D mode')
  -- Native outdoor map keeps actors and original door definitions.
  local townDef=assert(fresh.maps[town.id]);Map.current=town.id;Map._def=townDef
  C.bindMap(g,town.id,townDef)
  require('src.core.game3.objects').loadMap(g,town.id,townDef)
  P.cellX,P.cellY,P.px,P.py=10,10,160,160
  local info=render('littleroot-gameplay')
  assert(info.objects>=8 and info.actors>=2,'Town models or NPCs were lost')
  local door=assert(townDef.warps[1]);assert(C.warpAt(door.x,door.y),'Native house door lost its warp')
  -- Exercise the game's actual world/UI compositor, not just FieldView.draw.
  local Display=require('src.core.game3.display')
  local uiSeen=false
  Display.setUiRenderer(function()
    uiSeen=true
    love.graphics.setColor(.05,.08,.15,1);love.graphics.rectangle('fill',6,126,228,28)
    love.graphics.setColor(1,1,1,1);love.graphics.print(game..' 3D field test',12,132)
  end)
  assert(Display.present(g,800,600) and not Display.planesBroken,'Game compositor fell back to the flat path')
  assert(uiSeen and View._editor3DLast.mapId==town.id,'3D world or UI pass was lost')
  local hd=View._editor3DLast;local R=require('src.render.Renderer');local rect=R:frameRects()
  assert(hd.hd and hd.canvasWidth==math.floor(rect.pw+.5) and hd.canvasHeight==math.floor(rect.ph+.5),'World was upscaled from the GBA framebuffer')
  assert(R.canvas:getWidth()==240 and R.canvas:getHeight()==160,'Native UI canvas was resized with the 3D world')
  Display.setUiRenderer(nil)
  -- Unedited maps and unloaded mods go through the original renderer.
  local fallbackId=assert(door.destMap)
  do
    local fallback=assert(fresh.maps[fallbackId],'Native door destination missing')
    fallback.midLayout=assert(require('Gen3Map').layout(fresh,fallbackId))
    fallback.width,fallback.height=fallback.midLayout.width,fallback.midLayout.height
    Map.current=fallbackId;Map._def=fallback;C.bindMap(g,fallbackId,fallback)
    local previous=View._editor3DLast
    love.graphics.setCanvas({canvas,stencil=true});View.draw(g,480,320,{});love.graphics.setCanvas()
    assert(View._editor3DLast==previous,'An unedited interior incorrectly used 3D')
  end
  local reopened=assert(IO.load(S.path))
  local object=reopened.layeredMaps[map.id].visualObjects[2]
  assert(object.rotation==45 and object.lean==45,'Save/reopen lost 45-degree object settings')
  for _,message in ipairs(loader:status().errors or {}) do error(tostring(message)) end
  Map.current=map.id;Map._def=def;C.bindMap(g,map.id,def)
  local savedChains={}
  for name,chain in pairs(Runtime.hooks.chains) do
    local rows={};for i,entry in ipairs(chain) do rows[i]=entry end
    savedChains[name]=rows
  end
  Runtime.hooks:removeOwner('terrain3d_playable_test')
  assert(C.canEnter(g,4,5,{fromX=4,fromY=4,dir='down'}),'Unloading the mod retained its cliff hook')
  Runtime.hooks.chains=savedChains
  print('PASS: actual exported mod loader, real Gen3 sprites and NPCs, uphill/downhill player steps, cliff guard, original collision, native/custom warps, 2D fallback and saved 45-degree rotation/lean')
  return function()
    Map.current=town.id;Map._def=townDef;C.bindMap(g,town.id,townDef)
    require('src.core.game3.objects').loadMap(g,town.id,townDef)
    P.cellX,P.cellY,P.px,P.py=10,10,160,160
    assert(Display.present(g,800,600) and not Display.planesBroken)
  end
end
