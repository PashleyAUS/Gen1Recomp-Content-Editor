-- PP Up keeps each generation's bonus until the divisor or cap is edited.

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

local ItemEffects = require("src.inventory.ItemEffects")
assertEq(ItemEffects.ppBonus(40), 8, "gen1 bonus")
assertEq(ItemEffects.maxPp(40, 3), 64, "gen1 max")
ItemEffects.PP_DIV = 4
assertEq(ItemEffects.maxPp(40, 3), 70, "gen1 divisor")
ItemEffects.PP_DIV = 5
ItemEffects.PP_MAX_UPS = 1
assertEq(ItemEffects.maxPp(40, 3), 48, "gen1 ups")
ItemEffects.PP_MAX_UPS = 3

local Mon = require("src.battle.gen2.Mon")
local data = { moves = { TACKLE = { pp = 40 } } }
assertEq(Mon.ppBonus(40), 7, "gen2 cap")
assertEq(Mon.maxPpOf({ id = "TACKLE", ppUps = 3 }, data), 61, "gen2 max")
Mon.PP_BONUS_CAP = 4
assertEq(Mon.maxPpOf({ id = "TACKLE", ppUps = 3 }, data), 52, "gen2 edited cap")
Mon.PP_BONUS_CAP = 7
Mon.PP_MAX_UPS = 1
assertEq(Mon.ppUpsOf({ id = "TACKLE", ppUps = 3 }, data), 1, "gen2 ups")
Mon.PP_MAX_UPS = 3

local Pokemon = require("src.core.game3.pokemon")
assertEq(Pokemon.maxPp(35, 3), 56, "gen3 max")
Pokemon.PP_NUM = 40
assertEq(Pokemon.maxPp(35, 3), 77, "gen3 numerator")
Pokemon.PP_NUM = 20
Pokemon.PP_MAX_UPS = 1
assertEq(Pokemon.maxPp(35, 3), 42, "gen3 ups")
Pokemon.PP_MAX_UPS = 3

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, ppRules = { div = 4, maxUps = 2 },
})
assert(red:find("local ItemEffects = require(\"src.inventory.ItemEffects\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Mon", 1, true), "red skips gen2")
assert(red:find("ItemEffects.PP_DIV = 4", 1, true), "red divisor")
assert(red:find("ItemEffects.PP_MAX_UPS = 2", 1, true), "red ups")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    ppRules = { div = 4, cap = 5 },
  })
  assert(main:find("local Mon = require(\"src.battle.gen2.Mon\")", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
  assert(main:find("Mon.PP_DIV = 4", 1, true), version)
  assert(main:find("Mon.PP_BONUS_CAP = 5", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Pp = { num = 40, maxUps = 2 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitPp(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Pokemon.PP_NUM = 40", 1, true), version)
  assert(chunk:find("Pokemon.PP_MAX_UPS = 2", 1, true), version)
end

require("Rules")
print("PASS pp")
