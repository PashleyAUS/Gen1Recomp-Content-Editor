-- Multi-hit, Triple Kick, Perish Song, and Encore stay on the cart counts
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

local function zero()
  return 0
end

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.multiHitCount(zero), 2, "gen2 cart low roll")
Effects.MULTI_HIT = { 5, 2, 2, 3, 3, 3, 4, 5 }
assertEq(Effects.multiHitCount(zero), 5, "gen2 edited list")
Effects.MULTI_HIT = nil
assertEq(Effects.encoreTurns(zero), 3, "gen2 encore")
Effects.ENCORE_MIN = 1
assertEq(Effects.encoreTurns(zero), 1, "gen2 encore edited")
Effects.ENCORE_MIN = 3
assertEq(Effects.PERISH_TURNS, 4, "gen2 perish")
assertEq(Effects.hitCount("EFFECT_TRIPLE_KICK"), 3, "gen2 triple")
Effects.HIT_COUNTS.EFFECT_TRIPLE_KICK = 2
assertEq(Effects.hitCount("EFFECT_TRIPLE_KICK"), 2, "gen2 triple edited")
Effects.HIT_COUNTS.EFFECT_TRIPLE_KICK = 3

local MoveEffects = require("src.battle.MoveEffects")
local function hits(effect, list)
  return effect.hitCount({
    move = {},
    rng = function(_, hi) return hi end,
  })
end
assertEq(hits(MoveEffects.full.TWO_TO_FIVE_ATTACKS_EFFECT), 5, "gen1 last outcome")
MoveEffects.MULTI_HIT = { 9 }
assertEq(hits(MoveEffects.full.TWO_TO_FIVE_ATTACKS_EFFECT), 9, "gen1 edited")
MoveEffects.MULTI_HIT = nil
assertEq(hits(MoveEffects.full.ATTACK_TWICE_EFFECT), 2, "gen1 double")
MoveEffects.DOUBLE_HITS = 4
assertEq(hits(MoveEffects.full.ATTACK_TWICE_EFFECT), 4, "gen1 double edited")
MoveEffects.DOUBLE_HITS = 2

local Volatiles = require("src.core.game3.battle.effects.volatiles")
local Damage = require("src.core.game3.battle.damage")
assertEq(Volatiles.PERISH_TURNS, 3, "gen3 perish")
assertEq(Volatiles.ENCORE_MIN, 3, "gen3 encore min")
assertEq(Damage.TRIPLE_KICK_HITS, 3, "gen3 triple")
assertEq(Damage.DOUBLE_HITS, 2, "gen3 double")

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, hitRules = {
  multiHit = { 5, 2, 2, 3, 3, 3, 4, 5 }, doubleHits = 4,
} })
assert(red:find("MoveEffects.MULTI_HIT = { 5, 2, 2, 3, 3, 3, 4, 5 }", 1, true), "red list")
assert(red:find("MoveEffects.DOUBLE_HITS = 4", 1, true), "red double")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, hitRules = {
    perish = 2, encoreMin = 1, tripleHits = 2,
  } })
  assert(main:find("Effects.PERISH_TURNS = 2", 1, true), version .. " perish")
  assert(main:find("Effects.ENCORE_MIN = 1", 1, true), version .. " encore")
  assert(main:find("Effects.HIT_COUNTS.EFFECT_TRIPLE_KICK = 2", 1, true), version .. " triple")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Hits = {
    multiHit = { 5 }, perish = 2, tripleHits = 4,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitHits(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.MULTI_HIT = { 5 }", 1, true), version)
  assert(chunk:find("Volatiles.PERISH_TURNS = 2", 1, true), version)
  assert(chunk:find("Damage.TRIPLE_KICK_HITS = 4", 1, true), version)
end

require("Rules")
print("PASS hits")
