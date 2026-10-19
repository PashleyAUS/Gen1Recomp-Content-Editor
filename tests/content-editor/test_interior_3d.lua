package.path='tools/content-editor/?.lua;'..package.path
local I=require('Interior3D')
local s={cellWidth=6,cellHeight=6,layers={{cells={}}},collision={},gen3Collision={},gen3Behavior={}}
for i=1,36 do
  s.layers[1].cells[i]={source='@runtime:room',tile=1};s.collision[i]='walk';s.gen3Collision[i]=0;s.gen3Behavior[i]=0
end
for _,i in ipairs({2,15,17,35,36}) do s.collision[i]='solid';s.gen3Collision[i]=255 end
s.layers[1].cells[36].tile=99
local def={warps={{x=4,y=5,destMap='town',destWarp=1}},objects={{x=2,y=3,script='talk'}}}
local before={}
for i=1,36 do before[i]=s.collision[i] end
I.apply(s,def)
assert(s.visualInterior and s.visualPlayable and not s.visualAutoObjects)
assert(#s.visualObjects==3,'Void or exit tiles became furniture')
for i=1,36 do assert(s.collision[i]==before[i] and s.gen3Behavior[i]==0,'Interior changed native navigation or scripts') end
local verts,objects=require('MapGeometry3D').build(s,require('MapPreview3D'),6,6)
assert(#objects==3 and #verts>0)
for _,v in ipairs(verts) do for _,n in ipairs(v) do assert(n==n and math.abs(n)<math.huge) end end
assert(def.warps[1].destMap=='town' and def.objects[1].script=='talk')
local models=require('MapObjects3D')
assert(models.place(s,{x0=2,y0=3,x1=2,y1=3},'furniture',.5,45))
assert(s.visualObjects[#s.visualObjects].width==1,'Single furniture placement expanded to building size')
local manual=s.visualObjects[#s.visualObjects]
s.visualCamera.angle=.4
I.apply(s,def)
assert(s.visualObjects[#s.visualObjects]==manual and s.visualCamera.angle==.4,
  'Rebuilding a room lost its manual furniture or authored camera')
print('PASS: interior furniture geometry, native collision/scripts/warps preserved, void/exit exclusions and manual furniture')
local room={id='EM_ABANDONED_SHIP_CAPTAINS_OFFICE',baseTileset='general__facility',
  cellWidth=10,cellHeight=8,layers={{cells={}}},collision={}}
for i=1,80 do room.layers[1].cells[i]={source='@runtime:general__facility',tile=514};room.collision[i]='walk' end
room.layers[1].cells[1].tile=760;room.layers[1].cells[80].tile=513
local officeDef={warps={{x=7,y=6,destMap='corridor',destWarp=1}}}
I.apply(room,officeDef)
assert(#room.visualObjects==5,'Office fixtures were split into individual tiles')
assert(room.visualObjects[1].style=='native_room_wall' and room.visualObjects[1].width==9)
for i=2,5 do
  local o=room.visualObjects[i]
  assert(o.style=='native_fixture' and o.surfaceTopRows>0 and o.surfaceTopRows<o.height)
  assert(not (7>=o.x and 7<o.x+o.width and 6>=o.y and 6<o.y+o.height),'Office exit became furniture')
end
local officeVerts=require('MapGeometry3D').build(room,require('MapPreview3D'),10,8)
for _,v in ipairs(officeVerts) do
  for _,n in ipairs(v) do assert(n==n and math.abs(n)<math.huge) end
  assert(v[4]>=0 and v[4]<=1 and v[5]>=0 and v[5]<=1,'Office used pixels outside its native atlas')
end
assert(models.place(room,{x0=3,y0=5,x1=4,y1=6},'furniture',.65,45,45))
local desk=room.visualObjects[#room.visualObjects]
assert(desk.style=='native_fixture' and desk.surfaceTopRows==1.4 and desk.lean==45,
  'Editing the desk lost its original top/front artwork boundary')
I.apply(room,officeDef)
assert(room.visualObjects[#room.visualObjects]==desk,'Rebuild discarded the manually adjusted desk')
for i=1,80 do assert(room.collision[i]=='walk','Office furniture changed native collision') end
print('PASS: complete native office fixtures, upright wall, clear exit, finite textures and editable/rebuildable desk')
local pc={id='EM_OLDALE_TOWN_POKEMON_CENTER_1F',baseTileset='building__pokemon_center',
  cellWidth=14,cellHeight=10,layers={{cells={}}},collision={}}
for i=1,140 do pc.layers[1].cells[i]={source='@runtime:building__pokemon_center',tile=514};pc.collision[i]='walk' end
pc.layers[1].cells[1].tile=520;pc.layers[1].cells[140].tile=513
pc.layers[1].cells[3*14+5].tile=600;pc.layers[1].cells[4*14+5].tile=608
for x=4,9 do pc.collision[3*14+x+1]='solid' end
I.apply(pc,{warps={{x=6,y=8}}})
local counter
for _,o in ipairs(pc.visualObjects) do if o.x==4 and o.y==3 then counter=o end end
assert(counter and counter.style=='native_fixture' and counter.width==6 and counter.surfaceDepth==1,
  'Complete reception counter extends into native walkable floor')
assert(counter.surfaceTopRows==.45 and counter.surfaceFrontRect[4]==1,
  'Reception used the purple front or floor shadow as its horizontal top')
local machine,pcTerminal
for _,o in ipairs(pc.visualObjects) do
  if o.x==5 and o.y==1 then machine=o end
  if o.x==10 and o.y==0 then pcTerminal=o end
end
assert(machine and machine.style=='native_cutout' and machine.width==2 and machine.size==2,
  'Healing equipment must preserve complete upright native artwork')
assert(pcTerminal and pcTerminal.style=='native_cutout' and pcTerminal.size==3 and pcTerminal.cutoutBackgrounds,
  'PC must use a background-masked native artwork cutout')
assert(pc.collision[4*14+8]=='walk','Reception counter changed native player passage')
pc.id='EM_PETALBURG_CITY_POKEMON_CENTER_1F';I.apply(pc,{warps={{x=6,y=8}}})
local previousLayout=false
for _,o in ipairs(pc.visualObjects) do if o.style=='healing_station' then previousLayout=true end end
assert(previousLayout,'Oldale review changes were applied to another Center')
print('PASS: Pokemon Center reception uses a complete native counter with clear walkable frontage')
