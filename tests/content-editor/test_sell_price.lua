-- Marts pay half the buy price until the sell divisor is edited.

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

local Shop = require("src.ui.ShopMenu")
assertEq(Shop.sellUnit(200), 100, "gen1 half")
assertEq(Shop.sellUnit(15) * 2, 14, "gen1 halves before quantity")
Shop.SELL_DIV = 1
assertEq(Shop.sellUnit(15), 15, "gen1 full price")
Shop.SELL_DIV = 4
assertEq(Shop.sellUnit(15), 3, "gen1 quarter")
Shop.SELL_DIV = 2

local Mart = require("src.ui.gen2.MartMenu")
assertEq(Mart.sellPrice(15, 2), 15, "gen2 halves the total")
Mart.SELL_DIV = 1
assertEq(Mart.sellPrice(15, 2), 30, "gen2 full price")
Mart.SELL_DIV = 4
assertEq(Mart.sellPrice(15, 2), 7, "gen2 quarter of the total")
Mart.SELL_DIV = 2

local Sell = require("src.ui.game3.sell_flow")
assertEq(Sell.sellUnit(200), 100, "gen3 half")
assertEq(Sell.sellUnit(15) * 2, 14, "gen3 halves before quantity")
Sell.SELL_DIV = 1
assertEq(Sell.sellUnit(15), 15, "gen3 full price")
Sell.SELL_DIV = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, sellRules = { div = 4 } })
  assert(main:find("src.ui.ShopMenu\").SELL_DIV = 4", 1, true), version)
  assert(not main:find("MartMenu", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, sellRules = { div = 4 } })
  assert(main:find("src.ui.gen2.MartMenu\").SELL_DIV = 4", 1, true), version)
  assert(not main:find("src.ui.ShopMenu", 1, true), version)
end

local Gen3 = require("Gen3BattleRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, sellRules = { div = 4 } }
  assert(Native.used(p), version)
  local out = {}
  Gen3.emitSell(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("sell_flow\").SELL_DIV = 4", 1, true), version)
end

print("PASS sell price")
