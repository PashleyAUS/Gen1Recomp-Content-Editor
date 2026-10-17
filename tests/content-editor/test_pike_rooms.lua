-- Fourteen rooms keep a streak of 280 on the first wild set, and
-- 281 moves to the next. One room does that at 20 and 21. Room 14 of
-- 14 is not the last room. Room 15 is. One room makes room 2 the last.
-- Ruby, Sapphire, and Emerald share the length. FireRed does not.

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

local Pike = require("src.core.game3.rse.frontier.pike")
local function wild(streak)
  return Pike.wildMonHeaderId({ frontier = { _shaped = true, lvlMode = 0, pikeWinStreaks = { streak } } })
end
local function final(room)
  return Pike.isNextRoomFinal({ frontier = { _shaped = true, curChallengeBattleNum = room } })
end
assertEq(wild(280), 0, "280 wins stay on the first wild set")
assertEq(wild(281), 1, "281 wins move to the next wild set")
assertEq(final(14), false, "room 14 of 14 is not the last")
assertEq(final(15), true, "room 15 is the last")
Pike.NUM_PIKE_ROOMS = 1
assertEq(wild(20), 0, "one room keeps 20 wins on the first set")
assertEq(wild(21), 1, "one room moves 21 wins to the next set")
assertEq(final(1), false, "room 1 of 1 is not the last")
assertEq(final(2), true, "room 2 of 1 is the last")
Pike.NUM_PIKE_ROOMS = 14
assertEq(Pike.sleepTurns(), 7, "a Pike sleep room lasts 7 turns")
Pike.STATUS1_SLEEP_TURNS = 0
assertEq(Pike.sleepTurns(), 0, "zero Pike sleep turns")
Pike.STATUS1_SLEEP_TURNS = 7

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { pikeRooms = 1, pikeSleep = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("Pike.NUM_PIKE_ROOMS = 1", 1, true), version)
  assert(main:find("Pike.STATUS1_SLEEP_TURNS = 0", 1, true), version)
  assert(main:find("src.core.game3.rse.frontier.pike", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { pikeRooms = 1, pikeSleep = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("NUM_PIKE_ROOMS", 1, true), "firered")
assert(not table.concat(out, "\n"):find("STATUS1_SLEEP_TURNS", 1, true), "firered sleep")

print("PASS pike rooms")
