-- Placement and rendering share the embedded asset; no original disk path is needed.
local M={}
local decoded=setmetatable({},{__mode='k'})
function M.partVertices(part)
  if part.vertices then return part.vertices end
  if decoded[part] then return decoded[part] end
  local vertices,v={},{}
  for value in (part.data or ''):gmatch('[^,]+') do
    local n=tonumber(value);assert(n and n==n and math.abs(n)<1e12,'Invalid embedded model geometry')
    v[#v+1]=n
    if #v==9 then vertices[#vertices+1]=v;v={} end
    assert(#vertices<=150000,'Embedded model exceeds vertex limit')
  end
  assert(#v==0 and #vertices%3==0,'Incomplete embedded model triangles')
  decoded[part]=vertices;return vertices
end
function M.import(source,path)
  local model,err=require('ModelImport3D').load(path)
  if not model then return nil,err end
  -- Decode images now so corrupt/oversized textures fail before changing the map.
  if love and love.image then
    for _,part in ipairs(model.parts) do if part.material.image then
      local ok,result=pcall(function()
        local bytes=require('ModelImport3D').decode(part.material.image)
        local image=love.image.newImageData(love.filesystem.newFileData(bytes,'model.png'))
        local w,h=image:getDimensions();image:release()
        assert(w<=4096 and h<=4096,'Model textures must be 4096 x 4096 or smaller')
      end)
      if not ok then return nil,'Invalid model texture: '..tostring(result) end
    end end
  end
  source.visualModelLibrary=source.visualModelLibrary or {}
  source.visualModelLibrary[#source.visualModelLibrary+1]=model
  return model,#source.visualModelLibrary
end
function M.vertices(o,terrain,source)
  local model=o.model
  if not (model and model.parts) then return {} end
  local out={};local yaw,lean=math.rad(o.rotation or 0),math.rad(o.lean or 0)
  local cx,cy=o.x+o.width/2,o.y+o.height/2
  local base=terrain.surface(source,cx,cy)+(o.mount or 0);local size=o.size or 3
  for _,part in ipairs(model.parts) do
    local mat=part.material or {};local color=mat.color or {1,1,1,1}
    for _,v in ipairs(M.partVertices(part)) do
      local dx,dz=v[1]*size,v[2]*size
      local dy=-v[3]*size-dz*math.sin(lean)
      out[#out+1]={cx+dx*math.cos(yaw)-dy*math.sin(yaw),cy+dx*math.sin(yaw)+dy*math.cos(yaw),
        base+dz*math.cos(lean),v[4],v[5],v[6]*color[1],v[7]*color[2],v[8]*color[3],v[9]*(color[4] or 1),mat}
    end
  end
  return out
end
return M
