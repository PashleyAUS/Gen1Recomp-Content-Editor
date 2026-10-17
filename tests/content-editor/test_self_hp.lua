-- Ghost Curse and Belly Drum pay a fraction of max HP until that divisor is edited.

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
local Battle = require("src.battle.gen2.Battle")

local function battle()
  return {
    stages = { player = { attack = 0, defense = 0, speed = 0 } },
    sideOf = function() return "player" end,
    speciesDef = function() return { types = { "GHOST" } } end,
    monName = function() return "Gastly" end,
    volatile = function() return {} end,
    emit = function() end,
    markMissed = function() end,
    changeStage = function() end,
  }
end

local function curse(maxHp)
  local self = battle()
  local attacker = { hp = maxHp, maxHp = maxHp }
  Battle.MOVE_EFFECTS.EFFECT_CURSE(self, attacker, { hp = 40, maxHp = 40 })
  return attacker.hp
end

assertEq(curse(80), 40, "gen2 curse half")
Effects.CURSE_COST_DIV = 4
assertEq(curse(80), 60, "gen2 curse quarter")
Effects.CURSE_COST_DIV = 2

local function belly(maxHp)
  local self = battle()
  local attacker = { hp = maxHp, maxHp = maxHp }
  Battle.MOVE_EFFECTS.EFFECT_BELLY_DRUM(self, attacker)
  return attacker.hp, self.stages.player.attack
end

local hp, attack = belly(80)
assertEq(hp, 40, "gen2 belly half")
assertEq(attack, 6, "gen2 belly max")
Effects.BELLY_DIV = 4
hp = belly(80)
assertEq(hp, 60, "gen2 belly quarter")
Effects.BELLY_DIV = 2

local Types = require("src.core.game3.battle.types")
local Setup = require("src.core.game3.battle.effects.setup")
local Healing = require("src.core.game3.battle.effects.healing")

local function ghostCurse()
  local lost
  local user = { type1 = Types.ID.GHOST, hp = 80 }
  local target = {}
  local ad = {
    maxHp = function() return 80 end,
    applyHpLoss = function(_, _, n) lost = n end,
    sayText = function() end,
    foeOf = function() return target end,
  }
  Setup.curse({ adapter = ad, user = user, target = target })
  return lost
end

assertEq(ghostCurse(), 40, "gen3 curse half")
Healing.CURSE_DIV = 4
assertEq(ghostCurse(), 20, "gen3 curse quarter")
Healing.CURSE_DIV = 2

local function drum()
  local lost
  local stages = { attack = 0 }
  local ad = {
    maxHp = function() return 80 end,
    hp = function() return 80 end,
    stages = function() return stages end,
    applyHpLoss = function(_, _, n) lost = n end,
    sayText = function() end,
    sayFail = function() end,
  }
  Healing.bellyDrum({ adapter = ad, user = {} })
  return lost, stages.attack
end

local paid, stage = drum()
assertEq(paid, 40, "gen3 belly half")
assertEq(stage, 6, "gen3 belly max")
Healing.BELLY_DIV = 4
paid = drum()
assertEq(paid, 20, "gen3 belly quarter")
Healing.BELLY_DIV = 2

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, healRules = { curseCost = 4, bellyDiv = 4 },
})
assert(not red:find("CURSE_COST_DIV", 1, true), "red skips curse")
assert(not red:find("BELLY_DIV", 1, true), "red skips belly")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    healRules = { curseCost = 4, bellyDiv = 4 },
  })
  assert(main:find("Effects.CURSE_COST_DIV = 4", 1, true), version .. " curse")
  assert(main:find("Effects.BELLY_DIV = 4", 1, true), version .. " belly")
  assert(not main:find("src.battle.MoveEffects", 1, true), version .. " skips gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Heal = { curseDiv = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitHeal(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Healing.CURSE_DIV = 4", 1, true), version)
end

require("Rules")
print("PASS self hp")
