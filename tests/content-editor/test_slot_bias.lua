-- A normal Gen 2 machine aims at a 7 when the roll is under 1.
-- The first cutoff the roll reaches wins. 0 on the first row catches
-- only a roll of 0. Gold, Silver, and Crystal share both tables.

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
assertEq(Slot.initBias(-1, false, roll(0)), 0, "roll 0 is a 7")
assertEq(Slot.initBias(-1, false, roll(2)), 0x04, "roll 2 is a Poké Ball")
Slot.BIAS_NORMAL[1][1] = 0
assertEq(Slot.initBias(-1, false, roll(0)), 0, "zero still catches roll 0")
assertEq(Slot.initBias(-1, false, roll(1)), 0x04, "roll 1 passes a zero cutoff")
Slot.BIAS_NORMAL[1][1] = 1
assertEq(Slot.initBias(-1, true, roll(1)), 0, "lucky roll 1 is still a 7")
Slot.BIAS_LUCKY[1][1] = 0
assertEq(Slot.initBias(-1, true, roll(1)), 0x04, "lucky zero lets roll 1 through")
Slot.BIAS_LUCKY[1][1] = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, slotBias = { n7 = 0, l7 = 0 } })
  assert(main:find("BIAS_NORMAL[1][1] = 0", 1, true), version)
  assert(main:find("BIAS_LUCKY[1][1] = 0", 1, true), version)
  assert(main:find("src.ui.gen2.SlotMachine", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, slotBias = { n7 = 0 } })
assert(not red:find("BIAS_NORMAL", 1, true), "red")
local Bias = require("SlotBias")
local out = {}
Bias.emit({ version = "emerald", generation = 3, slotBias = { n7 = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("BIAS_NORMAL", 1, true), "emerald")

Slot.MANIP_COUNTER = 0
assertEq(Slot.stopReel1(1, 0), 1, "zero chase stops on the press")
Slot.MANIP_COUNTER = 1
assertEq(Slot.stopReel1(1, 0x10), 2, "one slot does not reach Squirtle")
Slot.MANIP_COUNTER = 4
assertEq(Slot.stopReel1(1, 0x10), 3, "four slots reach Squirtle")

local chase = Writer.emitMain({ version = "gold", generation = 2, slotBias = { chase = 0 } })
assert(chase:find("MANIP_COUNTER = 0", 1, true), "chase emits")
local redChase = Writer.emitMain({ version = "red", generation = 1, slotBias = { chase = 0 } })
assert(not redChase:find("MANIP_COUNTER", 1, true), "red chase")

print("PASS slot bias")
