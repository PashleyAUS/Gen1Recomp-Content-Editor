-- Vitamins, Rare Candy, battle items, and bitter herbs change friendship from the friendship page.

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
local ItemUse = require("src.core.game3.item_use")

local vitamin = Pokemon.FRIENDSHIP_DELTAS[Pokemon.FRIENDSHIP_EVENT_VITAMIN]
local battle = Pokemon.FRIENDSHIP_DELTAS[Pokemon.FRIENDSHIP_EVENT_BATTLE_ITEM]
assertEq(Pokemon.VITAMIN_FRIENDSHIP_CHANGE, vitamin, "vitamin row")
assertEq(Pokemon.STAT_BOOST_FRIENDSHIP_CHANGE, battle, "battle row")

local oldVitamin = vitamin[1]
local oldBattle = battle[1]
vitamin[1] = 9
battle[1] = 4
local mon = { friendship = 10, species = 1 }
Pokemon.itemFriendship(mon, Pokemon.VITAMIN_FRIENDSHIP_CHANGE)
assertEq(mon.friendship, 19, "vitamin friendship")
Pokemon.itemFriendship(mon, Pokemon.STAT_BOOST_FRIENDSHIP_CHANGE)
assertEq(mon.friendship, 23, "battle item friendship")
vitamin[1] = oldVitamin
battle[1] = oldBattle

local powder = ItemUse.BITTER_MEDICINE_FRIENDSHIP[30]
local oldPowder = powder[1]
powder[1] = -1
local herb = { friendship = 50, species = 1 }
Pokemon.itemFriendship(herb, powder)
assertEq(herb.friendship, 49, "energy powder friendship")
powder[1] = oldPowder

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = {
    version = version, generation = 3,
    gen3Friendship = { e1t1 = 9, e2t1 = 4, h30t1 = -1 },
  }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitFriendship(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Pokemon.FRIENDSHIP_DELTAS[1][1] = 9", 1, true), version .. " vitamin")
  assert(chunk:find("Pokemon.FRIENDSHIP_DELTAS[2][1] = 4", 1, true), version .. " battle")
  assert(chunk:find("ItemUse.BITTER_MEDICINE_FRIENDSHIP[30][1] = -1", 1, true), version .. " powder")
end

print("PASS item friendship")
