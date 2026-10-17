-- Fourteen rooms times 20 clears is 280 wins, which stays on the
-- first wild set. 281 moves to the second. A first line of 0 keeps a
-- streak of 0 on the first set and moves 1 win to the second. Ruby,
-- Sapphire, and Emerald share the lines. FireRed does not.

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
assertEq(wild(280), 0, "280 wins stay on the first set")
assertEq(wild(281), 1, "281 wins move to the second set")
assertEq(wild(560), 1, "560 wins stay on the second set")
assertEq(wild(561), 2, "561 wins move to the third set")
assertEq(wild(840), 2, "840 wins stay on the third set")
assertEq(wild(841), 3, "841 wins move to the last set")
Pike.WILD_SET_1 = 0
assertEq(wild(0), 0, "a line of 0 keeps no wins on the first set")
assertEq(wild(1), 1, "one win moves on when the first line is 0")
Pike.WILD_SET_1 = 20

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { pikeWild1 = 0 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("Pike.WILD_SET_1 = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { pikeWild1 = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("WILD_SET_1", 1, true), "firered")

print("PASS pike wild")
