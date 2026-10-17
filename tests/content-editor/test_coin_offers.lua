-- The Game Corner sells 50 coins for ¥1000 and 500 for ¥10000.
-- A pack of 0 coins costs nothing when its price is 0.
-- Gold, Silver, and Crystal share the counter.

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

local Prize = require("src.ui.gen2.PrizeMenu")
local row = Prize.COUNTERS.COIN_VENDOR.prizes[1]
assertEq(row.amount, 50, "small pack")
assertEq(row.cost, 1000, "small price")
Prize.COIN_OFFERS[1] = { amount = 0, cost = 0 }
Prize.applyCoinOffers()
assertEq(row.amount, 0, "empty pack")
assertEq(row.cost, 0, "free pack")
local save = { player = { money = 0 }, coins = 0 }
local counter = Prize.COUNTERS.COIN_VENDOR
assertEq(Prize.buy(save, counter, row), "ok", "free buy")
Prize.COIN_OFFERS[1] = { amount = 50, cost = 1000 }
Prize.applyCoinOffers()

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    coinOffers = { small = 0, smallCost = 0 },
  })
  assert(main:find("COIN_OFFERS[1] = { amount = 0, cost = 0 }", 1, true), version)
  assert(main:find("applyCoinOffers", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, coinOffers = { small = 0 } })
assert(not red:find("COIN_OFFERS", 1, true), "red")
local Offers = require("CoinOffers")
local out = {}
Offers.emit({ version = "emerald", generation = 3, coinOffers = { small = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("COIN_OFFERS", 1, true), "emerald")

print("PASS coin offers")
