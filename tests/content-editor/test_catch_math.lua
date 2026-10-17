-- Catch checks keep each generation's HP formula until a coefficient changes.

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

local Gen1 = require("src.battle.Catching")
local mon = { hp = 100, stats = { hp = 100 } }
local def = { catchRate = 45 }
local function roll()
  local n = 0
  return function()
    n = n + 1
    if n == 1 then return 0 end
    return 85
  end
end
assertEq(Gen1.attempt("POKE_BALL", mon, def, roll()), true, "gen1 cart")
Gen1.HP_DIV = 2
assertEq(Gen1.attempt("POKE_BALL", mon, def, roll()), false, "gen1 hp divisor")
Gen1.HP_DIV = 4

local Gen2 = require("src.battle.gen2.Catching")
local function gen2(hp)
  return Gen2.rate({ ball = "POKE_BALL", maxHp = 40, hp = hp, catchRate = 45 })
end
assertEq(gen2(20), 30, "gen2 cart")
Gen2.HP_CUR_MULT = 0
assertEq(gen2(50), 45, "gen2 current hp")
Gen2.HP_CUR_MULT = 2

local Gen3 = require("src.core.game3.battle.catching")
local foe = { mon = { hp = 50, maxHp = 100 } }
assertEq(Gen3.catchOdds(4, foe), 30, "gen3 cart")
Gen3.HP_CUR_MULT = 0
assertEq(Gen3.catchOdds(4, foe), 45, "gen3 current hp")
Gen3.HP_CUR_MULT = 2
foe.status = "SLP"
assertEq(Gen3.catchOdds(4, foe), 60, "gen3 sleep")
Gen3.SLEEP_NUM = 1
assertEq(Gen3.catchOdds(4, foe), 30, "gen3 sleep numerator")
Gen3.SLEEP_NUM = 2
local _, shakes = Gen3.tryCatch(1, foe, nil, nil, function() return 0 end)
assertEq(shakes, 4, "gen3 shakes")
Gen3.SHAKE_TRIES = 2
_, shakes = Gen3.tryCatch(1, foe, nil, nil, function() return 0 end)
assertEq(shakes, 2, "gen3 shake tries")
Gen3.SHAKE_TRIES = 4

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1,
  catchMath = { hpDiv = 2, shake1 = 20 },
})
assert(red:find("local Catching = require(\"src.battle.Catching\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Catching", 1, true), "red skips gen2")
assert(red:find("Catching.HP_DIV = 2", 1, true), "red divisor")
assert(red:find("Catching.SHAKE_1 = 20", 1, true), "red band")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    catchMath = { curMult = 0, shift = 8 },
  })
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
  assert(not main:find("require(\"src.battle.Catching\")", 1, true), version .. " skips gen1")
  assert(main:find("Catching.HP_CUR_MULT = 0", 1, true), version)
  assert(main:find("Catching.HP_SHIFT = 8", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3CatchMath = { curMult = 0, shakeTries = 2 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitCatchMath(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Catching.HP_CUR_MULT = 0", 1, true), version)
  assert(chunk:find("Catching.SHAKE_TRIES = 2", 1, true), version)
end

require("Rules")
print("PASS catch math")
