package.path='tools/content-editor/?.lua;tools/content-editor/panels/?.lua;runtime/gen1recomp/?.lua;'..package.path
local I,C,O,G,T=require('ModelImport3D'),require('CustomModels3D'),require('MapObjects3D'),require('MapGeometry3D'),require('MapPreview3D')
local root='tests/content-editor/fixtures/models3d/'
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function source()
  local s={cellWidth=12,cellHeight=12,visualAutoObjects=false,layers={{cells={}}},collision={}}
  for i=1,144 do s.collision[i]='walk';s.layers[1].cells[i]={tile=1,source='native'} end
  return s
end
for _,bytes in ipairs({'','a','ab','abc','abcd',string.char(0,255,1,254,2,253)}) do assert(I.decode(I.encode(bytes))==bytes) end
local models={}
for _,ext in ipairs({'obj','gltf','glb'}) do
  local m,err=I.load(root..'pyramid.'..ext);assert(m,err);models[ext]=m
  assert(m.vertexCount==18 and #m.parts==1 and m.parts[1].material.image,'Missing triangulation/material/texture: '..ext)
  assert(not m.parts[1].vertices and m.parts[1].data,'Exports must avoid excessive Lua numeric constants')
  local min,max=math.huge,-math.huge
  for _,v in ipairs(C.partVertices(m.parts[1])) do min=math.min(min,v[2]);max=math.max(max,v[2]) end
  assert(math.abs(min-I.GROUND_LIFT)<1e-9 and math.abs(max-1-I.GROUND_LIFT)<1e-9,'Static scene transforms were not normalized to grounded Y-up geometry')
  assert(I.decode(m.parts[1].material.image)==read(root..'checker.png'),'Embedded texture changed')
  local s=source();local raw=require('ModWriter').encodeLua({s.layers,s.collision})
  assert(O.place(s,{x0=3,y0=4,x1=4,y1=5},'model',2,45,45,.5,m))
  local geometry=G.build(s,T,12,12);local count=0
  for _,v in ipairs(geometry) do if v[10] then
    count=count+1;for i=1,9 do assert(v[i]==v[i] and math.abs(v[i])<1e6) end
  end end
  assert(count==18,'Custom geometry did not reach shared renderer')
  assert(raw==require('ModWriter').encodeLua({s.layers,s.collision}),'Model placement changed native artwork or passage')
  assert(not O.place(s,{x0=3,y0=4,x1=4,y1=5},'model',2,45,45,.5,m),'Identical placement should not dirty project')
  local serialized=require('ModWriter').encodeLua(s)
  local loaded=assert(loadstring('return '..serialized))()
  assert(loaded.visualObjects[1].model.parts[1].material.image==m.parts[1].material.image,'Model texture did not survive serialization')
  assert(#C.vertices(loaded.visualObjects[1],T,loaded)==18,'Export requires original model files')
end
assert(models.gltf.parts[1].data==models.glb.parts[1].data,'glTF and GLB geometry differ')
local function rejects(path,data,pattern)
  local ok,err=pcall(I.parse,path,data,read);assert(not ok and tostring(err):find(pattern,1,true),tostring(err))
end
local json=require('src.link.Json')
local gltf=read(root..'pyramid.gltf')
rejects(root..'broken.gltf',gltf:gsub('pyramid.bin','../pyramid.bin'),'inside the model folder')
rejects(root..'broken.gltf',gltf:gsub('pyramid.bin','https://example.com/pyramid.bin'),'local relative files')
local d=json.decode(gltf);d.extensionsRequired={'KHR_draco_mesh_compression'}
rejects(root..'broken.gltf',json.encode(d),'Unsupported required glTF extension')
d=json.decode(gltf);d.animations={{}}
rejects(root..'broken.gltf',json.encode(d),'Animated models are unsupported')
d=json.decode(gltf);d.skins={{joints={0}}};d.nodes[2].skin=0
assert(I.parse(root..'skinned.gltf',json.encode(d),read).vertexCount==18,'Skinned model was rejected')
local quad=I.parse(root..'quad.obj','v 0 0 0\nv 4 0 0\nv 4 2 3\nv 0 2 3\nf 1 2 3 4',read)
for _,v in ipairs(C.partVertices(quad.parts[1])) do
  assert(math.abs(v[2]-I.GROUND_LIFT)<1e-9 or math.abs(v[2]-1-I.GROUND_LIFT)<1e-9,'Polygon corners shared by fan triangles were normalized twice')
  assert(math.abs(v[3])==.75,'Polygon corners shared by fan triangles were normalized twice')
end
local pit=I.parse(root..'pit.obj','v 0 2 0\nv 10 2 0\nv 10 2 10\nv 0 2 10\nv 4 0 4\nv 5 0 4\nv 4 0 5\nv 5 10 5\nf 1 2 3 4\nf 5 6 7\nf 1 2 8',read)
local floorY,pitY=math.huge,math.huge
for _,v in ipairs(C.partVertices(pit.parts[1])) do
  if v[1]==-.5 and v[3]==.5 then floorY=v[2] end
  if math.abs(v[1]+.1)<1e-9 and math.abs(v[3]-.1)<1e-9 and v[2]<0 then pitY=v[2] end
end
assert(math.abs(floorY-I.GROUND_LIFT)<1e-9 and math.abs(pitY+.2-I.GROUND_LIFT)<1e-9,'Largest flat surface did not become the ground level')
local tri=I.parse(root..'tri.obj','v 0 0 0\nv 1 0 0\nv 0 1 1\nf 1 2 3',read)
for _,v in ipairs(C.partVertices(tri.parts[1])) do if v[2]==1 then assert(v[3]<0,'Source +Z must be stored so the renderer places it south') end end
d=json.decode(gltf);d.nodes[2].children={0}
rejects(root..'broken.gltf',json.encode(d),'Cyclic')
rejects(root..'bad.obj','v 0 0 0\nf 1 2 3','out of range')
rejects(root..'bad.glb','glTF','Truncated')
local s=source();local m,index=C.import(s,root..'pyramid.obj');assert(m and index==1)
local before=#s.visualModelLibrary;assert(not C.import(s,root..'missing.obj'));assert(#s.visualModelLibrary==before,'Failed import mutated model library')
print('PASS: OBJ/MTL, glTF/GLB, native UV textures, transforms, placement, portable exports and invalid dependency/mesh rejection')
