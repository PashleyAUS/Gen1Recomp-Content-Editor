package.path='tools/content-editor/?.lua;'..package.path
local W=require('MapWorld3D')
local function source(w,h)
  local s={cellWidth=w,cellHeight=h,collision={},layers={{cells={}}}}
  for i=1,w*h do s.collision[i]='walk';s.layers[1].cells[i]={tile=i,source='@runtime:test'} end
  return s
end
local maps={town=source(20,20),north=source(10,30),west=source(12,15)}
local links={town={{dir='north',map='north',offset=6},{dir='west',map='west',offset=-3}},
 north={{dir='south',map='town',offset=-6}},west={{dir='east',map='town',offset=3}}}
local placed,ids=W.place(maps,'town',function(id) return links[id] end)
assert(placed.north.x==6 and placed.north.y==-30)
assert(placed.west.x==-12 and placed.west.y==-3)
local view,owners,left,top=W.build(maps,placed,ids,{town={},north={},west={}},10,0,80)
local function at(x,y) return owners[(y-top)*80+x-left+1] end
assert(at(10,0).id=='town' and at(10,0).x==10 and at(10,0).y==0)
assert(at(10,-1).id=='north' and at(10,-1).x==4 and at(10,-1).y==29)
assert(at(-1,0).id=='west' and at(-1,0).x==11 and at(-1,0).y==3)
local _,_,nextLeft,nextTop=W.build(maps,placed,ids,{town={},north={},west={}},10,-.1,80)
assert(left==nextLeft and top==nextTop,'Crossing a seam changed the render origin')
for step=-40,40 do
  local _,_,x,y=W.build(maps,placed,ids,{town={},north={},west={}},step+.25,step-.25,80)
  assert(step+.25-x>=36 and step+.25-x<=44 and step-.25-y>=36 and step-.25-y<=44,'Camera approached the render-window edge')
end
local trees={town={{kind='tree',x=0,y=0,width=2,height=2}},
 north={{kind='tree',x=2,y=3,width=2,height=3}},west={}}
local forest,atlas=W.build(maps,placed,ids,trees,10,0,80)
assert(atlas[1].id=='north' and atlas[1].x==2 and atlas[1].y==3,'Forest sampled a crownless border fragment')
assert(atlas[161].y==5,'Complete tree texture omitted its third row')
assert(forest.visualTreeKeyRect.width==2 and forest.visualTreeKeyRect.height==3,
  'Tree transparency must sample the complete sprite background palette')
local checked=false
for _,o in ipairs(forest.visualObjects) do
  if o.kind=='tree' then
    assert(o.textureH==3 and o.textureW==2,'Tree did not use complete canopy texture')
    if not o.virtual and o.height==2 then checked=true end
  end
end
assert(checked,'Replacing the canopy changed the original tree footprint')
local native=source(2,3);native.baseTileset='pallet_outdoor'
for i,tile in ipairs({14,15,30,31,20,21}) do
  native.layers[1].cells[i]={tile=tile,source='@runtime:pallet_outdoor'}
end
local detected=require('MapObjects3D').detect(native)
assert(#detected==1 and detected[1].height==3,'FireRed/LeafGreen crown row was not detected')
print('PASS: connected world offsets, reciprocal links, boundary owners, stable camera and complete tree crowns')
