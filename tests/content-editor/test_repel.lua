-- Repel lasts 100, 200, or 250 steps until those counts are edited.

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
local function useGen1(id)
  local save = { player = { name = "Red" }, repelSteps = 0 }
  local data = { items = { [id] = { name = id } } }
  pcall(function() Gen1.use(data, save, id) end)
  return save.repelSteps
end
assertEq(useGen1("REPEL"), 100, "gen1 repel")
assertEq(useGen1("SUPER_REPEL"), 200, "gen1 super")
assertEq(useGen1("MAX_REPEL"), 250, "gen1 max")
Gen1.REPEL_STEPS.REPEL = 40
assertEq(useGen1("REPEL"), 40, "gen1 edited")
Gen1.REPEL_STEPS.REPEL = 100

local World = require("src.world.gen2.World")
local function useGen2(id)
  local save = { repelSteps = 0, inventory = { [id] = 1 } }
  local self = {
    game = { save = save },
    battleActive = false,
    busy = function() return false end,
  }
  World.useRepel(self, id)
  return save.repelSteps
end
assertEq(useGen2("SUPER_REPEL"), 200, "gen2 super")
World.REPEL_STEPS.SUPER_REPEL = 80
assertEq(useGen2("SUPER_REPEL"), 80, "gen2 edited")
World.REPEL_STEPS.SUPER_REPEL = 200

local ItemUse = require("src.core.game3.item_use")
local ItemsData = require("src.core.game3.items_data")
assertEq(ItemUse.repelSteps(86), 100, "gen3 repel")
assertEq(ItemUse.repelSteps("MAX_REPEL"), 250, "gen3 max")
ItemsData.REPEL_STEPS[86] = 40
assertEq(ItemUse.repelSteps(86), 40, "gen3 edited")
ItemsData.REPEL_STEPS[86] = 100

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, repelSteps = { REPEL = 40 },
})
assert(red:find("local ItemEffects = require(\"src.inventory.ItemEffects\")", 1, true), "red module")
assert(red:find("ItemEffects.REPEL_STEPS.REPEL = 40", 1, true), "red steps")
assert(not red:find("src.world.gen2.World", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, repelSteps = { MAX_REPEL = 80 },
  })
  assert(main:find("local World = require(\"src.world.gen2.World\")", 1, true), version)
  assert(main:find("World.REPEL_STEPS.MAX_REPEL = 80", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Repel = { REPEL = 40, [86] = 40 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitRepel(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemsData.REPEL_STEPS.REPEL = 40", 1, true), version)
  assert(chunk:find("ItemsData.REPEL_STEPS[86] = 40", 1, true), version)
end

require("Items")
print("PASS repel")
