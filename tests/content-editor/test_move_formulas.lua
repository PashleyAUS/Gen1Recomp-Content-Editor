-- Pay Day, Eruption, Rollout, Future Sight, Hidden Power, and the leftover
-- damage rolls stay on the cart until they are edited.

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

local Capabilities = require("src.core.game3.battle.capabilities")
local lo, hi = Capabilities.rollRange()
assertEq(lo, 85, "roll min")
assertEq(hi, 100, "roll max")
Capabilities.damageRollMin = 90
Capabilities.damageRollMax = 90
lo, hi = Capabilities.rollRange()
assertEq(lo, 90, "edited roll min")
assertEq(hi, 90, "edited roll max")
Capabilities.damageRollMin = 85
Capabilities.damageRollMax = 100

local MoveEffects = require("src.battle.MoveEffects")
assertEq(MoveEffects.PAY_DAY_PER_LEVEL, 2, "gen1 payday")
local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.PAY_DAY_PER_LEVEL, 2, "gen2 payday")
assertEq(Effects.rampedPower(30, 0), 30, "rollout first")
assertEq(Effects.rampedPower(30, 1), 60, "rollout second")
assertEq(Effects.rampedPower(30, 9), 480, "rollout cap")
assertEq(Effects.rampedPower(30, 0, true), 60, "defense curl")
Effects.RAMP_MULT = 3
assertEq(Effects.rampedPower(30, 1), 90, "edited ramp")
Effects.RAMP_MULT = 2
assertEq(Effects.FUTURE_SIGHT_TURNS, 4, "gen2 future sight")

local Battle = require("src.battle.gen2.Battle")
local power, typ = Battle:hiddenPower({
  dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
})
assertEq(power, 70, "gen2 hidden power")
assertEq(typ, "DARK", "gen2 hidden type")
Battle.HIDDEN_POWER_BASE = 1
power = Battle:hiddenPower({
  dvs = { attack = 15, defense = 15, speed = 15, special = 15 },
})
assertEq(power, 40, "gen2 edited hidden power")
Battle.HIDDEN_POWER_BASE = 31

local Damage = require("src.core.game3.battle.damage")
local Types = require("src.core.game3.battle.types")
local ivs = { hp = 31, atk = 31, def = 31, spe = 31, spa = 31, spd = 31 }
power, typ = Damage.hiddenPower({ ivs = ivs })
assertEq(power, 70, "gen3 hidden power")
assertEq(typ, Types.ID.DARK, "gen3 hidden type")
local p0, t0 = Damage.hiddenPower({ ivs = { hp = 0, atk = 0, def = 0, spe = 0, spa = 0, spd = 0 } })
assertEq(p0, 30, "gen3 zero power")
assertEq(t0, Types.ID.FIGHTING, "gen3 zero type")
assertEq(Damage.eruptionPower(1, 100, 150), 1, "eruption floor")
assertEq(Damage.eruptionPower(50, 100, 150), 75, "eruption half")
Damage.ERUPTION_MIN = 10
assertEq(Damage.eruptionPower(1, 100, 150), 10, "eruption edited")
Damage.ERUPTION_MIN = 1
assertEq(Damage.rolloutPower(30, 1, false), 60, "gen3 rollout")
assertEq(Damage.rolloutPower(30, 0, true), 60, "gen3 curl")
assertEq(Damage.PAY_DAY_PER_LEVEL, 5, "gen3 payday")
assertEq(Damage.FUTURE_SIGHT_TURNS, 3, "gen3 future sight")

local Setup = require("src.core.game3.battle.effects.setup")
local oldBase = Damage.base
Damage.base = function() return 12 end
Damage.FUTURE_SIGHT_TURNS = 2
local side = {}
Setup.futureSight({
  adapter = {
    foeSide = function() return side end,
    ownSide = function() return {} end,
    sayText = function() end,
    _st = {},
  },
  user = { side = "player", id = 0 },
  target = { side = "enemy", id = 1 },
  move = { power = 80, type = 14, numId = 248 },
  moveId = 248,
})
Damage.base = oldBase
Damage.FUTURE_SIGHT_TURNS = 3
assertEq(side.tokens[1].turns, 2, "future sight uses the delay")
assertEq(side.tokens[1].damage, 12, "future sight stores damage")

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1,
  moveFormulas = { payDay = 4, rampMult = 3 } })
assert(red:find("MoveEffects.PAY_DAY_PER_LEVEL = 4", 1, true), "red payday")
assert(not red:find("RAMP_MULT", 1, true), "red leaves rollout alone")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, moveFormulas = {
    payDay = 4, rampMult = 3, futureTurns = 2, hpBase = 1,
    types = { [1] = "FIRE" },
  } })
  assert(main:find("Effects.PAY_DAY_PER_LEVEL = 4", 1, true), version .. " payday")
  assert(main:find("Effects.RAMP_MULT = 3", 1, true), version .. " ramp")
  assert(main:find("Effects.FUTURE_SIGHT_TURNS = 2", 1, true), version .. " future")
  assert(main:find("Battle.HIDDEN_POWER_BASE = 1", 1, true), version .. " hidden")
  assert(main:find("FIRE", 1, true), version .. " type")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3MovePower = { payDay = 0, eruptionMin = 10 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitMoves(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.PAY_DAY_PER_LEVEL = 0", 1, true), version)
  assert(chunk:find("Damage.ERUPTION_MIN = 10", 1, true), version)
end

require("Rules")
print("PASS move formulas")
