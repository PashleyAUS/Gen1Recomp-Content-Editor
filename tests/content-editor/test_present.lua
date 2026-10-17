-- Present, Super Fang, Psywave, Sonic Boom, Dragon Rage, recoil, and drain
-- stay on the cart until they are edited.

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

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.presentResult(0), 40, "present low")
assertEq(Damage.presentResult(102), 80, "present mid")
assertEq(Damage.presentResult(178), 120, "present high")
assertEq(Damage.presentResult(204), nil, "present heal")
assertEq(Damage.presentHeal(100), 25, "present quarter")
Damage.PRESENT_BANDS[1].power = 5
assertEq(Damage.presentResult(0), 5, "present edited")
Damage.PRESENT_BANDS[1].power = 40
assertEq(Damage.divideHp(100, 2, 2), 50, "super fang half")
Damage.SUPER_FANG_DIV = 4
assertEq(Damage.divideHp(100, Damage.SUPER_FANG_DIV, 2), 25, "super fang edited")
Damage.SUPER_FANG_DIV = 2
assertEq(Damage.SONIC_BOOM, 20, "sonic boom")
assertEq(Damage.DRAGON_RAGE, 40, "dragon rage")

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.fixedDamage("EFFECT_SUPER_FANG", {}, { hp = 100 }), 50, "gen2 fang")
Effects.SUPER_FANG_DIV = 4
assertEq(Effects.fixedDamage("EFFECT_SUPER_FANG", {}, { hp = 100 }), 25, "gen2 fang edited")
Effects.SUPER_FANG_DIV = 2
local asked
Effects.fixedDamage("EFFECT_PSYWAVE", { level = 10 }, {}, function(n)
  asked = n
  return 0
end)
assertEq(asked, 14, "gen2 psywave span")
Effects.PSYWAVE_NUM = 2
Effects.fixedDamage("EFFECT_PSYWAVE", { level = 10 }, {}, function(n)
  asked = n
  return 0
end)
assertEq(asked, 9, "gen2 psywave edited")
Effects.PSYWAVE_NUM = 3
assertEq(Effects.recoilDamage(40), 10, "gen2 recoil")
assertEq(Effects.drainAmount(40), 20, "gen2 drain")

local MoveEffects = require("src.battle.MoveEffects")
local dmg = MoveEffects.full.SPECIAL_DAMAGE_EFFECT.chooseDamage({
  move = { id = "SONICBOOM" },
  user = { mon = { level = 10 } },
  rng = function(_, hi) return hi end,
})
assertEq(dmg, 20, "gen1 sonic")
MoveEffects.FIXED_DAMAGE.SONICBOOM = 7
dmg = MoveEffects.full.SPECIAL_DAMAGE_EFFECT.chooseDamage({
  move = { id = "SONICBOOM" },
  user = { mon = { level = 10 } },
  rng = function(_, hi) return hi end,
})
assertEq(dmg, 7, "gen1 sonic edited")
MoveEffects.FIXED_DAMAGE.SONICBOOM = 20
dmg = MoveEffects.full.SPECIAL_DAMAGE_EFFECT.chooseDamage({
  move = { id = "PSYWAVE" },
  user = { mon = { level = 10 } },
  rng = function(_, hi) return hi end,
})
assertEq(dmg, 14, "gen1 psywave")
local fang = MoveEffects.full.SUPER_FANG_EFFECT.chooseDamage({
  target = { mon = { hp = 100 } },
})
assertEq(fang, 50, "gen1 fang")
local applied
MoveEffects.full.RECOIL_EFFECT.afterDamage({
  brokeSub = false,
  totalDealt = 40,
  moveInst = {},
  user = {},
  battle = { applyRecoil = function(_, _, n) applied = n end },
})
assertEq(applied, 10, "gen1 recoil")
MoveEffects.full.RECOIL_EFFECT.afterDamage({
  brokeSub = false,
  totalDealt = 40,
  moveInst = { struggle = true },
  user = {},
  battle = { applyRecoil = function(_, _, n) applied = n end },
})
assertEq(applied, 20, "gen1 struggle recoil")

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, moveFormulas = {
  sonicBoom = 7, superFangDiv = 4, recoilDiv = 5,
} })
assert(red:find("MoveEffects.FIXED_DAMAGE.SONICBOOM = 7", 1, true), "red sonic")
assert(red:find("MoveEffects.SUPER_FANG_DIV = 4", 1, true), "red fang")
assert(not red:find("src.battle.gen2.Effects", 1, true), "red stays off gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, moveFormulas = {
    superFangDiv = 4, psywaveNum = 2, drainDiv = 3,
  } })
  assert(main:find("Effects.SUPER_FANG_DIV = 4", 1, true), version .. " fang")
  assert(main:find("Effects.PSYWAVE_NUM = 2", 1, true), version .. " psywave")
  assert(main:find("Effects.DRAIN_DIV = 3", 1, true), version .. " drain")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3MovePower = {
    sonicBoom = 7,
    presentBands = { { below = 102, power = 5 }, { heal = true } },
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitMoves(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.SONIC_BOOM = 7", 1, true), version)
  assert(chunk:find("Damage.PRESENT_BANDS =", 1, true), version)
  assert(chunk:find("power = 5", 1, true), version)
end

require("Rules")
print("PASS present")
