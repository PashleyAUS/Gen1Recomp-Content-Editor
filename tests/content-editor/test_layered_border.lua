package.path = "tools/content-editor/?.lua;" .. package.path
-- Border pattern selection is independent of graphics and project IO.
for _, name in ipairs({ "ModIO", "Preview", "TilePixels" }) do
  package.loaded[name] = {}
end
local LM = require("LayeredMap")
local map = {}
LM.setExplicitBorder(map, "trees", 21, 23)
assert(LM.borderDirection(map) == "vertical")
for y = -3, 3 do
  for x = -3, 3 do
    assert(LM.borderCellTile(map, x, y) == (y % 2 == 0 and 21 or 23))
  end
end
LM.setExplicitBorder(map, "trees", 21, 23, "horizontal")
for y = -3, 3 do
  for x = -3, 3 do
    assert(LM.borderCellTile(map, x, y) == (x % 2 == 0 and 21 or 23))
  end
end
LM.setExplicitBorder(map, "trees", 22, 24)
assert(LM.borderDirection(map) == "horizontal", "Editing IDs must preserve direction")
LM.setBorderFromStamp(map, "trees", {
  { dx = 3, dy = 4, tile = 21 }, { dx = 3, dy = 5, tile = 23 },
})
assert(LM.borderCellTile(map, -1, -1) == 23)
LM.setExplicitBorder(map, "trees", 21, nil)
assert(LM.borderCellTile(map, -1, -1) == 21)
assert(loadfile("tools/content-editor/panels/Maps.lua"))
print("Layered border checks passed")
