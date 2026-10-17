-- Helping Hand is 150 percent and Charge doubles until those numbers are edited.

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
assertEq(Damage.helpingHand(10), 15, "helping hand cart")
assertEq(Damage.charge(10), 20, "charge cart")
Damage.HELPING_HAND_PERCENT = 200
Damage.CHARGE_MULT = 1
assertEq(Damage.helpingHand(10), 20, "helping hand double")
assertEq(Damage.charge(10), 10, "charge off")
Damage.HELPING_HAND_PERCENT = 150
Damage.CHARGE_MULT = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { helpingHand = 200, chargeMult = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ helpingHand = 200, chargeMult = 1 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.HELPING_HAND_PERCENT = battleRules.helpingHand", 1, true), version)
  assert(chunk:find("Damage.CHARGE_MULT = battleRules.chargeMult", 1, true), version)
end

print("PASS helping hand")
