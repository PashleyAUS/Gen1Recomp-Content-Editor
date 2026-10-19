package.path='tools/content-editor/?.lua;'..package.path
local O,G,T=require('MapObjects3D'),require('MapGeometry3D'),require('MapPreview3D')
local function source(pair,w,h,tiles)
  local s={baseTileset=pair,cellWidth=w,cellHeight=h,layers={{cells={}}},collision={},visualAutoObjects=false}
  for i=1,w*h do s.layers[1].cells[i]={source='@runtime:'..pair,tile=(tiles or {})[i] or 1};s.collision[i]='walk' end
  return s
end
local clock=source('building__brendans_mays_house',2,2,{551,1,559,1})
local found=O.detectProps(clock)
assert(#found==1 and found[1].kind=='wall_decor' and found[1].height==2 and found[1].style=='clock')
clock.visualObjects=found
local vertices=G.build(clock,T,2,2)
local highest=0
for _,v in ipairs(vertices) do highest=math.max(highest,v[3]) end
assert(math.abs(highest-found[1].mount-found[1].size)<1e-8 and highest>1.5,'Clock was flattened or not mounted at its authored height')
assert(O.place(clock,{x0=0,y0=0,x1=0,y1=1},'wall_decor',.8,45,0,2))
assert(clock.visualObjects[1].style=='clock' and clock.visualObjects[1].crop[1]==.08,'Editing a clock lost its native shape/crop')
local plants=O.detectProps(source('player_house',2,2,{87,71,95,79}))
assert(#plants==2 and plants[1].kind=='potted_plant' and plants[1].height==2,'Plant crowns and pots were split into tile boxes')
local fence=O.detectProps(source('pallet_outdoor',6,1,{644,647,1,644,2,3}))
assert(#fence==4 and fence[1].kind=='fence' and fence[1].width==2 and fence[2].width==1,
  'Fence detection bridged a gap or failed to join adjacent rails')
assert(fence[3].kind=='sign' and fence[4].kind=='sign')
assert(#O.detectProps(source('unrelated',2,2,{551,87,559,95}))==0,'Prop signatures guessed artwork from an unrelated tileset')
local s=source('test',8,8)
for i,kind in ipairs({'wall_decor','potted_plant','sign','fence'}) do
  assert(O.place(s,{x0=i-1,y0=2,x1=i-1,y1=3},kind,nil,45,0))
end
local v,objects=G.build(s,T,8,8)
assert(#objects==4)
for _,vertex in ipairs(v) do
  for _,n in ipairs(vertex) do assert(n==n and math.abs(n)<math.huge,'Prop produced invalid geometry') end
  assert(vertex[4]>=0 and vertex[4]<=1 and vertex[5]>=0 and vertex[5]<=1,'Prop texture escaped its atlas')
end
for i=1,64 do assert(s.collision[i]=='walk' and s.layers[1].cells[i].tile==1,'Visual props modified native collision or 2D art') end
assert(O.place(s,{x0=0,y0=2,x1=0,y1=3},'wall_decor',.8,45,0,2))
assert(s.visualObjects[#s.visualObjects].mount==2,'Changing wall mounting height was ignored')
print('PASS: mounted clocks, complete plants, signs, fence gaps, rotated finite geometry and unchanged 2D/collision data')

-- Every object must be exactly one complete native-art card. A flat control
-- retains identical terrain, allowing this to reject synthesized side faces,
-- colored roof polygons, pots and shadows without mirroring vertex positions.
local kinds={'tree','building','furniture','wall_decor','potted_plant','sign','fence'}
for _,kind in ipairs(kinds) do
  local card=source('test',4,4)
  card.visualObjects={{kind=kind,x=1,y=1,width=2,height=2,size=2,rotation=45,lean=0}}
  local art=G.build(card,T,4,4)
  card.visualObjects={}
  local floor=G.build(card,T,4,4)
  assert(#art==#floor+6,kind..' synthesized geometry instead of one native artwork card')
  local minU,minV,maxU,maxV=1,1,0,0
  for i=#floor+1,#art do
    local vertex=art[i]
    assert(vertex[6]==1 and vertex[7]==1 and vertex[8]==1,kind..' invented colored artwork')
    minU=math.min(minU,vertex[4]);maxU=math.max(maxU,vertex[4])
    minV=math.min(minV,vertex[5]);maxV=math.max(maxV,vertex[5])
  end
  assert(math.abs(minU-16.5/64)<1e-8 and math.abs(maxU-47.5/64)<1e-8)
  assert(math.abs(minV-16.5/68)<1e-8 and math.abs(maxV-47.5/68)<1e-8,
    kind..' cropped or replaced the original artwork')
end
print('PASS: every object uses one complete original-art card without invented colored faces')
for _,kind in ipairs(kinds) do
  local s=source('test',8,8)
  assert(O.place(s,{x0=2,y0=2,x1=3,y1=3},kind,2,45,0))
  local upright=G.build(s,T,8,8)
  assert(O.place(s,{x0=2,y0=2,x1=3,y1=3},kind,2,45,45))
  assert(s.visualObjects[1].lean==45,kind..' discarded its lean setting')
  local tilted=G.build(s,T,8,8)
  local changed=false
  for i,v in ipairs(tilted) do
    if math.abs(v[2]-upright[i][2])>.001 or math.abs(v[3]-upright[i][3])>.001 then changed=true end
  end
  assert(changed,kind..' did not lean in the shared geometry')
end
print('PASS: all seven object kinds accept and render a 45-degree lean with rotation')
