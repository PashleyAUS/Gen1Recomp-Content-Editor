-- Doubling moves and Huge Power stay at x2 until the multiplier is edited.

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
assertEq(Damage.double(10), 20, "cart")
assertEq(Damage.double(3), 6, "cart chance")
Damage.DOUBLE_MULT = 3
assertEq(Damage.double(10), 30, "triple")
Damage.DOUBLE_MULT = 1
assertEq(Damage.double(10), 10, "off")
Damage.DOUBLE_MULT = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { doubleMult = 3 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ doubleMult = 3 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.DOUBLE_MULT = battleRules.doubleMult", 1, true), version)
end

print("PASS double mult")
