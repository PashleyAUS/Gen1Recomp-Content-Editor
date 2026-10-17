-- A species with two abilities takes the second one when the roll
-- leaves a remainder of 1. A width of 2 is the cart: personality 1 is
-- the second ability and personality 0 is the first. A width of 1 never
-- leaves a remainder of 1. Every Gen 3 game emits the width. Gold does not.

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

local Pokemon = require("src.core.game3.pokemon")
Pokemon.abilities = function() return { 11, 22 } end
assertEq(Pokemon.abilityId(1, 0), 11, "even personality is the first ability")
assertEq(Pokemon.abilityId(1, 1), 22, "odd personality is the second ability")
Pokemon.ABILITY_SLOT = 1
assertEq(Pokemon.abilityId(1, 1), 11, "a roll width of 1 is always the first")
Pokemon.ABILITY_SLOT = 4
assertEq(Pokemon.abilityId(1, 1), 22, "remainder 1 is still the second")
assertEq(Pokemon.abilityId(1, 3), 11, "remainder 3 is the first")
Pokemon.ABILITY_SLOT = 2

local Rules = require("Gen3BattleRules")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, gen3BattleRules = { abilitySlot = 1 } }, function()
    return "{ abilitySlot = 1 }"
  end, out)
  assert(table.concat(out, "\n"):find("ABILITY_SLOT = battleRules.abilitySlot", 1, true), version)
end
local Writer = require("ModWriter")
local gold = Writer.emitMain({ version = "gold", generation = 2, gen3BattleRules = { abilitySlot = 1 } })
assert(not gold:find("ABILITY_SLOT", 1, true), "gold")

print("PASS ability slot")
