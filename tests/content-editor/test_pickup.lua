-- Pickup offers an item on 1 roll in 10. A roll of 0 takes item 139.
-- 1 in 1 still offers an item when the roll is 5. A first cutoff of 0
-- lets that roll fall through to item 133. FireRed and LeafGreen share
-- the list. Emerald does not emit it.

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
Pokemon.speciesOf = function(mon) return tonumber(mon.species) end
local Prize = require("src.core.game3.battle.prize")
local function party()
  return { { species = 1, abilityId = 53, level = 20 } }
end
local function rolls(list)
  local i = 0
  return function()
    i = i + 1
    return list[i] or 0
  end
end
local found = Prize.pickup(party(), rolls({ 0, 0 }))
assertEq(found[1].item, 139, "roll 0 is item 139")
Prize.PICKUP_DENOM = 1
found = Prize.pickup(party(), rolls({ 5, 0 }))
assertEq(found[1].item, 139, "1 in 1 still offers an item")
Prize.PICKUP_DENOM = 10
found = Prize.pickup(party(), rolls({ 5, 0 }))
assertEq(found[1], nil, "5 is not the 1-in-10 roll")
Prize.PICKUP_ITEMS[1][2] = 0
found = Prize.pickup(party(), rolls({ 0, 0 }))
assertEq(found[1].item, 133, "a cutoff of 0 falls through")
Prize.PICKUP_ITEMS[1][2] = 15

local Items = require("PickupItems")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local out = {}
  Items.emit({ version = version, gen3Pickup = { cuts = { [1] = 0 } } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("PICKUP_ITEMS[1][2] = 0", 1, true), version)
end
local out = {}
Items.emit({ version = "emerald", gen3Pickup = { cuts = { [1] = 0 } } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("PICKUP_ITEMS", 1, true), "emerald")
local Rules = require("Gen3BattleRules")
out = {}
Rules.emit({ version = "ruby", gen3BattleRules = { pickupDenom = 1 } }, function(v) return "{ pickupDenom = 1 }" end, out)
assert(table.concat(out, "\n"):find("PICKUP_DENOM = battleRules.pickupDenom", 1, true), "ruby denom")

Prize.PICKUP_ROLL = 1
Prize.PICKUP_DENOM = 1
found = Prize.pickup(party(), rolls({ 7, 50 }))
assertEq(found[1].item, 139, "a roll width of 1 is always 0")
Prize.PICKUP_ROLL = 100
Prize.PICKUP_DENOM = 10

local common = {
  pickupProbabilities = { 30 },
  pickupItems = { { id = 10 }, { id = 11 } },
  rarePickupItems = { { id = 90 }, { id = 91 } },
}
local rare = {
  pickupProbabilities = { 0 },
  pickupItems = { { id = 10 }, { id = 11 } },
  rarePickupItems = { { id = 90 }, { id = 91 } },
}
assertEq(Prize.pickupBanded(1, 99, rare), 90, "99 is the first rare item")
assertEq(Prize.pickupBanded(11, 0, common), 11, "level 11 is the next band")
Prize.PICKUP_BAND = 1
assertEq(Prize.pickupBanded(2, 0, common), 11, "one level per band")
Prize.PICKUP_BAND = 10
Prize.PICKUP_BAND_CAP = 0
assertEq(Prize.pickupBanded(100, 0, common), 10, "a cap of 0 stays on the first band")
Prize.PICKUP_BAND_CAP = 9
Prize.PICKUP_RARE_HIGH = 5
Prize.PICKUP_RARE_LOW = 4
assertEq(Prize.pickupBanded(1, 4, rare), 91, "roll 4 is the second rare item")
Prize.PICKUP_RARE_HIGH = 99
Prize.PICKUP_RARE_LOW = 98

out = {}
Items.emit({ version = "ruby", gen3Pickup = { items = { [1] = 1 } } }, function() return "{}" end, out)
assert(table.concat(out, "\n"):find("PICKUP_ITEMS[1][1] = 1", 1, true), "ruby list")
out = {}
Rules.emit({ version = "emerald", gen3BattleRules = { pickupBand = 1 } }, function(v)
  return "{ pickupBand = " .. tostring(v.pickupBand) .. " }"
end, out)
local emerald = table.concat(out, "\n")
assert(emerald:find("pickupBand = 1", 1, true), "emerald band value")
assert(emerald:find("PICKUP_BAND = battleRules.pickupBand", 1, true), "emerald band field")

print("PASS pickup")
