-- Gen 2 waits 20, 10, 5, then 3 minutes between Pokégear calls,
-- and rings on half of the coin flips. 0 minutes is ready now.
-- A pass line of 0 never rings. 256 always rings.

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

local Phone = require("src.core.gen2.Phone")
assertEq(Phone.callPasses(127), true, "under 128 rings")
assertEq(Phone.callPasses(128), false, "128 does not")
Phone.CALL_PASS_BELOW = 0
assertEq(Phone.callPasses(0), false, "pass zero")
Phone.CALL_PASS_BELOW = 256
assertEq(Phone.callPasses(255), true, "pass 256")
Phone.CALL_PASS_BELOW = 128

local save = { phone = {} }
Phone.RECEIVE_CALL_DELAYS = { 0, 10, 5, 3 }
Phone.nextReceiveDelay(save, { clock = { day = 1, hour = 1, minute = 1 } })
assertEq(save.phone.delayMins, 0, "first wait zero")
Phone.RECEIVE_CALL_DELAYS = { 20, 10, 5, 3 }
assertEq(Phone.callCycleCap(), 3, "four waits")

local Writer = require("ModWriter")
local Odds = require("PhoneOdds")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    phoneOdds = { delays = { 0, 10, 5, 3 }, passBelow = 0 },
  })
  assert(main:find("RECEIVE_CALL_DELAYS = { 0, 10, 5, 3 }", 1, true), version)
  assert(main:find("CALL_PASS_BELOW = 0", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, phoneOdds = { passBelow = 0 } })
  assert(not main:find("CALL_PASS_BELOW", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Odds.emit({ version = version, generation = 3, phoneOdds = { passBelow = 0 } }, function() return "{}" end, out)
  assert(not table.concat(out, "\n"):find("CALL_PASS_BELOW", 1, true), version)
end

print("PASS phone odds")
