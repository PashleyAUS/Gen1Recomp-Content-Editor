-- Border > Around the map (Gen3Void.lua): extrude, hand-painted tiles past
-- a map's edge, margins, mod default. Plain LuaJIT, no LOVE. Run from the
-- repository root:
--   luajit tests/content-editor/test_gen3_void.lua
package.path = "tools/content-editor/?.lua;" .. package.path
local Void = require("Gen3Void")

local pass, fail = 0, 0
local function run(name, fn)
  local ok, err = pcall(fn)
  if ok then pass = pass + 1; print("ok    " .. name)
  else fail = fail + 1; print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end

run("extrude repeats the last 2 rows / columns", function()
  local w = 10
  local want = { [-4] = 0, [-3] = 1, [-2] = 0, [-1] = 1, [0] = 0, [5] = 5, [9] = 9, [10] = 8, [11] = 9, [12] = 8, [13] = 9 }
  for c, e in pairs(want) do assert(Void.edge(c, w) == e, c .. " -> " .. Void.edge(c, w)) end
  assert(Void.edge(-3, 1) == 0 and Void.edge(4, 1) == 0)
end)

run("painting stays outside the map and inside the margin", function()
  local p = {}
  assert(Void.paint(p, "M", 10, 8, -1, 0, 5, "pairA"))
  assert(not Void.paint(p, "M", 10, 8, -1, 0, 5, "pairA"))
  assert(select(2, Void.paint(p, "M", 10, 8, 3, 3, 5, "pairA")) == "inside")
  assert(select(2, Void.paint(p, "M", 10, 8, -17, 0, 5, "pairA")) == "margin")
  assert(Void.paint(p, "M", 10, 8, 17, 15, 7, "pairB"))
  local c = Void.cell(p, "M", 17, 15); assert(c.m == 7 and c.p == "pairB")
  assert(Void.paint(p, "M", 10, 8, -1, 0, nil))
  assert(Void.cell(p, "M", -1, 0) == nil)
end)

run("keys round-trip, negative coordinates included", function()
  for _, xy in ipairs({ { -64, -64 }, { -1, 0 }, { 575, 575 }, { 0, -1 } }) do
    local x, y = Void.unkey(Void.key(xy[1], xy[2]))
    assert(x == xy[1] and y == xy[2])
  end
end)

run("a smaller margin drops tiles past it", function()
  local p = {}
  Void.paint(p, "M", 10, 8, -16, 0, 1, "a"); Void.paint(p, "M", 10, 8, -2, 0, 1, "a")
  local changed, removed = Void.setMargin(p, "M", 10, 8, 4)
  assert(changed and removed == 1 and Void.margin(p, "M") == 4)
  assert(Void.cell(p, "M", -2, 0) and not Void.cell(p, "M", -16, 0))
  assert(not Void.setMargin(p, "M", 10, 8, 65))
end)

run("mod default covers outdoor maps; a map's own choice wins", function()
  local p = {}
  assert(Void.fillFor(p, "M", true) == "border")
  Void.setDefault(p, "extrude")
  assert(Void.fillFor(p, "M", true) == "extrude" and Void.fillFor(p, "M", false) == "border")
  Void.setMapFill(p, "M", "border"); assert(Void.fillFor(p, "M", true) == "border")
  Void.setMapFill(p, "H", "extrude"); assert(Void.fillFor(p, "H", false) == "extrude")
  Void.setMapFill(p, "M", nil); assert(Void.fillFor(p, "M", true) == "extrude")
end)

run("empty records tidy away; used() and compile()", function()
  local p = {}
  assert(not Void.used(p) and Void.compile(p) == nil)
  Void.paint(p, "M", 10, 8, -1, 0, 3, "a")
  assert(Void.used(p))
  local c = Void.compile(p); assert(c.default == "border" and c.maps.M.cells[Void.key(-1, 0)].m == 3)
  Void.paint(p, "M", 10, 8, -1, 0, nil)
  assert(p.gen3VoidMaps == nil and not Void.used(p))
  Void.setDefault(p, "extrude"); assert(Void.used(p)); Void.setDefault(p, "border"); assert(p.gen3VoidDefault == nil)
end)

run("the editor preview matches what the game draws", function()
  local p = {}
  local grid = function(x, y) return y * 100 + x end
  local border = { width = 2, height = 2, pair = "b", cellAt = function(_, x, y) return { mid = 900 + y * 2 + x } end }
  local opts = { width = 10, height = 8, pair = "map", outdoor = true, cell = grid, border = border }
  local mid, pair, kind = Void.preview(p, "M", -1, 3, opts)
  assert(kind == "border" and pair == "b" and mid == 900 + 1 * 2 + 1)
  Void.setDefault(p, "extrude")
  mid, pair, kind = Void.preview(p, "M", -1, 3, opts)
  assert(kind == "extrude" and pair == "map" and mid == grid(1, 3))
  Void.paint(p, "M", 10, 8, -1, 3, 42, "x")
  mid, pair, kind = Void.preview(p, "M", -1, 3, opts)
  assert(kind == "painted" and mid == 42 and pair == "x")
end)

run("space outside every map belongs to one map, split in straight lines", function()
  local rects = { { id = "A", ox = 0, oy = 0, w = 10, h = 10 }, { id = "B", ox = -5, oy = -20, w = 30, h = 20 } }
  assert(Void.owner(rects, 3, -1) == 2)      -- inside the northern map
  assert(Void.owner(rects, -1, 5) == 1)      -- beside the open map
  assert(Void.owner(rects, -8, -2) == 2)     -- beside the wide northern map
  assert(Void.owner(rects, 12, 5) == 1)      -- level with A's rows: A's side
  assert(Void.owner(rects, 12, 12) == 2)     -- below B's edge, past A's corner: B
  -- the old diagonal: A's corner vs B's edge now splits on A's bottom row
  for y = 10, 20 do assert(Void.owner(rects, 11, y) == 2) end
  for y = 0, 9 do assert(Void.owner(rects, 30, y) == 1) end
  -- corners past every map: the smaller vertical gap, then horizontal
  local two = { { id = "A", ox = 0, oy = 0, w = 4, h = 4 }, { id = "C", ox = 6, oy = 2, w = 4, h = 4 } }
  assert(Void.owner(two, 20, -3) == 1 and Void.owner(two, -9, 8) == 2)
  -- ties go to the smaller map id, whichever map is listed (opened) first
  local l, r = { id = "L", ox = 0, oy = 0, w = 4, h = 4 }, { id = "R", ox = 7, oy = 0, w = 4, h = 4 }
  assert(Void.owner({ l, r }, 5, 2) == 1 and Void.owner({ r, l }, 5, 2) == 2)
end)

run("a painted tile shows from every map, owner's first", function()
  local p = {}
  local rects = { { id = "B", ox = 0, oy = 0, w = 4, h = 4 }, { id = "A", ox = 6, oy = 0, w = 4, h = 4 } }
  local o = Void.owner(rects, 5, 1)           -- 1 from A, 2 from B
  assert(rects[o].id == "A")
  Void.paint(p, "B", 4, 4, 5, 1, 9, "x")     -- saved under B (older project)
  local c, r = Void.paintedAt(p, rects, o, 5, 1)
  assert(c.m == 9 and r.id == "B")
  Void.paint(p, "A", 4, 4, -1, 1, 7, "x")    -- A's own coords: world (5, 1)
  c, r = Void.paintedAt(p, rects, o, 5, 1)
  assert(c.m == 7 and r.id == "A")
end)

run("validate rejects bad data", function()
  assert(not pcall(Void.validate, { gen3VoidDefault = "fog" }))
  assert(not pcall(Void.validate, { gen3VoidMaps = { M = { margin = 99 } } }))
  assert(not pcall(Void.validate, { gen3VoidMaps = { M = { cells = { [5] = { m = 2000, p = "a" } } } } }))
  assert(pcall(Void.validate, { gen3VoidMaps = { M = { fill = "extrude", cells = { [5] = { m = 2, p = "a" } } } } }))
end)

print(("%d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
