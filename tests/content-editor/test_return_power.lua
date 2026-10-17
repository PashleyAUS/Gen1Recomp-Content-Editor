-- Return is friendship * 10 / 25 until the fraction is edited.

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

local Effects = require("src.battle.gen2.Effects")
assertEq(Effects.happinessPower(255), 102, "gen2 return")
assertEq(Effects.happinessPower(255, true), 0, "gen2 frustration")
assertEq(Effects.happinessPower(0, true), 102, "gen2 low friendship")
Effects.RETURN_NUM = 20
assertEq(Effects.happinessPower(255), 204, "gen2 edited")
Effects.RETURN_NUM = 10

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.friendshipPower(255), 102, "gen3 return")
assertEq(Damage.friendshipPower(255, true), 0, "gen3 frustration")
Damage.RETURN_DEN = 10
assertEq(Damage.friendshipPower(255), 255, "gen3 edited")
Damage.RETURN_DEN = 25

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1,
  returnPower = { num = 20, den = 25 } })
assert(not red:find("RETURN_NUM", 1, true), "red stays off")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    returnPower = { num = 20, den = 10 } })
  assert(main:find("Effects.RETURN_NUM = returnPower.num", 1, true), version)
  assert(main:find("Effects.RETURN_DEN = returnPower.den", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { returnNum = 20, returnDen = 10 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ returnNum = 20, returnDen = 10 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.RETURN_NUM = battleRules.returnNum", 1, true), version)
  assert(chunk:find("Damage.RETURN_DEN = battleRules.returnDen", 1, true), version)
end

require("Rules")
print("PASS return power")
