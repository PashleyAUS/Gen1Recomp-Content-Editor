package.path='tools/content-editor/?.lua;'..package.path
local G,T=require('MapGeometry3D'),require('MapPreview3D')
local source={cellWidth=16,cellHeight=12,visualAutoObjects=false,layers={{cells={}}},collision={}}
for i=1,192 do
  source.layers[1].cells[i]={source='@runtime:general__petalburg',tile=i}
  source.collision[i]='walk'
end
local house={kind='building',x=2,y=4,width=5,height=5,size=5,rotation=0,lean=0,
  style='littleroot_native_surfaces'}
source.visualObjects={}
local ground=G.build(source,T,16,12)
source.visualObjects={house}
local vertices=G.build(source,T,16,12)
assert(#vertices>#ground+6,'Sample house is still one tilted card')
local front,roof=false,false
for i=#ground+1,#vertices do
  local v=vertices[i]
  assert(v[6]==1 and v[7]==1 and v[8]==1 and v[9]==1,'House invented colored artwork')
  assert(v[4]>2/16 and v[4]<7/16 and v[5]>64/196 and v[5]<144/196,
    'House sampled art outside its original native rectangle')
  assert(v[3]==0 or math.abs(v[3]-1.625)<1e-8,'Roof is not flat or wall height varies')
  for _,n in ipairs(v) do assert(n==n and math.abs(n)<math.huge) end
  if math.abs(v[2]-8.9)<1e-8 and math.abs(v[3]-1.625)<1e-8 then front=true end
  if math.abs(v[2]-4.1)<1e-8 and math.abs(v[3]-1.625)<1e-8 then roof=true end
end
assert(front and roof,'Upright front and flat roof are missing')
-- All side/rear wall triangles reuse exactly the same complete native tile.
for i=#ground+7,#vertices-6 do
  local v=vertices[i]
  assert(v[4]>=64.5/256 and v[4]<=79.5/256 and v[5]>=128.5/196 and v[5]<=143.5/196,
    'Side wall did not repeat the selected single front-wall tile')
end
assert(house.x==2 and house.y==4 and house.rotation==0,'Rendering moved the original entrance footprint')
for i=1,192 do
  assert(source.collision[i]=='walk' and source.layers[1].cells[i].tile==i,
    'Sample changed original collision or 2D map artwork')
end
house.style='native_house'
assert(#G.build(source,T,16,12)==#ground+6,'Unselected buildings changed appearance')
print('PASS: opt-in house separates native roof and facade; original UVs, collision and other buildings preserved')
local lab={kind='building',x=2,y=4,width=7,height=5,size=5,rotation=0,lean=0,
  style='littleroot_lab_native_surfaces'}
source.visualObjects={lab}
local labVertices=G.build(source,T,16,12)
for i=#ground+1,#labVertices do
  local v=labVertices[i]
  assert(v[3]==0 or v[3]==2,'Lab roof is not horizontal at its native facade height')
  assert(v[6]==1 and v[7]==1 and v[8]==1,'Lab invented colored textures')
end
-- Sides reuse one native front-wall tile, not a strip or facade with doors.
for i=#ground+7,#labVertices-6 do
  local v=labVertices[i]
  assert(v[4]>=48.5/256 and v[4]<=63.5/256 and v[5]>=128.5/196 and v[5]<=143.5/196,
    'Lab sides did not repeat the selected complete front-wall tile')
end
for i=#labVertices-5,#labVertices do assert(labVertices[i][3]==2,'Lab roof retained a tilt') end
assert(source.visualObjects[1]==lab and lab.width==7 and lab.height==5,'Lab footprint changed')
print('PASS: lab has a flat native roof, upright facade, single-tile sides and unchanged footprint')
-- Opening an existing editor project must use the same surfaces without
-- changing its manual records, and unrelated maps must remain unchanged.
source.id='EM_LITTLEROOT_TOWN';source.baseTileset='general__petalburg'
source.layers[1].cells[4*16+3].tile=520
house.style='native_house';house.lean=45;source.visualObjects={house}
local resolved=require('MapObjects3D').objects(source)
assert(resolved[1].style=='littleroot_native_surfaces' and resolved[1].lean==0,
  'Older editable project retained a tilted house')
assert(house.style=='native_house' and house.lean==45,'Preview mutated the saved manual object')
source.id='custom_map'
assert(require('MapObjects3D').objects(source)[1].style=='native_house','Treatment leaked to another map')
print('PASS: editor compatibility selects the shared surfaces without rewriting manual records')
source.id='EM_LITTLEROOT_TOWN'
local O=require('MapObjects3D')
assert(O.place(source,{x0=2,y0=4,x1=6,y1=8},'building',5,0,45))
local tilted=O.objects(source)[1]
assert(tilted.style=='littleroot_native_surfaces' and tilted.lean==45,
  'Tilting a native building lost its surface style or lean')
local tiltedVertices=G.build(source,T,16,12)
local highest=0
for _,v in ipairs(tiltedVertices) do highest=math.max(highest,v[3]) end
assert(math.abs(highest-1.625*math.cos(math.pi/4))<1e-8,'Native wall surfaces ignored lean')
print('PASS: native building surfaces retain their style and apply the authored lean')
