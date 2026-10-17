-- A Heavy Ball turns the dex weight into a high byte with three divides,
-- then /256. Weight 1000 stays in the lightest band. Dividing that byte
-- by 1 lands in the heaviest band. Gold, Silver, and Crystal share it.

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

local Catching = require("src.battle.gen2.Catching")
assertEq(Catching.heavyBallBoost(1000), -20, "1000 is the lightest band")
Catching.HEAVY_DIV[4] = 1
assertEq(Catching.heavyBallBoost(1000), 40, "divisor 1 is the heaviest band")
Catching.HEAVY_DIV[4] = 256
Catching.HEAVY_DIV[1] = 1
assertEq(Catching.heavyDiv(1, 2), 1, "a divisor of 1 is kept")
Catching.HEAVY_DIV[1] = 0
assertEq(Catching.heavyDiv(1, 2), 1, "zero becomes 1")
Catching.HEAVY_DIV[1] = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    specialtyBalls = { HEAVY_BALL = { divs = { 1, 16, 2, 256 } } },
  })
  assert(main:find("HEAVY_DIV[1] = 1", 1, true), version)
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  specialtyBalls = { HEAVY_BALL = { divs = { 1, 16, 2, 256 } } },
})
assert(not red:find("HEAVY_DIV", 1, true), "red")

print("PASS heavy div")
