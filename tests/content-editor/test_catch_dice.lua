-- Gen 2 rolls one number under 256. A roll under the rate catches.
-- A roll of 1 only produces 0, so a rate of at least 1 always catches.
-- Gold, Silver, and Crystal share the roll. Red does not.

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
local seen
local function random(n)
  seen = n
  return n - 1
end
local opts = { ball = "POKE_BALL", maxHp = 200, hp = 1, catchRate = 45, random = random }
local caught = Catching.vanillaAttempt(opts)
assertEq(seen, 256, "the cart rolls out of 256")
assertEq(caught, false, "255 is not under the rate")
Catching.CATCH_DICE = 1
caught = Catching.vanillaAttempt(opts)
assertEq(seen, 1, "a roll of 1 is used")
assertEq(caught, true, "0 is under the rate")
Catching.CATCH_DICE = 256

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, catchMath = { catchDice = 1 } })
  assert(main:find("CATCH_DICE = 1", 1, true), version)
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, catchMath = { catchDice = 1 } })
assert(not red:find("CATCH_DICE", 1, true), "red")

print("PASS catch dice")
