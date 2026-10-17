-- Confusion length is data. The cart rolls 2 to 5 turns.

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
assertEq(Status.confusionTurns(function(lo, hi) return hi end), 5, "gen1 cart high")
assertEq(Status.confusionTurns(function(lo) return lo end), 2, "gen1 cart low")
Status.CONFUSION_MIN = 1
Status.CONFUSION_SPAN = 1
assertEq(Status.confusionTurns(function(lo) return lo end), 1, "gen1 one turn")
Status.CONFUSION_MIN = 2
Status.CONFUSION_SPAN = 4

local Battle = require("src.battle.gen2.Battle")
local function zero() return 0 end
assertEq(Battle.confusionLength(zero), 2, "gen2 cart low")
assertEq(Battle.confusionLength(zero, Battle.RAMPAGE_SPAN, Battle.CONFUSION_MIN), 2, "thrash low")
Battle.CONFUSION_MIN = 6
Battle.CONFUSION_SPAN = 1
assertEq(Battle.confusionLength(zero), 6, "gen2 edited")
Battle.CONFUSION_MIN = 2
Battle.CONFUSION_SPAN = 4

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.confusion.turns(function() return 0 end), 2, "gen3 cart low")
assertEq(Rules.confusion.turns(function() return 3 end), 5, "gen3 cart high")
Rules.confusion.MIN = 8
Rules.confusion.SPAN = 1
assertEq(Rules.confusion.turns(function() return 0 end), 8, "gen3 edited")
Rules.confusion.MIN = 2
Rules.confusion.SPAN = 4

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    ailments = { confusionMin = 1, confusionSpan = 1 } })
  assert(main:find("Status.CONFUSION_MIN = ailments.confusionMin", 1, true), version)
  assert(main:find("Status.CONFUSION_SPAN = ailments.confusionSpan", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    ailments = { confusionMin = 1, confusionSpan = 1, rampageSpan = 3 } })
  assert(main:find("Battle.CONFUSION_MIN = ailments.confusionMin", 1, true), version)
  assert(main:find("Battle.RAMPAGE_SPAN = ailments.rampageSpan", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { confusionMin = 1, confusionSpan = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ confusionMin = 1, confusionSpan = 1 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.confusion.MIN = battleRules.confusionMin", 1, true), version)
  assert(chunk:find("Rules.confusion.SPAN = battleRules.confusionSpan", 1, true), version)
end

require("Rules")
print("PASS confusion")
