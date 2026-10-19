-- Embedded in exported Emerald, FireRed and LeafGreen mods. All textures come from the player's import.
local M={}

function M.install(mod,maps,terrain,geometry,renderer,models,world)
  local Runtime=require('src.mods.Runtime')
  local Map=require('src.core.game3.map')
  local FieldView=require('src.core.game3.field_view')
  local Collision=require('src.core.game3.collision')
  local Player=require('src.core.game3.player')
  local Objects=require('src.core.game3.objects')
  local Sprites=require('src.core.game3.ow_sprites')
  local T=require('src.core.game3.tileset_native')
  local states,groups={},{}
  local enabled,toggleHeld=true,false
  local function current()
    return maps[Map.current or Collision._mapId]
  end
  local function cameraState(source)
    local key=source.visualWorldAnchor or Map.current or Collision._mapId
    local state=states[key] or {zoom=1};states[key]=state
    if not state.camera then state.camera=terrain.cameraDefaults(source) end
    return state
  end
  mod.hooks:wrap('input.key',function(proceed,game,event)
    if event.key=='f6' and event.phase=='released' then
      local handled=toggleHeld;toggleHeld=false
      if handled then return end
    end
    local source=current()
    local input=game.input
    if not source or (input and (input.captureArmed or (input.keyBindings and input.keyBindings[event.key]~=nil)))
        or not require('src.core.game3.runtime').isActive()
        or require('src.core.game3.field').locked
        or require('src.ui.game3.stack').top()
        or require('src.core.game3.battle').isActive() then return proceed(game,event) end
    if event.phase=='pressed' then
      if event.key=='f6' then
        if not toggleHeld then enabled=not enabled;toggleHeld=true end
        return
      end
      if enabled and terrain.cameraKey(cameraState(source).camera,event.key,terrain.cameraDefaults(source)) then return end
    end
    return proceed(game,event)
  end)
  local function window(source,px,py,state)
    local ox=math.max(0,math.min(math.max(0,source.cellWidth-128),math.floor(px/32)*32-48))
    local oy=math.max(0,math.min(math.max(0,source.cellHeight-128),math.floor(py/32)*32-48))
    if source.cellWidth<=128 and source.cellHeight<=128 then return source,0,0 end
    if state.view and state.viewX==ox and state.viewY==oy then return state.view,ox,oy end
    local copy={id=source.id,baseTileset=source.baseTileset,cellWidth=math.min(128,source.cellWidth-ox),
      cellHeight=math.min(128,source.cellHeight-oy),layers={},collision={},visualHeights={},visualShapes={},
      visualAutoObjects=source.visualAutoObjects,visualObjects={}}
    for _,key in ipairs({'visualTreeStyle','visualTint','visualPerspective','visualBackground','visualEnvironment','visualNativeCutouts','visualProfileVersion'}) do
      copy[key]=source[key]
    end
    for i,layer in ipairs(source.layers or {}) do
      copy.layers[i]={cells={},visible=layer.visible,export=layer.export}
    end
    for y=0,copy.cellHeight-1 do for x=0,copy.cellWidth-1 do
      local from=(y+oy)*source.cellWidth+x+ox+1;local to=y*copy.cellWidth+x+1
      for i,layer in ipairs(source.layers or {}) do copy.layers[i].cells[to]=(layer.cells or {})[from] end
      for _,key in ipairs({'collision','visualHeights','visualShapes'}) do copy[key][to]=(source[key] or {})[from] end
    end end
    for _,o in ipairs(source.visualObjects or {}) do
      if o.x>=ox and o.y>=oy and o.x+o.width<=ox+copy.cellWidth and o.y+o.height<=oy+copy.cellHeight then
        local item={};for k,v in pairs(o) do item[k]=v end
        item.x,item.y=o.x-ox,o.y-oy;copy.visualObjects[#copy.visualObjects+1]=item
      end
    end
    state.view,state.viewX,state.viewY=copy,ox,oy
    return copy,ox,oy
  end
  local function actors(source,ox,oy,game,shiftX,shiftY,ghosts)
    local result={}
    local function add(gid,px,py,facing,phase,flip,opts)
      opts=opts or {}
      local spr=gid and Sprites.getDraw(gid)
      if not spr then return end
      local frame,hflip=Sprites.pose(spr,facing,phase,flip,opts)
      if not spr.quads[frame] then return end
      local wx,wy=px/16+.5+(shiftX or 0),py/16+.5+(shiftY or 0)
      result[#result+1]={image=spr.image,quad=spr.quads[frame],x=wx-ox,y=wy-oy,
        z=terrain.surface(source,wx,wy)-(opts.raiseY or 0)/16,flip=hflip,
        offsetX=(hflip and -1 or 1)*(spr.drawOffX or 0),offsetY=spr.drawOffY or 0,alpha=opts.alpha}
    end
    for _,o in ipairs(Objects.forDraw()) do
      add(o.graphicsId or (o.def and (o.def.graphicsId or o.def.graphics)),
        (o.px or o.cellX*16)+(o.raiseX or 0),o.py or o.cellY*16,o.facing,
        Objects.walkPhase(o),o.stepFlip,{frame=o.customFrame,alpha=Objects.fadeAlpha(o),raiseY=o.raiseY})
    end
    for _,entry in ipairs(ghosts or {}) do
      for _,o in ipairs(require('src.core.game3.ghosts').forDraw(entry.id) or {}) do
        add(o.graphicsId or (o.def and (o.def.graphicsId or o.def.graphics)),
          (o.px or o.cellX*16)+entry.x*16,(o.py or o.cellY*16)+entry.y*16,o.facing,
          Objects.walkPhase(o),o.stepFlip,{frame=o.customFrame,alpha=Objects.fadeAlpha(o),raiseY=o.raiseY})
      end
    end
    if not Player.isVisible or Player.isVisible() then
      add(Sprites.playerGraphicsId(game),Player.px,Player.py,Player.facing,Player.walkPhase(),Player.stepFlip,
        {running=Player.runPose and Player.runPose(),frame=Player.acroFrame and Player.acroFrame(),raiseY=Player.spriteYOffset})
    end
    return result
  end
  local function atlas(state,source,def,ox,oy,restore,owners,game)
    local cols,rows=source.cellWidth,source.cellHeight
    local g=love.graphics
    if not state.atlas or state.atlas:getWidth()~=cols*16 or state.atlas:getHeight()~=rows*16+4 then
      if state.atlas then state.atlas:release() end
      state.atlas=g.newCanvas(cols*16,rows*16+4);state.atlas:setFilter('nearest','nearest')
    end
    local batches,visibleMaps={},{}
    for y=0,rows-1 do for x=0,cols-1 do
      local owner=owners and owners[y*cols+x+1]
      local d=owner and game.data.maps[owner.id] or def
      if owner then visibleMaps[owner.id]=true end
      local key=d and d.pair
      if not key or not d.midLayout then return false end
      local batch=batches[key]
      if not batch then
        local ts=T.get(key);if not ts then return false end
        if restore and ts._editorRebuild then ts._editorRebuild() end
        batch={ts=ts,under=g.newSpriteBatch(ts.image,cols*rows,'stream'),
          over=ts.overImage and g.newSpriteBatch(ts.overImage,cols*rows,'stream')}
        batches[key]=batch
      end
      local mid=d.midLayout:midAt(owner and owner.x or x+ox,owner and owner.y or y+oy)
      local slot=T.slotFor(batch.ts,mid)
      batch.under:add(T.quad(batch.ts,slot),x*16,y*16)
      if batch.over then batch.over:add(T.overQuad(batch.ts,slot),x*16,y*16) end
    end end
    g.push('all');g.setCanvas(state.atlas);g.origin();g.setScissor();g.clear(.12,.17,.2,1);g.setColor(1,1,1,1)
    for _,batch in pairs(batches) do g.draw(batch.under);batch.under:release() end
    for _,batch in pairs(batches) do if batch.over then g.draw(batch.over);batch.over:release() end end
    g.setColor(1,1,1,1);g.rectangle('fill',0,rows*16,4,4);g.pop()
    state.visibleMaps=visibleMaps
    return true
  end
  if not FieldView._editorSceneDispatch then
    FieldView._editorSceneDispatch=true
    local draw=FieldView.draw
    FieldView.draw=function(...) return Runtime.call('editor.gen3.scene.draw',draw,...) end
  end
  mod.hooks:wrap('editor.gen3.scene.draw',function(proceed,game,w,h,opts)
    local source=current()
    if not source then return proceed(game,w,h,opts) end
    local id=Map.current or Collision._mapId
    local state=cameraState(source)
    if not enabled then
      state.drawn=false
      -- A room's native atlas may have been evicted while the 3D view was
      -- active. Load it before the native renderer's readiness check.
      local def=Map.currentDef() or (game.data and game.data.maps[id])
      if def and def.pair then T.get(def.pair) end
      FieldView._editor3DLast={mapId=id,mode='2d',localX=Player.px/16+.5,localY=Player.py/16+.5}
      return proceed(game,w,h,opts)
    end
    if opts and opts.actorsOnly then
      if not state.drawn then return proceed(game,w,h,opts) end
      return
    end
    state.drawn=false
    w,h=w or 240,h or 160
    FieldView._viewW,FieldView._viewH=w,h
    local def=Map.currentDef() or (game.data and game.data.maps[id])
    local px,py=Player.px/16+.5,Player.py/16+.5
    local view,ox,oy=window(source,px,py,state)
    local owners,shiftX,shiftY,ghosts,worldX,worldY
    if world and source.visualWorldAnchor then
      local anchor=source.visualWorldAnchor
      local group=groups[anchor]
      if not group then
        local subset,objects={},{}
        for mid,s in pairs(maps) do if s.visualWorldAnchor==anchor then subset[mid]=s;objects[mid]=models.objects(s) end end
        local placed,ids=world.place(subset,anchor,function(mid) return require('src.core.game3.connections').each(game.data.maps[mid]) end)
        group={maps=subset,objects=objects,placed=placed,ids=ids};groups[anchor]=group
      end
      local p=assert(group.placed[id]);worldX,worldY=px+p.x,py+p.y
      local left,top=math.floor((worldX-40)/8+.5)*8,math.floor((worldY-40)/8+.5)*8
      if not state.worldView or state.worldLeft~=left or state.worldTop~=top then
        state.worldView,state.owners,state.worldLeft,state.worldTop=world.build(group.maps,group.placed,group.ids,group.objects,worldX,worldY,80)
        state.updated=nil
      end
      view,owners,ox,oy=state.worldView,state.owners,0,0
      shiftX,shiftY=p.x-state.worldLeft,p.y-state.worldTop
      px,py=px+shiftX,py+shiftY
      ghosts={}
      for _,entry in ipairs(Map.world or {}) do
        if group.placed[entry.id] and entry.id~=id then ghosts[#ghosts+1]={id=entry.id,x=entry.ox,y=entry.oy} end
      end
    end
    local now=love.timer.getTime()
    local drawableW,drawableH=love.graphics.getPixelDimensions()
    if state.drawableW~=drawableW or state.drawableH~=drawableH or state.ox~=ox or state.oy~=oy or not state.updated or now-state.updated>.12 then
      if not atlas(state,view,def,ox,oy,state.drawableW~=drawableW or state.drawableH~=drawableH,owners,game) then return proceed(game,w,h,opts) end
      state.updated,state.ox,state.oy=now,ox,oy
      state.drawableW,state.drawableH=drawableW,drawableH
      state.atlasRevision=(state.atlasRevision or 0)+1
    end
    local surface=owners and view or source
    local z=terrain.surface(surface,px,py)
    local list=actors(surface,ox,oy,game,shiftX,shiftY,ghosts)
    local camera=state.camera
    local rw,rh,scale,samples=w,h,1,0
    local compositor=require('src.render.Renderer')
    local transition=require('src.core.game3.battle_transition')
    local transitioning=transition and transition.isActive and transition.isActive()
    -- Use the renderer's native window-resolution world override. It preserves
    -- the normal UI compositor, anchoring, warp fades and interior fallback.
    local hd=compositor and compositor.worldActive and compositor.setWorldOverride
      and love.graphics.getCanvas()==compositor.worldCanvas and not transitioning
    if hd then
      local rect=compositor:frameRects()
      rw,rh=math.max(1,math.floor(rect.pw+.5)),math.max(1,math.floor(rect.ph+.5))
      scale=math.min(rw/w,rh/h)
      samples=math.min(4,love.graphics.getSystemLimits().canvasmsaa or 0)
    end
    local cameraX,cameraY=px-ox,py-oy
    if source.visualInterior then
      -- Clamp indoor tracking to the room so the doorway does not push it off-screen.
      local halfW=rw/(camera.scale*scale)/2-1
      local halfH=rh/(camera.scale*scale)/2/math.sin(camera.pitch)-1
      local function clampRoom(value,extent,half)
        if extent<=half*2 then return extent/2 end
        return math.max(half,math.min(extent-half,value))
      end
      cameraX=clampRoom(cameraX,view.cellWidth,halfW)
      cameraY=clampRoom(cameraY,view.cellHeight,halfH)
    end
    renderer.draw(state,view,terrain,geometry,0,0,rw,rh,{angle=camera.angle or -.65,pitch=camera.pitch or .65,static=true,
      camera={x=cameraX,y=cameraY,z=z,scale=(camera.scale or 16)*scale},actors=list,
      offscreen=hd,samples=samples})
    if hd then compositor:setWorldOverride(state.scene) end
    state.drawn=true
    local sx,sy=state.project(px-ox,py-oy,z)
    FieldView._editor3DLast={mapId=id,mode='3d',customModels=#(state.modelMeshes or {}),x=px,y=py,z=z,actors=#list,objects=state.objectCount,
      screenX=sx,screenY=sy,width=rw,height=rh,nativeWidth=w,nativeHeight=h,
      hd=hd and true or false,samples=samples,worldX=worldX,worldY=worldY,
      cameraAngle=camera.angle,cameraPitch=camera.pitch,cameraScale=camera.scale,
      interior=source.visualInterior and true or false,
      localX=Player.px/16+.5,localY=Player.py/16+.5,connected=owners and true or false,
      visibleMaps=state.visibleMaps,canvasWidth=state.scene:getWidth(),canvasHeight=state.scene:getHeight(),atlasRevision=state.atlasRevision}
  end)
  if not Collision._editorSceneDispatch then
    Collision._editorSceneDispatch=true
    local canEnter=Collision.canEnter
    Collision.canEnter=function(...) return Runtime.call('editor.gen3.scene.enter',canEnter,...) end
  end
  mod.hooks:wrap('editor.gen3.scene.enter',function(proceed,game,tx,ty,opts)
    local allowed,reason=proceed(game,tx,ty,opts)
    if not allowed then return allowed,reason end
    local source=current();opts=opts or {}
    if not source then return allowed,reason end
    local fx,fy=opts.fromX or Player.cellX,opts.fromY or Player.cellY
    if not fx or not fy or tx<0 or ty<0 or tx>=source.cellWidth or ty>=source.cellHeight
        or fx<0 or fy<0 or fx>=source.cellWidth or fy>=source.cellHeight then return allowed,reason end
    local dx,dy=tx-fx,ty-fy
    if math.abs(dx)+math.abs(dy)~=1 then return allowed,reason end
    local ex,ey=(fx+tx)/2+.5,(fy+ty)/2+.5
    local before=terrain.surface(source,ex-dx*.0001,ey-dy*.0001)
    local after=terrain.surface(source,ex+dx*.0001,ey+dy*.0001)
    if math.abs(before-after)>.01 then return false,'3d_cliff' end
    return allowed,reason
  end)
end
return M
