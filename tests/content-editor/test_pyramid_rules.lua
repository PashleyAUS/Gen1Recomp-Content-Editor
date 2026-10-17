-- A streak of 140 is round 0 of 20, and round 6 of 7. Pickup cutoffs
-- of 10 then 30 send roll 0 to column 1 and roll 10 to column 2. One
-- column sends roll 10 back to column 1. A roll width of 1 turns 50
-- into 0. Ruby, Sapphire, and Emerald share this. FireRed does not.

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
local sess = { frontier = { _shaped = true, lvlMode = 0, pyramidWinStreaks = { 140 } } }
assertEq(Pyramid.round(sess), 0, "140 wins is round 0 of 20")
assertEq(Pyramid.hint(140), 0, "the hint repeats every 20 rounds")
Pyramid.TOTAL_ROUNDS = 7
assertEq(Pyramid.round(sess), 6, "seven rounds leave remainder 6")
assertEq(Pyramid.hint(140), 6, "the hint uses the same seven")
Pyramid.TOTAL_ROUNDS = 20
assertEq(Pyramid.pickupIndex({ 10, 30 }, 0), 1, "roll 0 is column 1")
assertEq(Pyramid.pickupIndex({ 10, 30 }, 10), 2, "roll 10 is column 2")
Pyramid.PICKUP_ITEMS_PER_ROUND = 1
assertEq(Pyramid.pickupIndex({ 10, 30 }, 10), 1, "one column stays on column 1")
Pyramid.PICKUP_ITEMS_PER_ROUND = 10
assertEq(Pyramid.pickupRand(50), 50, "50 fits in a roll of 100")
Pyramid.PICKUP_ROLL = 1
assertEq(Pyramid.pickupRand(50), 0, "a roll width of 1 is always 0")
Pyramid.PICKUP_ROLL = 100

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { rounds = 7 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("TOTAL_ROUNDS = 7", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { rounds = 7 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("TOTAL_ROUNDS", 1, true), "firered")

print("PASS pyramid rules")
