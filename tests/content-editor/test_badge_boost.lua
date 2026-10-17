-- Gen 3 badges multiply Attack, Defense, and both Special stats by this percent.

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

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.badgeBoost(80), 88, "cart badge")
Damage.BADGE_PERCENT = 150
assertEq(Damage.badgeBoost(80), 120, "edited badge")
Damage.BADGE_PERCENT = 0
assertEq(Damage.badgeBoost(80), 0, "zero badge")
Damage.BADGE_PERCENT = 110

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { badgePercent = 150 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function(t) return "{ badgePercent = " .. t.badgePercent .. " }" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("BADGE_PERCENT = battleRules.badgePercent", 1, true), version)
end

print("PASS badge boost")
