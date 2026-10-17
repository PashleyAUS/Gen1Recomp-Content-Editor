-- Stat stage multipliers are data in every game.

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

local Stats = require("src.pokemon.Stats")
assertEq(Stats.applyStage(100, 1), 150, "gen1 cart +1")
local saved = Stats.STAGE_MULT[1]
Stats.STAGE_MULT[1] = { 200, 100 }
assertEq(Stats.applyStage(100, 1), 200, "gen1 edited +1")
Stats.STAGE_MULT[1] = saved

local Damage = require("src.battle.gen2.Damage")
assertEq(Damage.applyStage(100, 2), 200, "gen2 cart +2")
saved = Damage.STAGE[2]
Damage.STAGE[2] = { 300, 100 }
assertEq(Damage.applyStage(100, 2), 300, "gen2 edited +2")
Damage.STAGE[2] = saved

local G3 = require("src.core.game3.battle.damage")
assertEq(G3.applyStage(100, -1), 66, "gen3 cart -1")
saved = G3.STAGE_RATIO[-1]
G3.STAGE_RATIO[-1] = { 50, 100 }
assertEq(G3.applyStage(100, -1), 50, "gen3 edited -1")
G3.STAGE_RATIO[-1] = saved

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    statStages = { ["1"] = 200 } })
  assert(main:find("Stats.STAGE_MULT[1] = { 200, 100 }", 1, true), version)
  assert(not main:find("Damage.STAGE", 1, true), version .. " stays off gen2")
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    statStages = { ["-1"] = 50 } })
  assert(main:find("Damage.STAGE[-1] = { 50, 100 }", 1, true), version)
  assert(not main:find("Stats.STAGE_MULT", 1, true), version .. " stays off gen1")
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3StatStages = { ["1"] = 300 },
    gen3AccStages = { ["-2"] = 40 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitStages(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.STAGE_RATIO[1] = { 300, 100 }", 1, true), version .. " stat")
  assert(chunk:find("Rules.ACCURACY_STAGE[-2] = { 40, 100 }", 1, true), version .. " accuracy")
end

require("Rules")
print("PASS stat stages")
