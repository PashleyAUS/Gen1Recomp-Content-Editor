-- Eight beaten trainers leave none of eight. Counting only the first
-- flag leaves seven. Counting none leaves all eight. Ruby, Sapphire,
-- and Emerald share the count. FireRed does not.

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
assertEq(Pyramid.trainersLeft(8, 0xFF), 0, "eight beaten trainers leave none")
Pyramid.MAX_TRAINERS = 1
assertEq(Pyramid.trainersLeft(8, 0xFF), 7, "one counted flag leaves seven")
Pyramid.MAX_TRAINERS = 0
assertEq(Pyramid.trainersLeft(8, 0xFF), 8, "no counted flags leave all eight")
Pyramid.MAX_TRAINERS = 8

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { trainers = 1 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("MAX_TRAINERS = 1", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { trainers = 1 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_TRAINERS", 1, true), "firered")

print("PASS pyramid trainers")
