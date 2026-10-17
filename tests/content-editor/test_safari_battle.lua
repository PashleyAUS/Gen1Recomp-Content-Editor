-- Safari bait, rocks, and fleeing follow the edited numbers.

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

local Battle = require("src.battle.BattleState")
local rngState = {}
local function rngOf(value)
  return function(lo, hi)
    rngState.last = { lo, hi }
    return value
  end
end

local wild = { safariCatchRate = 100, baitFactor = 0, escapeFactor = 4 }
Battle.safariBait(wild, rngOf(3))
assertEq(wild.safariCatchRate, 50, "bait halves")
assertEq(wild.baitFactor, 3, "bait factor")
assertEq(wild.escapeFactor, 0, "bait clears anger")
assertEq(rngState.last[1], 1, "factor low")
assertEq(rngState.last[2], 5, "factor high")
Battle.SAFARI_BAIT_DIV = 4
wild.safariCatchRate = 100
Battle.safariBait(wild, rngOf(1))
assertEq(wild.safariCatchRate, 25, "edited bait")
Battle.SAFARI_BAIT_DIV = 2

wild = { safariCatchRate = 100, baitFactor = 2, escapeFactor = 0 }
Battle.safariRock(wild, rngOf(4))
assertEq(wild.safariCatchRate, 200, "rock doubles")
assertEq(wild.escapeFactor, 4, "rock factor")
assertEq(wild.baitFactor, 0, "rock clears bait")
Battle.SAFARI_ROCK_MULT = 0
wild.safariCatchRate = 100
Battle.safariRock(wild, rngOf(1))
assertEq(wild.safariCatchRate, 0, "zero rock")
Battle.SAFARI_ROCK_MULT = 2

rngState.last = nil
assertEq(Battle.safariFlees(128, false, false, rngOf(255)), true, "fast mon flees")
assertEq(rngState.last, nil, "fast mon skips the roll")
assertEq(Battle.safariFlees(10, false, false, rngOf(0)), true, "low roll flees")
assertEq(rngState.last[1], 0, "flee low")
assertEq(rngState.last[2], 255, "flee high")
assertEq(Battle.safariFlees(10, false, false, rngOf(20)), false, "high roll stays")
assertEq(Battle.safariFlees(10, true, false, rngOf(4)), true, "eating still rolls")
assertEq(Battle.safariFlees(10, true, false, rngOf(5)), false, "eating quarter")
Battle.SAFARI_FLEE_ABOVE = 255
assertEq(Battle.safariFlees(200, false, false, rngOf(255)), false, "edited flee gate")
Battle.SAFARI_FLEE_ABOVE = 127

local Rules = require("src.core.game3.battle.rules")
local rollState = {}
local function roll(value)
  return function(lo, hi)
    rollState.last = { lo, hi }
    return value
  end
end
local sf = { catchFactor = 10, baitCounter = 0, rockCounter = 1 }
Rules.safari.throwBait(sf, roll(0))
assertEq(sf.catchFactor, 5, "gen3 bait")
assertEq(sf.baitCounter, 2, "gen3 bait turns")
assertEq(sf.rockCounter, 0, "bait clears rocks")
assertEq(rollState.last[2], 4, "turn roll")
sf = { catchFactor = 4, baitCounter = 0, rockCounter = 0 }
Rules.safari.throwBait(sf, roll(0))
assertEq(sf.catchFactor, 3, "bait floor")
sf = { catchFactor = 11, rockCounter = 0, baitCounter = 2 }
Rules.safari.throwRock(sf, roll(0))
assertEq(sf.catchFactor, 20, "rock cap")
assertEq(sf.baitCounter, 0, "rock clears bait")
assertEq(Rules.safari.fleeRate({ escapeFactor = 4 }), 20, "plain flee")
assertEq(Rules.safari.fleeRate({ escapeFactor = 4, rockCounter = 1 }), 40, "angry flee")
assertEq(Rules.safari.fleeRate({ escapeFactor = 4, baitCounter = 1 }), 5, "eating flee")
assertEq(Rules.safari.fleeRate({ escapeFactor = 4, rse = true, rockCounter = 1 }), 20, "rse flee")
Rules.safari.FLEE_SCALE = 1
assertEq(Rules.safari.fleeRate({ escapeFactor = 4 }), 4, "edited flee scale")
Rules.safari.FLEE_SCALE = 5
Rules.safari.ROCK_CAP = 40
sf = { catchFactor = 11, rockCounter = 0, baitCounter = 0 }
Rules.safari.throwRock(sf, roll(0))
assertEq(sf.catchFactor, 22, "edited rock cap")
Rules.safari.ROCK_CAP = 20

local Runtime = require("SafariSettingsRuntime")
local Settings = require("SafariSettings")
Settings.validate({ fee = 500, balls = 30, steps = 500, yellowDiscount = true,
  exitMap = "SAFARI_ZONE_GATE", exitX = 4, exitY = 3, facing = "down", baitDiv = 4 }, 1)
Settings.validate({ balls = 30, steps = 600, rockCap = 40 }, 3)
local ok = pcall(Settings.validate, { balls = 30, steps = 500 }, 2)
assertEq(ok, false, "gen2 has no safari zone")
Runtime.applyBattle({ baitDiv = 4, fleeAbove = 200 }, 1)
assertEq(Battle.SAFARI_BAIT_DIV, 4, "gen1 install")
assertEq(Battle.SAFARI_FLEE_ABOVE, 200, "gen1 flee install")
Runtime.applyBattle({ rockCap = 40, fleeScale = 1 }, 3)
assertEq(Rules.safari.ROCK_CAP, 40, "gen3 install")
assertEq(Rules.safari.FLEE_SCALE, 1, "gen3 flee install")
assertEq(Battle.SAFARI_BAIT_DIV, 4, "gen3 install leaves gen1")
Battle.SAFARI_BAIT_DIV = 2
Battle.SAFARI_FLEE_ABOVE = 127
Rules.safari.ROCK_CAP = 20
Rules.safari.FLEE_SCALE = 5

print("PASS safari battle")
