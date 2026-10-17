-- Day-Care experience per step. One point per step is the cart. Zero adds nothing.

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

local Breeding = require("src.core.gen2.Breeding")
local function deposited(exp)
  return {
    dayCare = {
      man = { mon = { level = 5, experience = exp } },
      lady = { mon = { level = 5, experience = exp } },
      compatible = false,
    },
  }
end

local save = deposited(10)
Breeding.dayCareStep({}, save, function() return 0 end)
assertEq(save.dayCare.man.mon.experience, 11, "gen2 one point")
assertEq(save.dayCare.lady.mon.experience, 11, "gen2 both parents")

save = deposited(10)
Breeding.dayCareStep({ breeding = { expPerStep = 5 } }, save, function() return 0 end)
assertEq(save.dayCare.man.mon.experience, 15, "gen2 five points")

save = deposited(10)
Breeding.dayCareStep({ breeding = { expPerStep = 0 } }, save, function() return 0 end)
assertEq(save.dayCare.man.mon.experience, 10, "gen2 zero adds nothing")

local Daycare = require("src.core.game3.daycare")
local Experience = require("src.core.game3.battle.experience")
local function monAt(level)
  return { growthRate = 0, level = level, exp = Experience.expForLevel(0, level), species = 1 }
end

local base = monAt(5)
local cart = Daycare.levelAfterSteps(base, 100)
assertEq(cart, Experience.levelForExp(0, base.exp + 100), "gen3 one point per step")
Daycare.EXP_PER_STEP = 5
assertEq(Daycare.levelAfterSteps(base, 100), Experience.levelForExp(0, base.exp + 500), "gen3 five points")
Daycare.EXP_PER_STEP = 0
assertEq(Daycare.levelAfterSteps(base, 100), 5, "gen3 zero adds nothing")
Daycare.EXP_PER_STEP = 1

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    breeding = { expPerStep = 5 },
  })
  assert(main:find("expPerStep", 1, true), version)
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  breeding = { expPerStep = 5 },
})
assert(not red:find("expPerStep", 1, true), "red has no day care pair")

local Hatch = require("Gen3Breeding")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Hatch.emitHatch({ version = version, generation = 3, gen3Hatch = { expPerStep = 0 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("EXP_PER_STEP = 0", 1, true), version)
end

print("PASS daycare exp")
