-- Walking friendship. Gen 2 pays when the step counter wraps, and then only
-- every other wrap. Gen 3 pays every 128 steps, then may skip the roll.
-- Gen 1 has no walking friendship.

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

local Happiness = require("src.core.gen2.Happiness")
local save = { party = { { happiness = 10 } }, stepCount = 0, happinessStepCount = 0 }
Happiness.STEP_SKIP = 1
assertEq(Happiness.stepCycle(save), true, "gen2 every wrap pays")
assertEq(save.party[1].happiness, 11, "gen2 gain")
Happiness.STEP_GAIN = 0
save.happinessStepCount = 0
Happiness.stepCycle(save)
assertEq(save.party[1].happiness, 11, "gen2 gain zero")
Happiness.STEP_GAIN = 1
Happiness.STEP_SKIP = 0
save.happinessStepCount = 0
assertEq(Happiness.stepCycle(save), false, "gen2 skip zero")
assertEq(save.party[1].happiness, 11, "gen2 skip zero leaves it")
Happiness.STEP_SKIP = 2
save.happinessStepCount = 0
assertEq(Happiness.stepsToGain(save), 512, "gen2 cart distance")
Happiness.STEP_SKIP = 2

local Steps = require("src.core.game3.step_events")
local Pokemon = require("src.core.game3.pokemon")
Pokemon.WALK_SKIP_MOD = 1
Steps.HAPPINESS_PERIOD = 1
local session = {
  version = "firered",
  party = { { species = 25, friendship = 70, hp = 20, level = 5 } },
  vars = {},
}
local ok, err = pcall(Steps.onStepTaken, session, {})
if not ok then error("gen3 walk: " .. tostring(err)) end
assertEq(session.party[1].friendship, 71, "gen3 every step")
Steps.HAPPINESS_PERIOD = 0
session.party[1].friendship = 70
session.happinessSteps = 0
session.vars = {}
Steps.onStepTaken(session, {})
assertEq(session.party[1].friendship, 70, "gen3 period zero")
Steps.HAPPINESS_PERIOD = 128
Pokemon.WALK_SKIP_MOD = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, happiness = { stepSkip = 0, stepGain = 0 } })
  assert(main:find("stepSkip = 0", 1, true), version)
  assert(main:find("stepGain = 0", 1, true), version)
  assert(main:find("Happiness.STEP_SKIP", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, happiness = { stepSkip = 0 } })
  assert(not main:find("STEP_SKIP", 1, true), version)
end

local Rules = require("Gen3BattleRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald", "firered", "leafgreen" }) do
  local out = {}
  Rules.emitFriendship({ version = version, generation = 3, gen3Friendship = { walkSteps = 0 } }, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("HAPPINESS_PERIOD = 0", 1, true), version)
  assert(chunk:find("src.core.game3.step_events", 1, true), version)
end

print("PASS walk friendship")
