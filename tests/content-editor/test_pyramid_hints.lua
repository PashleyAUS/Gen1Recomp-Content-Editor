-- Seven tiles away is still a trainer hint when the near line is 8.
-- Eight tiles away points to the exit. A line of 0 points to the exit
-- even from the same tile. Ruby, Sapphire, and Emerald share the
-- lines. FireRed does not.

package.path = table.concat({
  "tools/content-editor/?.lua",
  "tools/content-editor/panels/?.lua",
  "tools/save-editor/?.lua",
  "runtime/gen1recomp/?.lua",
  "runtime/gen1recomp/?/init.lua",
  package.path,
}, ";")

dofile("tests/love_stub.lua")

local function assertEq(actual, expected, label)
  if actual ~= expected then
    error(label .. ": got " .. tostring(actual) .. " expected " .. tostring(expected))
  end
end

local Pyramid = require("src.core.game3.rse.frontier.pyramid")
local kind, idx = Pyramid.exitHint(7, 0, 8, Pyramid.HINT.REMAINING_TRAINERS)
assertEq(kind, Pyramid.HINT.REMAINING_TRAINERS, "seven tiles stays a trainer hint")
assertEq(idx, 0, "a trainer hint has no direction")
kind, idx = Pyramid.exitHint(8, 0, 8, Pyramid.HINT.REMAINING_TRAINERS)
assertEq(kind, Pyramid.HINT.EXIT_DIRECTION, "eight tiles points to the exit")
assertEq(idx, 2, "eight tiles east is direction 2")
kind, idx = Pyramid.exitHint(0, 0, 0, Pyramid.HINT.REMAINING_TRAINERS)
assertEq(kind, Pyramid.HINT.EXIT_DIRECTION, "a line of 0 points to the exit")
kind, idx = Pyramid.exitHint(15, 0, Pyramid.hintDistance(Pyramid.HINT_MID, 16), Pyramid.HINT.REMAINING_ITEMS)
assertEq(kind, Pyramid.HINT.REMAINING_ITEMS, "fifteen tiles stays an item hint")
Pyramid.HINT_FAR = 0
kind = Pyramid.exitHint(3, 0, Pyramid.hintDistance(Pyramid.HINT_FAR, 24), Pyramid.HINT.REMAINING_TRAINERS)
assertEq(kind, Pyramid.HINT.EXIT_DIRECTION, "a far line of 0 points to the exit")
Pyramid.HINT_FAR = 24

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { hintNear = 0 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("HINT_NEAR = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { hintNear = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("HINT_NEAR", 1, true), "firered")

print("PASS pyramid hints")
