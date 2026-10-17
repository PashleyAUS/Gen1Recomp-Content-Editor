-- A normal machine arms sevens on a roll above 253. A lucky one uses 250.
-- A roll above 210 can match. A roll of 0 arms 60 sure wins. 0 sure wins
-- arms none. 255 never arms that line.
-- Red, Blue, and Yellow share this machine.

package.path = table.concat({
  "tools/content-editor/?.lua",
  "tools/content-editor/panels/?.lua",
  "tools/save-editor/?.lua",
  "runtime/gen1recomp/?.lua",
  "runtime/gen1recomp/?/init.lua",
  package.path,
}, ";")

love = dofile("tests/love_stub.lua")

local function assertEq(actual, expected, label)
  if actual ~= expected then
    error(label .. ": got " .. tostring(actual) .. " expected " .. tostring(expected))
  end
end

local Slot = require("src.ui.SlotMachine")
local roll = 0
love.math.random = function() return roll end
local function spin(lucky)
  return { lucky = lucky and true or false, sevenBar = false, canWin = false, allowMatchesCounter = 0 }
end

assertEq(Slot.barChance(true), 250, "lucky line")
assertEq(Slot.barChance(false), 253, "plain line")
roll = 254
local plain = spin(false)
Slot.setFlags(plain)
assertEq(plain.sevenBar, true, "254 arms sevens")
roll = 251
local lucky = spin(true)
Slot.setFlags(lucky)
assertEq(lucky.sevenBar, true, "251 arms a lucky machine")
local quiet = spin(false)
Slot.setFlags(quiet)
assertEq(quiet.sevenBar, false, "251 does not arm a normal machine")
assertEq(quiet.canWin, true, "251 can still match")
Slot.WIN_ABOVE = 255
Slot.setFlags(quiet)
assertEq(quiet.canWin, false, "255 allows no match")
Slot.WIN_ABOVE = 210
Slot.MATCH_SPINS = 0
roll = 0
local armed = spin(false)
Slot.setFlags(armed)
assertEq(armed.allowMatchesCounter, 0, "zero roll arms nothing")
Slot.MATCH_SPINS = 60

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, slotLuck = { matchSpins = 0, plainBar = 255 } })
  assert(main:find("MATCH_SPINS = 0", 1, true), version)
  assert(main:find("PLAIN_BAR = 255", 1, true), version)
  assert(main:find("src.ui.SlotMachine", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, slotLuck = { matchSpins = 0 } })
  assert(not main:find("MATCH_SPINS", 1, true), version)
end
local Luck = require("SlotLuck")
local out = {}
Luck.emit({ version = "firered", generation = 3, slotLuck = { matchSpins = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MATCH_SPINS", 1, true), "firered")

print("PASS slot luck")
