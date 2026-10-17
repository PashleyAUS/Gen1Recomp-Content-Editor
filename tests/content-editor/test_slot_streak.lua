-- A Gen 2 seven streak still uses the cartridge bit checks at 1 in 8 and
-- 1 in 4. A roll with bit 1 set is not a rare visit. 1 always happens and
-- 0 never does, and the roll is still taken. Gold, Silver, and Crystal share it.

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

local Slot = require("src.ui.gen2.SlotMachine")
local function roll(n)
  return function() return n end
end
assertEq(Slot.rollKeepSevenChance(roll(0)), true, "a clear roll is a rare visit")
assertEq(Slot.rollKeepSevenChance(roll(2)), false, "bit 1 is not a rare visit")
assertEq(Slot.keepSevenBias(true, roll(0)), true, "a rare visit keeps a clear 7")
assertEq(Slot.keepSevenBias(false, roll(0)), true, "a normal visit keeps a clear 7")
assertEq(Slot.keepSevenBias(false, roll(4)), false, "bit 2 drops a normal 7")
Slot.RARE_VISIT = 1
assertEq(Slot.rollKeepSevenChance(roll(2)), true, "1 in 1 is always a rare visit")
Slot.RARE_VISIT = 0
assertEq(Slot.rollKeepSevenChance(roll(0)), false, "1 in 0 is never a rare visit")
Slot.RARE_VISIT = 8
Slot.STREAK_PLAIN = 1
assertEq(Slot.keepSevenBias(false, roll(4)), true, "1 in 1 keeps the 7")
Slot.STREAK_PLAIN = 4
Slot.STREAK_RARE = 0
assertEq(Slot.keepSevenBias(true, roll(0)), false, "1 in 0 drops the 7")
Slot.STREAK_RARE = 8

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, slotStreak = { rareVisit = 1, streakPlain = 1 } })
  assert(main:find("RARE_VISIT = 1", 1, true), version)
  assert(main:find("STREAK_PLAIN = 1", 1, true), version)
  assert(main:find("src.ui.gen2.SlotMachine", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, slotStreak = { rareVisit = 1 } })
assert(not red:find("RARE_VISIT", 1, true), "red")
local Streak = require("SlotStreak")
local out = {}
Streak.emit({ version = "emerald", generation = 3, slotStreak = { rareVisit = 1 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("RARE_VISIT", 1, true), "emerald")

print("PASS slot streak")
