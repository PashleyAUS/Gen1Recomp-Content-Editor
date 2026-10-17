-- A lucky Hoenn visit adds 10 to the first regular prize and takes 10
-- off the last. 0 leaves that visit on the ordinary odds. Pika Power
-- bolts stop at 16, and a cap of 0 never adds one.
-- Ruby, Sapphire, and Emerald share this machine.

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

local Slots = require("src.core.game3.rse.slot_machine")
local function probs(values)
  local t = {}
  for i = 0, 4 do t[i] = { [0] = values[i + 1] } end
  return t
end
local function machine(lucky, values)
  local i = 0
  return setmetatable({
    luckyGame = lucky and true or false,
    machineId = 0,
    random = function()
      i = i + 1
      return 15
    end,
    T = { biasProbRegular = probs(values) },
  }, Slots)
end

assertEq(machine(true, { 10, 0, 0, 0, 0 }):trySelectBiasRegular(), 0, "plus 10 catches the first prize")
Slots.LUCKY_NUDGE = 0
assertEq(machine(true, { 10, 0, 0, 0, 0 }):trySelectBiasRegular(), 5, "a shift of 0 misses it")
Slots.LUCKY_NUDGE = 10
assertEq(machine(false, { 10, 0, 0, 0, 0 }):trySelectBiasRegular(), 5, "an ordinary visit is not shifted")
assertEq(machine(true, { 0, 0, 0, 0, 20 }):trySelectBiasRegular(), 5, "minus 10 drops the last prize")
Slots.LUCKY_NUDGE = 0
assertEq(machine(true, { 0, 0, 0, 0, 20 }):trySelectBiasRegular(), 4, "no shift keeps the last prize")
Slots.LUCKY_NUDGE = 10

assertEq(Slots.nextBolts(15), 16, "the 16th bolt still counts")
assertEq(Slots.nextBolts(16), 16, "bolts stop at 16")
Slots.BOLT_CAP = 0
assertEq(Slots.nextBolts(0), 0, "a cap of 0 adds nothing")
Slots.BOLT_CAP = 16

local Luck = require("RseSlotLuck")
local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  local project = { version = version, generation = 3, rseSlotLuck = { nudge = 0, boltCap = 0 } }
  assert(Native.used(project), version .. " counts")
  Luck.emit(project, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("LUCKY_NUDGE = 0", 1, true), version)
  assert(main:find("BOLT_CAP = 0", 1, true), version)
  assert(main:find("src.core.game3.rse.slot_machine", 1, true), version)
end
local out = {}
Luck.emit({ version = "firered", generation = 3, rseSlotLuck = { nudge = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("LUCKY_NUDGE", 1, true), "firered")
out = {}
Luck.emit({ version = "gold", generation = 2, rseSlotLuck = { nudge = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("LUCKY_NUDGE", 1, true), "gold")

print("PASS rse slot luck")
