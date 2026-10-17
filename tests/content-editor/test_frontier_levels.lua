-- Ten Battle Points stay at 10. A ceiling of 5 stops 4 plus 3 at 5,
-- and a ceiling of 0 pays nothing. Level 50 mode is level 50. Open
-- mode raises a level 40 party to 60, and a floor of 0 leaves 40.
-- A tent party of 10 becomes 30. Ruby, Sapphire, and Emerald share
-- these. FireRed does not.

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

local D = require("src.core.game3.rse.frontier.trainers")
local Util = require("src.core.game3.rse.frontier.util")
local function points(have, add, cap)
  if cap ~= nil then D.MAX_BATTLE_FRONTIER_POINTS = cap end
  local sess = { frontier = { _shaped = true, battlePoints = have } }
  Util.addBattlePoints(sess, add)
  return sess.frontier.battlePoints
end
assertEq(points(0, 10), 10, "ten points stay at 10")
assertEq(points(4, 3, 5), 5, "a ceiling of 5 stops at 5")
assertEq(points(0, 10, 0), 0, "a ceiling of 0 pays nothing")
D.MAX_BATTLE_FRONTIER_POINTS = 9999

assertEq(D.enemyLevel(D.LVL.L50, { { species = 1, level = 40 } }), 50, "level 50 mode is 50")
assertEq(D.enemyLevel(D.LVL.OPEN, { { species = 1, level = 40 } }), 60, "open mode raises 40 to 60")
assertEq(D.enemyLevel(D.LVL.OPEN, { { species = 1, level = 70 } }), 70, "open mode keeps 70")
D.FRONTIER_MIN_LEVEL_OPEN = 0
assertEq(D.enemyLevel(D.LVL.OPEN, { { species = 1, level = 40 } }), 40, "a floor of 0 leaves 40")
D.FRONTIER_MIN_LEVEL_OPEN = 60
D.FRONTIER_MAX_LEVEL_50 = 40
assertEq(D.enemyLevel(D.LVL.L50, {}), 40, "level 50 mode can be 40")
D.FRONTIER_MAX_LEVEL_50 = 50

D.tentPack = function() return { trainers = {}, mons = {} } end
local _, tent = D.facilityPtrs({ frontier = { lvlMode = D.LVL.TENT }, party = { { species = 1, level = 10 } } }, 0)
assertEq(tent, 30, "a tent party of 10 becomes 30")
D.TENT_MIN_LEVEL = 0
_, tent = D.facilityPtrs({ frontier = { lvlMode = D.LVL.TENT }, party = { { species = 1, level = 10 } } }, 0)
assertEq(tent, 10, "a tent floor of 0 leaves 10")
D.TENT_MIN_LEVEL = 30

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { points = 5, openMin = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("MAX_BATTLE_FRONTIER_POINTS = 5", 1, true), version)
  assert(main:find("FRONTIER_MIN_LEVEL_OPEN = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { points = 5 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_BATTLE_FRONTIER_POINTS", 1, true), "firered")

print("PASS frontier levels")
