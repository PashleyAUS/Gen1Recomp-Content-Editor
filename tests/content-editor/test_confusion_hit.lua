-- A confused self-hit is a 128-out-of-256 roll of a 40-power hit until edited.

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
assertEq(Status.confusionHits(function() return 0 end), true, "gen1 low roll hits")
assertEq(Status.confusionHits(function() return 200 end), false, "gen1 high roll misses")
assertEq(Status.confusionPower(), 40, "gen1 power")
Status.CONFUSION_HIT = 0
assertEq(Status.confusionHits(function() return 0 end), false, "gen1 never")
Status.CONFUSION_HIT = 256
assertEq(Status.confusionHits(function() return 255 end), true, "gen1 always")
Status.CONFUSION_HIT = 128
Status.CONFUSION_POWER = 10
assertEq(Status.confusionPower(), 10, "gen1 edited power")
Status.CONFUSION_POWER = 40

local Battle = require("src.battle.gen2.Battle")
assertEq(Battle.confusionHits(function() return 0 end), true, "gen2 low roll hits")
assertEq(Battle.confusionHits(function() return 200 end), false, "gen2 high roll misses")
Battle.CONFUSION_HIT = 0
assertEq(Battle.confusionHits(function() return 0 end), false, "gen2 never")
Battle.CONFUSION_HIT = 128

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.confusion.hits(function() return 0 end), true, "gen3 low roll hits")
assertEq(Rules.confusion.hits(function() return 200 end), false, "gen3 high roll misses")
assertEq(Rules.confusion.power(), 40, "gen3 power")
Rules.confusion.HIT = 0
assertEq(Rules.confusion.hits(function() return 0 end), false, "gen3 never")
Rules.confusion.POWER = 15
assertEq(Rules.confusion.power(), 15, "gen3 edited power")
Rules.confusion.HIT = 128
Rules.confusion.POWER = 40

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    ailments = { confusionHit = 0, confusionPower = 10 } })
  assert(main:find("Status.CONFUSION_HIT = ailments.confusionHit", 1, true), version)
  assert(main:find("Status.CONFUSION_POWER = ailments.confusionPower", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    ailments = { confusionHit = 256, confusionPower = 20 } })
  assert(main:find("Battle.CONFUSION_HIT = ailments.confusionHit", 1, true), version)
  assert(main:find("Battle.CONFUSION_POWER = ailments.confusionPower", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { confusionHit = 0, confusionPower = 10 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ confusionHit = 0, confusionPower = 10 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.confusion.HIT = battleRules.confusionHit", 1, true), version)
  assert(chunk:find("Rules.confusion.POWER = battleRules.confusionPower", 1, true), version)
end

require("Rules")
print("PASS confusion hit")
