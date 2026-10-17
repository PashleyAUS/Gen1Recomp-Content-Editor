-- Burn's Attack cut and the Gen 3 ability rates follow the edited numbers.

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

local Status = require("src.battle.Status")
local burned = { mon = { status = "BRN" } }
assertEq(Status.applyPenalty(burned, "attack", 100), 50, "gen1 burn halves attack")
Status.BURN_ATTACK_DIV = 4
assertEq(Status.applyPenalty(burned, "attack", 100), 25, "gen1 edited burn")
Status.BURN_ATTACK_DIV = 1
assertEq(Status.applyPenalty(burned, "attack", 100), 100, "gen1 burn leaves attack")
Status.BURN_ATTACK_DIV = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, ailments = { burnAttack = 4 } })
  assert(main:find("Status.BURN_ATTACK_DIV = ailments.burnAttack", 1, true), version)
  assert(not main:find("BURN_ATTACK_DIVISOR", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, ailments = { burnAttack = 4 } })
  assert(main:find("Battle.BURN_ATTACK_DIVISOR = ailments.burnAttack", 1, true), version)
  assert(not main:find("Status.BURN_ATTACK_DIV", 1, true), version)
end

local Abilities = require("src.core.game3.battle.abilities")
assertEq(Abilities.earlyBirdTurns(false), 1, "ordinary sleep")
assertEq(Abilities.earlyBirdTurns(true), 2, "early bird")
Abilities.EARLY_BIRD_TURNS = 0
assertEq(Abilities.earlyBirdTurns(true), 0, "early bird off")
Abilities.EARLY_BIRD_TURNS = 4
assertEq(Abilities.earlyBirdTurns(true), 4, "edited early bird")
Abilities.EARLY_BIRD_TURNS = 2

local function roller(value)
  local ad = {}
  function ad:roll(lo, hi)
    self.last = { lo, hi }
    return value
  end
  return ad
end
local hit = roller(0)
assertEq(Abilities.hits(hit, 3, 3), true, "one in three hits")
assertEq(hit.last[1], 0, "low")
assertEq(hit.last[2], 2, "vanilla span")
assertEq(Abilities.hits(roller(1), 3, 3), false, "other rolls miss")
local spore = roller(0)
assertEq(Abilities.hits(spore, Abilities.EFFECT_SPORE_DENOM, 10), true, "effect spore hit")
assertEq(spore.last[2], 9, "effect spore span")
Abilities.EFFECT_SPORE_DENOM = 1
local always = roller(0)
assertEq(Abilities.hits(always, Abilities.EFFECT_SPORE_DENOM, 10), true, "always")
assertEq(always.last[2], 0, "always span")
Abilities.EFFECT_SPORE_DENOM = 10

assertEq(Abilities.portion(80, 16, 16), 5, "rain dish cart")
assertEq(Abilities.portion(80, 2, 16), 40, "edited portion")
assertEq(Abilities.portion(1, 16, 16), 1, "minimum 1")

local healed
local rain = {
  _st = { weather = "RAIN" },
  hp = function() return 10 end,
  maxHp = function() return 80 end,
  abilityOf = function() return "RAIN_DISH" end,
  heal = function(_, _, n) healed = n end,
  sayText = function() end,
}
assertEq(Abilities.endTurn(rain, {}), true, "rain dish")
assertEq(healed, 5, "rain dish amount")
Abilities.RAIN_DISH_DIV = 2
healed = nil
Abilities.endTurn(rain, {})
assertEq(healed, 40, "edited rain dish")
Abilities.RAIN_DISH_DIV = 16

local lost
local rough = {
  hp = function(_, b) return b.hp end,
  maxHp = function() return 80 end,
  abilityOf = function(_, b) return b.ability end,
  applyHpLoss = function(_, _, n) lost = n end,
  sayText = function() end,
}
local hitMove = {
  adapter = rough, user = { hp = 80 }, target = { ability = "ROUGH_SKIN", hp = 80 },
  targetDamaged = true, move = { flags = 1, power = 40 }, moveType = 0,
  tryFaintUser = function() end,
}
assertEq(Abilities.onDamage(hitMove), true, "rough skin")
assertEq(lost, 5, "rough skin amount")
Abilities.ROUGH_SKIN_DIV = 4
lost = nil
Abilities.onDamage(hitMove)
assertEq(lost, 20, "edited rough skin")
Abilities.ROUGH_SKIN_DIV = 16

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local rules = {
    earlyBird = 4, rainDishDiv = 8, absorbDiv = 2, roughSkinDiv = 8,
    shedSkin = 2, effectSpore = 5, contactStatus = 2, cuteCharm = 2,
  }
  local p = { version = version, generation = 3, gen3BattleRules = rules }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ earlyBird = 4 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Abilities.EARLY_BIRD_TURNS = battleRules.earlyBird", 1, true), version)
  assert(chunk:find("Abilities.RAIN_DISH_DIV = battleRules.rainDishDiv", 1, true), version)
  assert(chunk:find("Abilities.ABSORB_DIV = battleRules.absorbDiv", 1, true), version)
  assert(chunk:find("Abilities.ROUGH_SKIN_DIV = battleRules.roughSkinDiv", 1, true), version)
  assert(chunk:find("Abilities.SHED_SKIN_DENOM = battleRules.shedSkin", 1, true), version)
  assert(chunk:find("Abilities.EFFECT_SPORE_DENOM = battleRules.effectSpore", 1, true), version)
  assert(chunk:find("Abilities.CONTACT_STATUS_DENOM = battleRules.contactStatus", 1, true), version)
  assert(chunk:find("Abilities.CUTE_CHARM_DENOM = battleRules.cuteCharm", 1, true), version)
end

print("PASS ability rates")
