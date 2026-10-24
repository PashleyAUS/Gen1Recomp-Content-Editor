-- Selection geometry only: moving a marquee never changes map cells.
local M = {}
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
function M.bounds(r)
  return math.min(r.x0,r.x1),math.min(r.y0,r.y1),math.max(r.x0,r.x1),math.max(r.y0,r.y1)
end

-- Coordinates are fractional cells; the right/bottom edges lie one cell
-- beyond the inclusive selection bounds. Keep the center usable at low zoom.
function M.hit(rects, x, y, tolerance)
  for i=#rects,1,-1 do
    local x0,y0,x1,y1=M.bounds(rects[i]);x1,y1=x1+1,y1+1
    local tx=math.min(tolerance,(x1-x0)*0.3)
    local ty=math.min(tolerance,(y1-y0)*0.3)
    if x>=x0-tx and x<=x1+tx and y>=y0-ty and y<=y1+ty then
      local horizontal=math.abs(x-x0)<=tx and "w" or math.abs(x-x1)<=tx and "e" or ""
      local vertical=math.abs(y-y0)<=ty and "n" or math.abs(y-y1)<=ty and "s" or ""
      return i, vertical..horizontal~="" and vertical..horizontal or "move"
    end
  end
end

function M.adjust(rect, handle, dx, dy, width, height)
  local x0,y0,x1,y1=M.bounds(rect)
  if handle=="move" then
    dx=clamp(dx,-x0,width-1-x1);dy=clamp(dy,-y0,height-1-y1)
    return {x0=x0+dx,y0=y0+dy,x1=x1+dx,y1=y1+dy}
  end
  if handle:find("w",1,true) then x0=clamp(x0+dx,0,x1) end
  if handle:find("e",1,true) then x1=clamp(x1+dx,x0,width-1) end
  if handle:find("n",1,true) then y0=clamp(y0+dy,0,y1) end
  if handle:find("s",1,true) then y1=clamp(y1+dy,y0,height-1) end
  return {x0=x0,y0=y0,x1=x1,y1=y1}
end
return M
