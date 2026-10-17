-- Gen 2 shiny rate is 1/N for wild and gift Pokémon on Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local Mon = require("src.battle.gen2.Mon")
local State = require("State")
local Writer = require("ModWriter")

local species = {
  name = "SENTRET",
  baseStats = { hp = 35, attack = 46, defense = 34, speed = 20,
    specialAttack = 35, specialDefense = 45 },
  types = { "NORMAL" },
}
local forced = { pokemon = { SENTRET = species }, shinyRate = 1 }
for _ = 1, 5 do
  local mon = Mon.new(forced, "SENTRET", 5)
  assert(mon and mon.shiny, "1/1 makes every rolled mon shiny")
  assert(Mon.vanillaShiny(mon.dvs), "the shiny roll uses shiny DVs")
end

local pinned = Mon.new(forced, "SENTRET", 5, {
  dvs = { attack = 9, defense = 8, speed = 8, special = 8 },
})
assert(pinned and not pinned.shiny, "a caller that supplies DVs keeps them")

local plain = Mon.new({ pokemon = { SENTRET = species } }, "SENTRET", 5)
assert(plain, "an unset rate still builds the mon")

local function emit(game)
  local project = State.blankProject("shiny")
  project.game = game
  project.shinyRate = 128
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("shinyRate = 128", 1, true), game .. " saves the shiny rate")
  assert(main:find("data.shinyRate = shinyRate", 1, true), game)
end
local red = State.blankProject("shiny")
red.game = "red"
red.shinyRate = 128
assert(not Writer.emitMain(red, {}):find("shinyRate", 1, true), "Red has no Gen 2 shiny rate")

print("PASS gen2 shiny rate")
