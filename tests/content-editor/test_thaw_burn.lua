-- Gen 3 thaw, burn damage, and spread hits keep the cart divisors until edited.

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

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.freeze.thaws(function() return 0 end), true, "thaw on zero")
assertEq(Rules.freeze.thaws(function() return 1 end), false, "stay frozen")
Rules.freeze.THAW = 1
assertEq(Rules.freeze.thaws(function() return 0 end), true, "always thaw")
Rules.freeze.THAW = 5

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.divideStat(80, Damage.BURN_DAMAGE_DIV, 2), 40, "burn cart")
assertEq(Damage.divideStat(80, Damage.SPREAD_DIV, 2), 40, "spread cart")
Damage.BURN_DAMAGE_DIV = 1
Damage.SPREAD_DIV = 4
assertEq(Damage.divideStat(80, Damage.BURN_DAMAGE_DIV, 2), 80, "burn off")
assertEq(Damage.divideStat(80, Damage.SPREAD_DIV, 2), 20, "spread quarter")
Damage.BURN_DAMAGE_DIV = 2
Damage.SPREAD_DIV = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { thawChance = 1, burnDamageDiv = 1, spreadDiv = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ thawChance = 1, burnDamageDiv = 1, spreadDiv = 4 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.freeze.THAW = battleRules.thawChance", 1, true), version)
  assert(chunk:find("Damage.BURN_DAMAGE_DIV = battleRules.burnDamageDiv", 1, true), version)
  assert(chunk:find("Damage.SPREAD_DIV = battleRules.spreadDiv", 1, true), version)
end

print("PASS thaw burn")
