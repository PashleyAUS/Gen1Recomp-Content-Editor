-- Self-Destruct and Explosion halve defense until the divisor is edited.

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
assertEq(Gen1.explosionDefense(80), 40, "gen1 cart")
Gen1.EXPLOSION_DEF_DIV = 1
assertEq(Gen1.explosionDefense(80), 80, "gen1 off")
Gen1.EXPLOSION_DEF_DIV = 2

local Gen2 = require("src.battle.gen2.Damage")
assertEq(Gen2.explosionDefense(80), 40, "gen2 cart")
Gen2.EXPLOSION_DEF_DIV = 4
assertEq(Gen2.explosionDefense(80), 20, "gen2 quarter")
Gen2.EXPLOSION_DEF_DIV = 2

local Gen3 = require("src.core.game3.battle.damage")
assertEq(Gen3.explosionDefense(80), 40, "gen3 cart")
Gen3.EXPLOSION_DEF_DIV = 1
assertEq(Gen3.explosionDefense(1), 1, "gen3 stays at least 1")
Gen3.EXPLOSION_DEF_DIV = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, explodeDiv = 4 })
  assert(main:find("require(\"src.battle.Damage\").EXPLOSION_DEF_DIV = div", 1, true), version)
  assert(not main:find("gen2.Damage", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, explodeDiv = 4 })
  assert(main:find("require(\"src.battle.gen2.Damage\").EXPLOSION_DEF_DIV = div", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { explodeDiv = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ explodeDiv = 4 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.EXPLOSION_DEF_DIV = battleRules.explodeDiv", 1, true), version)
end

require("Rules")
print("PASS explosion")
