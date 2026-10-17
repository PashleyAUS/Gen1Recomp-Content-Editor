-- Accuracy keeps each generation's cart roll until the range is edited.

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
local move = { accuracy = 100 }
local atk = { stages = {} }
local def = { stages = {} }
local rules = { oneIn256Miss = true }
assertEq(Gen1.accuracyThreshold(rules, move, atk, def), 255, "gen1 scale")
local seen
local hit = Gen1.accuracyRoll(rules, move, atk, def, function(lo, hi)
  seen = { lo, hi }
  return 254
end)
assertEq(seen[1], 0, "gen1 roll low")
assertEq(seen[2], 255, "gen1 roll high")
assertEq(hit, true, "gen1 hit")
Gen1.ACC_NUM = 50
assertEq(Gen1.accuracyThreshold(rules, move, atk, def), 50, "gen1 numerator")
Gen1.ACC_NUM = 255
Gen1.ACC_SPAN = 128
hit = Gen1.accuracyRoll(rules, move, atk, def, function()
  error("span covers the threshold")
end)
assertEq(hit, true, "gen1 span")
Gen1.ACC_SPAN = 256

local Gen2 = require("src.battle.gen2.Damage")
local Battle = require("src.battle.gen2.Battle")
hit = Gen2.rollHit(100, 0, 0, function(n)
  seen = n
  return 0
end)
assertEq(seen, 100, "gen2 span")
assertEq(hit, true, "gen2 hit")
Gen2.HIT_MAX = 40
hit = Gen2.rollHit(100, 0, 0, function() return 40 end)
assertEq(hit, false, "gen2 cap")
Gen2.HIT_MAX = 100
local powder = { heldEffect = function() return "HELD_BRIGHTPOWDER", 20 end }
assertEq(Battle.moveAccuracy(powder, 100, {}), 93, "gen2 powder")
Gen2.POWDER_DEN = 100
assertEq(Battle.moveAccuracy(powder, 100, {}), 80, "gen2 powder scale")
Gen2.POWDER_DEN = 256

local Gen3 = require("src.core.game3.battle.damage")
local Engine = require("src.core.game3.battle.engine")
local ad = {
  rng = function()
    return function(lo, hi)
      seen = { lo, hi }
      return hi
    end
  end,
}
assertEq(Engine.accuracyHit(ad, 100), true, "gen3 cart")
assertEq(seen[1], 1, "gen3 low")
assertEq(seen[2], 100, "gen3 high")
Gen3.HIT_HI = 200
assertEq(Engine.accuracyHit(ad, 100), false, "gen3 high edited")
assertEq(seen[2], 200, "gen3 edited range")
Gen3.HIT_HI = 100

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1,
  accuracyRules = { accNum = 200, accSpan = 128 },
})
assert(red:find("require(\"src.battle.Damage\")", 1, true), "red module")
assert(not red:find("src.battle.gen2.Damage", 1, true), "red skips gen2")
assert(red:find("Damage.ACC_NUM = 200", 1, true), "red numerator")
assert(red:find("Damage.ACC_SPAN = 128", 1, true), "red span")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    accuracyRules = { hitMax = 80, powderDen = 128 },
  })
  assert(main:find("src.battle.gen2.Damage", 1, true), version)
  assert(not main:find("require(\"src.battle.Damage\")", 1, true), version .. " skips gen1")
  assert(main:find("Damage.HIT_MAX = 80", 1, true), version)
  assert(main:find("Damage.POWDER_DEN = 128", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Accuracy = { hitHi = 80 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitAccuracy(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.HIT_HI = 80", 1, true), version)
end

require("Rules")
print("PASS accuracy")
