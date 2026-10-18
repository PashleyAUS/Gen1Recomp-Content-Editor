-- Shared editor/runtime renderer; textures and gameplay actors are supplied by the caller.
local M={}
local format={{'VertexPosition','float',3},{'VertexTexCoord','float',2},{'VertexColor','float',4}}
function M.draw(state,source,terrain,geometry,x,y,w,h,options)
  options=options or {}
  local g=love.graphics
  local cols,rows=math.min(source.cellWidth,128),math.min(source.cellHeight,128)
  local angle,pitch=options.angle or state.angle or 0,options.pitch or state.pitch or .85
  local projected,minX,minY,maxX,maxY
  local cached=options.static and state.projection
  local reuse=cached and cached.source==source and cached.angle==angle and cached.pitch==pitch
  if reuse then
    projected=cached.vertices
    minX,minY,maxX,maxY=unpack(cached.bounds)
  else
    local world,objects=geometry.build(source,terrain,cols,rows)
    state.objectCount=#objects
    projected={}
    minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    for _,p in ipairs(world) do
      local px,py,depth=terrain.project(p[1]-cols/2,p[2]-rows/2,p[3],angle,pitch)
      local cameraDepth=depth*math.cos(pitch)+p[3]*math.sin(pitch)
      projected[#projected+1]={px,py,-cameraDepth/(cols+rows+64),p[4],p[5],p[6],p[7],p[8],p[9]}
      minX,minY,maxX,maxY=math.min(minX,px),math.min(minY,py),math.max(maxX,px),math.max(maxY,py)
    end
    if options.static then
      state.projection={source=source,angle=angle,pitch=pitch,vertices=projected,bounds={minX,minY,maxX,maxY}}
    end
  end
  local fit=math.min(w/math.max(1,maxX-minX),h/math.max(1,maxY-minY))*.9*(state.zoom or 1)
  local centerX,centerY=(minX+maxX)/2,(minY+maxY)/2
  if options.camera then
    centerX,centerY=terrain.project(options.camera.x-cols/2,options.camera.y-rows/2,options.camera.z or 0,angle,pitch)
    fit=options.camera.scale or 16
  end
  state.project=function(wx,wy,wz)
    local px,py,depth=terrain.project(wx-cols/2,wy-rows/2,wz,angle,pitch)
    return w/2+(px-centerX)*fit,h/2+(py-centerY)*fit,
      -(depth*math.cos(pitch)+wz*math.sin(pitch))/(cols+rows+64)
  end
  local vertices
  if not options.static or not reuse or state.meshFit~=fit then
    vertices={}
    for _,p in ipairs(projected) do
      vertices[#vertices+1]={p[1]*fit,p[2]*fit,p[3],p[4],p[5],p[6],p[7],p[8],p[9]}
    end
  end
  local sw,sh=math.max(1,math.ceil(w)),math.max(1,math.ceil(h))
  local samples=options.samples or 0
  if not state.scene or state.scene:getWidth()~=sw or state.scene:getHeight()~=sh or state.samples~=samples then
    if state.scene then state.scene:release();state.depth:release() end
    state.scene=g.newCanvas(sw,sh,{msaa=samples,dpiscale=1})
    state.samples=samples
    state.depth=g.newCanvas(sw,sh,{format='depth24',readable=false,msaa=samples,dpiscale=1})
  end
  if not state.shader then
    state.shader=g.newShader([[
      extern vec4 treeKeys[8];
      extern vec3 worldTint;
      vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
        vec4 pixel=Texel(texture,uv);
        if (color.a>1.5) {
          for (int i=0;i<8;i++) {
            if (treeKeys[i].a>0.5 && distance(pixel.rgb,treeKeys[i].rgb)<0.012) discard;
          }
          color.a=1.0;
        }
        pixel*=color;
        pixel.rgb*=worldTint;
        if (pixel.a<0.01) discard;
        return pixel;
      }
    ]], [[
      extern number cameraDepth;
      extern number perspectiveStrength;
      vec4 position(mat4 transform_projection, vec4 vertex_position) {
        vec4 p=transform_projection*vec4(vertex_position.xy,0.0,1.0);
        p.xy/=max(0.4,1.0+(vertex_position.z-cameraDepth)*perspectiveStrength);
        p.z=vertex_position.z;
        return p;
      }
    ]])
  end
  if not state.treeKeys then
    local keys={}
    if source.visualTreeStyle=='sprite' then
      local counts,spot={},nil
      for _,layer in ipairs(source.layers or {}) do
        for i,cell in pairs(layer.cells or {}) do
          if cell and (source.collision or {})[i]=='walk' then
            local key=tostring(cell.source)..':'..tostring(cell.tile)
            counts[key]=(counts[key] or 0)+1
            if not spot or counts[key]>spot.count then spot={i=i,count=counts[key]} end
          end
        end
      end
      if spot then
        local pixels=state.atlas:newImageData()
        local sx,sy=(spot.i-1)%source.cellWidth*16,math.floor((spot.i-1)/source.cellWidth)*16
        local colors={}
        local rect=source.visualTreeKeyRect
        if rect then sx,sy=rect.x*16,rect.y*16 end
        local width=rect and rect.width*16 or 16
        for py=sy,sy+(rect and 3 or 15) do for px=sx,sx+width-1 do
          if not rect or px<sx+4 or px>=sx+width-4 then
          local r,g,b=pixels:getPixel(px,py);local key=string.format('%.3f,%.3f,%.3f',r,g,b)
          colors[key]=colors[key] or {r,g,b,1,count=0};colors[key].count=colors[key].count+1
          end
        end end
        for _,color in pairs(colors) do keys[#keys+1]=color end
        table.sort(keys,function(a,b) return a.count>b.count end)
        pixels:release()
      end
    end
    state.treeKeys={}
    for i=1,8 do local c=keys[i] or {0,0,0,0};state.treeKeys[i]={c[1],c[2],c[3],c[4]} end
  end
  state.shader:send('treeKeys',unpack(state.treeKeys))
  state.shader:send('worldTint',source.visualTint or {1,1,1})
  local cameraDepth=0
  if options.camera then
    local cam=options.camera
    local _,_,depth=terrain.project(cam.x-cols/2,cam.y-rows/2,cam.z or 0,angle,pitch)
    cameraDepth=-(depth*math.cos(pitch)+(cam.z or 0)*math.sin(pitch))/(cols+rows+64)
  end
  state.shader:send('cameraDepth',cameraDepth)
  state.shader:send('perspectiveStrength',source.visualPerspective or 0)
  g.push('all');g.setCanvas({state.scene,depthstencil=state.depth});g.origin();g.setScissor()
  g.clear(.07,.12,.22,1,0,1);g.setDepthMode('less',true);g.setShader(state.shader)
  if vertices and #vertices>0 then
    if state.worldMesh then state.worldMesh:release() end
    state.worldMesh=g.newMesh(format,vertices,'triangles',options.static and 'static' or 'stream')
    state.meshFit=fit
  end
  if state.worldMesh then
    g.push();g.translate(w/2-centerX*fit,h/2-centerY*fit)
    state.worldMesh:setTexture(state.atlas);g.setColor(1,1,1,1);g.draw(state.worldMesh)
    g.pop()
  end
  for _,actor in ipairs(options.actors or {}) do
    if actor.image and actor.quad then
      local sx,sy,depth=state.project(actor.x,actor.y,actor.z)
      local qx,qy,qw,qh=actor.quad:getViewport()
      local iw,ih=actor.image:getDimensions()
      local u0,u1=qx/iw,(qx+qw)/iw
      if actor.flip then u0,u1=u1,u0 end
      local v0,v1=qy/ih,(qy+qh)/ih
      local width,height=qw/16*fit,qh/16*fit
      sx=sx+(actor.offsetX or 0)/16*fit
      sy=sy+(actor.offsetY or 0)/16*fit
      local alpha=actor.alpha or 1
      local av={{sx-width/2,sy-height,depth,u0,v0,1,1,1,alpha},
        {sx+width/2,sy-height,depth,u1,v0,1,1,1,alpha},
        {sx+width/2,sy,depth,u1,v1,1,1,1,alpha},
        {sx-width/2,sy,depth,u0,v1,1,1,1,alpha}}
      local triangles={av[1],av[2],av[3],av[1],av[3],av[4]}
      local mesh=g.newMesh(format,triangles,'triangles','stream')
      mesh:setTexture(actor.image);g.draw(mesh);mesh:release()
    end
  end
  g.pop()
  if not options.offscreen then
    g.push('all');g.setColor(1,1,1,1);g.setBlendMode('alpha','premultiplied');g.draw(state.scene,x,y);g.pop()
  end
end
return M
