package.path='tools/content-editor/?.lua;'..package.path
local E,I,G,T=require('Environment3D'),require('Interior3D'),require('MapGeometry3D'),require('MapPreview3D')
local function room(pair,id)
  local s={id=id,baseTileset=pair,cellWidth=10,cellHeight=10,layers={{cells={}}},collision={},gen3Elevation={},gen3Behavior={}}
  for i=1,100 do
    s.layers[1].cells[i]={source='@runtime:'..pair,tile=534};s.collision[i]='walk'
    s.gen3Elevation[i]=3;s.gen3Behavior[i]=0
  end
  return s
end
local s=room('general__cave','EM_GRANITE_CAVE_1F')
for i=1,10 do s.collision[i]='solid' end
s.visualHeights={[1]=5};s.visualShapes={[1]='north'}
local warps={{x=5,y=0,destMap='outside',destWarp=1}}
I.apply(s,{warps=warps})
assert(s.visualEnvironment=='cave' and s.visualHeights[2]==2 and s.visualHeights[1]==5)
assert(s.visualHeights[5]==nil and s.visualHeights[6]==nil and s.visualHeights[7]==nil,'Relief blocked an exit approach')
s.visualHeights[2]=4;s.visualShapes[3]='east'
I.apply(s,{warps=warps})
assert(s.visualHeights[2]==4 and s.visualHeights[3]==2 and s.visualShapes[3]=='east','Rebuild lost manual terrain')
assert(E.kind(room('general__rom_082d4bdc','FR_MT_MOON_1F'))=='cave','Opaque FR/LG cave tileset not recognized')
assert(not E.kind(room('general__petalburg','EM_LITTLEROOT_TOWN')),'Outdoor town was classified as cave')
local u=room('general__underwater','EM_UNDERWATER_ROUTE124')
u.layers[1].cells[34].tile=641;u.collision[34]='water';u.collision[35]='solid'
local beforeTile=u.layers[1].cells[34].tile
I.apply(u,{warps={}})
assert(u.visualEnvironment=='underwater' and u.visualHeights[35]==2 and u.visualHeights[34]==nil)
assert(#u.visualObjects==1 and u.visualObjects[1].lean==45 and u.visualObjects[1].environmentGenerated)
local firstCount=#u.visualObjects
I.apply(u,{warps={}});assert(#u.visualObjects==firstCount,'Rebuild duplicated underwater plants')
assert(u.layers[1].cells[34].tile==beforeTile and u.collision[34]=='water' and u.gen3Elevation[34]==3
  and u.gen3Behavior[34]==0,'Underwater build changed native movement or Dive data')
for _,source in ipairs({s,u}) do
  for _,v in ipairs(G.build(source,T,10,10)) do
    for _,n in ipairs(v) do assert(n==n and math.abs(n)<math.huge) end
    assert(v[4]>=0 and v[4]<=1 and v[5]>=0 and v[5]<=1)
  end
end
print('PASS: cave/reef relief, protected exits, manual terrain, native underwater plants, unchanged passage data and FR/LG cave detection')
