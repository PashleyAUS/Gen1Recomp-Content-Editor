-- Full paralysis keeps the cart odds until they are edited.

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
assertEq(Status.paralysisBlocks(function() return 0 end), true, "gen1 low roll locks")
assertEq(Status.paralysisBlocks(function() return 100 end), false, "gen1 high roll moves")
Status.PARALYSIS_THRESHOLD = 0
assertEq(Status.paralysisBlocks(function() return 0 end), false, "gen1 never")
Status.PARALYSIS_THRESHOLD = 256
assertEq(Status.paralysisBlocks(function() return 255 end), true, "gen1 always")
Status.PARALYSIS_THRESHOLD = 63

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.paralysis.blocks(function() return 0 end), true, "gen3 zero locks")
assertEq(Rules.paralysis.blocks(function() return 1 end), false, "gen3 other roll moves")
Rules.paralysis.SKIP = 1
assertEq(Rules.paralysis.blocks(function() return 0 end), true, "gen3 always")
Rules.paralysis.SKIP = 4

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    ailments = { paralysisFull = 0 } })
  assert(main:find("Status.PARALYSIS_THRESHOLD = ailments.paralysisFull", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    ailments = { paralysisFull = 0, paralysisSkip = 1 } })
  assert(not main:find("PARALYSIS_THRESHOLD", 1, true), version)
  assert(main:find("Battle.PARALYSIS_SKIP_CHANCE = ailments.paralysisSkip", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { paralysisSkip = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ paralysisSkip = 1 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.paralysis.SKIP = battleRules.paralysisSkip", 1, true), version)
end

require("Rules")
print("PASS paralysis")
