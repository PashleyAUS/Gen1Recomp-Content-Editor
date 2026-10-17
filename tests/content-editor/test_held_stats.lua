-- Species held items double a stat, and Thick Fat and the sports halve, until edited.

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

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.heldStat(40), 80, "held cart")
assertEq(Damage.divideStat(80, Damage.THICK_FAT_DIV, 2), 40, "thick fat cart")
assertEq(Damage.percentOf(100, Damage.COMPOUND_EYES_PERCENT, 130), 130, "compound eyes")
assertEq(Damage.percentOf(100, Damage.HUSTLE_ACC_PERCENT, 80), 80, "hustle accuracy")
Damage.HELD_STAT_MULT = 1
assertEq(Damage.heldStat(40), 40, "held off")
Damage.THICK_FAT_DIV = 1
assertEq(Damage.divideStat(80, Damage.THICK_FAT_DIV, 2), 80, "thick fat off")
Damage.COMPOUND_EYES_PERCENT = 100
assertEq(Damage.percentOf(100, Damage.COMPOUND_EYES_PERCENT, 130), 100, "compound eyes off")
Damage.HELD_STAT_MULT = 2
Damage.THICK_FAT_DIV = 2
Damage.COMPOUND_EYES_PERCENT = 130

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = {
    heldStatMult = 3, thickFatDiv = 1, sportDiv = 4,
    compoundEyes = 100, sandVeil = 50, hustleAccuracy = 70,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ heldStatMult = 3, thickFatDiv = 1, sportDiv = 4, compoundEyes = 100, sandVeil = 50, hustleAccuracy = 70 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.HELD_STAT_MULT = battleRules.heldStatMult", 1, true), version)
  assert(chunk:find("Damage.SPORT_DIV = battleRules.sportDiv", 1, true), version)
  assert(chunk:find("Damage.HUSTLE_ACC_PERCENT = battleRules.hustleAccuracy", 1, true), version)
end

print("PASS held stats")
