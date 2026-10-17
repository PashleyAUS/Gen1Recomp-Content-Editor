-- A species ratio of 127 is female when the roll is 0 and male when
-- the roll is 127. A roll width of 1 turns 127 into 0, so that
-- Pokémon is female. Every Gen 3 game emits the width. Gold does not.

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
Pokemon.speciesMeta = function() return { genderRatio = 127 } end
assertEq(Pokemon.gender(1, 0), "F", "roll 0 is female")
assertEq(Pokemon.gender(1, 127), "M", "roll 127 is male")
Pokemon.GENDER_ROLL = 1
assertEq(Pokemon.gender(1, 127), "F", "a roll width of 1 is female")
Pokemon.GENDER_ROLL = 256

local Rules = require("Gen3BattleRules")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, gen3BattleRules = { genderRoll = 1 } }, function()
    return "{ genderRoll = 1 }"
  end, out)
  assert(table.concat(out, "\n"):find("GENDER_ROLL = battleRules.genderRoll", 1, true), version)
end
local Writer = require("ModWriter")
local gold = Writer.emitMain({ version = "gold", generation = 2, gen3BattleRules = { genderRoll = 1 } })
assert(not gold:find("GENDER_ROLL", 1, true), "gold")

print("PASS gender roll")
