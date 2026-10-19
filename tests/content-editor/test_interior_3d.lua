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
