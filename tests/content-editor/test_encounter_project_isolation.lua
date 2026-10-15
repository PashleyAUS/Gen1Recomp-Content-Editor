package.path = "tools/content-editor/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")
local Generation = require("Generation")
local EncounterEdit = require("EncounterEdit")
local State = require("State")

for _, game in ipairs({"gold", "silver", "crystal"}) do
  local base = {
    grass = {ROUTE_29 = {rates = {MORN = 25, DAY = 25, NITE = 25}, slots = {
      MORN = {{level = 3, species = "PIDGEY"}},
      DAY = {{level = 3, species = "PIDGEY"}},
      NITE = {{level = 3, species = "HOOTHOOT"}},
    }}},
    water = {}, fishGroups = {}, treeSets = {},
  }
  local data = {encounters = base, gen2Encounters = base}
  local restore = Generation.preserveBaseEncounters(data)
  -- Simulate an installed mod's registry patch, including a nested mutation.
  base.grass.ROUTE_29.slots.DAY[1].species = "AERODACTYL"
  base.fishGroups.foreign = {old = {{species = "AERODACTYL"}}}
  base.treeSets.foreign = {common = {{species = "AERODACTYL"}}}
  restore()
  assert(data.encounters == data.gen2Encounters, "Gen 2 aliases diverged")
  assert(not data.encounters.fishGroups.foreign)
  assert(not data.encounters.treeSets.foreign)
  local first = {version = game, data = data, project = State.blankProject("mod1")}
  local inherited = EncounterEdit.resolveEncounters(first, "ROUTE_29")
  first.project.maps.ROUTE_29 = {encounters = EncounterEdit.cloneEncounters(inherited)}
  first.project.maps.ROUTE_29.encounters.grass.slots.DAY[1].species = "AERODACTYL"
  local owned = EncounterEdit.resolveEncounters(first, "ROUTE_29", first.project.maps.ROUTE_29)
  assert(owned.grass.slots.DAY[1].species == "AERODACTYL")
  local second = {version = game, data = data, project = State.blankProject("mod2")}
  local clean, isOwned = EncounterEdit.resolveEncounters(second, "ROUTE_29")
  assert(not isOwned and clean.grass.slots.DAY[1].species == "PIDGEY")
  -- First edit/save in mod2 must copy the ROM slots, never mod1's slots.
  second.project.maps.ROUTE_29 = {encounters = EncounterEdit.cloneEncounters(clean)}
  assert(second.project.maps.ROUTE_29.encounters.grass.slots.DAY[1].species == "PIDGEY")
end
local data = {encounters = {ROUTE_1 = {grass = {slots = {{species = "PIDGEY"}}}}}}
local restore = Generation.preserveBaseEncounters(data)
data.encounters.ROUTE_1.grass.slots[1].species = "AERODACTYL"
data.gen2Encounters = {}
restore()
assert(data.encounters.ROUTE_1.grass.slots[1].species == "PIDGEY")
assert(data.gen2Encounters == nil, "Gen 1 must not gain a Gen 2 alias")
print("ok encounter projects inherit ROM data across installed mod loads")
