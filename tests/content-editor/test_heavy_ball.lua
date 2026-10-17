-- Heavy Ball weight bands stay at the cart bonuses until they are edited.

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

local function highOf(weight)
  local half = math.floor(weight / 2)
  local sub1 = math.floor(half / 16)
  local sub2 = math.floor(sub1 / 2)
  return math.floor((half - sub1 - sub2) / 256)
end

local function weightFor(high)
  local weight = 0
  while highOf(weight) < high do
    weight = weight + 1
    if weight > 20000 then error("no weight for high " .. high) end
  end
  return weight
end

local Catching = require("src.battle.gen2.Catching")
local vanilla = Catching.HEAVY_BANDS
assertEq(Catching.heavyBallBoost(0), -20, "lightest")
assertEq(Catching.heavyBallBoost(weightFor(4)), 0, "second band")
assertEq(Catching.heavyBallBoost(weightFor(8)), 20, "third band")
assertEq(Catching.heavyBallBoost(weightFor(12)), 30, "fourth band")
assertEq(Catching.heavyBallBoost(weightFor(16)), 40, "heaviest")

local function rate(weight)
  return Catching.rate({
    ball = "HEAVY_BALL", catchRate = 45, maxHp = 10, hp = 0, weight = weight,
  })
end
assertEq(rate(0), 25, "light catch rate")

Catching.HEAVY_BANDS = {
  { below = 4, bonus = 5 },
  { bonus = 9 },
}
assertEq(Catching.heavyBallBoost(0), 5, "edited light")
assertEq(Catching.heavyBallBoost(weightFor(16)), 9, "edited heavy")
assertEq(rate(0), 50, "edited catch rate")
Catching.HEAVY_BANDS = vanilla

local Writer = require("ModWriter")
local bands = {
  { below = 2, bonus = 1 },
  { below = 8, bonus = 0 },
  { below = 12, bonus = 20 },
  { below = 16, bonus = 30 },
  { bonus = 40 },
}
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    specialtyBalls = { HEAVY_BALL = { bands = bands } } })
  assert(main:find("Catching.HEAVY_BANDS =", 1, true), version)
  assert(main:find("below = 2", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1,
  specialtyBalls = { HEAVY_BALL = { bands = bands } } })
assert(not red:find("HEAVY_BANDS", 1, true), "red stays off")

require("Items")
print("PASS heavy ball")
