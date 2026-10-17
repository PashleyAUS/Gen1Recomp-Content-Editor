-- Flail and Reversal stay on the cart HP bands until they are edited.

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
assertEq(Effects.flailPower(1, 100), 200, "gen2 one hp")
assertEq(Effects.flailPower(100, 100), 20, "gen2 full hp")
Effects.FLAIL_BANDS[1].power = 10
assertEq(Effects.flailPower(1, 100), 10, "gen2 edited")
Effects.FLAIL_BANDS[1].power = 200

local Damage = require("src.core.game3.battle.damage")
assertEq(Damage.flailPower(1, 100), 200, "gen3 one hp")
assertEq(Damage.flailPower(100, 100), 20, "gen3 full hp")
Damage.FLAIL_SCALE = 0
assertEq(Damage.flailPower(50, 100), 200, "gen3 scale off still bumps a living mon")
Damage.FLAIL_SCALE = 48

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1,
  flailRules = { scale = 24 } })
assert(not red:find("FLAIL_SCALE", 1, true), "red stays off")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    flailRules = { scale = 24, bands = { { atMost = 1, power = 10 }, { power = 20 } } } })
  assert(main:find("Effects.FLAIL_SCALE = 24", 1, true), version)
  assert(main:find("Effects.FLAIL_BANDS =", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    flailRules = { scale = 24, bands = { { atMost = 1, power = 10 }, { power = 20 } } } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitFlail(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.FLAIL_SCALE = 24", 1, true), version)
  assert(chunk:find("Damage.FLAIL_BANDS =", 1, true), version)
end

require("Rules")
print("PASS flail")
