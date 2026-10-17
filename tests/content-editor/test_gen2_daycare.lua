-- Gen 2 Day-Care knobs are saved and read for Gold, Silver, and Crystal.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local Breeding = require("src.core.gen2.Breeding")
local State = require("State")
local Writer = require("ModWriter")

assert(Breeding.knob(nil, "eggLevel", Breeding.EGG_LEVEL) == 5, "missing data keeps the cart egg level")
assert(Breeding.retrievePrice(0) == 100, "an untouched withdrawal still costs 100")
assert(Breeding.retrievePrice(2) == 300, "each grown level still adds 100")

local data = { breeding = {
  eggLevel = 10,
  hatchHappiness = 200,
  minStepsToEgg = 40,
  withdrawFee = 50,
  withdrawFeePerLevel = 25,
} }
assert(Breeding.knob(data, "eggLevel", 5) == 10)
assert(Breeding.knob(data, "hatchHappiness", 120) == 200)
assert(Breeding.retrievePrice(2, data) == 100, "50 plus 25 for each of two levels")

local function emit(game)
  local project = State.blankProject("daycare")
  project.game = game
  project.breeding = { eggLevel = 10, withdrawFee = 50 }
  return Writer.emitMain(project, {})
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("data.breeding", 1, true), game .. " installs the Day-Care settings")
  assert(main:find("eggLevel = 10", 1, true), game)
  assert(main:find("withdrawFee = 50", 1, true), game)
end

local red = State.blankProject("daycare")
red.game = "red"
red.breeding = { eggLevel = 10 }
assert(not Writer.emitMain(red, {}):find("data.breeding", 1, true),
  "Red has no Day-Care")

local untouched = State.blankProject("daycare")
untouched.game = "silver"
untouched.breeding = {}
assert(not Writer.emitMain(untouched, {}):find("data.breeding", 1, true),
  "an empty Day-Care form stays on the cart values")

print("PASS gen2 daycare")
