-- A Level Ball multiplies again when the wild level is below half, and
-- again below a quarter. Level 9 against 20 is below half and not below
-- a quarter, so a rate of 10 becomes 40. Dividing the half rung by 1
-- makes that rung always land. Gold, Silver, and Crystal share it.

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
local function rate(enemy)
  return Catching.specialtyRate(10, "LEVEL_BALL", { playerLevel = 20, level = enemy })
end
assertEq(rate(10), 20, "level 10 is only below the player")
assertEq(rate(9), 40, "level 9 is below half")
assertEq(rate(4), 80, "level 4 is below a quarter")
Catching.LEVEL_BALL_DIV[1] = 1
assertEq(rate(10), 40, "divisor 1 always takes the half rung")
Catching.LEVEL_BALL_DIV[1] = 2

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    specialtyBalls = { LEVEL_BALL = { divs = { 1, 4 } } },
  })
  assert(main:find("LEVEL_BALL_DIV[1] = 1", 1, true), version)
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  specialtyBalls = { LEVEL_BALL = { divs = { 1, 4 } } },
})
assert(not red:find("LEVEL_BALL_DIV", 1, true), "red")

print("PASS level ball")
