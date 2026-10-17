-- Disable, Spite, Uproar, and Jump Kick crash stay on the cart numbers
-- until they are edited.

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

local function hi(_, high)
  return high
end

local MoveEffects = require("src.battle.MoveEffects")
local target = { name = "ABRA", curMoves = { { id = "TACKLE", pp = 10 } } }
MoveEffects.primary.DISABLE_EFFECT({
  rng = hi,
  data = { moves = { TACKLE = { name = "TACKLE" } } },
}, {}, target)
assertEq(target.disabledTurns, 8, "gen1 disable")
target = { name = "ABRA", curMoves = { { id = "TACKLE", pp = 10 } } }
MoveEffects.DISABLE_HI = 3
MoveEffects.primary.DISABLE_EFFECT({
  rng = hi,
  data = { moves = { TACKLE = { name = "TACKLE" } } },
}, {}, target)
assertEq(target.disabledTurns, 3, "gen1 disable edited")
MoveEffects.DISABLE_HI = 8

local crashed
MoveEffects.full.JUMP_KICK_EFFECT.onMiss({
  say = function() end,
  damage = function(_, amount) crashed = amount end,
  user = { name = "HITMONLEE" },
  battle = { data = {} },
}, "accuracy")
assertEq(crashed, 1, "gen1 crash")
MoveEffects.CRASH_DAMAGE = 4
MoveEffects.full.JUMP_KICK_EFFECT.onMiss({
  say = function() end,
  damage = function(_, amount) crashed = amount end,
  user = { name = "HITMONLEE" },
  battle = { data = {} },
}, "accuracy")
assertEq(crashed, 4, "gen1 crash edited")
MoveEffects.CRASH_DAMAGE = 1

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.disableTurns(function() return 1 end), 2, "gen2 disable")
Effects.DISABLE_ADD = 0
assertEq(Effects.disableTurns(function() return 1 end), 1, "gen2 disable edited")
Effects.DISABLE_ADD = 1
assertEq(Effects.spiteLoss(function() return 0 end, 10), 2, "gen2 spite")
Effects.SPITE_MIN = 5
assertEq(Effects.spiteLoss(function() return 0 end, 3), 3, "gen2 spite clamped")
Effects.SPITE_MIN = 2

local Damage = require("src.core.game3.battle.damage")
local Volatiles = require("src.core.game3.battle.effects.volatiles")
assertEq(Volatiles.spanCount(function() return 0 end, Volatiles.DISABLE_MIN, Volatiles.DISABLE_SPAN), 2, "gen3 disable")
assertEq(Volatiles.spanCount(function() return 3 end, Volatiles.UPROAR_MIN, Volatiles.UPROAR_SPAN), 5, "gen3 uproar")
assertEq(Damage.crashDamage(10, 100), 5, "gen3 crash")
assertEq(Damage.crashDamage(80, 20), 10, "gen3 crash cap")
Volatiles.SPITE_MIN = 1
assertEq(Volatiles.spanCount(function() return 0 end, Volatiles.SPITE_MIN, Volatiles.SPITE_SPAN), 1, "gen3 spite edited")
Volatiles.SPITE_MIN = 2
Damage.CRASH_DIV = 1
assertEq(Damage.crashDamage(10, 100), 10, "gen3 crash edited")
Damage.CRASH_DIV = 2

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, lockRules = {
  disableHi = 4, crashDamage = 0,
} })
assert(red:find("MoveEffects.DISABLE_HI = 4", 1, true), "red disable")
assert(red:find("MoveEffects.CRASH_DAMAGE = 0", 1, true), "red crash")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, lockRules = {
    disableAdd = 0, spiteMin = 1,
  } })
  assert(main:find("Effects.DISABLE_ADD = 0", 1, true), version .. " disable")
  assert(main:find("Effects.SPITE_MIN = 1", 1, true), version .. " spite")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Locks = {
    uproarMin = 1, crashDiv = 4, spiteSpan = 2,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitLocks(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Volatiles.UPROAR_MIN = 1", 1, true), version)
  assert(chunk:find("Damage.CRASH_DIV = 4", 1, true), version)
  assert(chunk:find("Volatiles.SPITE_SPAN = 2", 1, true), version)
end

require("Rules")
print("PASS locks")
