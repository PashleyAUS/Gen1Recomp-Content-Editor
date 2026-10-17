-- A vitamin adds 2560 stat experience, or 10 effort, until that amount is edited.

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
  local target = {
    hp = 20, stats = { hp = 20 }, nickname = "Abra", species = "ABRA",
    level = 5, statExp = { hp = 0 }, dvs = {},
  }
  local data = { items = { HP_UP = { name = "HP UP" } }, pokemon = {} }
  pcall(function()
    Gen1.use(data, { player = { name = "Red" } }, "HP_UP", target)
  end)
  return target.statExp.hp
end
assertEq(useGen1(), 2560, "gen1 gain")
Gen1.VITAMIN_GAIN = 100
assertEq(useGen1(), 100, "gen1 edited")
Gen1.VITAMIN_GAIN = 2560
Gen1.VITAMIN_CAP = 50
local capped = {
  hp = 20, stats = { hp = 20 }, nickname = "Abra", species = "ABRA",
  level = 5, statExp = { hp = 50 }, dvs = {},
}
pcall(function()
  Gen1.use({ items = { HP_UP = { name = "HP UP" } }, pokemon = {} },
    { player = { name = "Red" } }, "HP_UP", capped)
end)
assertEq(capped.statExp.hp, 50, "gen1 cap")
Gen1.VITAMIN_CAP = 25600

local Gen2 = require("src.core.gen2.ItemEffects")
local function useGen2()
  local mon = { statExp = { hp = 0 }, level = 5, nickname = "Abra" }
  pcall(function() Gen2.useOnMon("HP_UP", mon, {}) end)
  return mon.statExp.hp
end
assertEq(useGen2(), 2560, "gen2 gain")
Gen2.VITAMIN_GAIN = 100
assertEq(useGen2(), 100, "gen2 edited")
Gen2.VITAMIN_GAIN = 2560

local ItemUse = require("src.core.game3.item_use")
local function useGen3()
  local mon = { species = 1, evs = { hp = 0, atk = 0, def = 0, spe = 0, spa = 0, spd = 0 } }
  pcall(function() ItemUse.useVitamin(nil, mon, 63) end)
  return mon.evs.hp
end
assertEq(useGen3(), 10, "gen3 gain")
ItemUse.VITAMIN_GAIN = 4
assertEq(useGen3(), 4, "gen3 edited")
ItemUse.VITAMIN_GAIN = 10

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, vitaminRules = { gain = 100, cap = 1000 },
})
assert(red:find("local ItemEffects = require(\"src.inventory.ItemEffects\")", 1, true), "red module")
assert(red:find("ItemEffects.VITAMIN_GAIN = 100", 1, true), "red gain")
assert(red:find("ItemEffects.VITAMIN_CAP = 1000", 1, true), "red cap")
assert(not red:find("src.core.gen2.ItemEffects", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, vitaminRules = { gain = 100 },
  })
  assert(main:find("local ItemEffects = require(\"src.core.gen2.ItemEffects\")", 1, true), version)
  assert(main:find("ItemEffects.VITAMIN_GAIN = 100", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Vitamin = { gain = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitVitamin(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemUse.VITAMIN_GAIN = 4", 1, true), version)
end

require("Items")
print("PASS vitamin")
