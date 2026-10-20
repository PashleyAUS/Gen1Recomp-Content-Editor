-- Uses imported ROM maps, real editor pointer handling and real LÖVE pixels.
return function(data, root, output, game)
  local State, L, K = require('State'), require('LayeredMap'), require('Kit')
  local Builder, Preview = require('MapBuilder'), require('MapPreview3D')
  local Writer, History = require('ModWriter'), require('History')
  local id = game == 'emerald' and 'EM_LITTLEROOT_TOWN' or 'FR_PALLET_TOWN'
  assert(data.maps[id], 'Missing native map: '..id)
  local S = State.new(); S.data=data; S.version=game
  S.project=State.blankProject('terrain_preview_test'); S.project.game=game
  require('Gen3ContentAdapter').prepare(S); require('Gen3Workspace').prepare(S)
  S.mapId=id; S.builderMapId=id; S.mapWorkspace=true; S.mapEditMode='map'
  local source=assert(L.convertMap(S,id))
  if game=='emerald' then
    local surfaces=0
    for _,o in ipairs(require('MapObjects3D').objects(source)) do
      if o.style=='littleroot_native_surfaces' or o.style=='littleroot_lab_native_surfaces' then
        surfaces=surfaces+1;assert(o.lean==0,'Editable native building is still tilted')
      end
    end
    assert(surfaces==2,'Fresh editable Littleroot did not match the house/lab demo')
  end
  S.builderLayer=1; S.builderTool='visual_height'; S.builderVisualHeight=6
  S.builderZoom=2; S.builderCamX=0; S.builderCamY=0; S._builderCamMapId=id
  S.mapShowNeighbors=false
  local dirty=0
  local App={markDirty=function() dirty=dirty+1; History.noteDirty(S) end,
    beginEditBatch=function() History.beginBatch(S) end,
    endEditBatch=function() History.endBatch(S) end}
  History.clear(S)
  local down,middleDown,spaceDown=false,false,false
  local oldMouse,oldKeyboard=love.mouse.isDown,love.keyboard.isDown
  love.mouse.isDown=function(button) return (button==1 and down) or (button==3 and middleDown) end
  love.keyboard.isDown=function(key) return key=='space' and spaceDown end
  local canvas=love.graphics.newCanvas(1600,1000)
  local function frame(mx,my,pressed,draw)
    down=pressed
    love.graphics.setCanvas({canvas,stencil=true});love.graphics.clear(.04,.06,.12,1)
    K.layout(1600,1000);K.beginFrame(mx or 0,my or 0,pressed,0);History.beginFrame(S)
    if draw then draw() else Builder.drawView(S,0,0,800,800,App); Preview.draw(S,source,820,0,760,800) end
    K.endFrame();History.endFrame(S);love.graphics.setCanvas()
    return canvas:newImageData()
  end
  local function save(image,suffix)
    local f=assert(io.open(output..'/'..game..'-'..suffix..'.png','wb'))
    f:write(image:encode('png'):getString());f:close()
  end
  local function previewBytes(image)
    local result={}
    -- Compare only the scene, excluding controls and text.
    for y=40,740,2 do for x=825,1570,2 do
      local r,g,b=image:getPixel(x,y)
      result[#result+1]=string.char(math.floor(r*255),math.floor(g*255),math.floor(b*255))
    end end
    return table.concat(result)
  end
  local initialLayers=Writer.encodeLua(source.layers)
  local before=frame();save(before,'before')
  -- Panning must work while the 3D Object tool remains selected, without
  -- requiring the left button or accidentally committing an object rectangle.
  local camX,camY=S.builderCamX,S.builderCamY
  local objectsBefore=Writer.encodeLua(source.visualObjects)
  local dirtyBefore=dirty
  S.builderTool='visual_object'
  middleDown=true;frame(200,200,false);frame(264,232,false)
  assert(S.builderCamX==camX-32 and S.builderCamY==camY-16,'Middle-only pan did not move the 2D map')
  middleDown=false;frame(264,232,false)
  assert(not S._builderDrag and not S.builderRangeDraft,'Middle pan left an object gesture active')
  spaceDown=true;frame(200,200,true);frame(232,216,true)
  local pannedX,pannedY=S.builderCamX,S.builderCamY
  spaceDown=false;frame(248,224,true)
  assert(S.builderCamX==pannedX-8 and S.builderCamY==pannedY-4,'Releasing Space switched a held pan into object placement')
  frame(248,224,false)
  assert(S.builderTool=='visual_object' and Writer.encodeLua(source.visualObjects)==objectsBefore
    and dirty==dirtyBefore,'Panning changed the selected tool, placed an object or dirtied the project')
  frame(200,200,true)
  assert(S.builderRangeDraft,'Object selection did not start after panning')
  middleDown=true;frame(216,208,false);frame(248,224,false)
  middleDown=false;frame(248,224,false)
  assert(not S.builderRangeDraft and Writer.encodeLua(source.visualObjects)==objectsBefore
    and dirty==dirtyBefore,'Interrupting an object rectangle with pan committed a phantom object')
  S.builderCamX,S.builderCamY=camX,camY;S.builderTool='visual_height';frame()
  save(S._terrain3D.atlas:newImageData(),'atlas')
  local grid=assert(io.open(output..'/'..game..'-grid-log.txt','w'))
  for cy=0,source.cellHeight-1 do
    local row={};for cx=0,source.cellWidth-1 do row[#row+1]=tostring(source.layers[1].cells[cy*source.cellWidth+cx+1].tile) end
    grid:write(cy..': '..table.concat(row,',')..'\n')
  end
  grid:close()
  local collision=Writer.encodeLua(source.collision)
  local elevation=Writer.encodeLua(source.gen3Elevation)
  -- Target actual cell (5,5), through drawCanvas's camera and pointer conversion.
  local function pointer(cx,cy)
    return 8*K.scale+(cx*16+8-(S.builderCamX or 0))*S.builderZoom,
      8*K.scale+(cy*16+8-(S.builderCamY or 0))*S.builderZoom
  end
  local mx,my=pointer(5,5)
  local raised=frame(mx,my,true);frame(mx,my,false)
  assert(Preview.height(source,5,5)==6, '2D height brush did not paint native cell')
  assert(dirty>0 and History.canUndo(S), 'Height brush bypassed dirty/history handling')
  assert(previewBytes(before)~=previewBytes(raised), 'Height paint did not change preview pixels in the same frame')
  assert(Writer.encodeLua(source.collision)==collision and Writer.encodeLua(source.gen3Elevation)==elevation,
    'Visual brush changed passage data')
  save(raised,'height')
  assert(History.undo(S), 'Height undo failed')
  source=S.project.layeredMaps[id]
  assert(Preview.height(source,5,5)==0, 'Undo kept visual height')
  assert(previewBytes(frame())==previewBytes(before), 'Undo did not restore preview')
  assert(History.redo(S), 'Height redo failed')
  source=S.project.layeredMaps[id]
  assert(Preview.height(source,5,5)==6, 'Redo lost visual height')
  assert(previewBytes(frame())==previewBytes(raised), 'Redo did not restore preview')
  -- Drag across several cells using the real line interpolation path.
  mx,my=pointer(6,5);frame(mx,my,true)
  mx,my=pointer(9,5);frame(mx,my,true);frame(mx,my,false)
  for cx=6,9 do assert(Preview.height(source,cx,5)==6,'Drag skipped a native cell') end
  -- Verify real textured tile edits, including the atlas refresh interval.
  S.builderTool='pencil'; S.builderStamp=nil
  local first=source.layers[1].cells[5*source.cellWidth+5+1]
  local replacement
  for _,ref in pairs(source.layers[1].cells) do
    if ref.tile~=first.tile and ref.source==first.source then replacement=ref;break end
  end
  assert(replacement,'No alternate native tile')
  S.builderSourceId=replacement.source;S.builderTile=replacement.tile
  local beforeTile=frame()
  mx,my=pointer(5,5);frame(mx,my,true);frame(mx,my,false)
  assert(source.layers[1].cells[5*source.cellWidth+6].tile==replacement.tile,'2D pencil did not paint native tile')
  love.timer.sleep(0.14)
  local afterTile=frame()
  assert(previewBytes(beforeTile)~=previewBytes(afterTile),'Painted native tile did not refresh 3D atlas')
  save(afterTile,'tile')
  local Objects=require('MapObjects3D')
  local auto=Objects.detect(source)
  local trees,buildings=0,0
  for _,o in ipairs(auto) do
    if o.kind=='tree' then trees=trees+1 else buildings=buildings+1 end
  end
  assert(trees>=5 and buildings>=2,'Native tree/building signatures did not recognize the town')
  local tilesBefore=Writer.encodeLua(source.layers)
  local passageBefore=Writer.encodeLua({source.collision,source.gen3Collision,source.gen3Elevation})
  -- Every slope is painted through the real brush, including same-height changes.
  S.builderTool='visual_height';S.builderVisualHeight=2
  local last=frame()
  for _,shape in ipairs(Preview.shapes) do
    S.builderVisualShape=shape.id
    mx,my=pointer(10,18)
    local shaped=frame(mx,my,true);frame(mx,my,false)
    assert((source.visualShapes[18*source.cellWidth+11] or 'flat')==shape.id,'Slope brush lost orientation')
    assert(previewBytes(shaped)~=previewBytes(last),'Slope edit did not update 3D geometry: '..shape.id)
    last=shaped
  end
  save(last,'slopes')
  -- Drag a model footprint through the same rectangle interaction as the UI.
  local function footprint(kind,x0,y0,x1,y1)
    S.builderTool='visual_object';S.builderObjectKind=kind;S.builderObjectSize=4
    mx,my=pointer(x0,y0);frame(mx,my,true)
    mx,my=pointer(x1,y1);frame(mx,my,true)
    return frame(mx,my,false)
  end
  local treeImage=footprint('tree',10,9,11,10)
  assert(source.visualObjects[#source.visualObjects].kind=='tree','Tree placement did not commit')
  save(treeImage,'tree')
  S.builderTreeLean=45
  local buildingImage=footprint('building',10,14,12,16)
  assert(source.visualObjects[#source.visualObjects].kind=='building','Building placement did not commit')
  assert(source.visualObjects[#source.visualObjects].lean==45,'Editor discarded non-tree object lean')
  assert(previewBytes(treeImage)~=previewBytes(buildingImage),'Building model did not appear')
  local objectCount=#Objects.objects(source)
  footprint('none',10,9,10,9)
  assert(#Objects.objects(source)==objectCount-1,'Remove kept the raised tree')
  assert(History.undo(S),'Object remove undo failed');source=S.project.layeredMaps[id]
  assert(#Objects.objects(source)==objectCount,'Undo lost tree model')
  assert(History.redo(S),'Object remove redo failed');source=S.project.layeredMaps[id]
  assert(#Objects.objects(source)==objectCount-1,'Redo kept removed tree')
  assert(Writer.encodeLua(source.layers)==tilesBefore,'3D models changed 2D tiles')
  assert(Writer.encodeLua({source.collision,source.gen3Collision,source.gen3Elevation})==passageBefore,
    'Slopes or objects changed passage rules')
  for i=0,3 do
    S._terrain3D.angle=-.65+i*math.pi/2
    save(frame(),'angle-'..i)
  end
  S._terrain3D.angle=-.65
  -- Reopen serialized project data, which also checks sparse visual height storage.
  local reopened=assert(loadstring('return '..Writer.encodeLua(S.project)))()
  assert(reopened.layeredMaps[id].visualHeights[5*source.cellWidth+6]==6)
  assert(reopened.layeredMaps[id].visualShapes[18*source.cellWidth+11]=='corner_sw')
  assert(#reopened.layeredMaps[id].visualObjects==#source.visualObjects,'Serialized objects were lost')
  -- Check full workspace layout with real assets and property controls.
  local function workspaceDraw()
    require('MapsWorkspace').draw(S,10,10,1580,980,App)
  end
  -- Repeat through the complete workspace layout, including toolbar sizing.
  S.tab='maps3d';require('MapsWorkspace').activate(S,App)
  -- Measure and render the actual toolbar tooltip through LÖVE. A stray
  -- Windows-encoded accented character previously crashed getWidth on hover.
  local oldOfferTooltip=K.offerTooltip
  local eventsTooltip
  K.offerTooltip=function(x,y,w,h,text)
    if text and text:find('Place NPCs',1,true) then eventsTooltip=text end
    return oldOfferTooltip(x,y,w,h,text)
  end
  frame(0,0,false,workspaceDraw)
  K.offerTooltip=oldOfferTooltip
  assert(eventsTooltip,'Add events tooltip was not exercised')
  frame(0,0,false,function() K.drawTooltip(eventsTooltip,400,400) end)
  S.builderTool='visual_height'; S.builderVisualHeight=9;S.builderVisualShape='east'
  local oldCard=K.card; local rect
  local expectedX=10+math.min(270*K.scale,math.max(220*K.scale,1580*0.22))+9*K.scale
  K.card=function(x,y,w,h,...)
    if math.abs(x-expectedX)<1 and h>150 then rect={x=x,y=y,w=w,h=h} end
    return oldCard(x,y,w,h,...)
  end
  frame(0,0,false,workspaceDraw)
  K.card=oldCard
  assert(rect,'Workspace editor canvas not found')
  local cx=math.floor(((S.builderCamX or 0)+(rect.w-16*K.scale)/S.builderZoom/2)/16)
  local cy=math.floor(((S.builderCamY or 0)+(rect.h-16*K.scale)/S.builderZoom/2)/16)
  mx=rect.x+8*K.scale+(cx*16+8-S.builderCamX)*S.builderZoom
  my=rect.y+8*K.scale+(cy*16+8-S.builderCamY)*S.builderZoom
  frame(mx,my,true,workspaceDraw)
  assert(Preview.height(source,cx,cy)==9,'Full workspace pointer did not paint the intended cell')
  local workspace=frame(mx,my,false,workspaceDraw)
  save(workspace,'workspace')
  if os.getenv('POKEPORT_CUSTOM_MODEL_REVIEW')=='1' then
    dofile(root..'/tests/content-editor/custom_model_review.lua')(S,source,root)
    S.builderCamX,S.builderCamY,S.builderZoom=0,0,2
    S.builderObjectSize=2;S.builderObjectRotation=45
    frame(0,0,false)
    local modelX,modelY=pointer(10,14)
    frame(modelX,modelY,true)
    frame(modelX,modelY,false)
    local placed
    for _,o in ipairs(source.visualObjects) do if o.kind=='model' and o.x==10 and o.y==14 then placed=o end end
    assert(placed and placed.model==source.visualModelLibrary[3] and placed.rotation==45 and placed.size==2,
      'Dragging a custom model footprint did not place the selected GLB asset')
    save(frame(0,0,false,workspaceDraw),'custom-model-workspace')
  end
  if os.getenv('POKEPORT_NATIVE_PROFILE_REVIEW')=='1' then
    local unchanged=Writer.encodeLua({source.layers,source.collision,source.gen3Collision,source.gen3Elevation})
    require('NativeMapProfiles3D').build(S,id,{})
    assert(source.visualNativeProfile and unchanged==Writer.encodeLua({source.layers,source.collision,source.gen3Collision,source.gen3Elevation}))
    save(frame(0,0,false,workspaceDraw),'native-profiles-workspace')
  end
  -- A clean showcase, separate from the destructive test edits above.
  source.layers=assert(loadstring('return '..initialLayers))()
  source.visualHeights={};source.visualShapes={};source.visualObjects=nil
  for x=9,11 do
    Preview.paint(source,x,10,1,'flat')
    Preview.paint(source,x,11,0,'north')
  end
  S.builderVisualHeight=0;S.builderVisualShape='north'
  S._terrain3D.updated=-1
  save(frame(0,0,false,workspaceDraw),'showcase')
  S.builderTool='visual_object'
  save(frame(0,0,false,workspaceDraw),'objects-workspace')
  local selected=S.mapId
  local authored=Writer.encodeLua({source.layers,source.collision,source.visualHeights,source.visualShapes,source.visualObjects})
  local calls=0;local drawPreview=Preview.draw
  Preview.draw=function(...) calls=calls+1;return drawPreview(...) end
  S._builderDrag={range=true,tool='visual_object',x0=1,y0=1}
  S.builderRangeDraft={x0=1,y0=1,x1=3,y1=3}
  S.tab='maps'
  save(frame(0,0,false,workspaceDraw),'2d-tab')
  assert(calls==0 and S.builderTool=='pencil','2D Maps retained the 3D preview/tool')
  assert(not S._builderDrag and not S.builderRangeDraft,'Tab switch retained an active 3D object gesture')
  assert(not Builder.supportsTool(S,'visual_object') and not Builder.supportsTool(S,'visual_height'))
  S.builderTool='eraser';S.tab='maps3d'
  save(frame(0,0,false,workspaceDraw),'3d-tab')
  assert(calls>0 and S.builderTool=='visual_object','3D Maps did not restore the live preview and object tool')
  assert(Builder.supportsTool(S,'visual_object') and Builder.supportsTool(S,'visual_height'))
  S.tab='maps';frame(0,0,false,workspaceDraw)
  assert(S.builderTool=='eraser' and S.mapId==selected,'Map tabs did not retain their tools or shared map selection')
  assert(authored==Writer.encodeLua({source.layers,source.collision,source.visualHeights,source.visualShapes,source.visualObjects}),
    'Switching between map tabs modified authored content')
  S.mapEditMode='events';S.mapViewMode='world';S.mapBorderEditor=true
  S.tab='maps3d';require('MapsWorkspace').activate(S,App)
  assert(S.mapEditMode=='map' and S.mapViewMode=='editor' and not S.mapBorderEditor,
    '3D Maps opened the 2D events, world or border view')
  S.tab='maps';require('MapsWorkspace').activate(S,App)
  assert(S.mapEditMode=='events' and S.mapViewMode=='world' and S.mapBorderEditor,
    '2D Maps lost its previous view on returning from 3D Maps')
  Preview.draw=drawPreview
  love.mouse.isDown=oldMouse
  love.keyboard.isDown=oldKeyboard
  print('PASS '..game..' '..id..': native textures, all slope brushes, automatic models, manual tree/building placement/removal, four camera angles, same-frame geometry, tile refresh, passage isolation, undo/redo, persistence, workspace')
end
