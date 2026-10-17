-- Randoms 0 and 1 put the entrance on square 0 and the exit on square
-- 1. The same random puts them on 1 and 15 so they do not share a
-- square. Four squares put a shared roll on 1 and 3. One square keeps
-- both on 0. Ruby, Sapphire, and Emerald share the count. FireRed does
-- not.

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
local function place(exitRoll, entranceRoll, squares)
  if squares ~= nil then Pyramid.NUM_SQUARES = squares end
  local sess = { frontier = { _shaped = true, pyramidRandoms = { exitRoll, 0, 0, entranceRoll } } }
  return Pyramid.entranceAndExit(sess)
end
local entrance, exit = place(1, 0)
assertEq(entrance, 0, "entrance is square 0")
assertEq(exit, 1, "exit is square 1")
entrance, exit = place(0, 0)
assertEq(entrance, 1, "a shared roll moves the entrance to 1")
assertEq(exit, 15, "a shared roll moves the exit to 15")
entrance, exit = place(0, 4, 4)
assertEq(entrance, 1, "four squares put the entrance on 1")
assertEq(exit, 3, "four squares put the exit on 3")
entrance, exit = place(3, 9, 1)
assertEq(entrance, 0, "one square keeps the entrance on 0")
assertEq(exit, 0, "one square keeps the exit on 0")
Pyramid.NUM_SQUARES = 16

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { squares = 4 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("NUM_SQUARES = 4", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { squares = 4 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("NUM_SQUARES", 1, true), "firered")

print("PASS pyramid squares")
