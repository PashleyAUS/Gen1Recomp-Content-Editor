package.path='tools/content-editor/?.lua;runtime/gen1recomp/?.lua;'..package.path
local P,O,G,T=require('NativeMapProfiles3D'),require('MapObjects3D'),require('MapGeometry3D'),require('MapPreview3D')
local W=require('ModWriter')
local function source(w,h)
  local s={id='TEST',cellWidth=w,cellHeight=h,baseTileset='interior',layers={{cells={}}},collision={}}
  for i=1,w*h do s.layers[1].cells[i]={source='@runtime:interior',tile=1};s.collision[i]='walk' end
  return s
end
local s=source(12,10)
for y=0,1 do for x=0,11 do s.collision[y*12+x+1]='solid' end end
for y=4,5 do for x=3,4 do s.collision[y*12+x+1]='solid';s.layers[1].cells[y*12+x+1].tile=2 end end
local custom={kind='model',x=8,y=4,width=1,height=1,size=2,model={version=1,parts={}}}
s.visualObjects={custom};s.visualHeights={[8*12+2]=7};s.visualShapes={[8*12+2]='north'}
local original=W.encodeLua({s.layers,s.collision})
P.apply(s,{mapType=8,warps={{x=6,y=8}}},{[1]={colors={0xdddddd}},[2]={colors={0x333333}}})
assert(s.visualNativeProfile.category=='interior' and s.visualNativeProfile.counts.wall==1)
local prop
for _,o in ipairs(s.visualObjects) do if o.x==3 and o.y==4 then prop=o end end
assert(prop and prop.width==2 and prop.height==2 and prop.style=='native_profile_voxel','Connected furniture was fragmented')
assert(s.visualObjects[#s.visualObjects]==custom and s.visualHeights[8*12+2]==7,'Manual work changed')
assert(original==W.encodeLua({s.layers,s.collision}),'Profiles changed native gameplay/art')
local count=#s.visualObjects;P.apply(s,{mapType=8},{[1]={colors={0xdddddd}},[2]={colors={0x333333}}})
assert(#s.visualObjects==count,'Rebuild duplicated generated objects')
assert(O.place(s,{x0=3,y0=4,x1=4,y1=5},'furniture',2,45,0,0,nil,'cutout'))
local corrected=s.visualObjects[#s.visualObjects]
assert(corrected.style=='native_profile_cutout' and not corrected.profileGenerated)
P.apply(s,{mapType=8},{[1]={colors={0xdddddd}},[2]={colors={0x333333}}})
local retained=false;for _,o in ipairs(s.visualObjects) do if o==corrected then retained=true end end
assert(retained,'Rebuild overwrote a manual native-profile correction')
local cave=source(8,8);cave.layers[1].cells[1].tile=0;cave.collision[1]='solid';cave.collision[2]='solid'
P.apply(cave,{mapType=4,warps={}},{[0]={void=true},[1]={colors={1}}})
assert(cave.visualEnvironment=='cave' and cave.visualHeights[1]==nil and cave.visualHeights[2]==2,'Cave relief raised void or lost walls')
local a,b=source(8,8),source(8,8);a.id='A';b.id='B'
P.apply(a,{mapType=3},{});P.apply(b,{mapType=3},{})
local state={data={maps={}},project={layeredMaps={A=a,B=b},maps={A={connections={east={map='B',offset=0}}},B={connections={west={map='A',offset=0}}}}}}
P.connect(state);assert(a.visualWorldAnchor==b.visualWorldAnchor,'Connected maps received different camera anchors')
local originalBuild,originalLove=P.build,love
love={timer={getTime=function() return 0 end}}
local jobState={data={maps={A={},B={}}},project={maps={},layeredMaps={}}}
local began,ended,marked=0,0,0
local app={beginEditBatch=function() began=began+1 end,endEditBatch=function() ended=ended+1 end,markDirty=function() marked=marked+1 end}
P.build=function(_,id) if id=='B' then error('Test missing native asset') end end
P.start(jobState,app);P.update(jobState)
assert(not jobState.nativeProfileJob and jobState.nativeProfileReport.built==1 and #jobState.nativeProfileReport.errors==1)
assert(began==1 and ended==1 and marked>0,'Bulk build did not balance its edit batch or surface failures')
P.start(jobState,app);jobState.nativeProfileJob.cancelled=true;P.update(jobState)
assert(jobState.nativeProfileReport.cancelled and ended==2,'Stopping a bulk build did not finish its edit batch')
P.build,love=originalBuild,originalLove
print('PASS: reusable native profiles, grouped furniture, manual overrides, void relief, rebuilds and connected camera anchors')
