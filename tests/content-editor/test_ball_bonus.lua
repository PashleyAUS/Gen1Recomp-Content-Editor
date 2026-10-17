-- Specialty-ball catch bonuses are data.

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

local Catching = require("src.battle.gen2.Catching")
assertEq(Catching.specialtyRate(45, "FAST_BALL", { species = "MAGNEMITE" }), 180, "cart fast ball")
assertEq(Catching.specialtyRate(45, "FAST_BALL", { species = "PIKACHU" }), 45, "pikachu is not on the cart list")
Catching.FAST_BALL_SPECIES = { PICHU = true }
Catching.FAST_BALL_MULT = 2
assertEq(Catching.specialtyRate(45, "FAST_BALL", { species = "PICHU" }), 90, "edited species and multiplier")
assertEq(Catching.specialtyRate(45, "FAST_BALL", { species = "MAGNEMITE" }), 45, "magnemite dropped")
Catching.FAST_BALL_SPECIES = { MAGNEMITE = true, GRIMER = true, TANGELA = true }
Catching.FAST_BALL_MULT = 4
assertEq(Catching.specialtyRate(10, "LURE_BALL", { fishing = true }), 30, "cart lure")
Catching.LURE_BALL_MULT = 5
assertEq(Catching.specialtyRate(10, "LURE_BALL", { fishing = true }), 50, "edited lure")
Catching.LURE_BALL_MULT = 3

local Writer = require("ModWriter")
local function project(version)
  return {
    version = version, generation = 2,
    specialtyBalls = {
      FAST_BALL = { mult = 2, species = { "PICHU" } },
      LURE_BALL = { mult = 5 },
    },
  }
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain(project(version))
  assert(main:find("Catching.FAST_BALL_MULT = 2", 1, true), version .. " fast")
  assert(main:find("PICHU", 1, true), version .. " species")
  assert(main:find("Catching.LURE_BALL_MULT = 5", 1, true), version .. " lure")
end
local red = Writer.emitMain({ version = "red", generation = 1,
  specialtyBalls = { FAST_BALL = { mult = 2, species = { "PICHU" } } } })
assert(not red:find("FAST_BALL_MULT", 1, true), "red stays quiet")

local G3 = require("src.core.game3.battle.catching")
local Types = require("src.core.game3.battle.types")
assertEq(G3.ballMultiplier(2, { mon = { level = 50 } }, {}, nil), 20, "cart ultra")
G3.BALL_BONUS[2] = 40
assertEq(G3.ballMultiplier(2, { mon = { level = 50 } }, {}, nil), 40, "edited ultra")
G3.BALL_BONUS[2] = 20
local water = Types.ID.WATER
assertEq(G3.ballMultiplier(6, { type1 = water, mon = { level = 50 } }, {}, nil), 30, "cart net")
G3.NET_BOOST = 15
assertEq(G3.ballMultiplier(6, { type1 = water, mon = { level = 50 } }, {}, nil), 15, "edited net")
G3.NET_BOOST = 30
assertEq(G3.ballMultiplier(8, { mon = { level = 10 } }, {}, nil), 30, "cart nest")
G3.NEST_LEVEL = 15
assertEq(G3.ballMultiplier(8, { mon = { level = 10 } }, {}, nil), 10, "edited nest floor")
G3.NEST_LEVEL = 40
G3.NEST_LEVEL = 15
G3.NEST_FLOOR = 0
assertEq(G3.ballMultiplier(8, { mon = { level = 10 } }, {}, nil), 5, "a floor of 0 keeps 5")
G3.NEST_FLOOR = 10
G3.NEST_LEVEL = 40
assertEq(G3.ballMultiplier(10, { mon = { level = 50 } }, { turn = 1 }, nil), 11, "turn 1 starts at 11")
G3.TIMER_STEP = 0
assertEq(G3.ballMultiplier(10, { mon = { level = 50 } }, { turn = 1 }, nil), 10, "zero per turn stays at the start")
G3.TIMER_STEP = 1

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BallBonus = { ultra = 40, netBoost = 15 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitBalls(p, function() return "{ ultra = 40, netBoost = 15 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Catching.BALL_BONUS[2] = ballBonus.ultra", 1, true), version .. " ultra")
  assert(chunk:find("Catching.NET_BOOST = ballBonus.netBoost", 1, true), version .. " net")
end
local floorOut = {}
Gen3BattleRules.emitBalls({ version = "emerald", gen3BallBonus = { nestFloor = 0, timerStep = 0 } }, function() return "{}" end, floorOut)
local floorChunk = table.concat(floorOut, "\n")
assert(floorChunk:find("Catching.NEST_FLOOR = ballBonus.nestFloor", 1, true), "nest floor emits")
assert(floorChunk:find("Catching.TIMER_STEP = ballBonus.timerStep", 1, true), "timer step emits")

require("Items")
require("Rules")
print("PASS ball bonus")
