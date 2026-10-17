-- Egg ticks follow the edited step count. Zero is a real cycle count.

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
local save = { party = { { isEgg = true, eggSteps = 1 } } }
for _ = 1, 127 do
  assertEq(Breeding.step({}, save, function() return 0 end), nil, "gen2 quiet")
end
assertEq(Breeding.step({}, save, function() return 0 end), "hatch", "gen2 tick at 128")
assertEq(save.party[1].eggSteps, 0, "gen2 egg reached 0")

save = { party = { { isEgg = true, eggSteps = 1 } } }
local data = { breeding = { stepCycle = 10, eggStepPhase = 4 } }
for _ = 1, 3 do
  assertEq(Breeding.step(data, save, function() return 0 end), nil, "gen2 short quiet")
end
assertEq(Breeding.step(data, save, function() return 0 end), "hatch", "gen2 tick at 4")
assertEq(Breeding.stepsToHatch({ isEgg = true, eggSteps = 2 }, data), 20, "gen2 steps left")

local Daycare = require("src.core.game3.daycare")
local session = { party = { { isEgg = true, eggCycles = 5, species = 1 } } }
assertEq(Daycare.tickEggCycles(session), nil, "gen3 still cycling")
assertEq(session.party[1].eggCycles, 4, "gen3 plain 1")
Daycare.PLAIN_CYCLES = 0
session.party[1].eggCycles = 5
session.party[1].friendship = 5
Daycare.tickEggCycles(session)
assertEq(session.party[1].eggCycles, 5, "gen3 plain 0 removes nothing")
Daycare.PLAIN_CYCLES = 3
session.party[1].eggCycles = 5
session.party[1].friendship = 5
Daycare.tickEggCycles(session)
assertEq(session.party[1].eggCycles, 2, "gen3 plain 3")
session.party[1].eggCycles = 1
session.party[1].friendship = 1
Daycare.tickEggCycles(session)
assertEq(session.party[1].eggCycles, 0, "gen3 remainder still loses 1")
Daycare.PLAIN_CYCLES = 1

local G3Breed = require("src.core.game3.breeding")
Daycare.STEP_CYCLE = 10
assertEq(G3Breed.tryProduceEgg({}, { steps = { 0, 3 } }, 2), false, "gen3 egg check waits")
Daycare.STEP_CYCLE = 256

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    breeding = { stepCycle = 10, eggStepPhase = 4 },
  })
  assert(main:find("stepCycle", 1, true), version .. " step cycle")
  assert(main:find("eggStepPhase", 1, true), version .. " phase")
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  breeding = { stepCycle = 10 },
})
assert(not red:find("stepCycle", 1, true), "red has no eggs")

local Native = require("Gen3Native")
local Hatch = require("Gen3Breeding")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Hatch = { stepCycle = 10, flameCycles = 0, plainCycles = 4 } }
  assert(Native.used(p), version)
  local out = {}
  Hatch.emitHatch(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("STEP_CYCLE = 10", 1, true), version)
  assert(chunk:find("FLAME_CYCLES = 0", 1, true), version)
  assert(chunk:find("PLAIN_CYCLES = 4", 1, true), version)
end

print("PASS egg cycle")
