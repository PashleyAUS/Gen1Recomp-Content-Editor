-- Energy Powder restores 50 HP and Energy Root restores 200 until those amounts are edited.

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
ItemsData.medicineKind = function() return "heal" end
ItemsData.info = function() return nil end
local ItemUse = require("src.core.game3.item_use")

local function heal(id, hp)
  local mon = { hp = hp, maxHp = 100 }
  ItemUse.healMon(nil, mon, id)
  return mon.hp
end

assertEq(heal(30, 10), 60, "energy powder")
assertEq(heal(31, 10), 100, "energy root")
ItemUse.HERB_HEAL[30] = 5
ItemUse.HERB_HEAL[31] = 7
assertEq(heal(30, 10), 15, "edited powder")
assertEq(heal(31, 10), 17, "edited root")
ItemUse.HERB_HEAL[30] = 50
ItemUse.HERB_HEAL[31] = 200

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3HerbHeal = { [30] = 5, [31] = 7 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitHerbHeal(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemUse.HERB_HEAL[30] = 5", 1, true), version .. " powder")
  assert(chunk:find("ItemUse.HERB_HEAL[31] = 7", 1, true), version .. " root")
end

print("PASS herb heal")
