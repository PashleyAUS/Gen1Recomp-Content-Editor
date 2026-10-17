-- A normal award of 3 pays 3. A Brain adds 10, so the same award
-- pays 13 and the Frontier Pass records 13. A bonus of 0 pays 3.
-- The pass stops at 65535. A pass ceiling of 0 records nothing.
-- Ruby, Sapphire, and Emerald share these. FireRed does not.

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
local points, paid, card = Util.scoreBattlePoints(0, 0, 3, false)
assertEq(points, 3, "a normal award pays 3")
assertEq(paid, 3, "the wallet receives 3")
assertEq(card, 3, "the pass records 3")
points, paid, card = Util.scoreBattlePoints(0, 0, 3, true)
assertEq(points, 13, "a Brain adds 10")
assertEq(card, 13, "the pass records the bonus")
D.BRAIN_BONUS = 0
points = Util.scoreBattlePoints(0, 0, 3, true)
assertEq(points, 3, "a bonus of 0 pays the normal award")
D.BRAIN_BONUS = 10
_, _, card = Util.scoreBattlePoints(0, 65530, 10, true)
assertEq(card, 65535, "the pass stops at 65535")
D.CARD_POINT_CAP = 0
_, _, card = Util.scoreBattlePoints(0, 0, 5, true)
assertEq(card, 0, "a pass ceiling of 0 records nothing")
D.CARD_POINT_CAP = 0xFFFF

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { brain = 0, card = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("BRAIN_BONUS = 0", 1, true), version)
  assert(main:find("CARD_POINT_CAP = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { brain = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("BRAIN_BONUS", 1, true), "firered")

print("PASS frontier brain")
