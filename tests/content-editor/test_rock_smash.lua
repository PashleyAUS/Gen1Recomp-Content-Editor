-- Rock Smash finds a Pokémon on a roll below 4 out of 10, then walks the
-- rock list with a roll out of 100. A chance of 0 finds nothing. A roll
-- width of 1 always rolls 0, which is a find. Gold, Silver, and Crystal
-- emit the three fields. Red and FireRed do not.

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

local Encounter = require("src.battle.gen2.Encounter")
assertEq(Encounter.rockFinds(3), true, "3 of 10 finds one")
assertEq(Encounter.rockFinds(4), false, "4 of 10 finds nothing")
assertEq(Encounter.rockDice(), 10, "cart roll")
assertEq(Encounter.rockListDice(), 100, "cart list roll")
Encounter.ROCK_GATE = 0
assertEq(Encounter.rockFinds(0), false, "chance zero finds nothing")
Encounter.ROCK_GATE = 4
Encounter.ROCK_DICE = 1
assertEq(Encounter.rockDice(), 1, "roll width one")
Encounter.ROCK_DICE = 10
Encounter.ROCK_LIST_DICE = 1
assertEq(Encounter.rockListDice(), 1, "list width one")
Encounter.ROCK_LIST_DICE = 100

local Writer = require("ModWriter")
local Odds = require("WildOdds")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    wildOdds = { rockGate = 0, rockDice = 1, rockList = 1 },
  })
  assert(main:find("ROCK_GATE = 0", 1, true), version)
  assert(main:find("ROCK_DICE = 1", 1, true), version)
  assert(main:find("ROCK_LIST_DICE = 1", 1, true), version)
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  wildOdds = { rockGate = 0, rockDice = 1, rockList = 1 },
})
assert(not red:find("ROCK_GATE", 1, true), "red")
local frlg = {}
Odds.emit({
  version = "firered", generation = 3,
  wildOdds = { rockGate = 0, rockDice = 1, rockList = 1 },
}, function() return "{}" end, frlg)
assert(not table.concat(frlg, "\n"):find("ROCK_GATE", 1, true), "firered")

print("PASS rock smash")
