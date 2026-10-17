-- Gen 2 friendship amounts are editable on Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local State = require("State")
local Writer = require("ModWriter")
local Happiness = require("src.core.gen2.Happiness")
local Evolution = require("src.core.gen2.Evolution")
local Catching = require("src.battle.gen2.Catching")
local Mon = require("src.battle.gen2.Mon")

local saved = {
  base = Happiness.BASE,
  friend = Happiness.FRIEND_BALL,
  evolve = Evolution.HAPPINESS_TO_EVOLVE,
  t1 = Happiness.THRESHOLD_1,
  step = Happiness.STEP_GAIN,
  row = { Happiness.CHANGES[1][1], Happiness.CHANGES[1][2], Happiness.CHANGES[1][3] },
  catch = Catching.FRIEND_BALL_HAPPINESS,
}

Happiness.BASE = 10
Happiness.FRIEND_BALL = 50
Catching.FRIEND_BALL_HAPPINESS = 50
Happiness.THRESHOLD_1 = 1
Happiness.STEP_GAIN = 4
Evolution.HAPPINESS_TO_EVOLVE = 30
Happiness.TO_EVOLVE = 30
Happiness.CHANGES[1] = { 9, 8, 7 }

local species = {
  name = "SENTRET",
  baseStats = { hp = 35, attack = 46, defense = 34, speed = 20,
    specialAttack = 35, specialDefense = 45 },
  types = { "NORMAL" },
}
local mon = Mon.new({ pokemon = { SENTRET = species } }, "SENTRET", 5)
assert(mon.happiness == 10, "a new mon uses the edited starting happiness")
assert(Happiness.delta("GAINLEVEL", 0) == 9, "the low tier uses the edited level-up amount")
assert(Happiness.forNewMon({ ball = "FRIEND_BALL" }) == 50, "Friend Ball uses the edited value")
assert(Catching.FRIEND_BALL_HAPPINESS == 50, "a catch reads the same Friend Ball value")
assert(Evolution.HAPPINESS_TO_EVOLVE == 30, "happiness evolutions use the edited line")

local walker = { party = { { happiness = 1 } }, happinessStepCount = 1 }
assert(Happiness.stepCycle(walker) == true, "the paying step still pays")
assert(walker.party[1].happiness == 5, "the walk gain is the edited amount")

Happiness.BASE = saved.base
Happiness.FRIEND_BALL = saved.friend
Catching.FRIEND_BALL_HAPPINESS = saved.catch
Happiness.THRESHOLD_1 = saved.t1
Happiness.STEP_GAIN = saved.step
Evolution.HAPPINESS_TO_EVOLVE = saved.evolve
Happiness.TO_EVOLVE = saved.evolve
Happiness.CHANGES[1] = saved.row
assert(Happiness.delta("GAINLEVEL", 0) == 5, "the cart level-up amount is restored")

local function emit(game)
  local project = State.blankProject("happiness")
  project.game = game
  project.happiness = {
    base = 0,
    stepGain = 0,
    toEvolve = 180,
    changes = { { 4, 3, 2 } },
  }
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("Happiness.BASE = happiness.base", 1, true), game .. " writes starting happiness")
  assert(main:find("stepGain = 0", 1, true), game .. " writes a zero walk gain")
  assert(main:find("Evolution.HAPPINESS_TO_EVOLVE = happiness.toEvolve", 1, true), game)
  assert(main:find("Happiness.CHANGES[i]", 1, true), game .. " writes the change rows")
end
local red = State.blankProject("happiness")
red.game = "red"
red.happiness = { base = 10 }
assert(not Writer.emitMain(red, {}):find("Happiness.BASE", 1, true), "Red has no Gen 2 friendship table")

print("PASS gen2 happiness")
