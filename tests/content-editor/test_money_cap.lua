-- Wallet and coin ceilings follow the edited caps. Zero is a real ceiling.

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

local Caps = require("src.core.MoneyCaps")
assertEq(Caps.clampMoney(1000000), 999999, "cart money ceiling")
assertEq(Caps.clampCoins(10000), 9999, "cart coin ceiling")
Caps.MAX_MONEY = 40
Caps.MAX_COINS = 0
assertEq(Caps.clampMoney(41), 40, "edited money")
assertEq(Caps.clampCoins(5), 0, "zero coins")

local Commands = require("src.script.Commands")
local ctx = { save = { money = 30 } }
Commands.give_money(ctx, 20)
assertEq(ctx.save.money, 40, "gen1 give money")

local CoinCase = require("src.core.gen2.CoinCase")
Caps.MAX_COINS = 7
local save = { player = { coins = 5 } }
local balance, capped = CoinCase.giveCoins(save, 4)
assertEq(balance, 7, "gen2 coins")
assertEq(capped, true, "gen2 coin carry")

local Prize = require("src.core.game3.battle.prize")
local session = { money = 30 }
Prize.apply(session, 20)
assertEq(session.money, 40, "gen3 prize")

local Bag = require("src.core.game3.bag")
local coins = { coins = 6 }
assertEq(Bag.Coins.add(coins, 5), true, "gen3 coin add")
assertEq(coins.coins, 7, "gen3 coins stop at the cap")
assertEq(Bag.Coins.add(coins, 1), false, "gen3 full case")

local Corner = require("src.core.game3.scripting.natives_corner")
assertEq(Corner.checkAddCoins(6, 2), 0, "gen3 case would overflow")
Caps.MAX_COINS = 20
assertEq(Corner.checkAddCoins(6, 2), 1, "gen3 case has room")

Caps.MAX_MONEY = 999999
Caps.MAX_COINS = 9999

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal" }) do
  local gen = (version == "gold" or version == "silver" or version == "crystal") and 2 or 1
  local main = Writer.emitMain({
    version = version, generation = gen,
    constants = { moneyCap = 40, coinCap = 0 },
  })
  assert(main:find("MAX_MONEY = 40", 1, true), version .. " money")
  assert(main:find("MAX_COINS = 0", 1, true), version .. " coins")
end
local vanilla = Writer.emitMain({
  version = "red", generation = 1,
  constants = { moneyCap = 999999, coinCap = 9999 },
})
assert(not vanilla:find("MAX_MONEY", 1, true), "cart money stays unset")
assert(not vanilla:find("MAX_COINS", 1, true), "cart coins stay unset")

local Native = require("Gen3Native")
local Emit = require("MoneyCaps")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, constants = { moneyCap = 40, coinCap = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Emit.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("MAX_MONEY = 40", 1, true), version)
  assert(chunk:find("MAX_COINS = 0", 1, true), version)
end

print("PASS money cap")
