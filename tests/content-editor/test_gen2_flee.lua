-- Gen 2 wild flee lists are editable on Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local EncounterEdit = require("EncounterEdit")
local State = require("State")
local Writer = require("ModWriter")
local Battle = require("src.battle.gen2.Battle")
local Roamers = require("src.core.gen2.Roamers")

local gold = { version = "gold" }
local silver = { version = "silver" }
local crystal = { version = "crystal" }
assert(#EncounterEdit.vanillaFlee(gold, "always") == 3, "Gold always-flee includes Suicune")
assert(EncounterEdit.vanillaFlee(gold, "always")[3] == "SUICUNE")
assert(#EncounterEdit.vanillaFlee(silver, "always") == 3, "Silver matches Gold")
assert(#EncounterEdit.vanillaFlee(crystal, "always") == 2, "Crystal leaves Suicune off the always list")
assert(EncounterEdit.vanillaFlee(crystal, "often")[1] == "CUBONE")

local function battle(species, data, roll)
  return {
    wild = true,
    player = {},
    enemy = { species = species },
    data = data,
    random = function() return roll or 0 end,
    volatile = function() return {} end,
    enemyFled = function(self) self.fled = true return true end,
  }
end

local forced = battle("PICHU", { fleeMons = { always = { "PICHU" } } })
assert(Battle.tryEnemyFlee(forced) == true, "an edited always-list flees")

local quiet = battle("RAIKOU", { fleeMons = { always = {} } }, 200)
assert(Battle.tryEnemyFlee(quiet) == false, "an empty always-list keeps Raikou")

local cart = battle("RAIKOU", {})
assert(Battle.tryEnemyFlee(cart) == true, "an unset list still uses the cart")
assert(Roamers.fleeSet({}, "always") == nil)

local neverOften = battle("CUBONE", { fleeMons = { oftenRoll = 0 } }, 0)
assert(Battle.tryEnemyFlee(neverOften) == false, "threshold 0 never passes the often gate")

local function emit(game)
  local project = State.blankProject("flee")
  project.game = game
  project.fleeMons = {
    always = { "PICHU" },
    oftenRoll = 200,
  }
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("PICHU", 1, true), game .. " saves the flee species")
  assert(main:find("oftenRoll = 200", 1, true), game .. " saves the threshold")
  assert(main:find("data.fleeMons = fleeMons", 1, true), game)
end
local red = State.blankProject("flee")
red.game = "red"
red.fleeMons = { always = { "PICHU" } }
assert(not Writer.emitMain(red, {}):find("fleeMons", 1, true), "Red has no Gen 2 flee lists")

print("PASS gen2 flee")
