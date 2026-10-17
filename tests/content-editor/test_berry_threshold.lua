-- Held berries and Intimidate follow the edited numbers.

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

local function eat(hp, maxHp)
  local healed
  local battle = {
    heldEffect = function() return "HELD_BERRY", 10 end,
    itemDef = function() return { name = "BERRY" } end,
    monName = function() return "A" end,
    heal = function(_, mon, amount)
      healed = amount
      mon.hp = (mon.hp or 0) + amount
    end,
    emit = function() end,
  }
  local mon = { hp = hp, maxHp = maxHp, item = "BERRY" }
  Battle.tickHeldItem(battle, mon)
  return healed, mon.item
end

local healed, item = eat(50, 100)
assertEq(healed, 10, "gen2 half eats")
assertEq(item, nil, "gen2 berry consumed")
healed = eat(51, 100)
assertEq(healed, nil, "gen2 above half waits")
Effects.BERRY_HP_DIV = 4
healed, item = eat(25, 100)
assertEq(healed, 10, "gen2 quarter eats")
healed = eat(26, 100)
assertEq(healed, nil, "gen2 above quarter waits")
Effects.BERRY_HP_DIV = 2

local ItemsData = require("src.core.game3.items_data")
ItemsData.info = function() error("no pack") end
local Rules = require("src.core.game3.battle.rules")
local HeldItems = require("src.core.game3.battle.held_items")

local function berry(itemId, hp, maxHp)
  local healed
  local mon = { item = itemId, hp = hp, mon = { hp = hp, maxHp = maxHp } }
  local ad = {
    hp = function(_, b) return b.hp end,
    maxHp = function() return maxHp end,
    heal = function(_, b, amount)
      healed = amount
      b.hp = b.hp + amount
    end,
    sayText = function() end,
    playAnim = function() end,
    ownSide = function() end,
    abilityOf = function() return nil end,
  }
  local used = HeldItems.normal(ad, mon)
  return used, healed, mon.item
end

local used, amount, left = berry(139, 50, 100)
assertEq(used, true, "oran at half")
assertEq(amount, 10, "oran heals 10")
assertEq(left, 0, "oran consumed")
used = berry(139, 51, 100)
assertEq(used, false, "oran above half")
used, amount = berry(143, 50, 100)
assertEq(used, true, "figy at half")
assertEq(amount, 12, "figy heals an eighth")
Rules.residual.berryHpDiv = 4
used = berry(139, 25, 100)
assertEq(used, true, "oran at a quarter")
used = berry(139, 26, 100)
assertEq(used, false, "oran above a quarter")
used, amount = berry(143, 25, 100)
assertEq(used, true, "figy at a quarter")
assertEq(amount, 12, "figy amount unchanged")
Rules.residual.berryHpDiv = 2

local Abilities = require("src.core.game3.battle.abilities")
local foe = { stages = { attack = 0 }, substituteHP = 0 }
local user = { ability = "INTIMIDATE", expIntimidatePending = true }
local ad = {
  activeBattlers = function() return { user } end,
  abilityOf = function(_, b) return b.ability end,
  isFainted = function() return false end,
  foeOf = function() return foe end,
  ownSide = function() return {} end,
  playAnim = function() end,
  sayText = function() end,
  _st = {},
}
assertEq(Abilities.runIntimidate(ad), true, "intimidate")
assertEq(foe.stages.attack, -1, "drops one")
Abilities.INTIMIDATE_DROP = 2
user.expIntimidatePending = true
Abilities.runIntimidate(ad)
assertEq(foe.stages.attack, -3, "edited drop")
Abilities.INTIMIDATE_DROP = 0
user.expIntimidatePending = true
local before = foe.stages.attack
Abilities.runIntimidate(ad)
assertEq(foe.stages.attack, before, "zero drop")
Abilities.INTIMIDATE_DROP = 1

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, residualRules = { berryDiv = 4 } })
  assert(main:find("Effects.BERRY_HP_DIV = 4", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, residualRules = { berryDiv = 4 } })
  assert(not main:find("BERRY_HP_DIV", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local residual = { version = version, generation = 3, gen3Residual = { berryHpDiv = 4 } }
  assert(Gen3Native.used(residual), version .. " residual")
  local out = {}
  Gen3BattleRules.emitResiduals(residual, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Rules.residual.berryHpDiv = 4", 1, true), version)
  local rules = { version = version, generation = 3, gen3BattleRules = { intimidateDrop = 2 } }
  assert(Gen3Native.used(rules), version .. " intimidate")
  out = {}
  Gen3BattleRules.emit(rules, function() return "{ intimidateDrop = 2 }" end, out)
  chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Abilities.INTIMIDATE_DROP = battleRules.intimidateDrop", 1, true), version)
end

print("PASS berry threshold")
