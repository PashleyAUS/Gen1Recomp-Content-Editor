-- Editor-only visual terrain. Passage elevations remain independent.
local M = {}

function M.cameraDefaults(source)
  local c=source.visualCamera or {}
  return {angle=c.angle or -.65,pitch=c.pitch or .65,scale=c.scale or 16}
end

-- Shared controls for the editor and exported gameplay camera. Angles are radians.
function M.cameraKey(camera,key,defaults)
  local step=math.pi/12
  if key=='[' then camera.angle=(camera.angle-step)%(2*math.pi)
  elseif key==']' then camera.angle=(camera.angle+step)%(2*math.pi)
  elseif key=='pageup' then camera.pitch=math.min(1.5,camera.pitch+math.pi/36)
  elseif key=='pagedown' then camera.pitch=math.max(.15,camera.pitch-math.pi/36)
  elseif key=='=' or key=='kp+' then camera.scale=math.min(40,camera.scale*1.15)
  elseif key=='-' or key=='kp-' then camera.scale=math.max(4,camera.scale/1.15)
  elseif key=='home' then
    for _,k in ipairs({'angle','pitch','scale'}) do camera[k]=defaults[k] end
  else return false end
  return true
end

function M.height(source, x, y)
  return (source.visualHeights or {})[y * source.cellWidth + x + 1] or 0
end

M.shapes = {
  {id='flat',label='Flat',corners={0,0,0,0}},
  {id='north',label='Rise N',corners={1,1,0,0}},
  {id='east',label='Rise E',corners={0,1,1,0}},
  {id='south',label='Rise S',corners={0,0,1,1}},
  {id='west',label='Rise W',corners={1,0,0,1}},
  {id='corner_nw',label='Corner NW',corners={1,0,0,0}},
  {id='corner_ne',label='Corner NE',corners={0,1,0,0}},
  {id='corner_se',label='Corner SE',corners={0,0,1,0}},
  {id='corner_sw',label='Corner SW',corners={0,0,0,1}},
}
local shapeById={}
for _,shape in ipairs(M.shapes) do shapeById[shape.id]=shape end

function M.corners(source,x,y)
  local index=y*source.cellWidth+x+1
  local shape=shapeById[(source.visualShapes or {})[index]] or M.shapes[1]
  local base=M.height(source,x,y)*.5
  local result={}
  for i=1,4 do result[i]=base+shape.corners[i]*.5 end
  return result
end

function M.surface(source,x,y)
  local cx=math.max(0,math.min(source.cellWidth-1,math.floor(x)))
  local cy=math.max(0,math.min(source.cellHeight-1,math.floor(y)))
  local u,v=x-cx,y-cy
  local z=M.corners(source,cx,cy)
  local shape=(source.visualShapes or {})[cy*source.cellWidth+cx+1]
  if shape=='corner_nw' or shape=='corner_se' then
    if u+v<=1 then return z[1]*(1-u-v)+z[2]*u+z[4]*v end
    return z[2]*(1-v)+z[3]*(u+v-1)+z[4]*(1-u)
  end
  if v<=u then return z[1]*(1-u)+z[2]*(u-v)+z[3]*v end
  return z[1]*(1-v)+z[3]*u+z[4]*(v-u)
end

function M.paint(source, x, y, value, shape)
  shape=shape or 'flat'
  if x < 0 or y < 0 or x >= source.cellWidth or y >= source.cellHeight
      or type(value) ~= 'number' or value % 1 ~= 0 or value < 0 or value > 15
      or not shapeById[shape] then return false end
  local index=y*source.cellWidth+x+1
  local before=(source.visualShapes or {})[index] or 'flat'
  if M.height(source,x,y)==value and before==shape then return false end
  source.visualHeights=source.visualHeights or {}
  source.visualHeights[index]=value
  source.visualShapes=source.visualShapes or {}
  source.visualShapes[index]=shape~='flat' and shape or nil
  return true
end

function M.project(x, y, z, angle, pitch)
  local c, s = math.cos(angle), math.sin(angle)
  local depth = x * s + y * c
  return x * c - y * s, depth * math.sin(pitch) - z * math.cos(pitch), depth
end

function M.draw2D(source,x0,y0,x1,y1)
  local g=love.graphics
  g.setLineWidth(1)
  for y=y0,y1 do for x=x0,x1 do
    local shape=shapeById[(source.visualShapes or {})[y*source.cellWidth+x+1]]
    if shape and shape.id~='flat' then
      local dx,dy=0,0
      for i,p in ipairs({{-1,-1},{1,-1},{1,1},{-1,1}}) do
        dx=dx+p[1]*shape.corners[i];dy=dy+p[2]*shape.corners[i]
      end
      dx,dy=dx/math.max(1,math.abs(dx))*5,dy/math.max(1,math.abs(dy))*5
      local cx,cy=x*16+8,y*16+8
      g.setColor(.1,.8,1,.3);g.rectangle('fill',x*16,y*16,16,16)
      g.setColor(1,1,.5,1);g.line(cx-dx*.5,cy-dy*.5,cx+dx,cy+dy)
      g.circle('fill',cx+dx,cy+dy,1.8)
    end
  end end
end

function M.draw(S, source, x, y, w, h, App)
  local Kit, L = require('Kit'), require('LayeredMap')
  local g, scale = love.graphics, Kit.scale
  local state = S._terrain3D
  if not state then state = {angle = -0.65, pitch = 0.65, zoom = 1}; S._terrain3D = state end
  if state.cameraSource~=source then
    local c=M.cameraDefaults(source)
    state.angle,state.pitch,state.zoom=c.angle,c.pitch,1
    state.cameraSource=source;state.drag=nil
  end
  if Kit.button(x, y, 96 * scale, 26 * scale, S.mapHide3D and 'Show 3D' or 'Hide 3D', {}) then
    S.mapHide3D = not S.mapHide3D
  end
  if S.mapHide3D then return 32 * scale end
  if Kit.button(x + 100 * scale, y, 62 * scale, 26 * scale, 'Reset', {}) then
    local c=M.cameraDefaults(source)
    state.angle, state.pitch, state.zoom = c.angle,c.pitch,1
  end
  if Kit.button(x + 166 * scale, y, 30 * scale, 26 * scale, '-', {}) then state.zoom = math.max(0.25, state.zoom / 1.2) end
  if Kit.button(x + 200 * scale, y, 30 * scale, 26 * scale, '+', {}) then state.zoom = math.min(8, state.zoom * 1.2) end
  for i,entry in ipairs({{'Rotate <','['},{'Rotate >',']'},{'Tilt +','pageup'},{'Tilt -','pagedown'}}) do
    if Kit.button(x+(i-1)*58*scale,y+30*scale,55*scale,24*scale,entry[1],{}) then
      local c={angle=state.angle,pitch=state.pitch,scale=16}
      M.cameraKey(c,entry[2]);state.angle,state.pitch=c.angle,c.pitch
    end
  end
  if App and Kit.button(x,y+58*scale,114*scale,24*scale,'Save camera',{
      tooltip='Use this rotation and tilt when the mod starts; applies to connected 3D maps'}) then
    local camera=M.cameraDefaults(source);camera.angle,camera.pitch=state.angle,state.pitch
    source.visualCamera=camera
    for _,other in pairs(S.project.layeredMaps or {}) do
      if source.visualWorldAnchor and other.visualWorldAnchor==source.visualWorldAnchor then
        other.visualCamera={angle=camera.angle,pitch=camera.pitch,scale=camera.scale}
      end
    end
    App.markDirty()
  end
  Kit.text('micro',string.format('Rotate %.0f / Tilt %.0f',state.angle*180/math.pi%360,state.pitch*180/math.pi),x+118*scale,y+64*scale)
  y, h = y + 88 * scale, h - 108 * scale
  if w < 1 or h < 1 then return end
  local hot = Kit.hit(x, y, w, h) and not Kit.blockClicks
  local mx, my = Kit.mouseX, Kit.mouseY
  if hot and love.mouse.isDown(1) then
    if state.drag then
      state.angle = state.angle + (mx - state.drag[1]) * 0.01
      state.pitch = math.max(0.15, math.min(1.5, state.pitch + (my - state.drag[2]) * 0.01))
    end
    state.drag = {mx, my}
  else state.drag = nil end
  -- Bound preview work on huge maps; editing and export retain the entire map.
  local cols, rows = math.min(source.cellWidth, 128), math.min(source.cellHeight, 128)
  local now = love.timer.getTime()
  if state.source ~= source or not state.atlas or now - (state.updated or 0) > 0.12 then
    local tw, th = cols * 16, rows * 16 + 4
    if not state.atlas or state.atlas:getWidth() ~= tw or state.atlas:getHeight() ~= th then
      if state.atlas then state.atlas:release() end
      state.atlas = g.newCanvas(tw, th)
      state.atlas:setFilter('nearest', 'nearest')
    end
    local resolve = L.sourceResolver(S)
    g.push('all')
    g.setCanvas(state.atlas); g.origin(); g.setScissor(); g.clear(0.12, 0.17, 0.2, 1)
    for _, layer in ipairs(source.layers or {}) do
      if layer.visible ~= false and layer.export ~= false then
        for cy = 0, rows - 1 do for cx = 0, cols - 1 do
          local ref = (layer.cells or {})[cy * source.cellWidth + cx + 1]
          local desc = ref and resolve(ref.source)
          if desc then L.drawSourceTile(S, desc, ref.tile, cx * 16, cy * 16, 16, layer.opacity or 1, source.id) end
        end end
      end
    end
    g.setColor(1,1,1,1); g.rectangle('fill',0,rows*16,4,4)
    g.pop()
    state.source, state.updated = source, now
  end
  require('MapScene3D').draw(state,source,M,require('MapGeometry3D'),x,y,w,h)
  Kit.text('micro', (cols < source.cellWidth or rows < source.cellHeight)
    and 'Preview: first 128 cells per axis' or 'Drag to orbit / tilt. Use +/- to zoom.', x, y+h+3*scale)
end

return M
