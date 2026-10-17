-- Potions, drinks, Moomoo Milk, and Oran and Sitrus Berries restore the HP on the item page.

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

local ItemsData = require("src.core.game3.items_data")
ItemsData.info = function() return nil end
ItemsData.toNumericId = function(id) return tonumber(id) end
ItemsData.medicineKind = function() return "heal" end
local ItemUse = require("src.core.game3.item_use")

local function heal(id, hp, maxHp)
  local mon = { hp = hp, maxHp = maxHp or 100 }
  ItemUse.healMon(nil, mon, id)
  return mon.hp
end

assertEq(heal(13, 10), 30, "potion")
assertEq(heal(29, 10), 100, "moomoo milk")
assertEq(heal(20, 10), 100, "max potion fills")
assertEq(heal(139, 10), 20, "oran berry")
ItemsData.HEAL_AMOUNT[13] = 4
ItemsData.HEAL_AMOUNT.POTION = 4
ItemsData.HEAL_AMOUNT[20] = 15
ItemsData.HEAL_AMOUNT.MAX_POTION = 15
assertEq(heal(13, 10), 14, "edited potion")
assertEq(heal("POTION", 10), 14, "potion name")
assertEq(heal(20, 10), 25, "edited max potion")
ItemsData.HEAL_AMOUNT[13] = 20
ItemsData.HEAL_AMOUNT.POTION = 20
ItemsData.HEAL_AMOUNT[20] = 9999
ItemsData.HEAL_AMOUNT.MAX_POTION = 9999

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3HealHp = { [13] = 4, [142] = 12 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitHealHp(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemsData.HEAL_AMOUNT[13] = 4", 1, true), version .. " potion")
  assert(chunk:find("ItemsData.HEAL_AMOUNT.POTION = 4", 1, true), version .. " potion name")
  assert(chunk:find("ItemsData.HEAL_AMOUNT[142] = 12", 1, true), version .. " sitrus")
  assert(chunk:find("ItemsData.HEAL_AMOUNT.SITRUS_BERRY = 12", 1, true), version .. " sitrus name")
end

print("PASS heal hp")
