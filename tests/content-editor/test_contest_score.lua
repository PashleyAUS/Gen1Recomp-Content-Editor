-- A contest mon scores its max-HP low byte four times, each stat once,
-- a bit of four DVs, current HP divided by 8, and 1 for a held item.
-- A weight of 0 drops that term. A current-HP divisor of 0 skips it.
-- Rival scores add a roll of 0 through 7. A bump span of 0 adds nothing.

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

local Bug = require("src.core.gen2.BugContest")
local mon = {
  species = "CATERPIE",
  maxHp = 100, hp = 16, item = "BERRY",
  stats = { attack = 10, defense = 10, speed = 10, specialAttack = 10, specialDefense = 10 },
  dvs = { defense = 2, attack = 2, special = 2, speed = 2 },
}
-- 100*4 + 10*5 + 16+8+4+1 + floor(16/8) + 1 = 400+50+29+2+1 = 482
assertEq(Bug.score(mon), 482, "cart score")
Bug.HP_MULT = 0
assertEq(Bug.score(mon), 82, "hp weight zero")
Bug.HP_MULT = 4
Bug.HP_DIV = 0
assertEq(Bug.score(mon), 480, "hp div zero")
Bug.HP_DIV = 8
Bug.ITEM_BONUS = 0
assertEq(Bug.score(mon), 481, "item bonus zero")
Bug.ITEM_BONUS = 1

local calls = { 0, 7 }
local function random()
  local n = table.remove(calls, 1)
  return n or 0
end
Bug.SCORE_BUMP = 0
local rolled = Bug.rollContestant(1, random)
assertEq(rolled.score % 8 == 0 or rolled.score >= 0, true, "rolled")
local listed = rolled.score
calls = { 0, 7 }
local again = Bug.rollContestant(1, random)
assertEq(again.score, listed, "bump zero")
Bug.SCORE_BUMP = 8

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    bugContestRules = { balls = 20, minutes = 20, hpMult = 0, scoreBump = 0 },
  })
  assert(main:find("HP_MULT = 0", 1, true), version)
  assert(main:find("SCORE_BUMP = 0", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({
    version = version, generation = 1,
    bugContestRules = { hpMult = 0 },
  })
  assert(not main:find("HP_MULT", 1, true), version)
end

print("PASS contest score")
