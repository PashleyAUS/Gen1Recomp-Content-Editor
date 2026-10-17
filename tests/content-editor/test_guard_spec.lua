-- Guard Spec lasts as many turns as Mist. The cart uses 5.

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

local Capabilities = require("src.core.game3.battle.capabilities")
local BattleItems = require("src.core.game3.battle.items")
local Screens = require("src.core.game3.battle.effects.screens")

Capabilities.mistDefaultTurns = 3
local guard = {}
assertEq(BattleItems.applyGuardSpec(guard), true, "guard applies")
assertEq(guard.expMistTurns, 3, "guard turns")
assertEq(BattleItems.applyGuardSpec(guard), false, "guard already up")
assertEq(guard.expMistTurns, 3, "guard stays")

local mist = {}
Screens.mist({
  user = {},
  adapter = {
    ownSide = function() return mist end,
    sayText = function() end,
  },
})
assertEq(mist.expMistTurns, 3, "mist turns")
Capabilities.mistDefaultTurns = 5

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { mistTurns = 3 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ mistTurns = 3 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Capabilities.mistDefaultTurns = battleRules.mistTurns", 1, true), version)
end

print("PASS guard spec")
