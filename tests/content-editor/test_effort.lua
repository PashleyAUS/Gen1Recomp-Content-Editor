-- Effort gains keep the cart caps and multipliers until they are edited.

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
local Experience = require("src.battle.Experience")
local data = {
  pokemon = {
    A = {
      growthRate = "MEDIUM_FAST",
      baseStats = { hp = 10, attack = 10, defense = 10, speed = 10, special = 10 },
      baseExp = 1,
    },
  },
  constants = { levelCap = 5 },
}
local function gen1Mon()
  return {
    species = "A", level = 5, exp = 1000000, hp = 20,
    stats = { hp = 20, attack = 10, defense = 10, speed = 10, special = 10 },
    dvs = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
    statExp = { hp = 65530, attack = 0, defense = 0, speed = 0, special = 0 },
  }
end
local defeated = {
  baseExp = 1,
  baseStats = { hp = 10, attack = 1, defense = 1, speed = 1, special = 1 },
}
local mon = gen1Mon()
Experience.apply(data, mon, defeated, 5, false, 1, false, { defer = true })
assertEq(mon.statExp.hp, 65535, "gen1 cap")
Stats.MAX_STAT_EXP = 65532
mon = gen1Mon()
Experience.apply(data, mon, defeated, 5, false, 1, false, { defer = true })
assertEq(mon.statExp.hp, 65532, "gen1 edited cap")
Stats.MAX_STAT_EXP = 65535

local Mon = require("src.battle.gen2.Mon")
local loser = { baseStats = { hp = 10, attack = 8, defense = 6, speed = 4, specialAttack = 12 } }
local gains = Mon.gainStatExp({ statExp = {} }, loser, 1, true, true)
assertEq(gains.hp, 10, "gen2 pokerus and share")
Mon.STAT_EXP_POKERUS = 3
gains = Mon.gainStatExp({ statExp = {} }, loser, 1, true, false)
assertEq(gains.hp, 30, "gen2 pokerus")
Mon.STAT_EXP_POKERUS = 2
Mon.MAX_STAT_EXP = 12
gains = Mon.gainStatExp({ statExp = { hp = 10 } }, loser, 1, false, false)
assertEq(gains.hp, 10, "gen2 gain before cap")
local held = { statExp = { hp = 10 } }
Mon.gainStatExp(held, loser, 1, false, false)
assertEq(held.statExp.hp, 12, "gen2 cap")
Mon.MAX_STAT_EXP = 65535

local Pokemon = require("src.core.game3.pokemon")
Pokemon.evYield = function()
  return { hp = 2, atk = 0, def = 0, spe = 0, spa = 0, spd = 0 }
end
local function fresh(extra)
  local row = { evs = {} }
  for k, v in pairs(extra or {}) do row[k] = v end
  return row
end
assertEq(Pokemon.gainEVs(fresh(), 1), 2, "gen3 yield")
assertEq(Pokemon.gainEVs(fresh({ pokerus = 1 }), 1), 4, "gen3 pokerus")
Pokemon.POKERUS_EV_MULT = 3
assertEq(Pokemon.gainEVs(fresh({ pokerus = 1 }), 1), 6, "gen3 pokerus edited")
Pokemon.POKERUS_EV_MULT = 2
assertEq(Pokemon.gainEVs(fresh({ item = 181 }), 1), 4, "gen3 macho")
Pokemon.MACHO_EV_MULT = 3
assertEq(Pokemon.gainEVs(fresh({ item = 181 }), 1), 6, "gen3 macho edited")
Pokemon.MACHO_EV_MULT = 2
Pokemon.MAX_TOTAL_EVS = 3
assertEq(Pokemon.gainEVs(fresh({ evs = { hp = 2 } }), 1), 1, "gen3 total")
Pokemon.MAX_TOTAL_EVS = 510

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, effort = { cap = 1000 },
})
assert(red:find("local Stats = require(\"src.pokemon.Stats\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Mon", 1, true), "red skips gen2")
assert(red:find("Stats.MAX_STAT_EXP = 1000", 1, true), "red cap")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    effort = { cap = 1000, pokerus = 3 },
  })
  assert(main:find("local Mon = require(\"src.battle.gen2.Mon\")", 1, true), version)
  assert(not main:find("src.pokemon.Stats", 1, true), version .. " skips gen1")
  assert(main:find("Mon.MAX_STAT_EXP = 1000", 1, true), version)
  assert(main:find("Mon.STAT_EXP_POKERUS = 3", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Effort = { total = 600, macho = 3 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitEffort(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Pokemon.MAX_TOTAL_EVS = 600", 1, true), version)
  assert(chunk:find("Pokemon.MACHO_EV_MULT = 3", 1, true), version)
end

require("Rules")
print("PASS effort")
