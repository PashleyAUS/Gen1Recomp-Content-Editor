-- Gen 1 critical hits keep the cart shift chain until it is edited.

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

local Damage = require("src.battle.Damage")
local attacker = { def = { baseStats = { speed = 100 } } }
local rules = {}
local function hit(roll, high, focus, bug)
  attacker.focusEnergy = focus
  rules.focusEnergyBug = bug
  return Damage.critRoll(rules, attacker, "TACKLE", function() return roll end, high)
end

assertEq(hit(49, false), true, "cart normal hits")
assertEq(hit(50, false), false, "cart normal misses")
assertEq(hit(254, true), true, "cart high-crit hits")
assertEq(hit(255, true), false, "cart high-crit caps")
assertEq(hit(126, false, true), true, "focus energy")
assertEq(hit(127, false, true), false, "focus energy edge")

Damage.CRIT_NORMAL_DIV = 1
assertEq(hit(99, false), true, "no final halve")
assertEq(hit(100, false), false, "no final halve edge")
Damage.CRIT_NORMAL_DIV = 2
Damage.CRIT_HIGH_SHIFTS = 0
assertEq(hit(99, true), true, "high-crit without extra shifts")
assertEq(hit(100, true), false, "high-crit without extra shifts edge")
Damage.CRIT_HIGH_SHIFTS = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    battleCrit = { speedDiv = 1, highShifts = 0, levelMult = 1 } })
  assert(main:find("Damage.CRIT_SPEED_DIV = battleCrit.speedDiv", 1, true), version)
  assert(main:find("Damage.CRIT_LEVEL_MULT = battleCrit.levelMult", 1, true), version)
  assert(not main:find("CRITICAL_CHANCES", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    battleCrit = { speedDiv = 1, multiplier = 3 } })
  assert(not main:find("CRIT_SPEED_DIV", 1, true), version)
  assert(main:find("Damage.CRIT_MULTIPLIER = battleCrit.multiplier", 1, true), version)
end

require("Rules")
print("PASS gen1 crit")
