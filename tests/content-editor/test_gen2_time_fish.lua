-- Gen 2 day/night fishing groups save for Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")

local session = {
  data = { encounters = {
    timeFishGroups = {
      [0] = {
        day = { species = "CORSOLA", level = 20 },
        nite = { species = "STARYU", level = 20 },
      },
    },
    fishGroups = {
      FISHGROUP_OCEAN = {
        old = {
          { chance = 255, species = "CORSOLA", level = 20, timeGroup = 0,
            day = { species = "CORSOLA", level = 20 },
            nite = { species = "STARYU", level = 20 } },
        },
        good = {},
        super = {},
      },
      FISHGROUP_NONE = {
        old = { { chance = 255, species = "MAGIKARP", level = 10 } },
        good = {},
        super = {},
      },
    },
  } },
  project = {},
}
local shown = EncounterEdit.vanillaTimeFish(session)
assert(shown[0].day.species == "CORSOLA", "reads the cache group")
assert(session.project.timeFishGroups == nil, "viewing the groups does not copy them")

local rows = EncounterEdit.ensureTimeFish(session)
rows[0].day.species = "DRATINI"
rows[0].day.level = 30
assert(session.data.encounters.timeFishGroups[0].day.species == "CORSOLA",
  "the vanilla group stays put")

local function emit(game)
  local project = State.blankProject("time_fish")
  project.game = game
  project.timeFishGroups = {
    [0] = {
      day = { species = "DRATINI", level = 30 },
      nite = { species = "STARYU", level = 20 },
    },
  }
  return Writer.emitMain(project, session.data)
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find('encounters:patch("timeFishGroups"', 1, true), game .. " writes the groups")
  assert(main:find("[0]", 1, true), game .. " keeps group 0")
  local fishAt = main:find('encounters:patch("fishGroups"', 1, true)
  assert(fishAt, game .. " rewrites rod slots that use the group")
  assert(main:find("DRATINI", fishAt, true), game .. " day species reaches the rod")
  assert(main:find("FISHGROUP_OCEAN", fishAt, true), game)
  assert(not main:find("FISHGROUP_NONE", fishAt, true), game .. " leaves other groups alone")
end

local red = State.blankProject("time_fish")
red.game = "red"
red.timeFishGroups = { [0] = { day = { species = "DRATINI", level = 30 }, nite = { species = "STARYU", level = 20 } } }
local redMain = Writer.emitMain(red, session.data)
assert(not redMain:find("timeFishGroups", 1, true), "Red has no time-of-day fishing")

local untouched = State.blankProject("time_fish")
untouched.game = "silver"
local plain = Writer.emitMain(untouched, session.data)
assert(not plain:find("timeFishGroups", 1, true), "an unedited group stays vanilla")

print("PASS gen2 time fish")
