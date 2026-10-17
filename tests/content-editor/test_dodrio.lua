-- A blue berry is 10 points, green 30, gold 50. A miss takes 50 away.
-- The prize is given at 3000. A berry worth 0 adds nothing.
-- The earlier games do not have Dodrio Berry Picking.

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

local R = require("src.core.game3.minigames.dodrio_berry_picking.rules")
local T = { berry_score_multipliers = { 10, 30, 50, 50 } }
assertEq(R.score(T, { [0] = 1 }), 10, "blue")
assertEq(R.score(T, { [0] = 1, [3] = 1 }), 0, "a miss wipes a blue")
assertEq(R.PRIZE_SCORE, 3000, "prize")
R.SCORE_MULT = { [0] = 0 }
assertEq(R.score(T, { [0] = 3, [1] = 1 }), 30, "blue worth zero")
R.SCORE_MULT = nil
R.PRIZE_SCORE = 0
assertEq(R.PRIZE_SCORE, 0, "prize at zero")
R.PRIZE_SCORE = 3000

local Rules = require("DodrioRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, dodrioRules = { blue = 0, prize = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rules.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("SCORE_MULT[0] = 0", 1, true), version)
  assert(chunk:find("PRIZE_SCORE = 0", 1, true), version)
end
local Writer = require("ModWriter")
local main = Writer.emitMain({ version = "gold", generation = 2, dodrioRules = { prize = 0 } })
assert(not main:find("PRIZE_SCORE", 1, true), "gold")

print("PASS dodrio")
