-- Trainer prize payout is data for every game.

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

local Gen1 = require("src.battle.Prize")
assertEq(Gen1.trainerWin(25, 9), 225, "gen1 cart prize")
Gen1.MULTIPLIER = 2
assertEq(Gen1.trainerWin(25, 9), 450, "gen1 doubled prize")
Gen1.MULTIPLIER = 1

local Prize = require("src.battle.gen2.Prize")
local function save()
  return { player = { money = 0 }, mom = { savedMoney = 0 } }
end
local cart = Prize.award(save(), { baseMoney = 25, level = 9 })
assertEq(cart.total, 900, "gen2 cart pays four quarters")
assertEq(cart.wallet, 900, "gen2 wallet")
Prize.QUARTERS = 1
local once = Prize.award(save(), { baseMoney = 25, level = 9 })
assertEq(once.total, 225, "one quarter")
assertEq(once.wallet, 225, "wallet keeps the one quarter")
Prize.QUARTERS = 4
Prize.AMULET_MULTIPLIER = 3
local coin = Prize.award(save(), { baseMoney = 25, level = 9, amuletCoin = true })
assertEq(coin.quarter, 675, "amulet triples the quarter")
assertEq(coin.total, 2700, "then the four quarters")
Prize.AMULET_MULTIPLIER = 2

local G3 = require("src.core.game3.battle.prize")
assertEq(G3.rewardRse(nil, { secretBaseLevel = 5, moneyMultiplier = 1 }), 100, "secret base cart")
G3.SECRET_BASE_FACTOR = 10
assertEq(G3.rewardRse(nil, { secretBaseLevel = 5, moneyMultiplier = 1 }), 50, "secret base edited")
G3.SECRET_BASE_FACTOR = 20
local Trainers = require("src.core.game3.scripting.trainers")
local info = Trainers.info
Trainers.info = function() return { class = 57 } end
assertEq(G3.calc(1, { lastLevel = 10, class = 57 }), 4 * 10 * 4, "youngster cart factor")
G3.FACTOR = 1
assertEq(G3.calc(1, { lastLevel = 10, class = 57 }), 40, "factor 1 drops the four")
G3.FACTOR = 4
Trainers.info = info

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    prizeRules = { multiplier = 3 } })
  assert(main:find("Prize.MULTIPLIER = prizeRules.multiplier", 1, true), version)
  assert(not main:find("Prize.QUARTERS", 1, true), version .. " stays off gen2")
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    prizeRules = { quarters = 1, amulet = 3 } })
  assert(main:find("Prize.QUARTERS = prizeRules.quarters", 1, true), version)
  assert(main:find("Prize.AMULET_MULTIPLIER = prizeRules.amulet", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { prizeFactor = 1, amuletMultiplier = 3, secretBaseFactor = 10 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ prizeFactor = 1, amuletMultiplier = 3, secretBaseFactor = 10 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Prize.FACTOR = battleRules.prizeFactor", 1, true), version)
  assert(chunk:find("Prize.AMULET_MULTIPLIER", 1, true), version)
  assert(chunk:find("Prize.SECRET_BASE_FACTOR", 1, true), version)
end

print("PASS prize rules")
