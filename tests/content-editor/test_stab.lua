-- Same-type bonus stays at half again until it is edited.

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

local Gen1 = require("src.battle.Damage")
assertEq(Gen1.applyStab(10), 15, "gen1 cart")
Gen1.STAB_NUM = 2
Gen1.STAB_DEN = 1
assertEq(Gen1.applyStab(10), 20, "gen1 double")
Gen1.STAB_NUM = 0
assertEq(Gen1.applyStab(10), 0, "gen1 off")
Gen1.STAB_NUM = 3
Gen1.STAB_DEN = 2

local Gen2 = require("src.battle.gen2.Damage")
assertEq(Gen2.applyStab(10), 15, "gen2 cart")
Gen2.STAB_NUM = 200
Gen2.STAB_DEN = 100
assertEq(Gen2.applyStab(10), 20, "gen2 double")
Gen2.STAB_NUM = 15
Gen2.STAB_DEN = 10

local Gen3 = require("src.core.game3.battle.damage")
assertEq(Gen3.applyStab(10), 15, "gen3 cart")
Gen3.STAB_NUM = 200
Gen3.STAB_DEN = 100
assertEq(Gen3.applyStab(10), 20, "gen3 double")
Gen3.STAB_NUM = 15
Gen3.STAB_DEN = 10

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, stabPercent = 200 })
  assert(main:find("require(\"src.battle.Damage\")", 1, true), version)
  assert(main:find("Damage.STAB_NUM = percent", 1, true), version)
  assert(not main:find("gen2.Damage", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, stabPercent = 200 })
  assert(main:find("require(\"src.battle.gen2.Damage\")", 1, true), version)
  assert(main:find("Damage.STAB_DEN = 100", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { stabPercent = 200 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ stabPercent = 200 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.STAB_NUM = battleRules.stabPercent", 1, true), version)
  assert(chunk:find("Damage.STAB_DEN = 100", 1, true), version)
end

require("Rules")
print("PASS stab")
