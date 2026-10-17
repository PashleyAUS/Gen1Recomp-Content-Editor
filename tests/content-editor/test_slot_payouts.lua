-- Three 7s pay 300 coins on every Game Corner machine that has them.
-- A payout of 0 pays nothing. Each game keeps its own table.

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

local Gen1 = require("src.ui.SlotMachine")
assertEq(Gen1.payoutOf("7"), 300, "red seven")
Gen1.PAYOUTS["7"] = 0
assertEq(Gen1.payoutOf("7"), 0, "red seven zero")
Gen1.PAYOUTS["7"] = 300

local Gen2 = require("src.ui.gen2.SlotMachine")
assertEq(Gen2.payout(0), 300, "gold seven")
Gen2.PAYOUTS[0] = 0
assertEq(Gen2.payout(0), 0, "gold seven zero")
Gen2.PAYOUTS[0] = 300

local Frlg = require("src.core.game3.slot_machine")
assertEq(Frlg.coinsFor(6), 300, "firered seven")
Frlg.PAYOUT_TABLE[6] = 0
assertEq(Frlg.coinsFor(6), 0, "firered seven zero")
Frlg.PAYOUT_TABLE[6] = 300

local bit = require("bit")
local Rse = require("src.core.game3.rse.slot_machine")
local machine = {
  payout = 0, matches = 0,
  T = { payouts = { [7] = 300 }, matchFlags = { [7] = 1 } },
}
Rse.PAYOUTS = { [7] = 0 }
Rse._award(machine, 7)
assertEq(machine.payout, 0, "emerald seven zero")
Rse.PAYOUTS = nil

local Writer = require("ModWriter")
local Native = require("Gen3Native")
local Pay = require("SlotPayouts")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, slotPayouts = { seven = 0 } })
  assert(main:find('PAYOUTS["7"] = 0', 1, true), version)
  assert(not main:find("PAYOUT_TABLE", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, slotPayouts = { seven = 0 } })
  assert(main:find("PAYOUTS[0] = 0", 1, true), version)
  assert(main:find("src.ui.gen2.SlotMachine", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, slotPayouts = { seven = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Pay.emit(p, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("PAYOUT_TABLE[6] = 0", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, slotPayouts = { replay = 5 } }
  assert(Native.used(p), version)
  local out = {}
  Pay.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("PAYOUTS[2] = 5", 1, true), version)
  assert(chunk:find("rse.slot_machine", 1, true), version)
end

print("PASS slot payouts")
