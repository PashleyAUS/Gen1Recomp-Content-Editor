-- Magnitude keeps the cart roll until a band is edited.

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
local function byte(n)
  return function() return n end
end
local power, number = Effects.magnitudePower(byte(0))
assertEq(power, 10, "gen2 low power")
assertEq(number, 4, "gen2 low number")
power, number = Effects.magnitudePower(byte(255))
assertEq(power, 150, "gen2 high power")
assertEq(number, 10, "gen2 high number")
Effects.MAGNITUDE_POWER[1][2] = 1
power, number = Effects.magnitudePower(byte(0))
assertEq(power, 1, "gen2 edited")
Effects.MAGNITUDE_POWER[1][2] = 10

local Damage = require("src.core.game3.battle.damage")
number, power = Damage.magnitudeResult(0)
assertEq(number, 4, "gen3 low number")
assertEq(power, 10, "gen3 low power")
number, power = Damage.magnitudeResult(99)
assertEq(number, 10, "gen3 high number")
assertEq(power, 150, "gen3 high power")
Damage.MAGNITUDE_BANDS[1].power = 1
number, power = Damage.magnitudeResult(0)
assertEq(power, 1, "gen3 edited")
Damage.MAGNITUDE_BANDS[1].power = 10

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1,
  magnitudeBands = { { at = 13, power = 1, number = 4 } } })
assert(not red:find("MAGNITUDE_POWER", 1, true), "red stays off")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    magnitudeBands = { { at = 13, power = 1, number = 4 }, { at = 255, power = 150, number = 10 } } })
  assert(main:find("Effects.MAGNITUDE_POWER =", 1, true), version)
  assert(main:find("{ 13, 1, 4 }", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    magnitudeBands = { { below = 5, number = 4, power = 1 }, { number = 10, power = 150 } } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitMagnitude(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.MAGNITUDE_BANDS =", 1, true), version)
  assert(chunk:find("power = 1", 1, true), version)
end

require("Rules")
print("PASS magnitude")
