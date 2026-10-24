package.path="tools/content-editor/?.lua;"..package.path
local M=require("MapSelection")
local r={x0=2,y0=3,x1=6,y1=8}
local function equal(a,b)
  for _,k in ipairs({"x0","y0","x1","y1"}) do assert(a[k]==b[k],k..": "..tostring(a[k])) end
end
for _,p in ipairs({{2,3,"nw"},{7,3,"ne"},{2,9,"sw"},{7,9,"se"},
    {4,3,"n"},{4,9,"s"},{2,6,"w"},{7,6,"e"},{4,6,"move"}}) do
  local i,h=M.hit({r},p[1],p[2],.2);assert(i==1 and h==p[3])
end
assert(not M.hit({r},0,0,.2))
assert(select(2,M.hit({{x0=0,y0=0,x1=0,y1=0}},.5,.5,2))=="move",
  "A single-cell selection must still have a draggable interior at low zoom")
equal(M.adjust(r,"move",3,-2,20,20),{x0=5,y0=1,x1=9,y1=6})
equal(M.adjust(r,"move",100,-100,20,20),{x0=15,y0=0,x1=19,y1=5})
equal(M.adjust(r,"se",4,3,20,20),{x0=2,y0=3,x1=10,y1=11})
equal(M.adjust(r,"nw",-10,-10,20,20),{x0=0,y0=0,x1=6,y1=8})
equal(M.adjust(r,"e",-100,0,20,20),{x0=2,y0=3,x1=2,y1=8})
equal(M.adjust({x0=6,y0=8,x1=2,y1=3},"n",0,2,20,20),{x0=2,y0=5,x1=6,y1=8})
equal(r,{x0=2,y0=3,x1=6,y1=8})
assert(M.hit({r,r},4,6,.2)==2,"Topmost range should receive the gesture")
print("PASS: selection handles, move, resize, map bounds and small/reversed ranges")
