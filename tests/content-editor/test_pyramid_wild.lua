-- A row of 20 drops 5 levels, so roll 0 is level 15 and roll 10 is
-- level 25. A drop of 0 keeps 20. A roll of 1 stays on the dropped
-- level. An ordinary IV roll of 32 is 0. A high IV roll of 0 is 15,
-- and a floor of 0 is 0. Ruby, Sapphire, and Emerald share these.
-- FireRed does not.

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
assertEq(Pyramid.wildLevel(20, 0), 15, "roll 0 is 15")
assertEq(Pyramid.wildLevel(20, 10), 25, "roll 10 is 25")
Pyramid.WILD_LEVEL_DROP = 0
assertEq(Pyramid.wildLevel(20, 0), 20, "a drop of 0 keeps 20")
Pyramid.WILD_LEVEL_DROP = 5
Pyramid.WILD_LEVEL_SPAN = 1
assertEq(Pyramid.wildLevel(20, 10), 15, "a roll of 1 stays on the dropped level")
Pyramid.WILD_LEVEL_SPAN = 11
assertEq(Pyramid.wildIv(31), 31, "31 fits in a roll of 32")
assertEq(Pyramid.wildIv(32), 0, "32 wraps to 0")
Pyramid.WILD_IV_SPAN = 1
assertEq(Pyramid.wildIv(15), 0, "a roll of 1 is always 0")
Pyramid.WILD_IV_SPAN = 32
assertEq(Pyramid.wildHighIv(0), 15, "the high floor is 15")
assertEq(Pyramid.wildHighIv(16), 31, "roll 16 is 31")
Pyramid.WILD_HIGH_IV_BASE = 0
assertEq(Pyramid.wildHighIv(0), 0, "a floor of 0 is 0")
Pyramid.WILD_HIGH_IV_BASE = 15

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { levelDrop = 0 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("WILD_LEVEL_DROP = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { levelDrop = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("WILD_LEVEL_DROP", 1, true), "firered")

print("PASS pyramid wild")
