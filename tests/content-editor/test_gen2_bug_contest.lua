-- Gold, Silver, and Crystal Bug-Catching Contest pools save into encounters.bugContest.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")

local session = {
  data = { encounters = { bugContest = {
    { chance = 50, species = "CATERPIE", min = 7, max = 10 },
    { chance = 255, species = "VENOMOTH", min = 30, max = 40 },
  } } },
  project = {},
}
local vanilla = EncounterEdit.vanillaBugContest(session)
assert(vanilla[1].species == "CATERPIE" and vanilla[1].chance == 50, "reads the cache pool")
assert(session.project.bugContest == nil, "viewing the pool does not copy it")

local rows = EncounterEdit.ensureBugContest(session)
rows[1].species = "SCYTHER"
rows[1].chance = 80
assert(session.project.bugContest[1].species == "SCYTHER", "the first edit copies the pool")
assert(EncounterEdit.vanillaBugContest(session)[1].species == "CATERPIE", "vanilla stays put")

local function emitted(game, pool)
  local project = State.blankProject("bug_contest")
  project.game = game
  project.bugContest = pool
  return Writer.emitMain(project, {})
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emitted(game, {
    { chance = 80, species = "SCYTHER", min = 13, max = 14 },
    { chance = 255, species = "VENOMOTH", min = 30, max = 40 },
  })
  assert(main:find('encounters:override("bugContest"', 1, true), game .. " replaces the pool")
  assert(main:find("SCYTHER", 1, true), game)
  assert(main:find("chance = 255", 1, true), game .. " keeps the fallthrough row")
end

local red = emitted("red", {
  { chance = 80, species = "SCYTHER", min = 13, max = 14 },
})
assert(not red:find("bugContest", 1, true), "Red has no Bug-Catching Contest")

local untouched = State.blankProject("bug_contest")
untouched.game = "crystal"
local plain = Writer.emitMain(untouched, {})
assert(not plain:find("bugContest", 1, true), "an unedited pool stays vanilla")

local session = { project = {} }
local rules = EncounterEdit.contestRules(session)
assert(rules.balls == 20 and rules.minutes == 20, "vanilla contest is 20 balls and 20 minutes")
assert(session.project.bugContestRules == nil)
local edited = EncounterEdit.ensureContestRules(session)
edited.balls = 5
edited.minutes = 8
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local project = State.blankProject("bug_contest")
  project.game = game
  project.bugContestRules = { balls = 5, minutes = 8 }
  local main = Writer.emitMain(project, {})
  assert(main:find("BugContest.BALLS = 5", 1, true), game .. " park balls")
  assert(main:find("BugContest.MINUTES = 8", 1, true), game .. " contest minutes")
end
local redRules = State.blankProject("bug_contest")
redRules.game = "red"
redRules.bugContestRules = { balls = 5, minutes = 8 }
assert(not Writer.emitMain(redRules, {}):find("BugContest.BALLS", 1, true),
  "Red has no contest timer")

local BugContest = require("src.core.gen2.BugContest")
assert(BugContest.encounterRate(true) == 102, "tall grass is 102")
assert(BugContest.encounterRate(false) == 51, "park grass is 51")
assert(BugContest.triggers(true, function() return 101 end) == true, "101 connects")
assert(BugContest.triggers(true, function() return 102 end) == false, "102 misses")
BugContest.ENCOUNTER_RATE_SUPER_TALL = 0
assert(BugContest.triggers(true, function() return 0 end) == false, "a rate of 0 never connects")
BugContest.ENCOUNTER_RATE_SUPER_TALL = 102
local park = { encounters = { bugContest = {
  { chance = 30, species = "CATERPIE", min = 7, max = 7 },
  { chance = 70, species = "SCYTHER", min = 10, max = 10 },
} } }
local function once(value)
  return function() return value end
end
assert(BugContest.chooseWild(park, once(40)).species == "CATERPIE", "40 halved is the first row")
BugContest.CHOOSE_DIV = 1
assert(BugContest.chooseWild(park, once(40)).species == "SCYTHER", "40 kept whole is the second row")
BugContest.CHOOSE_DIV = 2
local spins = { 5, 0 }
BugContest.CHOOSE_LIMIT = 1
assert(BugContest.chooseWild(park, function()
  return table.remove(spins, 1)
end).species == "CATERPIE", "a limit of 1 waits for a 0")
BugContest.CHOOSE_LIMIT = 200
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local project = State.blankProject("bug_contest")
  project.game = game
  project.bugContestRules = { tallRate = 0, grassRate = 0, chooseLimit = 1, chooseDiv = 1 }
  local main = Writer.emitMain(project, {})
  assert(main:find("ENCOUNTER_RATE_SUPER_TALL = 0", 1, true), game)
  assert(main:find("ENCOUNTER_RATE_GRASS = 0", 1, true), game)
  assert(main:find("CHOOSE_LIMIT = 1", 1, true), game)
  assert(main:find("CHOOSE_DIV = 1", 1, true), game)
end
local redPark = State.blankProject("bug_contest")
redPark.game = "red"
redPark.bugContestRules = { tallRate = 0 }
assert(not Writer.emitMain(redPark, {}):find("ENCOUNTER_RATE_SUPER_TALL", 1, true), "red")

local rivals = EncounterEdit.vanillaContestants()
assert(rivals[1].name == "DON" and rivals[1].mons[1].species == "KAKUNA",
  "reads the ten rival trainers")
local rivalSession = { project = {} }
local copied = EncounterEdit.ensureContestants(rivalSession)
copied[1].mons[1].species = "SCYTHER"
copied[1].mons[1].score = 400
assert(rivals[1].mons[1].species == "KAKUNA", "the vanilla rivals stay put")
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local project = State.blankProject("bug_contest")
  project.game = game
  project.bugContestants = copied
  local main = Writer.emitMain(project, {})
  assert(main:find("BugContest.CONTESTANTS", 1, true), game .. " replaces the rivals")
  assert(main:find("SCYTHER", 1, true), game)
  assert(main:find("score = 400", 1, true), game)
end
local redRivals = State.blankProject("bug_contest")
redRivals.game = "red"
redRivals.bugContestants = copied
assert(not Writer.emitMain(redRivals, {}):find("CONTESTANTS", 1, true),
  "Red has no contest rivals")

print("PASS gen2 bug contest")
