-- Hoenn roulette pays 3, then 4, then 6, then 12 times the bet.
-- The last step is also one number. A step of 0 pays nothing.
-- Ruby, Sapphire, and Emerald share the wheel.

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

local Roulette = require("src.core.game3.rse.roulette")
assertEq(Roulette.multiplierAt(1), 3, "first color")
assertEq(Roulette.multiplierAt(4), 12, "one number")
local T = { grid = {
  [5] = { baseMultiplier = Roulette.NUM_BOARD_COLORS },
  [1] = { baseMultiplier = Roulette.NUM_BOARD_POKES },
  [16] = { baseMultiplier = Roulette.NUM_ROULETTE_SLOTS, flag = 1 },
} }
local st = { colorHits = { [0] = 0 }, pokeHits = { [0] = 0 }, hitFlags = 0 }
assertEq(Roulette.getMultiplier(T, st, 5), 3, "color bet")
assertEq(Roulette.getMultiplier(T, st, 1), 4, "pokemon bet")
assertEq(Roulette.getMultiplier(T, st, 16), 12, "number bet")
Roulette.MULTIPLIERS[4] = 0
assertEq(Roulette.getMultiplier(T, st, 16), 0, "number pays zero")
Roulette.MULTIPLIERS[4] = 12
assertEq(Roulette.ballsPerRound(), 6, "six balls")
Roulette.BALLS_PER_ROUND = 0
assertEq(Roulette.ballsPerRound(), 0, "no balls")
local cleared = Roulette.newState({
  rouletteTables = { [0] = { wheelSpeed = 1, wheelDelay = 1 } },
  minBets = { [0] = 1 },
}, 0, 0)
assertEq(cleared.betSelection[0], nil, "zero balls clears nothing")
Roulette.BALLS_PER_ROUND = 6
local six = Roulette.newState({
  rouletteTables = { [0] = { wheelSpeed = 1, wheelDelay = 1 } },
  minBets = { [0] = 1 },
}, 0, 0)
assertEq(six.betSelection[5], 0, "sixth ball")

local travel = { rouletteTables = { [0] = { randDistanceLow = 20, randDistanceHigh = 40 } } }
assertEq(Roulette.randomForBallTravelDistance(travel, 0, 0, 4, 0, 1), 10, "hour 4 halves the travel")
assertEq(Roulette.randomForBallTravelDistance(travel, 0, 0, 10, 0, 1), 80, "hour 10 does not")
Roulette.LUCKY_BEFORE = 4
assertEq(Roulette.randomForBallTravelDistance(travel, 0, 0, 4, 0, 1), 80, "a window ending at 4 skips hour 4")
Roulette.LUCKY_BEFORE = 10
assertEq(Roulette.randomForBallTravelDistance(travel, 0, Roulette.HAS_SHROOMISH + Roulette.HAS_TAILLOW, 10, 100, 0), 1,
  "both Pokémon stay short at hour 10")
Roulette.BOTH_BEFORE = 10
assertEq(Roulette.randomForBallTravelDistance(travel, 0, Roulette.HAS_SHROOMISH + Roulette.HAS_TAILLOW, 10, 100, 0), 10,
  "ending at 10 drops hour 10")
Roulette.BOTH_BEFORE = 11
assertEq(Roulette.usesFirstAngle(12), true, "hour 12 uses the first angle")
assertEq(Roulette.usesFirstAngle(13), false, "hour 13 uses the second")
Roulette.ANGLE_BEFORE = 0
assertEq(Roulette.usesFirstAngle(0), false, "a switch at 0 never uses the first")
Roulette.ANGLE_BEFORE = 13

local Rules = require("RouletteRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, rouletteRules = { step4 = 0, balls = 0, luckyBefore = 4, angleBefore = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rules.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("MULTIPLIERS[4] = 0", 1, true), version)
  assert(chunk:find("MAX_MULTIPLIER = 0", 1, true), version)
  assert(chunk:find("BALLS_PER_ROUND = 0", 1, true), version)
  assert(chunk:find("LUCKY_BEFORE = 4", 1, true), version)
  assert(chunk:find("ANGLE_BEFORE = 0", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen" }) do
  local out = {}
  Rules.emit({ version = version, generation = 3, rouletteRules = { step4 = 0 } }, function() return "{}" end, out)
  assert(not table.concat(out, "\n"):find("MULTIPLIERS", 1, true), version)
end
local Writer = require("ModWriter")
for _, version in ipairs({ "red", "gold" }) do
  local gen = version == "gold" and 2 or 1
  local main = Writer.emitMain({ version = version, generation = gen, rouletteRules = { step4 = 0 } })
  assert(not main:find("rse.roulette", 1, true), version)
end

print("PASS roulette")
