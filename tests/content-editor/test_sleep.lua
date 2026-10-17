-- Sleep length is data. Each game keeps its cart roll until it is edited.

package.path = table.concat({
  "tools/content-editor/?.lua",
  "tools/content-editor/panels/?.lua",
  "tools/save-editor/?.lua",
  "runtime/gen1recomp/?.lua",
  "runtime/gen1recomp/?/init.lua",
  package.path,
}, ";")

dofile("tests/love_stub.lua")

local function assertEq(actual, expected, label)
  if actual ~= expected then
    error(label .. ": got " .. tostring(actual) .. " expected " .. tostring(expected))
  end
end

local Status = require("src.battle.Status")
assertEq(Status.sleepTurns(function(lo) return lo end), 1, "gen1 cart low")
assertEq(Status.sleepTurns(function(_, hi) return hi end), 7, "gen1 cart high")
Status.SLEEP_MIN = 4
Status.SLEEP_SPAN = 1
assertEq(Status.sleepTurns(function(lo) return lo end), 4, "gen1 one turn")
Status.SLEEP_MIN = 1
Status.SLEEP_SPAN = 7

local Battle = require("src.battle.gen2.Battle")
local function zero() return 0 end
assertEq(Battle.sleepTurns(zero), 2, "gen2 cart low")
assertEq(Battle.sleepTurns(function() return 5 end), 7, "gen2 cart high")
assertEq(Battle.sleepTurns(function() return 2 end, true), 4, "tower high")
assertEq(Battle.confusionLength(zero, Battle.NAP_SPAN, Battle.NAP_MIN), 1, "nap low")
Battle.SLEEP_MIN = 9
Battle.SLEEP_SPAN = 1
assertEq(Battle.sleepTurns(zero), 9, "gen2 edited")
Battle.SLEEP_MIN = 2
Battle.SLEEP_SPAN = 6

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.sleep.turns(function() return 0 end), 2, "gen3 cart low")
assertEq(Rules.sleep.turns(function() return 3 end), 5, "gen3 cart high")
assertEq(Rules.sleep.REST, 3, "gen3 rest")
Rules.sleep.MIN = 8
Rules.sleep.SPAN = 1
assertEq(Rules.sleep.turns(function() return 0 end), 8, "gen3 edited")
Rules.sleep.MIN = 2
Rules.sleep.SPAN = 4

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    ailments = { sleepMin = 3, sleepSpan = 1, restTurns = 1 } })
  assert(main:find("Status.SLEEP_MIN = ailments.sleepMin", 1, true), version)
  assert(main:find("Status.REST_TURNS = ailments.restTurns", 1, true), version)
  assert(not main:find("SLEEP_TOWER_SPAN", 1, true), version .. " stays off the tower")
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    ailments = { sleepMin = 2, sleepSpan = 1, sleepTowerSpan = 1, restTurns = 1, napSpan = 1 } })
  assert(main:find("Battle.SLEEP_SPAN = ailments.sleepSpan", 1, true), version)
  assert(main:find("Battle.SLEEP_TOWER_SPAN = ailments.sleepTowerSpan", 1, true), version)
  assert(main:find("Battle.NAP_SPAN = ailments.napSpan", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { sleepMin = 1, sleepSpan = 1, restTurns = 2 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ sleepMin = 1, sleepSpan = 1, restTurns = 2 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.sleep.MIN = battleRules.sleepMin", 1, true), version)
  assert(chunk:find("Rules.sleep.REST = battleRules.restTurns", 1, true), version)
end

require("Rules")
print("PASS sleep")
