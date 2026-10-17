-- Paralysis, the Speed badge, Macho Brace, and weather abilities change Speed.

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

local Status = require("src.battle.Status")
local par = { mon = { status = "PAR" } }
assertEq(Status.applyPenalty(par, "speed", 100), 25, "gen1 quarters speed")
Status.PARALYSIS_SPEED_DIV = 2
assertEq(Status.applyPenalty(par, "speed", 100), 50, "gen1 edited speed")
Status.PARALYSIS_SPEED_DIV = 4

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    ailments = { paralysisSpeed = 2 } })
  assert(main:find("Status.PARALYSIS_SPEED_DIV = ailments.paralysisSpeed", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    ailments = { paralysisSpeed = 2 } })
  assert(not main:find("Status.PARALYSIS_SPEED_DIV", 1, true), version)
  assert(main:find("Battle.PARALYSIS_SPEED_DIVISOR = ailments.paralysisSpeed", 1, true), version)
end

local Engine = require("src.core.game3.battle.engine")
local Rules = require("src.core.game3.battle.rules")
local Damage = require("src.core.game3.battle.damage")
local Pokemon = require("src.core.game3.pokemon")

local function speed(battler, st, adapter)
  return Engine.speedOf(battler, st or {}, adapter)
end

local paralyzed = { mon = { speed = 100, status = "PAR" }, status = "PAR" }
assertEq(speed(paralyzed), 25, "gen3 quarters speed")
Rules.paralysis.SPEED_DIV = 2
assertEq(speed(paralyzed), 50, "gen3 edited paralysis")
Rules.paralysis.SPEED_DIV = 1
assertEq(speed(paralyzed), 100, "gen3 no speed cut")
Rules.paralysis.SPEED_DIV = 4

local badged = { side = "player", mon = { speed = 100 } }
local badges = { badges = { [3] = true } }
assertEq(speed(badged, badges), 110, "speed badge")
Damage.BADGE_PERCENT = 150
assertEq(speed(badged, badges), 150, "edited speed badge")
Damage.BADGE_PERCENT = 0
assertEq(speed(badged, badges), 0, "zero speed badge")
Damage.BADGE_PERCENT = 110
assertEq(speed(badged, {}), 100, "no speed badge")

local braced = { mon = { speed = 100 }, item = 181 }
assertEq(speed(braced), 50, "macho brace halves speed")
Pokemon.MACHO_EV_MULT = 4
assertEq(speed(braced), 25, "edited macho brace")
Pokemon.MACHO_EV_MULT = 0
assertEq(speed(braced), 100, "zero macho brace")
Pokemon.MACHO_EV_MULT = 2

local adapter = { abilityOf = function(_, b) return b.ability end }
local swim = { ability = "SWIFT_SWIM", mon = { speed = 10 } }
assertEq(speed(swim, { weather = "RAIN" }, adapter), 20, "swift swim")
Damage.WEATHER_SPEED_MULT = 3
assertEq(speed(swim, { weather = "RAIN" }, adapter), 30, "edited swift swim")
local chloro = { ability = "CHLOROPHYLL", mon = { speed = 10 } }
assertEq(speed(chloro, { weather = "SUN" }, adapter), 30, "chlorophyll")
assertEq(speed(swim, { weather = "SUN" }, adapter), 10, "swift swim needs rain")
Damage.WEATHER_SPEED_MULT = 0
assertEq(speed(swim, { weather = "RAIN" }, adapter), 0, "zero weather speed")
Damage.WEATHER_SPEED_MULT = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { paralysisSpeed = 2, weatherSpeed = 3 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ paralysisSpeed = 2, weatherSpeed = 3 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.paralysis.SPEED_DIV = battleRules.paralysisSpeed", 1, true), version)
  assert(chunk:find("WEATHER_SPEED_MULT = battleRules.weatherSpeed", 1, true), version)
end

print("PASS speed mods")
