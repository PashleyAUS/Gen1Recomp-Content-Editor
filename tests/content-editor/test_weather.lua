-- Battle weather multipliers are data, and the editor saves them.

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
assertEq(Effects.weatherModifier("rain", "WATER", nil), 1.5, "cart rain water")
Effects.WEATHER_TYPE_MODIFIERS.rain.WATER = 2
assertEq(Effects.weatherModifier("rain", "WATER", nil), 2, "edited rain water")
Effects.WEATHER_TYPE_MODIFIERS.rain.WATER = 1.5
assertEq(Effects.sandstormDamage(80), 10, "cart sandstorm")
Effects.SANDSTORM_FRACTION = 2
assertEq(Effects.sandstormDamage(80), 40, "edited sandstorm")
Effects.SANDSTORM_FRACTION = 8

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.weather.typeModifier("RAIN", "WATER"), 1.5, "gen3 cart rain")
Rules.weather.TYPE_MODIFIERS.RAIN.WATER = 2
assertEq(Rules.weather.typeModifier("RAIN", "WATER"), 2, "gen3 edited rain")
Rules.weather.TYPE_MODIFIERS.RAIN.WATER = 1.5

local Writer = require("ModWriter")
local function project(version)
  return {
    version = version, generation = 2,
    weather = { turns = 8, rainWater = 200, solarbeam = 25 },
  }
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain(project(version))
  assert(main:find("WEATHER_TURNS", 1, true), version .. " turns")
  assert(main:find("ratio(weather.rainWater)", 1, true), version .. " rain")
end
local red = Writer.emitMain({ version = "red", generation = 1,
  weather = { turns = 8, rainWater = 200 } })
assert(not red:find("WEATHER_TURNS", 1, true), "red stays quiet")

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { rainWaterPercent = 200, thunderSunAccuracy = 30 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ rainWaterPercent = 200, thunderSunAccuracy = 30 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("TYPE_MODIFIERS.RAIN.WATER", 1, true), version .. " rain")
  assert(chunk:find("THUNDER_SUN_ACCURACY", 1, true), version .. " thunder")
end

print("PASS weather")
