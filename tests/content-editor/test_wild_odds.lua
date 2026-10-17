-- Wild held items and headbutt gates.
-- FireRed splits one item at 50 or 5, and both items at 50 then 55.
-- Hoenn is nothing below 45 and rare from 95. Emerald Compound Eyes uses 20 and 80.
-- A Gen 2 tree finds nothing when the roll is at or above its gate.

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

local E = require("src.core.game3.encounters")
assertEq(E.heldItemFrlg(11, 22, 49), 11, "both, common")
assertEq(E.heldItemFrlg(11, 22, 50), 22, "both, rare")
assertEq(E.heldItemFrlg(11, 22, 55), nil, "both, nothing")
assertEq(E.heldItemFrlg(11, 0, 49), 11, "only common")
assertEq(E.heldItemFrlg(11, 0, 50), nil, "only common misses")
assertEq(E.heldItemFrlg(0, 22, 4), 22, "only rare")
assertEq(E.heldItemFrlg(0, 22, 5), nil, "only rare misses")
E.HELD_BOTH_COMMON = 0
assertEq(E.heldItemFrlg(11, 22, 0), 22, "common band zero")
E.HELD_BOTH_COMMON = 50
local none, rareAt = E.heldCuts(false)
assertEq(none, 45, "hoenn nothing")
assertEq(rareAt, 95, "hoenn rare")
none, rareAt = E.heldCuts(true)
assertEq(none, 20, "compound eyes nothing")
assertEq(rareAt, 80, "compound eyes rare")
E.HELD_NONE = 0
none = E.heldCuts(false)
assertEq(none, 0, "nothing band zero")
E.HELD_NONE = 45

local Trees = require("src.battle.gen2.Encounter")
assertEq(Trees.treeGate(Trees.TREEMON_SCORE_BAD), 1, "common tree")
assertEq(Trees.treeGate(Trees.TREEMON_SCORE_GOOD), 5, "good tree")
assertEq(Trees.treeGate(Trees.TREEMON_SCORE_RARE), 8, "rare tree")
Trees.TREE_BAD_GATE = 0
assertEq(Trees.treeGate(Trees.TREEMON_SCORE_BAD), 0, "gate zero")
Trees.TREE_BAD_GATE = 1
Trees.TREE_GOOD_BELOW = 0
assertEq(Trees.treeScore(0, 0, 0) == Trees.TREEMON_SCORE_GOOD, false, "good band zero")
Trees.TREE_GOOD_BELOW = 5
assertEq(Trees.treeScore(5, 4, 17), Trees.TREEMON_SCORE_RARE, "cart rare tree")
assertEq(Trees.treeScore(0, 0, 0), Trees.TREEMON_SCORE_GOOD, "cart offset keeps (0, 0) good")
Trees.TREE_COORD_ADD = 0
assertEq(Trees.treeScore(0, 0, 0), Trees.TREEMON_SCORE_RARE, "offset zero makes (0, 0) rare")
Trees.TREE_COORD_ADD = 4
Trees.TREE_COORD_DIV = 1
assertEq(Trees.treeScore(5, 4, 17), Trees.TREEMON_SCORE_GOOD, "divisor one leaves that tree good")
Trees.TREE_COORD_DIV = 5
Trees.TREE_COORD_MOD = 1
assertEq(Trees.treeScore(5, 4, 0), Trees.TREEMON_SCORE_RARE, "width one is always rare")
Trees.TREE_COORD_MOD = 10
Trees.TREE_COORD_WRAP = 1
assertEq(Trees.treeScore(5, 4, 0), Trees.TREEMON_SCORE_RARE, "wrap one is rare for trainer 0")
Trees.TREE_COORD_WRAP = 65536
assertEq(Trees.headbuttShakeFrames(), 32, "headbutt frames")
assertEq(Trees.headbuttShakeByte(), 64, "headbutt size")
local World = require("src.world.gen2.World")
local shaken = setmetatable({
  showText = function(_, _, done) done() end,
  playSfx = function() end,
}, { __index = World })
World.runHeadbutt(shaken, 3, 4)
assertEq(shaken.headbutt.timer, 32, "the tree waits 32 frames")
assertEq(shaken.shake.amplitude, 2, "64 is a two pixel shake")
assertEq(shaken.shake.left, 32, "the screen shakes for those frames")
Trees.HEADBUTT_SHAKE_FRAMES = 0
Trees.HEADBUTT_SHAKE_BYTE = 0
World.runHeadbutt(shaken, 3, 4)
assertEq(shaken.headbutt.timer, 0, "no frames rolls at once")
assertEq(shaken.shake.amplitude, 1, "byte 0 is a one pixel shake")
assertEq(shaken.shake.left, 0, "the screen shake uses the same count")
Trees.HEADBUTT_SHAKE_FRAMES = 32
Trees.HEADBUTT_SHAKE_BYTE = 0x40
local fishing = setmetatable({
  player = { cellX = 1, cellY = 2, facing = "down" },
  showEmote = function() end,
  showText = function() end,
}, { __index = World })
World.beginFishing(fishing, "battle", {})
assertEq(fishing.fishing.timer, 40, "the cast waits 40 frames")
Trees.FISH_CAST_FRAMES = 0
Trees.FISH_BITE_FRAMES = 0
World.beginFishing(fishing, "battle", {})
assertEq(fishing.fishing.timer, 0, "a cast of 0 does not wait")
World.updateFishing(fishing)
assertEq(fishing.fishing.phase, "bite", "a bite still follows")
assertEq(fishing.fishing.timer, 0, "a bite of 0 does not wait")
Trees.FISH_CAST_FRAMES = 40
Trees.FISH_BITE_FRAMES = 40

local Writer = require("ModWriter")
local Odds = require("WildOdds")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, wildOdds = { badGate = 0, bothCommon = 0, coordAdd = 0 } })
  assert(not main:find("TREE_BAD_GATE", 1, true), version)
  assert(not main:find("HELD_BOTH_COMMON", 1, true), version)
  assert(not main:find("TREE_COORD_ADD", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, wildOdds = { badGate = 0, treeDice = 1, coordAdd = 0, coordDiv = 1, coordMod = 1, coordWrap = 1, shakeFrames = 0, shakeByte = 0, fishCast = 0, fishBite = 0 } })
  assert(main:find("TREE_BAD_GATE = 0", 1, true), version)
  assert(main:find("TREE_DICE = 1", 1, true), version)
  assert(main:find("TREE_COORD_ADD = 0", 1, true), version)
  assert(main:find("TREE_COORD_DIV = 1", 1, true), version)
  assert(main:find("TREE_COORD_MOD = 1", 1, true), version)
  assert(main:find("TREE_COORD_WRAP = 1", 1, true), version)
  assert(main:find("HEADBUTT_SHAKE_FRAMES = 0", 1, true), version)
  assert(main:find("HEADBUTT_SHAKE_BYTE = 0", 1, true), version)
  assert(main:find("FISH_CAST_FRAMES = 0", 1, true), version)
  assert(main:find("FISH_BITE_FRAMES = 0", 1, true), version)
  assert(main:find("src.battle.gen2.Encounter", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, wildOdds = { bothCommon = 0, onlyRare = 0, shakeFrames = 0, fishCast = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Odds.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("HELD_BOTH_COMMON = 0", 1, true), version)
  assert(chunk:find("HELD_ONLY_RARE = 0", 1, true), version)
  assert(not chunk:find("HELD_NONE", 1, true), version)
  assert(not chunk:find("HEADBUTT_SHAKE", 1, true), version)
  assert(not chunk:find("FISH_CAST_FRAMES", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire" }) do
  local p = { version = version, generation = 3, wildOdds = { none = 0, eyesNone = 0 } }
  local out = {}
  Odds.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("HELD_NONE = 0", 1, true), version)
  assert(chunk:find("HELD_EYES_NONE = 0", 1, true), version)
  assert(not chunk:find("HELD_BOTH_COMMON", 1, true), version)
end
local emerald = {}
Odds.emit({ version = "emerald", generation = 3, wildOdds = { eyesRare = 0 } }, function() return "{}" end, emerald)
assert(table.concat(emerald, "\n"):find("HELD_EYES_RARE = 0", 1, true), "emerald")

print("PASS wild odds")
