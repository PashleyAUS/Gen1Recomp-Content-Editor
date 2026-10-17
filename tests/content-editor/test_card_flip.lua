-- Card Flip costs 3 coins. The exact card pays 72.
-- A cost of 0 is a free hand. A prize of 0 pays nothing.
-- Card 0 is a real card. Red, Blue, Yellow, and the Game Boy Advance
-- games do not have Card Flip.

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

local Card = require("src.ui.gen2.CardFlip")
assertEq(Card.BET, 3, "bet")
assertEq(Card.payout(2, 2, 0), 72, "exact card 0")
assertEq(Card.payout(2, 0, 0), 6, "mon pair")
assertEq(Card.payout(0, 0, 0), 0, "impossible")
Card.PAYOUT_CARD = 0
assertEq(Card.payout(2, 2, 0), 0, "exact card pays zero")
Card.PAYOUT_CARD = 72

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    cardFlipRules = { bet = 0, card = 0 },
  })
  assert(main:find("CardFlip.BET = 0", 1, true), version)
  assert(main:find("PAYOUT_CARD = 0", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({
    version = version, generation = 1,
    cardFlipRules = { bet = 0 },
  })
  assert(not main:find("PAYOUT_CARD", 1, true), version)
end
local Rules = require("CardFlipRules")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, generation = 3, cardFlipRules = { bet = 0 } }, function() return "{}" end, out)
  assert(not table.concat(out, "\n"):find("PAYOUT_CARD", 1, true), version)
end

print("PASS card flip")
