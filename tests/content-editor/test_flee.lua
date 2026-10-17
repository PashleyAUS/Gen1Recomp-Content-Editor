-- Running from a wild battle stays on the cart Speed math until it is edited.

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

local BattleState = require("src.battle.BattleState")
local function gen1(roll, attempts, p, e)
  return BattleState.runRollVanilla({
    runAttempts = attempts,
    rng = function() return roll end,
  }, p, e)
end
assertEq(gen1(255, 1, 100, 10), true, "gen1 faster")
assertEq(gen1(255, 1, 10, 100), false, "gen1 slow miss")
assertEq(gen1(12, 1, 10, 100), true, "gen1 equal roll")
assertEq(gen1(13, 1, 10, 100), false, "gen1 over roll")
BattleState.FLEE_BONUS = 300
assertEq(gen1(255, 2, 10, 100), true, "gen1 bonus edited")
BattleState.FLEE_BONUS = 30
assertEq(BattleState.runRollVanilla({ ghost = true, rng = function() return 255 end }, 1, 100), true, "gen1 ghost")

local Battle = require("src.battle.gen2.Battle")
local function gen2(roll, attempts, p, e)
  return Battle.runRollVanilla({
    runAttempts = attempts,
    random = function() return roll end,
  }, p, e)
end
assertEq(gen2(0, 1, 100, 10), true, "gen2 faster")
assertEq(gen2(0, 1, 10, 100), true, "gen2 first try")
assertEq(gen2(42, 1, 10, 100), false, "gen2 exact miss")
Battle.FLEE_BONUS = 0
Battle.FLEE_NUM = 0
assertEq(gen2(0, 1, 10, 100), false, "gen2 edited off")
Battle.FLEE_BONUS = 30
Battle.FLEE_NUM = 32

local Damage = require("src.core.game3.battle.damage")
local odds, cap = Damage.fleeOdds(50, 100, 0)
assertEq(odds, 64, "gen3 odds")
assertEq(cap, 256, "gen3 cap")
odds = Damage.fleeOdds(50, 100, 1)
assertEq(odds, 94, "gen3 second try")
Damage.FLEE_NUM = 0
odds = Damage.fleeOdds(50, 100, 0)
assertEq(odds, 0, "gen3 multiplier edited")
Damage.FLEE_NUM = 128

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, fleeRules = {
  num = 16, bonus = 0,
} })
assert(red:find("BattleState.FLEE_NUM = 16", 1, true), "red num")
assert(red:find("BattleState.FLEE_BONUS = 0", 1, true), "red bonus")
assert(not red:find("src.battle.gen2.Battle", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, fleeRules = {
    speedDiv = 2, cap = 100,
  } })
  assert(main:find("Battle.FLEE_SPEED_DIV = 2", 1, true), version .. " div")
  assert(main:find("Battle.FLEE_CAP = 100", 1, true), version .. " cap")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Flee = {
    num = 64, bonus = 10, cap = 100,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitFlee(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.FLEE_NUM = 64", 1, true), version)
  assert(chunk:find("Damage.FLEE_BONUS = 10", 1, true), version)
  assert(chunk:find("Damage.FLEE_CAP = 100", 1, true), version)
end

require("Rules")
print("PASS flee")
