-- Low Kick keeps the cart weight bands until they are edited.

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
assertEq(Damage.lowKickPower({ weight = 99 }), 20, "under 100")
assertEq(Damage.lowKickPower({ weight = 100 }), 40, "at 100")
assertEq(Damage.lowKickPower({ weight = 2000 }), 120, "heaviest")
Damage.LOW_KICK_BANDS[1].power = 5
assertEq(Damage.lowKickPower({ weight = 0 }), 5, "edited")
Damage.LOW_KICK_BANDS[1].power = 20

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    lowKickBands = { { below = 100, power = 5 }, { power = 120 } } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitLowKick(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.LOW_KICK_BANDS =", 1, true), version)
  assert(chunk:find("power = 5", 1, true), version)
end

require("Rules")
print("PASS low kick")
