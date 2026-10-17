-- X Attack, X Defend, X Speed, and X Special raise one stage until that count is edited.

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
  local battle = {
    kind = "wild",
    player = { name = "Abra", stages = { attack = 0 }, mon = {} },
  }
  local data = { items = { X_ATTACK = { name = "X ATTACK" } } }
  pcall(function()
    Gen1.use(data, { player = { name = "Red" } }, "X_ATTACK", nil, battle)
  end)
  return battle.player.stages.attack
end
assertEq(useGen1(), 1, "gen1 stage")
Gen1.X_STAGE = 2
assertEq(useGen1(), 2, "gen1 edited")
Gen1.X_STAGE = 1

local Battle = require("src.battle.gen2.Battle")
local function useGen2()
  local got
  local self = {
    player = {},
    emit = function() end,
    itemDef = function() return { name = "X ATTACK" } end,
    changeStage = function(_, _, _, n) got = n end,
  }
  Battle.useBattleItem(self, "X_ATTACK")
  return got
end
assertEq(useGen2(), 1, "gen2 stage")
Battle.X_STAGE = 2
assertEq(useGen2(), 2, "gen2 edited")
Battle.X_STAGE = 1

local BattleItems = require("src.core.game3.battle.items")
assertEq(BattleItems.xStage(1), 1, "gen3 byte")
assertEq(BattleItems.xStage(0), 0, "gen3 untouched stat")
BattleItems.X_STAGE = 2
assertEq(BattleItems.xStage(1), 2, "gen3 edited")
assertEq(BattleItems.xStage(0), 0, "gen3 still skips empty stats")
BattleItems.X_STAGE = nil

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, xItem = { stages = 2 } })
assert(red:find("local ItemEffects = require(\"src.inventory.ItemEffects\")", 1, true), "red module")
assert(red:find("ItemEffects.X_STAGE = 2", 1, true), "red stages")
assert(not red:find("src.battle.gen2.Battle", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, xItem = { stages = 2 },
  })
  assert(main:find("local Battle = require(\"src.battle.gen2.Battle\")", 1, true), version)
  assert(main:find("Battle.X_STAGE = 2", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3XItem = { stages = 2 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitXItem(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("BattleItems.X_STAGE = 2", 1, true), version)
end

require("Items")
print("PASS x item")
