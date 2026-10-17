-- Gold, Silver, and Crystal roaming beasts save into encounters.roamMons / roamMaps.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")

local session = {
  data = { encounters = {
    roamMons = {
      { species = "RAIKOU", level = 40, map = "ROUTE_42" },
      { species = "ENTEI", level = 40, map = "ROUTE_37" },
    },
    roamMaps = {
      { map = "ROUTE_42", to = { "ROUTE_43" } },
    },
  } },
  project = {},
}
local vanilla = EncounterEdit.vanillaRoamMons(session)
assert(#vanilla == 2 and vanilla[2].species == "ENTEI", "reads the cache roster")
assert(session.project.roamMons == nil, "viewing the roster does not copy it")
local maps = EncounterEdit.vanillaRoamMaps(session)
assert(maps[1].map == "ROUTE_42" and maps[1].to[1] == "ROUTE_43", "reads the cache routes")

local rows = EncounterEdit.ensureRoamMons(session)
rows[1].species = "SUICUNE"
rows[1].map = "ROUTE_38"
assert(session.project.roamMons[1].species == "SUICUNE")
assert(EncounterEdit.vanillaRoamMons(session)[1].species == "RAIKOU", "vanilla roster stays put")

local function emitted(game)
  local project = State.blankProject("roamers")
  project.game = game
  project.roamMons = {
    { species = "SUICUNE", level = 40, map = "ROUTE_38" },
  }
  project.roamMaps = {
    { map = "ROUTE_38", to = { "ROUTE_39", "ROUTE_42" } },
  }
  return Writer.emitMain(project, {})
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emitted(game)
  assert(main:find('encounters:override("roamMons"', 1, true), game .. " replaces the roster")
  assert(main:find('encounters:override("roamMaps"', 1, true), game .. " replaces the routes")
  assert(main:find("SUICUNE", 1, true), game)
  assert(main:find("ROUTE_39", 1, true), game)
end

local red = State.blankProject("roamers")
red.game = "red"
red.roamMons = { { species = "SUICUNE", level = 40, map = "ROUTE_38" } }
red.roamMaps = { { map = "ROUTE_38", to = { "ROUTE_39" } } }
local redMain = Writer.emitMain(red, {})
assert(not redMain:find("roamMons", 1, true), "Red has no roaming beasts")
assert(not redMain:find("roamMaps", 1, true), "Red has no roam routes")

local untouched = State.blankProject("roamers")
untouched.game = "crystal"
local plain = Writer.emitMain(untouched, {})
assert(not plain:find("roamMons", 1, true), "an unedited roster stays vanilla")

print("PASS gen2 roamers")
