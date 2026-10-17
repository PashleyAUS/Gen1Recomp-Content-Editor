-- A Tower streak of 50 stays 50 under the 9999 ceiling. A ceiling of
-- 10 shows 10. A ceiling of 0 shows 0. Ruby, Sapphire, and Emerald
-- share it. The Pyramid keeps its own ceiling. FireRed does not emit
-- this one.

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
local Tower = require("src.core.game3.rse.frontier.tower")
local sess = { frontier = { _shaped = true, towerWinStreaks = { { 50 } } } }
assertEq(Tower.currentWinStreak(sess, 0, 0), 50, "50 stays 50")
D.MAX_STREAK = 10
assertEq(Tower.currentWinStreak(sess, 0, 0), 10, "a ceiling of 10 shows 10")
D.MAX_STREAK = 0
assertEq(Tower.currentWinStreak(sess, 0, 0), 0, "a ceiling of 0 shows 0")
D.MAX_STREAK = 9999

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { streak = 10 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("MAX_STREAK = 10", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { streak = 10 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_STREAK", 1, true), "firered")

print("PASS frontier streak")
