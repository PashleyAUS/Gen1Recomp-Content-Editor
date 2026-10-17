-- A streak of 140 wins is round 0 when a challenge is 7 battles.
-- Ten battles per challenge leaves that streak on round 14. A tent
-- stores the next trainer on battle 0 of 3, and not on battle 2. One
-- tent battle stores nobody. Ruby, Sapphire, and Emerald share these.
-- FireRed does not.

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

local D = require("src.core.game3.rse.frontier.trainers")
local Pyramid = require("src.core.game3.rse.frontier.pyramid")
local sess = { frontier = { _shaped = true, lvlMode = 0, pyramidWinStreaks = { 140 } } }
assertEq(Pyramid.round(sess), 0, "140 wins is round 0 of a 7-battle challenge")
D.STAGES_PER_CHALLENGE = 10
assertEq(Pyramid.round(sess), 14, "ten battles per challenge leaves round 14")
D.STAGES_PER_CHALLENGE = 7

assertEq(D.tentStoresNext(0), true, "battle 0 of 3 stores the next trainer")
assertEq(D.tentStoresNext(2), false, "battle 2 of 3 stores nobody")
D.TENT_STAGES_PER_CHALLENGE = 1
assertEq(D.tentStoresNext(0), false, "one tent battle stores nobody")
D.TENT_STAGES_PER_CHALLENGE = 3

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { stages = 10, tentStages = 1 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("STAGES_PER_CHALLENGE = 10", 1, true), version)
  assert(main:find("TENT_STAGES_PER_CHALLENGE = 1", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { stages = 10 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("STAGES_PER_CHALLENGE", 1, true), "firered")

print("PASS frontier stages")
