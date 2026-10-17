-- Poison, burn, and paralysis amounts are editable on every supported game.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local State = require("State")
local Writer = require("ModWriter")
local Status = require("src.battle.Status")
local Battle = require("src.battle.gen2.Battle")
local Gen3Status = require("src.core.game3.battle.status")
local BattleRules = require("Gen3BattleRules")

local function hurt(divisor)
  Status.CHIP_DIVISOR = divisor
  local battler = { name = "A", mon = { stats = { hp = 16 }, hp = 16 } }
  Status.RECORDS.PSN.residual(battler)
  return battler.mon.hp
end
assert(hurt(16) == 15, "Red poison still takes 1/16")
assert(hurt(1) == 0, "a Gen 1 fraction of 1 takes the whole bar")
Status.CHIP_DIVISOR = 16

local function poison(fraction, maxHp)
  Battle.POISON_FRACTION = fraction
  return Battle.STATUSES.poison.residual(nil, nil, maxHp)
end
assert(poison(8, 80) == 10, "Gold poison still takes 1/8")
assert(poison(2, 80) == 40, "an edited poison fraction changes the chip")
Battle.POISON_FRACTION = 8
Battle.PARALYSIS_SPEED_DIVISOR = 2
assert(Battle.statusPenaltyFor(nil, { status = "paralyze" }, "speed", 100) == 50,
  "paralysis uses the edited Speed divisor")
Battle.PARALYSIS_SPEED_DIVISOR = 4

local lost
local adapter = {
  isFainted = function() return false end,
  maxHp = function() return 80 end,
  sayText = function() return "hurt" end,
  applyHpLoss = function(_, _, amount) lost = amount end,
}
Gen3Status.POISON_FRACTION = 2
Gen3Status.tickChip({ status = "PSN" }, adapter)
assert(lost == 40, "Gen 3 poison uses the edited fraction")
Gen3Status.POISON_FRACTION = 8

local function emit(game)
  local project = State.blankProject("ailments")
  project.game = game
  if game == "gold" or game == "silver" or game == "crystal" then
    project.ailments = { poisonFraction = 2, paralysisSpeed = 2 }
  else
    project.ailments = { chip = 4 }
  end
  return Writer.emitMain(project, {})
end
for _, game in ipairs({ "red", "blue", "yellow" }) do
  local main = emit(game)
  assert(main:find("Status.CHIP_DIVISOR = ailments.chip", 1, true), game)
  assert(main:find("chip = 4", 1, true), game)
end
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local main = emit(game)
  assert(main:find("Battle.POISON_FRACTION = ailments.poisonFraction", 1, true), game)
  assert(main:find("Battle.PARALYSIS_SPEED_DIVISOR = ailments.paralysisSpeed", 1, true), game)
end

for _, game in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local project = State.blankProject("ailments")
  project.game = game
  project.gen3BattleRules = { poisonFraction = 2, burnFraction = 4 }
  local out = {}
  BattleRules.emit(project, function() return "{ poisonFraction = 2, burnFraction = 4 }" end, out)
  local main = table.concat(out, "\n")
  assert(loadstring(main), game .. " ailment rules compile")
  assert(main:find("Status.POISON_FRACTION = battleRules.poisonFraction", 1, true), game)
  assert(main:find("Status.BURN_FRACTION = battleRules.burnFraction", 1, true), game)
end

print("PASS ailments")
