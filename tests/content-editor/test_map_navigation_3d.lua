package.path='tools/content-editor/?.lua;'..package.path
local N=require('MapNavigation3D')
local source={cellWidth=14,cellHeight=14,collision={}}
for i=1,196 do source.collision[i]='walk' end
local warp={x=6,y=8,destMap='INTERIOR',destWarp=1}
for angle=45,315,45 do
  local o={kind='building',x=4,y=4,width=5,height=5,rotation=angle}
  local nav=N.prepare(source,{warp},{o})
  assert(#nav.errors==0,angle..': '..table.concat(nav.errors,','))
  local e=assert(nav.byWarp[1])
  assert(e.oldX==warp.x and e.oldY==warp.y)
  local d=assert(({up={0,-1},down={0,1},left={-1,0},right={1,0}})[e.outward])
  assert(not N.blocked(nav,e.x,e.y,e.x+d[1],e.y+d[2]),'Outward step crosses a wall')
  assert(source.collision[(e.y+d[2])*14+e.x+d[1]+1]=='walk','Outward step has no safe ground')
  assert(not N.contains(o,e.x+.5,e.y+.5,.16),'Entrance overlaps a rotated wall')
  assert(nav.cells[e.y*14+e.x+1]==0)
  assert(N.blocked(nav,6,6,6,7),'Rotated building is not solid')
  local wx,wy=N.worldPoint(o,6.5,9)
  assert(math.abs(wx-e.doorX)<1e-8 and math.abs(wy-e.doorY)<1e-8)
  local lx,ly=N.localPoint(o,wx,wy)
  assert(math.abs(lx-6.5)<1e-8 and math.abs(ly-9)<1e-8)
end
assert(warp.x==6 and warp.y==8,'Navigation changed authoring warp data')
local o={kind='building',x=3,y=3,width=4,height=4,rotation=45}
assert(not N.contains(o,4,2.4) and not N.contains(o,6,2.4))
assert(N.crosses(o,4,2.4,6,2.4),'Movement tunneled across a diagonal corner')
local blocked={cellWidth=14,cellHeight=14,collision={}}
for i=1,196 do blocked.collision[i]='water' end
-- All possible front approaches are water, not safe landing tiles.
local nav=N.prepare(blocked,{{x=4,y=6}},{{kind='building',x=3,y=3,width=4,height=4,rotation=180}})
assert(#nav.errors==1,'An inaccessible rotated entrance was accepted')
assert(#N.prepare(source,{warp},{{kind='building',x=4,y=4,width=5,height=5,rotation=0}}).models==0)
print('PASS: rotated wall collision, swept corners, seven entrance angles, stable warp indices and inaccessible-door validation')
