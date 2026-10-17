-- A streak of 999 stays at 999, and a ceiling of 0 never rises. 41 wins
-- still use the short prize list. 42 wins use the long one. A streak of
-- 140 gives wild Pokémon high IVs, and 139 does not. One bag slot that
-- holds 5 refuses a sixth. Ruby, Sapphire, and Emerald share these.
-- FireRed does not.

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

local Pyramid = require("src.core.game3.rse.frontier.pyramid")
local function sess(streak)
  return { frontier = { _shaped = true, lvlMode = 0, pyramidWinStreaks = { streak }, pyramidRecordStreaks = { streak } } }
end
local full = sess(999)
Pyramid.updateStreak(full)
assertEq(full.frontier.pyramidWinStreaks[1], 999, "999 stays at 999")
Pyramid.MAX_STREAK = 0
local none = sess(0)
Pyramid.updateStreak(none)
assertEq(none.frontier.pyramidWinStreaks[1], 0, "a ceiling of 0 never rises")
Pyramid.MAX_STREAK = 999

assertEq(Pyramid.usesLongRewards(41), false, "41 wins stay on the short list")
assertEq(Pyramid.usesLongRewards(42), true, "42 wins use the long list")
Pyramid.LONG_STREAK = 0
assertEq(Pyramid.usesLongRewards(0), false, "0 wins stay short when the line is 0")
assertEq(Pyramid.usesLongRewards(1), true, "1 win is long when the line is 0")
Pyramid.LONG_STREAK = 41

assertEq(Pyramid.wildIvsAreHigh(140), true, "140 gives high IVs")
assertEq(Pyramid.wildIvsAreHigh(139), false, "139 keeps ordinary IVs")
Pyramid.WILD_HIGH_IV_STREAK = 0
assertEq(Pyramid.wildIvsAreHigh(0), true, "a line of 0 is high from the start")
Pyramid.WILD_HIGH_IV_STREAK = 140

Pyramid.BAG_ITEMS_COUNT = 1
Pyramid.MAX_BAG_ITEM_CAPACITY = 5
local bag = { frontier = { _shaped = true, lvlMode = 0 } }
assertEq(Pyramid.bagAdd(bag, 10, 5), true, "five fit in a stack of five")
local _, qty = Pyramid.bagLists(bag)
assertEq(qty[1], 5, "the stack is five")
assertEq(Pyramid.bagAdd(bag, 10, 1), false, "a sixth does not fit")
assertEq(qty[1], 5, "the stack stays at five")

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { maxStreak = 0, stack = 5 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("MAX_STREAK = 0", 1, true), version)
  assert(main:find("MAX_BAG_ITEM_CAPACITY = 5", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { maxStreak = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_STREAK", 1, true), "firered")

print("PASS pyramid limits")
