-- A catch rate of 1 wobbles again on a roll under 63. A rate of 6 uses
-- the row for 7, which is 103. Zero wobbles means the first check is the
-- verdict. Gold, Silver, and Crystal share the table.

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
assertEq(Catching.wobbleChance(1), 63, "rate 1")
assertEq(Catching.wobbleChance(6), 103, "rate 6 uses the row for 7")
assertEq(Catching.wobbleChance(255), 255, "rate 255 always wobbles")
Catching.WOBBLE_PROBABILITIES[1][2] = 0
assertEq(Catching.wobbleChance(1), 0, "a chance of 0 breaks free")
Catching.WOBBLE_PROBABILITIES[1][2] = 63

local caught = { caught = true, rate = 1 }
assertEq(Catching.wobbleStep(caught), 0, "the first of three wobbles")
assertEq(Catching.wobbleStep(caught), 0, "the second")
assertEq(Catching.wobbleStep(caught), 0, "the third")
assertEq(Catching.wobbleStep(caught), 1, "the fourth check clicks")
Catching.WOBBLE_LIMIT = 0
local missed = { caught = false, rate = 1 }
assertEq(Catching.wobbleStep(missed, function() return 0 end), 2, "zero wobbles breaks at once")
Catching.WOBBLE_LIMIT = 3

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    wobbleOdds = { limit = 0, chances = { [1] = 0 } },
  })
  assert(main:find("WOBBLE_LIMIT = 0", 1, true), version)
  assert(main:find("WOBBLE_PROBABILITIES[1][2] = 0", 1, true), version)
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, wobbleOdds = { limit = 0 } })
assert(not red:find("WOBBLE_LIMIT", 1, true), "red")

print("PASS wobble odds")
