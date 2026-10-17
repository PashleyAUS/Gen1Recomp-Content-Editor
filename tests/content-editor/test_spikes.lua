-- Spikes stay on the cart fraction of max HP until the divisor is edited.

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
local Battle = require("src.battle.gen2.Battle")
local function tick(mon)
  Battle.spikesDamage({
    sideOf = function() return "player" end,
    spikes = { player = true },
    speciesDef = function() return nil end,
    monName = function() return "A" end,
    emit = function() end,
  }, mon)
end
local mon = { hp = 80, maxHp = 80, types = { "NORMAL" } }
tick(mon)
assertEq(mon.hp, 70, "gen2 eighth")
Effects.SPIKES_DIV = 4
mon = { hp = 80, maxHp = 80, types = { "NORMAL" } }
tick(mon)
assertEq(mon.hp, 60, "gen2 edited")
Effects.SPIKES_DIV = 8
mon = { hp = 80, maxHp = 80, types = { "FLYING" } }
tick(mon)
assertEq(mon.hp, 80, "gen2 flying")

local Hazards = require("src.core.game3.battle.effects.hazards")
assertEq(Hazards.damage(80, 1), 10, "gen3 one layer")
assertEq(Hazards.damage(80, 2), 13, "gen3 two layers")
assertEq(Hazards.damage(80, 3), 20, "gen3 three layers")
local side = {}
Hazards.set(side, 3)
local failed = false
Hazards.spikes({
  user = {},
  adapter = {
    foeSide = function() return side end,
    sayFail = function() failed = true end,
    sayText = function() end,
  },
})
assertEq(failed, true, "gen3 third layer full")
Hazards.MAX_LAYERS = 4
failed = false
Hazards.spikes({
  user = {},
  adapter = {
    foeSide = function() return side end,
    sayFail = function() failed = true end,
    sayText = function() end,
  },
})
assertEq(failed, false, "gen3 extra layer")
assertEq(Hazards.layers(side), 4, "gen3 fourth layer")
Hazards.MAX_LAYERS = 3
Hazards.DIV = { 4, 6, 4 }
assertEq(Hazards.damage(80, 1), 20, "gen3 divisor edited")
Hazards.DIV = { 8, 6, 4 }

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, spikesRules = { div = 4 } })
assert(not red:find("SPIKES_DIV", 1, true), "red has no spikes")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, spikesRules = { div = 4 } })
  assert(main:find("Effects\").SPIKES_DIV = div", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Spikes = {
    maxLayers = 2, div1 = 4,
  } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitSpikes(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Hazards.MAX_LAYERS = 2", 1, true), version)
  assert(chunk:find("Hazards.DIV = { 4, 6, 4 }", 1, true), version)
end

require("Rules")
print("PASS spikes")
