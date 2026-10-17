-- The damage formula keeps the cart level and stat steps until they are edited.

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

local Gen1 = require("src.battle.Damage")
local function gen1Hit()
  return Gen1.compute({}, {
    mon = { level = 100 },
    curStats = { attack = 100, defense = 100 },
    stages = {},
    curTypes = {},
  }, {
    curStats = { attack = 100, defense = 100 },
    stages = {},
    curTypes = {},
  }, { power = 40, category = "physical", type = "NORMAL" }, {
    forceCrit = false, typeless = true, rng = function() return 1 end,
  })
end
assertEq(gen1Hit(), 35, "gen1 cart")
Gen1.LEVEL_NUM = 4
assertEq(gen1Hit(), 67, "gen1 level numerator")
Gen1.LEVEL_NUM = 2
Gen1.STAT_DIV = 25
assertEq(gen1Hit(), 69, "gen1 stat divisor")
Gen1.STAT_DIV = 50
Gen1.MIN_DAMAGE = 5
assertEq(gen1Hit(), 38, "gen1 minimum")
Gen1.MIN_DAMAGE = 2

local Gen2 = require("src.battle.gen2.Damage")
assertEq(Gen2.base(100, 40, 100, 100), 33, "gen2 cart")
Gen2.LEVEL_DEN = 4
assertEq(Gen2.base(100, 40, 100, 100), 41, "gen2 level divisor")
Gen2.LEVEL_DEN = 5
Gen2.LEVEL_ADD = 0
assertEq(Gen2.base(100, 40, 100, 100), 32, "gen2 level add")
Gen2.LEVEL_ADD = 2

local Gen3 = require("src.core.game3.battle.damage")
local Types = require("src.core.game3.battle.types")
local function gen3Hit()
  local mon = { level = 100, attack = 100, defense = 100, spAtk = 100, spDef = 100 }
  return Gen3.base({ mon = mon, stages = {} }, { mon = mon, stages = {} },
    { power = 40, type = Types.ID.NORMAL }, {})
end
assertEq(gen3Hit(), 35, "gen3 cart")
Gen3.LEVEL_ADD = 0
assertEq(gen3Hit(), 34, "gen3 level add")
Gen3.LEVEL_ADD = 2
Gen3.MIN_DAMAGE = 0
assertEq(gen3Hit(), 33, "gen3 minimum")
Gen3.MIN_DAMAGE = 2

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1,
  formulaRules = { levelNum = 4, statDiv = 25 },
})
assert(red:find("require(\"src.battle.Damage\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Damage", 1, true), "red skips gen2")
assert(red:find("Damage.LEVEL_NUM = 4", 1, true), "red numerator")
assert(red:find("Damage.STAT_DIV = 25", 1, true), "red divisor")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    formulaRules = { levelDen = 4, minDamage = 1, maxDamage = 500 },
  })
  assert(main:find("src.battle.gen2.Damage", 1, true), version)
  assert(not main:find("require(\"src.battle.Damage\")", 1, true), version .. " skips gen1")
  assert(main:find("Damage.LEVEL_DEN = 4", 1, true), version)
  assert(main:find("Damage.MIN_DAMAGE = 1", 1, true), version)
  assert(main:find("Damage.MAX_DAMAGE = 500", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Formula = { statDiv = 25, minDamage = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitFormula(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.STAT_DIV = 25", 1, true), version)
  assert(chunk:find("Damage.MIN_DAMAGE = 1", 1, true), version)
end

require("Rules")
print("PASS formula")
