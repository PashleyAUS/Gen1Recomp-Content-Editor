-- Ether and Elixir add a fixed amount of PP until that amount is edited.

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
local function ether()
  local target = {
    hp = 20, stats = { hp = 20 }, nickname = "Abra", species = "ABRA",
    moves = { { id = "TACKLE", pp = 5, ppUps = 0 } },
  }
  local data = {
    items = { ETHER = { name = "ETHER" } },
    moves = { TACKLE = { pp = 35 } },
    pokemon = {},
  }
  pcall(function()
    Gen1.use(data, { player = { name = "Red" } }, "ETHER", target, nil, 1)
  end)
  return target.moves[1].pp
end
assertEq(ether(), 15, "gen1 ether")
Gen1.PP_RESTORE.ETHER = 4
assertEq(ether(), 9, "gen1 edited")
Gen1.PP_RESTORE.ETHER = 10

local Gen2 = require("src.core.gen2.ItemEffects")
local function berry()
  local mon = { moves = { { id = "TACKLE", pp = 5 } } }
  local data = { moves = { TACKLE = { pp = 35 } } }
  Gen2.usePpItem("MYSTERYBERRY", mon, 1, data)
  return mon.moves[1].pp
end
assertEq(berry(), 10, "gen2 berry")
Gen2.RESTORE_PP.MYSTERYBERRY.amount = 4
assertEq(berry(), 9, "gen2 edited")
Gen2.RESTORE_PP.MYSTERYBERRY.amount = 5

local ItemUse = require("src.core.game3.item_use")
local Pokemon = require("src.core.game3.pokemon")
local savedEffect, savedId, savedPp = ItemUse.effect, Pokemon.moveIdAt, Pokemon.movePp
ItemUse.effect = function() return { 0, 0, 0, 0, 0x18, 0, 10 } end
Pokemon.moveIdAt = function(mon, slot) return mon.moves and mon.moves[slot] end
Pokemon.movePp = function() return 35 end
local function gen3()
  local mon = { moves = { 1 }, pp = { 5 }, ppBonusesPacked = 0 }
  ItemUse.applyPpItem(mon, 34, 1)
  return mon.pp[1]
end
assertEq(gen3(), 15, "gen3 ether")
ItemUse.PP_RESTORE[34] = 4
assertEq(gen3(), 9, "gen3 edited")
ItemUse.PP_RESTORE[34] = nil
ItemUse.effect, Pokemon.moveIdAt, Pokemon.movePp = savedEffect, savedId, savedPp

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, ppRestore = { ETHER = 4, MYSTERYBERRY = 3 },
})
assert(red:find("ItemEffects.PP_RESTORE.ETHER = 4", 1, true), "red ether")
assert(not red:find("MYSTERYBERRY", 1, true), "red skips berry")
assert(not red:find("src.core.gen2.ItemEffects", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, ppRestore = { ETHER = 4, MYSTERYBERRY = 3 },
  })
  assert(main:find("ItemEffects.RESTORE_PP.ETHER.amount = 4", 1, true), version)
  assert(main:find("ItemEffects.RESTORE_PP.MYSTERYBERRY.amount = 3", 1, true), version)
  assert(not main:find("src.inventory.ItemEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3PpRestore = { ETHER = 4, [34] = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitPpRestore(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("ItemUse.PP_RESTORE[\"ETHER\"] = 4", 1, true), version)
  assert(chunk:find("ItemUse.PP_RESTORE[34] = 4", 1, true), version)
end

require("Items")
print("PASS pp restore")
