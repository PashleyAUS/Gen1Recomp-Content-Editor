-- Encounter slot odds. Gen 1 rods miss on an odd byte and pick among four.
-- Gen 2 grass and water are cumulative percents; fishing rolls out of 256.
-- Gen 3 weights the twelve grass slots and five water slots, and each rod
-- has its own cumulative bands. Hoenn numbers those bands from 0.

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

local Overworld = require("src.world.OverworldController")
local group = {
  { species = "GOLDEEN", level = 10 },
  { species = "POLIWAG", level = 10 },
}
local hit = Overworld.fishingPick(group, 0)
assertEq(hit.species, "GOLDEEN", "even byte takes the first")
assertEq(Overworld.fishingPick(group, 1), nil, "odd byte misses")
Overworld.FISH_BITE_MOD = 0
hit = Overworld.fishingPick(group, 1)
assertEq(hit.species, "POLIWAG", "modulus 0 can bite an odd byte")
Overworld.FISH_BITE_MOD = 2
Overworld.FISH_SLOT_SPAN = 1
hit = Overworld.fishingPick(group, 4)
assertEq(hit.species, "GOLDEEN", "span 1 stays on the first")
Overworld.FISH_SLOT_SPAN = 4
assertEq(Overworld.fishRoll(), 256, "cart rod roll")
Overworld.FISH_ROLL = 1
assertEq(Overworld.fishRoll(), 1, "rod roll width one")
assertEq(Overworld.fishingPick(group, 0).species, "GOLDEEN", "the only roll of a width of 1 bites")
Overworld.FISH_ROLL = 256
assertEq(Overworld.fishAnimFrames(false), 190, "a miss lasts 190 frames")
assertEq(Overworld.fishAnimFrames(true), 280, "a bite lasts 280 frames")
local function lastEvent(bite, frames)
  local fa = { bite = bite }
  local hit
  for _ = 1, frames do hit = Overworld.stepFishAnim(fa) or hit end
  return hit, fa.frames
end
local ev, frame = lastEvent(false, 190)
assertEq(ev, "verdict", "the miss answers on its last frame")
assertEq(frame, 190, "frame 190")
Overworld.FISH_ANIM.wait = 0
assertEq(Overworld.fishAnimFrames(false), 90, "a wait of 0 ends when the cast would")
ev, frame = lastEvent(false, 90)
assertEq(ev, "verdict", "a wait of 0 still answers")
assertEq(frame, 90, "it answers on frame 90")
Overworld.FISH_ANIM.wait = 100
Overworld.FISH_ANIM.bubble = 0
assertEq(Overworld.fishAnimFrames(true), 221, "no bubble ends one frame after the shake")
local bite = { bite = true }
local last
for _ = 1, Overworld.fishAnimFrames(true) do
  last = Overworld.stepFishAnim(bite) or last
end
assertEq(last, "verdict", "no bubble still answers")
Overworld.FISH_ANIM.bubble = 60

local Encounter = require("src.battle.gen2.Encounter")
local tables = {
  grass = { ROUTE = { slots = { DAY = {
    { species = "PIDGEY", level = 2 },
    { species = "RATTATA", level = 3 },
    { species = "SENTRET", level = 3 },
    { species = "CATERPIE", level = 3 },
    { species = "WEEDLE", level = 3 },
    { species = "HOPPIP", level = 4 },
    { species = "HOOTHOOT", level = 4 },
  } } } },
  fishGroups = { pond = { old = { { chance = 10, species = "MAGIKARP", level = 5 } } } },
}
local function zero() return 0 end
assertEq(Encounter.grassSlot(tables, "ROUTE", "DAY", zero).species, "PIDGEY", "first grass band")
Encounter.GRASS_SLOT_CHANCES = { 0, 100, 100, 100, 100, 100, 100 }
assertEq(Encounter.grassSlot(tables, "ROUTE", "DAY", zero).species, "RATTATA", "zero first band")
Encounter.GRASS_SLOT_CHANCES = { 30, 60, 80, 90, 95, 99, 100 }
local seen
Encounter.fish(tables, "pond", "old", function(n) seen = n return 0 end)
assertEq(seen, 256, "fish dice")
Encounter.FISH_DICE = 1
Encounter.fish(tables, "pond", "old", function(n) seen = n return 0 end)
assertEq(seen, 1, "fish dice one")
Encounter.FISH_DICE = 256

local E = require("src.core.game3.encounters")
assertEq(E.fishingIndex({ 70, 100 }, { 1, 2 }, 0, 100), 1, "old rod first")
assertEq(E.fishingIndex({ 70, 100 }, { 1, 2 }, 70, 100), 2, "old rod second")
assertEq(E.fishingIndex({ 70, 100 }, { 0, 1 }, 70, 100), 1, "hoenn second is slot 1")
E.FRLG_FISH_OLD = { 0, 100 }
assertEq(E.fishingIndex(E.FRLG_FISH_OLD, { 1, 2 }, 0, 100), 2, "zero first band")
E.FRLG_FISH_OLD = { 70, 100 }
E.FISH_TOTAL = 1
assertEq(E.fishingIndex({ 70, 100 }, { 1, 2 }, 70, 1), 1, "roll of 1 keeps the remainder")
E.FISH_TOTAL = 100

local Writer = require("ModWriter")
local Slots = require("EncounterSlots")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, encounterSlots = { biteMod = 0, slotSpan = 1, fishRoll = 1, rodWait = 0, rodBubble = 0 } })
  assert(main:find("FISH_BITE_MOD = 0", 1, true), version)
  assert(main:find("FISH_SLOT_SPAN = 1", 1, true), version)
  assert(main:find("FISH_ROLL = 1", 1, true), version)
  assert(main:find("FISH_ANIM.wait = 0", 1, true), version)
  assert(main:find("FISH_ANIM.bubble = 0", 1, true), version)
  assert(not main:find("GRASS_SLOT_CHANCES", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    encounterSlots = { grass = { 0, 100, 100, 100, 100, 100, 100 }, fishDice = 1 },
  })
  assert(main:find("GRASS_SLOT_CHANCES = { 0, 100, 100, 100, 100, 100, 100 }", 1, true), version)
  assert(main:find("FISH_DICE = 1", 1, true), version)
  assert(not main:find("FISH_BITE_MOD", 1, true), version)
  assert(not main:find("FISH_ROLL", 1, true), version)
  assert(not main:find("FISH_ANIM", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, encounterSlots = { old = { 0, 100 }, fishTotal = 1 } }
  assert(Native.used(p), version)
  local out = {}
  Slots.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("FRLG_FISH_OLD = { 0, 100 }", 1, true), version)
  assert(chunk:find("FISH_TOTAL = 1", 1, true), version)
  assert(not chunk:find("RSE_FISH_OLD", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, encounterSlots = { land = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100 } } }
  assert(Native.used(p), version)
  local out = {}
  Slots.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("LAND_WEIGHTS = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 100 }", 1, true), version)
  assert(not chunk:find("FRLG_FISH", 1, true), version)
end

print("PASS encounter slots")
