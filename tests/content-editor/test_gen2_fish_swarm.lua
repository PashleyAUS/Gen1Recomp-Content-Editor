-- Gen 2 fishing swarms can swap any fish group on Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local Encounter = require("src.battle.gen2.Encounter")
local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")

local groups = {
  fishGroups = {
    FISHGROUP_QWILFISH = {},
    FISHGROUP_QWILFISH_SWARM = {},
    FISHGROUP_POND = {},
    FISHGROUP_DRATINI = {},
  },
}
assert(Encounter.fishGroupFor(groups, "FISHGROUP_QWILFISH", 1)
  == "FISHGROUP_QWILFISH_SWARM", "an unset table still swaps Qwilfish")

local custom = {
  fishGroups = groups.fishGroups,
  fishSwarmGroups = {
    [1] = { FISHGROUP_POND = "FISHGROUP_DRATINI" },
  },
}
assert(Encounter.fishGroupFor(custom, "FISHGROUP_POND", 1) == "FISHGROUP_DRATINI",
  "an edited flag swaps the group you named")
assert(Encounter.fishGroupFor(custom, "FISHGROUP_QWILFISH", 1) == "FISHGROUP_QWILFISH",
  "a flag you replaced no longer uses the cart swap")

local cleared = { fishGroups = groups.fishGroups, fishSwarmGroups = {} }
assert(Encounter.fishGroupFor(cleared, "FISHGROUP_QWILFISH", 1) == "FISHGROUP_QWILFISH",
  "an empty swap list turns fishing swarms off")

local vanilla = EncounterEdit.vanillaFishSwarms()
assert(vanilla[1].flag == 1 and vanilla[1].from == "FISHGROUP_QWILFISH", "Qwilfish is the first swap")
assert(vanilla[2].flag == 2 and vanilla[2].to == "FISHGROUP_REMORAID_SWARM", "Remoraid is the second")

local function emit(game)
  local project = State.blankProject("fishswarm")
  project.game = game
  project.fishSwarmGroups = {
    { flag = 1, from = "FISHGROUP_POND", to = "FISHGROUP_DRATINI" },
  }
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("fishSwarmGroups", 1, true), game .. " saves the swap table")
  assert(main:find("FISHGROUP_DRATINI", 1, true), game)
end
local red = State.blankProject("fishswarm")
red.game = "red"
red.fishSwarmGroups = {
  { flag = 1, from = "FISHGROUP_POND", to = "FISHGROUP_DRATINI" },
}
assert(not Writer.emitMain(red, {}):find("fishSwarmGroups", 1, true),
  "Red has no Gen 2 fishing swarms")

print("PASS gen2 fish swarm")
