-- Recover, Morning Sun, Wish, Swallow, Substitute, and Gen 2 time heals
-- stay on the cart fractions until they are edited.

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

local Healing = require("src.core.game3.battle.effects.healing")
assertEq(Healing.portion(100, Healing.RECOVER_DIV, 2), 50, "recover half")
assertEq(Healing.weatherHeal(30, "SUN"), 20, "sun two thirds")
assertEq(Healing.weatherHeal(100, nil), 50, "clear half")
assertEq(Healing.weatherHeal(100, "RAIN"), 25, "bad weather quarter")
assertEq(Healing.swallowAmount(100, 1), 25, "swallow one")
assertEq(Healing.swallowAmount(100, 2), 50, "swallow two")
assertEq(Healing.swallowAmount(100, 3), 100, "swallow three")
Healing.RECOVER_DIV = 4
assertEq(Healing.portion(100, Healing.RECOVER_DIV, 2), 25, "recover edited")
Healing.RECOVER_DIV = 2
Healing.SWALLOW[1] = 5
assertEq(Healing.swallowAmount(100, 1), 20, "swallow edited")
Healing.SWALLOW[1] = 4

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.healAmount(100), 50, "gen2 recover")
assertEq(Effects.substituteCost(100), 25, "gen2 substitute")
assertEq(Effects.counterDamage(30), 60, "gen2 counter")
assertEq(Effects.timeBasedHealFraction(nil, nil, nil), 0.5, "gen2 normal heal")
Effects.HEAL_MULTIPLIERS[3] = 1 / 4
assertEq(Effects.timeBasedHealFraction(nil, nil, nil), 0.25, "gen2 heal edited")
Effects.HEAL_MULTIPLIERS[3] = 1 / 2
Effects.HEAL_DIV = 4
assertEq(Effects.healAmount(100), 25, "gen2 recover edited")
Effects.HEAL_DIV = 2

local MoveEffects = require("src.battle.MoveEffects")
assertEq(MoveEffects.HEAL_DIV, 2, "gen1 recover")
assertEq(MoveEffects.SUBSTITUTE_DIV, 4, "gen1 substitute")

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, healRules = {
  recoverDiv = 4, substituteDiv = 5,
} })
assert(red:find("MoveEffects.HEAL_DIV = 4", 1, true), "red recover")
assert(red:find("MoveEffects.SUBSTITUTE_DIV = 5", 1, true), "red substitute")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, healRules = {
    recoverDiv = 4,
    counterMult = 3,
    bands = { { num = 1, den = 8 }, { num = 1, den = 4 }, { num = 1, den = 2 }, { num = 2, den = 3 } },
  } })
  assert(main:find("Effects.HEAL_DIV = 4", 1, true), version .. " recover")
  assert(main:find("Effects.COUNTER_MULT = 3", 1, true), version .. " counter")
  assert(main:find("Effects.HEAL_MULTIPLIERS = { 1/8, 1/4, 1/2, 2/3 }", 1, true), version .. " fractions")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Heal = { recoverDiv = 4, swallow1 = 8, sunNum = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitHeal(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Healing.RECOVER_DIV = 4", 1, true), version)
  assert(chunk:find("Healing.SWALLOW = { 8, 2, 1 }", 1, true), version)
  assert(chunk:find("Healing.SUN_NUM = 1", 1, true), version)
end

require("Rules")
print("PASS heal")
