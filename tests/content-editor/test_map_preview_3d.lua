package.path = 'tools/content-editor/?.lua;' .. package.path
local M = require('MapPreview3D')
local defaults=M.cameraDefaults({visualCamera={angle=0,pitch=.8,scale=8.5}})
local camera=M.cameraDefaults({visualCamera=defaults})
for _=1,24 do M.cameraKey(camera,']') end
assert(math.abs(math.sin(camera.angle))<1e-8,'Camera rotation failed to wrap')
for _=1,100 do M.cameraKey(camera,'pageup');M.cameraKey(camera,'=') end
assert(camera.pitch==1.5 and camera.scale==40,'Camera exceeded tilt/zoom limits')
for _=1,100 do M.cameraKey(camera,'pagedown');M.cameraKey(camera,'-') end
assert(camera.pitch==.15 and camera.scale==4,'Camera exceeded lower tilt/zoom limits')
assert(not M.cameraKey(camera,'up'),'Camera stole a movement key')
M.cameraKey(camera,'home',defaults)
assert(camera.angle==0 and camera.pitch==.8 and camera.scale==8.5 and defaults.scale==8.5)
assert(M.cameraFit(8.5,.8,.8)==8.5,'Tilt compensation changed the authored view')
local tilted=M.cameraFit(8.5,.15,.8)
assert(math.abs(tilted*math.sin(.15)-8.5*math.sin(.8))<1e-9,'Tilting changed how much of the map is on screen')
local source = {cellWidth=4,cellHeight=4,layers={},collision={},gen3Elevation={9}}
for i=1,16 do source.collision[i]='walk' end
assert(M.height(source,0,0)==0)
for _, v in ipairs({-1,16,0.5,'2'}) do assert(not M.paint(source,0,0,v)) end
assert(not M.paint(source,-1,0,2) and not M.paint(source,4,0,2))
assert(M.paint(source,1,1,6) and not M.paint(source,1,1,6))
assert(source.gen3Elevation[1]==9 and source.collision[6]=='walk')
package.loaded.ModIO = {}
package.loaded.Preview = {}
package.loaded.TilePixels = {}
local L = require('LayeredMap')
assert(L.resize(source,6,6))
assert(M.height(source,1,1)==6 and M.height(source,5,5)==0)
assert(L.resize(source,2,2) and M.height(source,1,1)==6)
assert(M.paint(source,1,1,0) and M.height(source,1,1)==0)
assert(M.paint(source,1,1,0,'north'), 'Shape changes at the same height must be edits')
local corners=M.corners(source,1,1)
assert(corners[1]==.5 and corners[2]==.5 and corners[3]==0 and corners[4]==0)
assert(not M.paint(source,1,1,0,'north') and not M.paint(source,1,1,0,'bad_shape'))
assert(M.paint(source,1,1,0,'flat') and source.visualShapes[4]==nil, 'Flat must remove an existing slope')
for _,shape in ipairs(M.shapes) do
  M.paint(source,1,1,2,shape.id)
  for i,z in ipairs(M.corners(source,1,1)) do assert(z==1+shape.corners[i]*.5) end
  assert(M.surface(source,1,1)==M.corners(source,1,1)[1])
  local mid=M.surface(source,1.5,1.5)
  assert(mid>=1 and mid<=1.5,'Tree root interpolation left the terrain surface')
end
assert(L.resize(source,4,4) and source.visualShapes[6]=='corner_sw', 'Resize lost slope index')
local Objects=require('MapObjects3D')
assert(Objects.place(source,{x0=3,y0=3,x1=2,y1=2},'building',4))
assert(not Objects.place(source,{x0=2,y0=2,x1=3,y1=3},'building',4))
assert(#Objects.objects(source)==1)
assert(Objects.place(source,{x0=2,y0=2,x1=2,y1=2},'none'))
assert(#Objects.objects(source)==0 and #source.visualObjects==1)
assert(Objects.place(source,{x0=3,y0=3,x1=3,y1=3},'tree',3))
assert(source.visualObjects[2].width==1, 'Edge placement must fit the map')
assert(L.resize(source,2,2) and #source.visualObjects==0, 'Shrink retained an out-of-bounds model')
assert(not Objects.place(source,{x0=0,y0=0,x1=1,y1=1},'tree',3,22))
assert(Objects.place(source,{x0=0,y0=0,x1=1,y1=1},'tree',3,0,0))
local unrotated=require('MapGeometry3D').build(source,M,2,2)
assert(Objects.place(source,{x0=0,y0=0,x1=1,y1=1},'tree',3,405,45))
assert(source.visualObjects[1].rotation==45 and source.visualObjects[1].lean==45)
local vertices=require('MapGeometry3D').build(source,M,2,2)
assert(#vertices>0 and #vertices%3==0)
local changed=false
for i,v in ipairs(vertices) do
  local before=unrotated[i]
  if before and (math.abs(v[1]-before[1])>.001 or math.abs(v[2]-before[2])>.001 or math.abs(v[3]-before[3])>.001) then changed=true end
end
assert(changed,'45-degree rotation/lean did not transform model geometry')
for _,v in ipairs(vertices) do
  assert(#v==9)
  for _,n in ipairs(v) do assert(n==n and math.abs(n)<math.huge) end
  assert(v[4]>=0 and v[4]<=1 and v[5]>=0 and v[5]<=1)
end
local x,y,d = M.project(2,3,4,0,math.pi/2)
assert(math.abs(x-2)<1e-8 and math.abs(y-3)<1e-8 and d==3)
print('PASS: height/slope validation, all corner orientations, same-height edits, model placement/removal, resize preservation, finite geometry and projection')
