-- Revive stands a fainted Pokémon up at max HP divided by 2 until that divisor changes.

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

local Gen1 = require("src.inventory.ItemEffects")
local function useGen1()
  local target = { hp = 0, stats = { hp = 100 }, nickname = "Abra", species = "ABRA", moves = {} }
  local data = { items = { REVIVE = { name = "REVIVE" } }, pokemon = {} }
  pcall(function()
    Gen1.use(data, { player = { name = "Red" } }, "REVIVE", target)
  end)
  return target.hp
end
assertEq(useGen1(), 50, "gen1 half")
Gen1.REVIVE_DIV = 4
assertEq(useGen1(), 25, "gen1 quarter")
Gen1.REVIVE_DIV = 2

local Gen2 = require("src.core.gen2.ItemEffects")
local function useGen2()
  local mon = { hp = 0, maxHp = 100, nickname = "Abra" }
  Gen2.useOnMon("REVIVE", mon, {})
  return mon.hp
end
assertEq(useGen2(), 50, "gen2 half")
Gen2.REVIVE_DIV = 4
assertEq(useGen2(), 25, "gen2 quarter")
Gen2.REVIVE_DIV = 2

local ItemUse = require("src.core.game3.item_use")
local function useGen3()
  local mon = { hp = 0, maxHp = 100 }
  ItemUse.revive(mon, false)
  return mon.hp
end
assertEq(useGen3(), 50, "gen3 half")
ItemUse.REVIVE_DIV = 4
assertEq(useGen3(), 25, "gen3 quarter")
local full = { hp = 0, maxHp = 100 }
ItemUse.revive(full, true)
assertEq(full.hp, 100, "gen3 max revive")
ItemUse.REVIVE_DIV = 2

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, reviveRules = { div = 4 } })
assert(red:find("local ItemEffects = require(\"src.inventory.ItemEffects\")", 1, true), "red module")
assert(red:find("ItemEffects.REVIVE_DIV = 4", 1, true), "red divisor")
assert(not red:find("src.core.gen2.ItemEffects", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, reviveRules = { div = 4 },
  })
  assert(main:find("local ItemEffects = require(\"src.core.gen2.ItemEffects\")", 1, true), version)
  assert(main:find("ItemEffects.REVIVE_DIV = 4", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Revive = { div = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitRevive(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemUse.REVIVE_DIV = 4", 1, true), version)
end

require("Items")
print("PASS revive")
