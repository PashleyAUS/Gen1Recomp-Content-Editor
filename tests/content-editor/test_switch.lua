-- Roar, Whirlwind, Teleport, and Transform PP stay on the cart numbers
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

local MoveEffects = require("src.battle.MoveEffects")
assertEq(MoveEffects.forceOutOk(10, 5, 0), true, "gen1 higher level")
assertEq(MoveEffects.forceOutOk(1, 8, 1), false, "gen1 low roll")
assertEq(MoveEffects.forceOutOk(1, 8, 2), true, "gen1 high roll")
MoveEffects.FORCE_OUT_DIV = 1
assertEq(MoveEffects.forceOutOk(1, 8, 7), false, "gen1 divisor edited")
MoveEffects.FORCE_OUT_DIV = 4
assertEq(MoveEffects.copiedPp(), 5, "gen1 transform pp")
MoveEffects.TRANSFORM_PP = 2
assertEq(MoveEffects.copiedPp(), 2, "gen1 transform edited")
MoveEffects.TRANSFORM_PP = 5

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.forceOutThreshold(8), 2, "gen2 threshold")
Effects.FORCE_OUT_DIV = 2
assertEq(Effects.forceOutThreshold(8), 4, "gen2 threshold edited")
Effects.FORCE_OUT_DIV = 4
assertEq(Effects.copiedPp(), 5, "gen2 transform pp")
local Battle = require("src.battle.gen2.Battle")
local attacker = {
  species = "DITTO", types = { "NORMAL" }, moves = {},
  stats = { hp = 40 }, shiny = false, level = 10,
}
local defender = {
  species = "ABRA", types = { "PSYCHIC" },
  moves = { { id = "TELEPORT" } },
  stats = { attack = 20, defense = 20, speed = 20, specialAttack = 20, specialDefense = 20 },
  shiny = false, level = 10,
}
Effects.TRANSFORM_PP = 3
Battle.MOVE_EFFECTS.EFFECT_TRANSFORM({
  volatile = function() return {} end,
  monName = function() return "A" end,
  speciesDef = function() return nil end,
  emit = function() end,
  sideOf = function() return "player" end,
}, attacker, defender)
assertEq(attacker.moves[1].pp, 3, "gen2 transform tick")
assertEq(attacker.moves[1].maxPp, 3, "gen2 transform max")
Effects.TRANSFORM_PP = 5

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.forceOutFails(10, 5, 0), false, "gen3 higher level")
assertEq(Damage.forceOutFails(5, 20, 0), true, "gen3 low roll")
Damage.FORCE_OUT_DIV = 1
assertEq(Damage.forceOutFails(5, 20, 255), false, "gen3 divisor edited")
Damage.FORCE_OUT_DIV = 4
assertEq(Damage.copyPp(40), 5, "gen3 copy cap")
assertEq(Damage.copyPp(3), 3, "gen3 copy under cap")
Damage.COPY_PP = 2
assertEq(Damage.copyPp(40), 2, "gen3 copy edited")
Damage.COPY_PP = 5

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, switchRules = {
  forceOutDiv = 2, transformPp = 8,
} })
assert(red:find("MoveEffects.FORCE_OUT_DIV = 2", 1, true), "red divisor")
assert(red:find("MoveEffects.TRANSFORM_PP = 8", 1, true), "red pp")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, switchRules = {
    forceOutDiv = 2, transformPp = 8,
  } })
  assert(main:find("Effects.FORCE_OUT_DIV = 2", 1, true), version .. " divisor")
  assert(main:find("Effects.TRANSFORM_PP = 8", 1, true), version .. " pp")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Switch = {
    forceOutDiv = 2, forceOutScale = 128, copyPp = 8,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitSwitch(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.FORCE_OUT_DIV = 2", 1, true), version)
  assert(chunk:find("Damage.FORCE_OUT_SCALE = 128", 1, true), version)
  assert(chunk:find("Damage.COPY_PP = 8", 1, true), version)
end

require("Rules")
print("PASS switch")
