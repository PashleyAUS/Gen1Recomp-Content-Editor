package.path='tools/content-editor/?.lua;'..package.path
local C=require('NativeArtworkCutout')
local pixels={getPixel=function(_,x,y)
  -- White background and an outlined object containing the same white color.
  if x>=4 and x<=11 and y>=4 and y<=11 and (x==4 or x==11 or y==4 or y==11) then return 0,0,0,1 end
  return 1,1,1,1
end}
local runs=C.runs(pixels,{x=0,y=0,width=1,height=1,cutoutBackgrounds={{0,0,.25,.25}}})
local count=0
for _,r in ipairs(runs) do
  assert(r[1]==4 and r[2]==12 and r[3]>=4 and r[3]<=11)
  assert(r.bottom==12,'Cutout must anchor its visible bottom to the floor')
  count=count+r[2]-r[1]
end
assert(count==64,'Flood fill removed enclosed native artwork or retained outer background')
print('PASS: native cutout silhouette, enclosed background colors and ground anchor')
