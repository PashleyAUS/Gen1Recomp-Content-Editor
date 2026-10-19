-- Remove only edge-connected native background; enclosed artwork stays intact.
local M={}
local cache=setmetatable({},{__mode='k'})
function M.runs(pixels,o)
  local signature=table.concat({o.textureX or o.x,o.textureY or o.y,o.textureW or o.width,o.textureH or o.height,
    tostring(o.cutoutColors),tostring(o.cutoutBackgrounds)},':')
  cache[pixels]=cache[pixels] or {}
  if cache[pixels][signature] then return cache[pixels][signature] end
  local pw,ph=pixels:getDimensions()
  local function key(x,y)
    if x<0 or y<0 or x>=pw or y>=ph then return 0,0 end
    local r,g,b,a=pixels:getPixel(x,y)
    return math.floor(r*255+.5)*65536+math.floor(g*255+.5)*256+math.floor(b*255+.5),a
  end
  local palette={}
  for _,color in ipairs(o.cutoutColors or {}) do palette[color]=true end
  for _,r in ipairs(o.cutoutBackgrounds or {}) do
    for y=math.ceil(r[2]*16),math.ceil((r[2]+r[4])*16)-1 do
      for x=math.ceil(r[1]*16),math.ceil((r[1]+r[3])*16)-1 do palette[key(x,y)]=true end
    end
  end
  local w,h=(o.textureW or o.width)*16,(o.textureH or o.height)*16
  local ox,oy=(o.textureX or o.x)*16,(o.textureY or o.y)*16
  local background,removed,queue={},{},{}
  for y=0,h-1 do for x=0,w-1 do
    local k,a=key(ox+x,oy+y)
    background[y*w+x+1]=palette[k] or a==0
  end end
  local function visit(x,y)
    if x<0 or y<0 or x>=w or y>=h then return end
    local i=y*w+x+1
    if background[i] and not removed[i] then removed[i]=true;queue[#queue+1]={x,y} end
  end
  for x=0,w-1 do visit(x,0);visit(x,h-1) end
  for y=0,h-1 do visit(0,y);visit(w-1,y) end
  local n=1
  while queue[n] do
    local p=queue[n];n=n+1
    visit(p[1]-1,p[2]);visit(p[1]+1,p[2]);visit(p[1],p[2]-1);visit(p[1],p[2]+1)
  end
  local runs,bottom={},0
  for y=0,h-1 do
    local x=0
    while x<w do
      if removed[y*w+x+1] then x=x+1 else
        local start=x
        repeat x=x+1 until x==w or removed[y*w+x+1]
        runs[#runs+1]={start,x,y};bottom=y+1
      end
    end
  end
  for _,r in ipairs(runs) do r.bottom=bottom;r.pixelWidth=w;r.pixelHeight=h end
  cache[pixels][signature]=runs
  return runs
end
return M
