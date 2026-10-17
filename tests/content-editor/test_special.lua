-- Protect, Bide, and one-hit KO accuracy stay on the cart numbers until
-- they are edited.

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

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.protectChance(0), 255, "gen2 protect first")
assertEq(Effects.protectChance(1), 127, "gen2 protect repeat")
Effects.PROTECT_START = 64
assertEq(Effects.protectChance(0), 64, "gen2 protect edited")
Effects.PROTECT_START = 255
assertEq(Effects.bideTurns(function() return 0 end), 2, "gen2 bide")
Effects.BIDE_MIN = 1
assertEq(Effects.bideTurns(function() return 0 end), 1, "gen2 bide edited")
Effects.BIDE_MIN = 2
assertEq(Effects.bideDamage(10), 20, "gen2 bide pay")
Effects.BIDE_MULT = 0
assertEq(Effects.bideDamage(10), 0, "gen2 bide pay edited")
Effects.BIDE_MULT = 2
assertEq(Effects.ohkoAccuracy(30, 12, 10), 34, "gen2 ohko")
assertEq(Effects.ohkoAccuracy(30, 10, 12), nil, "gen2 ohko lower")
Effects.OHKO_SCALE = 1
assertEq(Effects.ohkoAccuracy(30, 12, 10), 32, "gen2 ohko edited")
Effects.OHKO_SCALE = 2

local MoveEffects = require("src.battle.MoveEffects")
local user = {}
MoveEffects.full.BIDE_EFFECT.perform({
  user = user,
  rng = function(_, hi) return hi end,
  battle = { cancelMoveAnim = function() end, animBeforeMove = function() end },
})
assertEq(user.bideTurns, 3, "gen1 bide")
user = { isPlayer = true }
MoveEffects.BIDE_HI = 5
MoveEffects.full.BIDE_EFFECT.perform({
  user = user,
  rng = function(_, hi) return hi end,
  battle = { cancelMoveAnim = function() end, animBeforeMove = function() end },
})
assertEq(user.bideTurns, 5, "gen1 bide edited")
MoveEffects.BIDE_HI = 3

local BattleState = require("src.battle.BattleState")
local paid
local battle = {
  sayNext = function() end,
  romText = function() return "" end,
  animNext = function() end,
  applyDamage = function(_, _, amount) paid = amount end,
  handleBuildingRage = function() end,
  cancelMoveAnim = function() end,
}
local foe = { mon = { hp = 50 } }
BattleState.continueBide(battle, { bideTurns = 1, bideDamage = 10, isPlayer = true }, foe)
assertEq(paid, 20, "gen1 bide pay")
MoveEffects.BIDE_MULT = 3
BattleState.continueBide(battle, { bideTurns = 1, bideDamage = 10, isPlayer = true }, foe)
assertEq(paid, 30, "gen1 bide pay edited")
MoveEffects.BIDE_MULT = 2

local Damage = require("src.core.game3.battle.damage")
local Volatiles = require("src.core.game3.battle.effects.volatiles")
assertEq(Damage.bideStoreTurns(), 2, "gen3 bide turns")
assertEq(Damage.bidePayout(10), 20, "gen3 bide pay")
assertEq(Damage.ohkoChance(30, 12, 10), 32, "gen3 ohko")
assertEq(Volatiles.protectDenom(1), 2, "gen3 protect")
assertEq(Volatiles.protectDenom(4), 8, "gen3 protect cap")
Damage.OHKO_SCALE = 2
assertEq(Damage.ohkoChance(30, 12, 10), 34, "gen3 ohko edited")
Damage.OHKO_SCALE = 1
Volatiles.PROTECT_BASE = 3
assertEq(Volatiles.protectDenom(1), 3, "gen3 protect edited")
Volatiles.PROTECT_BASE = 2

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, specialRules = {
  bideLo = 1, bideMult = 0,
} })
assert(red:find("MoveEffects.BIDE_LO = 1", 1, true), "red bide")
assert(red:find("MoveEffects.BIDE_MULT = 0", 1, true), "red pay")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, specialRules = {
    protectStart = 128, bideMin = 1, ohkoScale = 1,
  } })
  assert(main:find("Effects.PROTECT_START = 128", 1, true), version .. " protect")
  assert(main:find("Effects.BIDE_MIN = 1", 1, true), version .. " bide")
  assert(main:find("Effects.OHKO_SCALE = 1", 1, true), version .. " ohko")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Special = {
    protectBase = 3, bideTurns = 4, ohkoScale = 2,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitSpecial(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Volatiles.PROTECT_BASE = 3", 1, true), version)
  assert(chunk:find("Damage.BIDE_TURNS = 4", 1, true), version)
  assert(chunk:find("Damage.OHKO_SCALE = 2", 1, true), version)
end

require("Rules")
print("PASS special")
