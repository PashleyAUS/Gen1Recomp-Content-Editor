-- A 3-line spin costs 3 coins, a 2-line spin costs 2, and a 1-line spin costs 1.
-- A cost of 0 is free, and the lines that spin stays the same.
-- FireRed and the Hoenn machines cap a spin at 3 coins. 0 means it cannot start.

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

local Gen1 = require("src.ui.SlotMachine")
assertEq(Gen1.betCost(3), 3, "gen1 three")
assertEq(Gen1.betCost(1), 1, "gen1 one")
Gen1.BET_COST[3] = 0
assertEq(Gen1.betCost(3), 0, "gen1 free")
assertEq(Gen1.betCost(2), 2, "gen1 two stays")
local wheels = { { "7", "7", "7" }, { "7", "7", "7" }, { "7", "7", "7" } }
local win = Gen1.evaluate(wheels, { 1, 1, 1 }, 3)
assertEq(win and win.symbol, "7", "three lines still pay")
Gen1.BET_COST[3] = 3

local Gen2 = require("src.ui.gen2.SlotMachine")
assertEq(Gen2.betCost(3), 3, "gen2 three")
Gen2.BET_COST[1] = 0
assertEq(Gen2.betCost(1), 0, "gen2 free")
local window = { 7, 7, 7 }
assertEq(Gen2.matchAll(1, window, window, window), 7, "one line still matches")
Gen2.BET_COST[1] = 1

local Frlg = require("src.core.game3.slot_machine")
assertEq(Frlg.maxBet(), 3, "frlg cap")
local oldCoins = Frlg.coins
Frlg.coins = function() return 5 end
Frlg.MAX_BET = 0
local st = { bet = 0 }
assertEq(Frlg.betOne(st, {}), false, "frlg cannot insert")
assertEq(Frlg.betMax(st, {}), false, "frlg cannot fill")
assertEq(st.bet, 0, "frlg bet stays")
Frlg.MAX_BET = 1
assertEq(Frlg.betMax(st, {}), true, "frlg one coin")
assertEq(st.bet, 1, "frlg capped")
Frlg.coins = oldCoins
Frlg.MAX_BET = 3

local Rse = require("src.core.game3.rse.slot_machine")
assertEq(Rse.maxBet(), 3, "rse cap")
Rse.MAX_BET = 0
assertEq(Rse.maxBet(), 0, "rse none")
Rse.MAX_BET = 3

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, slotBets = { three = 0 } })
  assert(main:find("src.ui.SlotMachine", 1, true), version)
  assert(main:find("BET_COST[3] = 0", 1, true), version)
  assert(not main:find("gen2.SlotMachine", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, slotBets = { one = 0 } })
  assert(main:find("src.ui.gen2.SlotMachine", 1, true), version)
  assert(main:find("BET_COST[1] = 0", 1, true), version)
  assert(not main:find("MAX_BET", 1, true), version)
end

local Native = require("Gen3Native")
local Bets = require("SlotBets")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, slotBets = { max = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Bets.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("src.core.game3.slot_machine", 1, true), version)
  assert(chunk:find("MAX_BET = 0", 1, true), version)
  assert(not chunk:find("rse.slot_machine", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, slotBets = { max = 1 } }
  local out = {}
  Bets.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("rse.slot_machine", 1, true), version)
  assert(chunk:find("MAX_BET = 1", 1, true), version)
  assert(not chunk:find("BET_COST", 1, true), version)
end

print("PASS slot bets")
