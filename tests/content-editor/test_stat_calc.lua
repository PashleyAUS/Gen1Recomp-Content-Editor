-- Stat calculation keeps each generation's cart formula until a coefficient changes.

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

local Stats = require("src.pokemon.Stats")
local function gen1()
  return Stats.calc({
    baseStats = { hp = 100, attack = 100, defense = 100, speed = 100, special = 100 },
  }, 100, { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }, {})
end
local g1 = gen1()
assertEq(g1.attack, 205, "gen1 attack")
assertEq(g1.hp, 310, "gen1 hp")
Stats.BASE_MULT = 1
assertEq(gen1().attack, 105, "gen1 multiplier")
Stats.BASE_MULT = 2
Stats.HP_LEVEL = 0
assertEq(gen1().hp, 210, "gen1 hp level")
Stats.HP_LEVEL = 1

local Mon = require("src.battle.gen2.Mon")
local function gen2()
  return Mon.stats({
    hp = 100, attack = 100, defense = 100, speed = 100,
    specialAttack = 100, specialDefense = 100,
  }, { attack = 0, defense = 0, speed = 0, special = 0 }, 100, {})
end
local g2 = gen2()
assertEq(g2.attack, 205, "gen2 attack")
assertEq(g2.hp, 310, "gen2 hp")
Mon.DV_MULT = 4
assertEq(gen2().attack, 205, "gen2 zero dv")
local withDv = Mon.stats({
  hp = 100, attack = 100, defense = 100, speed = 100,
  specialAttack = 100, specialDefense = 100,
}, { attack = 15, defense = 0, speed = 0, special = 0 }, 100, {})
assertEq(withDv.attack, 265, "gen2 dv multiplier")
Mon.DV_MULT = 2

local Pokemon = require("src.core.game3.pokemon")
local saved = Pokemon.stats
Pokemon.stats = function()
  return { hp = 100, atk = 100, def = 100, spe = 100, spa = 100, spd = 100 }
end
local function gen3(personality)
  return Pokemon.calcStats(1, 100, {}, {}, personality or 0)
end
assertEq(gen3(0).attack, 205, "gen3 attack")
assertEq(gen3(0).maxHp, 310, "gen3 hp")
assertEq(gen3(3).attack, 225, "gen3 nature")
Pokemon.STAT_BASE_MULT = 1
assertEq(gen3(0).attack, 105, "gen3 multiplier")
Pokemon.STAT_BASE_MULT = 2
Pokemon.NATURE_UP = 120
assertEq(gen3(3).attack, 246, "gen3 nature percent")
Pokemon.NATURE_UP = nil
assertEq(Pokemon.calcStats(303, 100, {}, {}, 0).maxHp, 1, "shedinja")
Pokemon.stats = saved

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1,
  statCalc = { baseMult = 1, evCap = 100 },
})
assert(red:find("local Stats = require(\"src.pokemon.Stats\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Mon", 1, true), "red skips gen2")
assert(red:find("Stats.BASE_MULT = 1", 1, true), "red multiplier")
assert(red:find("Stats.EV_CAP = 100", 1, true), "red cap")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    statCalc = { dvMult = 4, hpLevel = 0 },
  })
  assert(main:find("local Mon = require(\"src.battle.gen2.Mon\")", 1, true), version)
  assert(not main:find("src.pokemon.Stats", 1, true), version .. " skips gen1")
  assert(main:find("Mon.DV_MULT = 4", 1, true), version)
  assert(main:find("Mon.HP_LEVEL = 0", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3StatCalc = { natureUp = 120, statAdd = 10 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitStatCalc(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Pokemon.NATURE_UP = 120", 1, true), version)
  assert(chunk:find("Pokemon.STAT_ADD = 10", 1, true), version)
end

require("Rules")
print("PASS stat calc")
