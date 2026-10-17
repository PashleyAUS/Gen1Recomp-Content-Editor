-- Experience divisor and bonuses are editable on every supported game.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local State = require("State")
local Writer = require("ModWriter")
local Gen1 = require("src.battle.Experience")
local Mon = require("src.battle.gen2.Mon")
local Gen3 = require("src.core.game3.battle.experience")
local BattleRules = require("Gen3BattleRules")

local foe = { baseExp = 64 }
local cart = Gen1.gainFor(foe, 5, true, 1, false)
assert(cart == math.max(1, math.floor(math.floor(64 * 5 / 7) * 1.5)), "Red still uses /7 and 1.5x")
local tuned = Gen1.gainFor(foe, 5, false, 1, false, { exp = { divisor = 1 } })
assert(tuned == 64 * 5, "a Gen 1 divisor of 1 skips the /7")

local gen2Cart = Mon.experienceGain(foe, 5, 1, true, {})
assert(gen2Cart == math.max(1, math.floor(math.floor(64 * 5 / 7) * 3 / 2)), "Gold still uses /7 and 3/2")
Mon.EXP_DIVISOR = 1
assert(Mon.experienceGain(foe, 5, 1, false, {}) == 320, "an edited divisor changes the award")
Mon.EXP_DIVISOR = 7
Mon.EXP_LUCKY_NUM, Mon.EXP_LUCKY_DEN = 200, 100
local lucky = Mon.experienceGain(foe, 5, 1, false, { luckyEgg = true })
assert(lucky == math.floor(math.floor(64 * 5 / 7) * 200 / 100), "Lucky Egg uses the edited percent")
Mon.EXP_LUCKY_NUM, Mon.EXP_LUCKY_DEN = 3, 2

local yield = Gen3.expYield
Gen3.expYield = function() return 70 end
local gen3Cart = Gen3.gainFor(1, 7, { trainer = true })
assert(gen3Cart == math.floor(math.floor(70 * 7 / 7) * 150 / 100), "Gen 3 still uses /7 and 150/100")
Gen3.DIVISOR = 1
assert(Gen3.gainFor(1, 10, {}) == 700, "an edited Gen 3 divisor changes the award")
Gen3.DIVISOR = 7
Gen3.expYield = yield

local function emit(game, lucky)
  local project = State.blankProject("exp")
  project.game = game
  project.expRules = { divisor = 1, trainerPercent = 200 }
  if lucky then project.expRules.luckyPercent = 200 end
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "red", "blue", "yellow" }) do
  local main = emit(game)
  assert(main:find('constants:patch("exp"', 1, true), game .. " saves the experience formula")
  assert(main:find("divisor = 1", 1, true), game)
  assert(not main:find("EXP_DIVISOR", 1, true), game)
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game, true)
  assert(main:find("Mon.EXP_DIVISOR = expRules.divisor", 1, true), game)
  assert(main:find("Mon.EXP_LUCKY_NUM = expRules.luckyPercent", 1, true), game)
end

for _, game in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local project = State.blankProject("exp")
  project.game = game
  project.gen3BattleRules = { expDivisor = 1, expLuckyPercent = 200 }
  local out = {}
  BattleRules.emit(project, function() return "{ expDivisor = 1, expLuckyPercent = 200 }" end, out)
  local main = table.concat(out, "\n")
  assert(loadstring(main), game .. " experience rules compile")
  assert(main:find("Experience.DIVISOR = battleRules.expDivisor", 1, true), game)
  assert(main:find("Experience.LUCKY_NUM = battleRules.expLuckyPercent", 1, true), game)
end

print("PASS exp rules")
