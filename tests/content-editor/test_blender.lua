-- The Berry Blender adds 100 flavor, then one more for every 333 RPM.
-- A flavor above 50 is gold. A base of 0 adds nothing. Gold above 0
-- turns any flavor into gold.
-- Ruby, Sapphire, and Emerald share the blender.

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

local Blender = require("src.core.game3.rse.berry_blender")
assertEq(Blender.rpmFactor(0), 100, "still flavor")
assertEq(Blender.rpmFactor(333), 101, "one step")
assertEq(Blender.goldAt(), 50, "gold line")
local berries = { [0] = { itemId = 1, flavors = { [0] = 10, 0, 0, 0, 0, 0 } } }
local ids = { enigma = -1 }
local block = Blender.calculatePokeblock(berries, 1, 0, function() return 0 end, ids, {})
assertEq(block.spicy, 9, "spicy")
assertEq(block.color, Blender.COLOR.RED, "red")
Blender.RPM_ADD = 0
block = Blender.calculatePokeblock(berries, 1, 0, function() return 0 end, ids, { 1 })
assertEq(block.color, Blender.COLOR.BLACK, "no flavor is black")
assertEq(block.spicy, 2, "black still has a taste")
Blender.RPM_ADD = 100
Blender.GOLD_AT = 0
block = Blender.calculatePokeblock(berries, 1, 0, function() return 0 end, ids, {})
assertEq(block.color, Blender.COLOR.GOLD, "any flavor is gold")
Blender.GOLD_AT = 50
Blender.RPM_DIV = 0
assertEq(Blender.rpmFactor(10), 110, "divisor stays one or more")
Blender.RPM_DIV = 333

local wheel = {
  playerIdToArrowId = { [1] = 0 },
  T = { arrowHitRangeStart = { [1] = 100 } },
}
local function at(units)
  return Blender.arrowProximity(wheel, (units - 24) * 256, 1)
end
assertEq(at(100), Blender.PROXIMITY.GOOD, "edge is good")
assertEq(at(120), Blender.PROXIMITY.BEST, "perfect window")
Blender.BEST_SPAN = 0
assertEq(at(120), Blender.PROXIMITY.GOOD, "no perfect window")
Blender.BEST_SPAN = 8
Blender.HIT_SPAN = 0
assertEq(at(120), Blender.PROXIMITY.MISS, "no hit window")
Blender.HIT_SPAN = 48
assertEq(math.floor(55 / Blender.gainDiv("best")), 1, "perfect progress")
Blender.BEST_GAIN_DIV = 0
assertEq(Blender.gainDiv("best"), 1, "progress divisor stays one")
Blender.BEST_GAIN_DIV = 55
assertEq(Blender.progressCap(), 1000, "blend length")
Blender.MAX_PROGRESS_BAR = 0
assertEq(Blender.progressCap(), 0, "blend ends immediately")
Blender.MAX_PROGRESS_BAR = 1000

local function spinning(speed)
  return {
    numPlayers = 1, speed = speed, bg_X = 0, bg_Y = 0,
    T = { numPlayersToSpeedDivisor = { [2] = 1 } },
    emit = function() end,
    shakeCoordForHit = function(_, coord) return coord end,
  }
end
local slow = spinning(100)
Blender.updateSpeedFromHit(slow, Blender.CMD.BEST)
assertEq(slow.speed, 484, "perfect while slow")
local fast = spinning(1500)
Blender.updateSpeedFromHit(fast, Blender.CMD.BEST)
assertEq(fast.speed, 1628, "perfect while fast")
local good = spinning(1500)
Blender.updateSpeedFromHit(good, Blender.CMD.GOOD)
assertEq(good.speed, 1500, "good adds nothing once fast")
Blender.SPEED_MISS = 0
local missed = spinning(128)
Blender.updateSpeedFromHit(missed, Blender.CMD.MISS)
assertEq(missed.speed, 128, "miss removes nothing")
Blender.SPEED_MISS = 256
local held = spinning(128)
Blender.updateSpeedFromHit(held, Blender.CMD.MISS)
assertEq(held.speed, 128, "a miss stays on the floor")
Blender.MIN_ARROW_SPEED = 0
local dropped = spinning(128)
Blender.updateSpeedFromHit(dropped, Blender.CMD.MISS)
assertEq(dropped.speed, 0, "a floor of 0 lets the miss empty the speed")
Blender.MIN_ARROW_SPEED = 0x80
local coast = { speed = 130, slowdownTimer = 0, gameEndState = 1, playerIdToArrowId = { [0] = 0 } }
for _ = 1, 5 do Blender.handlePlayerInput(coast, false) end
assertEq(coast.speed, 130, "five frames do not coast")
Blender.handlePlayerInput(coast, false)
assertEq(coast.speed, 129, "the sixth frame coasts")
Blender.SLOWDOWN_AT = 0
coast.speed = 130
coast.slowdownTimer = 0
Blender.handlePlayerInput(coast, false)
assertEq(coast.speed, 129, "a wait of 0 coasts on the first frame")
Blender.SLOWDOWN_AT = 5
local bit = require("bit")
local drop = setmetatable({
  numPlayers = 1,
  T = { arrowStartPos = { [1] = 1000 }, arrowStartPosIds = { [0] = 0 } },
}, Blender)
Blender.beginFall(drop)
assertEq(drop.arrowPos, bit.band(1000 - 0x5800, 0xFFFF), "cart drop")
Blender.ARROW_FALL_ROTATION = 0
Blender.beginFall(drop)
assertEq(drop.arrowPos, 1000, "no drop starts on the mark")
Blender.ARROW_FALL_ROTATION = 0x5800
local falling = { arrowPos = 0, centerScale = 0 }
Blender.fallFrame(falling)
assertEq(falling.arrowPos, 0x200, "one fall frame")
Blender.FALL_STEP = 0
falling.arrowPos = 0
Blender.fallFrame(falling)
assertEq(falling.arrowPos, 0, "a step of 0 stays put")
Blender.FALL_STEP = 0x200
local split = spinning(100)
Blender.SPEED_DIV[1] = 2
Blender.updateSpeedFromHit(split, Blender.CMD.BEST)
assertEq(split.speed, 292, "two-way split")
Blender.SPEED_DIV[1] = 1

local Rules = require("BlenderRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Blender = { rpmAdd = 0, goldAt = 0, hitSpan = 0, progressCap = 0, missSpeed = 0, div2 = 1, minSpeed = 0, slowEvery = 0, fallDrop = 0, fallStep = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rules.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("RPM_ADD = 0", 1, true), version)
  assert(chunk:find("GOLD_AT = 0", 1, true), version)
  assert(chunk:find("HIT_SPAN = 0", 1, true), version)
  assert(chunk:find("MAX_PROGRESS_BAR = 0", 1, true), version)
  assert(chunk:find("SPEED_MISS = 0", 1, true), version)
  assert(chunk:find("MIN_ARROW_SPEED = 0", 1, true), version)
  assert(chunk:find("SLOWDOWN_AT = 0", 1, true), version)
  assert(chunk:find("ARROW_FALL_ROTATION = 0", 1, true), version)
  assert(chunk:find("FALL_STEP = 0", 1, true), version)
  assert(chunk:find("SPEED_DIV[2] = 1", 1, true), version)
  assert(chunk:find("rse.berry_blender", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen" }) do
  local out = {}
  Rules.emit({ version = version, generation = 3, gen3Blender = { rpmAdd = 0 } }, function() return "{}" end, out)
  assert(not table.concat(out, "\n"):find("berry_blender", 1, true), version)
end
local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, gen3Blender = { rpmAdd = 0 } })
assert(not red:find("berry_blender", 1, true), "red")

print("PASS blender")
