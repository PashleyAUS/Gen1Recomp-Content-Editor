-- Trainer class prize factors stay on the cart table until a class is edited.

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

local Prize = require("src.core.game3.battle.prize")
assertEq(Prize.classValue(57), 4, "youngster cart")
assertEq(Prize.classValue(9999), 5, "unknown cart")
assertEq(Prize.lookupClass(57, 99), 99, "rse cart fallback")
Prize.CLASS_OVERRIDES = { [57] = 9 }
assertEq(Prize.classValue(57), 9, "youngster edited")
assertEq(Prize.lookupClass(57, 99), 9, "rse uses the edit")
Prize.DEFAULT_CLASS_VALUE = 7
assertEq(Prize.classValue(9999), 7, "unknown edited")
Prize.CLASS_OVERRIDES = nil
Prize.DEFAULT_CLASS_VALUE = 5

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3ClassMoney = { default = 7, classes = { ["57"] = 9 } } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitClasses(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Prize.DEFAULT_CLASS_VALUE = 7", 1, true), version)
  assert(chunk:find("Prize.CLASS_OVERRIDES[57] = 9", 1, true), version)
end

require("Rules")
print("PASS class money")
