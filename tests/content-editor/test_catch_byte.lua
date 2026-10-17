-- Once the max-HP term overflows, Gen 2 keeps only its low byte. Max HP
-- 200 and 1 HP give a rate of 44. A byte of 128 makes that same throw 42.
-- Gold, Silver, and Crystal share the byte. Red does not.

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
local function rate()
  return Catching.rate({ ball = "POKE_BALL", maxHp = 200, hp = 1, catchRate = 45 })
end
assertEq(rate(), 44, "the low byte stays 150")
Catching.HP_LOW = 128
assertEq(rate(), 42, "a byte of 128 wraps to 22")
Catching.HP_LOW = 256

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, catchMath = { lowByte = 128 } })
  assert(main:find("HP_LOW = 128", 1, true), version)
  assert(main:find("src.battle.gen2.Catching", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, catchMath = { lowByte = 128 } })
assert(not red:find("HP_LOW", 1, true), "red")

print("PASS catch byte")
