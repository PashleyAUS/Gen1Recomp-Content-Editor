-- Five matching digits win the lucky-number first prize. Three or four win
-- second. Two win third. Hoenn pays once two digits match, and five digits
-- are still the top prize. 0 digits means that line is won by any ID.

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

local Specials = require("src.script.gen2.Specials")
assertEq(Specials.luckyPrizeFor(5), 1, "five digits")
assertEq(Specials.luckyPrizeFor(3), 2, "three digits")
assertEq(Specials.luckyPrizeFor(2), 3, "two digits")
assertEq(Specials.luckyPrizeFor(1), 0, "one digit")
Specials.LUCKY_THIRD = 0
assertEq(Specials.luckyPrizeFor(0), 3, "third prize at zero")
Specials.LUCKY_THIRD = 2

local Lottery = require("src.core.game3.rse.lottery")
assertEq(Lottery.tierFor(1), 0, "one digit loses")
assertEq(Lottery.tierFor(2), 1, "two digits")
assertEq(Lottery.tierFor(5), 4, "five digits")
Lottery.MIN_DIGITS = 0
assertEq(Lottery.tierFor(0), 1, "any id")
assertEq(Lottery.tierFor(5), 4, "jackpot stays")
Lottery.MIN_DIGITS = 2

local Odds = require("LotteryOdds")
local Writer = require("ModWriter")
local Native = require("Gen3Native")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    lotteryOdds = { first = 0, third = 0 },
  })
  assert(main:find("LUCKY_FIRST = 0", 1, true), version)
  assert(main:find("LUCKY_THIRD = 0", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, lotteryOdds = { first = 0 } })
assert(not red:find("LUCKY_FIRST", 1, true), "red")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, lotteryOdds = { minDigits = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Odds.emit(p, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("MIN_DIGITS = 0", 1, true), version)
end
local out = {}
Odds.emit({ version = "firered", generation = 3, lotteryOdds = { minDigits = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MIN_DIGITS", 1, true), "firered")

print("PASS lottery")
