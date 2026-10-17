-- Gen 2 swarms (Gold, Silver, Crystal) and Crystal's asleep headbutt list.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")

local session = {
  data = { encounters = {
    swarmGrass = {
      ROUTE_29 = {
        map = "ROUTE_29",
        rates = { MORN = 15, DAY = 15, NITE = 15 },
        slots = {
          MORN = { { level = 2, species = "PIDGEY" } },
          DAY = { { level = 2, species = "PIDGEY" } },
          NITE = { { level = 2, species = "RATTATA" } },
        },
      },
    },
    swarmWater = {
      ROUTE_32 = {
        map = "ROUTE_32", rate = 10,
        slots = { { level = 15, species = "QWILFISH" } },
      },
    },
    treeMonsAsleep = {
      MORN = { "HERACROSS" },
      DAY = { "HERACROSS" },
      NITE = { "CATERPIE" },
    },
  } },
  project = {},
}
local ids = EncounterEdit.swarmMapIds(session)
assert(ids[1] == "ROUTE_29" and ids[2] == "ROUTE_32", "lists both swarm maps")
assert(session.project.swarmGrass == nil, "viewing a swarm does not copy it")

local grass = EncounterEdit.ensureSwarm(session, "ROUTE_29", "grass")
grass.slots.DAY[1].species = "DITTO"
assert(session.data.encounters.swarmGrass.ROUTE_29.slots.DAY[1].species == "PIDGEY",
  "the vanilla swarm stays put")
EncounterEdit.clearSwarm(session, "ROUTE_32", "water")
assert(session.project.swarmWater.ROUTE_32 == false, "removing a swarm marks it deleted")
local left = EncounterEdit.swarmMapIds(session)
assert(left[1] == "ROUTE_29" and left[2] == nil, "a deleted water swarm leaves the list")

local function emit(game, fill)
  local project = State.blankProject("swarms")
  project.game = game
  fill(project)
  return Writer.emitMain(project, {})
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game, function(project)
    project.swarmGrass = {
      ROUTE_29 = {
        map = "ROUTE_29",
        rates = { MORN = 15, DAY = 15, NITE = 15 },
        slots = { DAY = { { level = 2, species = "DITTO" } } },
      },
    }
    project.swarmWater = { ROUTE_32 = false }
  end)
  assert(main:find('encounters:patch("swarmGrass"', 1, true), game .. " writes the grass swarm")
  assert(main:find("DITTO", 1, true), game)
  assert(main:find('encounters:patch("swarmWater", { ["ROUTE_32"] = mod.DELETE })', 1, true),
    game .. " removes the water swarm")
end

local red = emit("red", function(project)
  project.swarmGrass = { ROUTE_29 = { map = "ROUTE_29", rates = {}, slots = {} } }
  project.treeMonsAsleep = { DAY = { "HERACROSS" } }
end)
assert(not red:find("swarmGrass", 1, true), "Red has no swarms")
assert(not red:find("treeMonsAsleep", 1, true), "Red has no asleep tree list")

local asleep = EncounterEdit.vanillaAsleep(session)
assert(asleep.NITE[1] == "CATERPIE", "reads the cache asleep list")
local rows = EncounterEdit.ensureAsleep(session)
rows.NITE[1] = "WEEDLE"
assert(session.data.encounters.treeMonsAsleep.NITE[1] == "CATERPIE",
  "the vanilla asleep list stays put")

local crystal = emit("crystal", function(project)
  project.treeMonsAsleep = { MORN = { "HERACROSS" }, DAY = { "HERACROSS" }, NITE = { "WEEDLE" } }
end)
assert(crystal:find('encounters:patch("treeMonsAsleep"', 1, true), "Crystal saves the asleep list")
assert(crystal:find("WEEDLE", 1, true))

local gold = emit("gold", function(project)
  project.treeMonsAsleep = { DAY = { "HERACROSS" } }
end)
assert(not gold:find("treeMonsAsleep", 1, true),
  "Gold and Silver do not use the asleep headbutt list")

local Encounter = require("src.battle.gen2.Encounter")
assert(Encounter.treeSleepTurns() == 7, "a headbutt sleeper rests 7 turns")
Encounter.TREEMON_SLEEP_TURNS = 0
assert(Encounter.treeSleepTurns() == 0, "zero turns wakes it at once")
Encounter.TREEMON_SLEEP_TURNS = 7
local crystalSleep = emit("crystal", function(project)
  project.treeSleepTurns = 0
end)
assert(crystalSleep:find("TREEMON_SLEEP_TURNS = 0", 1, true), "Crystal saves the sleep length")
for _, game in ipairs({ "gold", "silver", "red" }) do
  local main = emit(game, function(project)
    project.treeSleepTurns = 0
  end)
  assert(not main:find("TREEMON_SLEEP_TURNS", 1, true), game)
end

local untouched = State.blankProject("swarms")
untouched.game = "silver"
local plain = Writer.emitMain(untouched, {})
assert(not plain:find("swarmGrass", 1, true), "an unedited swarm stays vanilla")

print("PASS gen2 swarms")
