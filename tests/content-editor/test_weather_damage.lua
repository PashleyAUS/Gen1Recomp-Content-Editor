-- The Gen 3 damage formula reads the weather type table, not a second hardcoded cut.

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

local Types = require("src.core.game3.battle.types")
local Rules = require("src.core.game3.battle.rules")
local Damage = require("src.core.game3.battle.damage")

assertEq(Damage.weatherAdjust(10, "RAIN", Types.ID.WATER), 15, "rain water cart")
assertEq(Damage.weatherAdjust(10, "RAIN", Types.ID.FIRE), 5, "rain fire cart")
assertEq(Damage.weatherAdjust(10, "SUN", Types.ID.FIRE), 15, "sun fire cart")
assertEq(Damage.flashFire(10), 15, "flash fire cart")
assertEq(Damage.divideStat(10, Damage.SOLAR_BEAM_DIV, 2), 5, "solar beam cart")

Rules.weather.TYPE_MODIFIERS.RAIN.WATER = 2
assertEq(Damage.weatherAdjust(10, "RAIN", Types.ID.WATER), 20, "rain water edited")
Rules.weather.TYPE_MODIFIERS.RAIN.WATER = 1.5
Damage.FLASH_FIRE_PERCENT = 200
assertEq(Damage.flashFire(10), 20, "flash fire edited")
Damage.FLASH_FIRE_PERCENT = 150
Damage.SOLAR_BEAM_DIV = 1
assertEq(Damage.divideStat(10, Damage.SOLAR_BEAM_DIV, 2), 10, "solar beam off")
Damage.SOLAR_BEAM_DIV = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { solarBeamDiv = 1, flashFire = 200, rainWaterPercent = 200 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ solarBeamDiv = 1, flashFire = 200, rainWaterPercent = 200 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("TYPE_MODIFIERS.RAIN.WATER = battleRules.rainWaterPercent / 100", 1, true), version)
  assert(chunk:find("Damage.SOLAR_BEAM_DIV = battleRules.solarBeamDiv", 1, true), version)
  assert(chunk:find("Damage.FLASH_FIRE_PERCENT = battleRules.flashFire", 1, true), version)
end

print("PASS weather damage")
