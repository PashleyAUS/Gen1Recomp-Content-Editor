-- Gen 3 ability and item 1.5x boosts stay at 150 until they are edited.

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
assertEq(Damage.abilityBoost(100), 150, "ability cart")
assertEq(Damage.itemBoost(100), 150, "item cart")
assertEq(Damage.inPinch(30, 90), true, "pinch at a third")
assertEq(Damage.inPinch(31, 90), false, "above a third")
Damage.ABILITY_BOOST_NUM = 200
Damage.ABILITY_BOOST_DEN = 100
assertEq(Damage.abilityBoost(100), 200, "ability double")
Damage.ITEM_BOOST_NUM = 100
assertEq(Damage.itemBoost(100), 100, "item off")
Damage.PINCH_HP_DIV = 2
assertEq(Damage.inPinch(45, 90), true, "pinch at half")
assertEq(Damage.inPinch(46, 90), false, "above half")
Damage.ABILITY_BOOST_NUM = 150
Damage.ITEM_BOOST_NUM = 150
Damage.PINCH_HP_DIV = 3

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { abilityBoost = 200, itemBoost = 100, pinchHpDiv = 2 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ abilityBoost = 200, itemBoost = 100, pinchHpDiv = 2 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.ABILITY_BOOST_NUM = battleRules.abilityBoost", 1, true), version)
  assert(chunk:find("Damage.ITEM_BOOST_NUM = battleRules.itemBoost", 1, true), version)
  assert(chunk:find("Damage.PINCH_HP_DIV = battleRules.pinchHpDiv", 1, true), version)
end

print("PASS ability boost")
