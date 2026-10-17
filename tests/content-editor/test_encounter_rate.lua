-- Wild encounter modifiers. Gen 1 has none. Gen 2 doubles or halves for the
-- radio and halves again for a Cleanse Tag. Gen 3 scales the rate, then applies
-- the bike, flutes, Cleanse Tag, and abilities. Hoenn's dice is 2880; Kanto's is 1600.

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

local Gen1 = require("src.world.Encounter")
local route = { grass = { rate = 10, slots = {
  { species = "PIDGEY", level = 2 },
  { species = "RATTATA", level = 3 },
} } }
assertEq(Gen1.roll(route, function() return 9 end).species, "PIDGEY", "9 of 256 connects")
assertEq(Gen1.roll(route, function() return 10 end), nil, "10 of 256 misses")
assertEq(Gen1.roll({ grass = { rate = 0, slots = {} } }, function() error("rolled") end), nil, "rate zero")
Gen1.RATE_DICE = 1
assertEq(Gen1.roll(route, function(_, hi)
  if hi ~= 0 then error("width") end
  return 0
end).species, "PIDGEY", "a roll width of 1 connects")
Gen1.RATE_DICE = 256

local World = require("src.world.gen2.World")
assertEq(World.musicEncounterRate(10, "Music_PokemonMarch"), 20, "march doubles")
assertEq(World.musicEncounterRate(10, "Music_RuinsOfAlphRadio"), 20, "ruins doubles")
assertEq(World.musicEncounterRate(10, "Music_PokemonLullaby"), 5, "lullaby halves")
assertEq(World.musicEncounterRate(10, "Music_PalletTown"), 10, "other songs stay")
World.MUSIC_DOUBLE = 0
assertEq(World.musicEncounterRate(10, "Music_PokemonMarch"), 0, "radio double zero")
World.MUSIC_DOUBLE = 3
assertEq(World.musicEncounterRate(10, "Music_PokemonMarch"), 30, "radio triple")
World.MUSIC_HALF_DIV = 1
assertEq(World.musicEncounterRate(10, "Music_PokemonLullaby"), 10, "lullaby divisor 1")
World.MUSIC_DOUBLE = 2
World.MUSIC_HALF_DIV = 2
assertEq(World.cleanseEncounterRate(10), 5, "gen2 cleanse")
World.CLEANSE_DIV = 1
assertEq(World.cleanseEncounterRate(10), 10, "gen2 cleanse divisor 1")
World.CLEANSE_DIV = 2

local Trees = require("src.battle.gen2.Encounter")
assertEq(Trees.triggers(0, function() return 0 end), false, "rate zero never connects")
assertEq(Trees.triggers(10, function() return 9 end), true, "9 of 256 connects")
assertEq(Trees.triggers(10, function() return 10 end), false, "10 of 256 misses")
Trees.RATE_DICE = 1
assertEq(Trees.triggers(10, function(n)
  if n ~= 1 then error("dice") end
  return 0
end), true, "a roll width of 1 connects")
Trees.RATE_DICE = 256

local E = require("src.core.game3.encounters")
assertEq(E.encounterRate(10), 160, "firered scale")
E.RATE_SCALE = 0
assertEq(E.encounterRate(10), 0, "scale zero")
E.RATE_SCALE = 16
E.FRLG_MAX_RATE = 50
assertEq(E.encounterRate(10), 50, "firered cap")
E.FRLG_MAX_RATE = 1600
local Player = require("src.core.game3.player")
Player.biking = true
E.BIKE_NUM = 0
assertEq(E.encounterRate(10), 0, "bike percent zero")
E.BIKE_NUM = 80
Player.biking = false
assertEq(E.bikeRate(160), 128, "bike 80 of 100")
assertEq(E.fluteUp(100), 150, "white flute")
E.FLUTE_UP_DIV = 1
assertEq(E.fluteUp(100), 200, "white flute divisor 1")
E.FLUTE_UP_DIV = 2
assertEq(E.cleanseRate(90), 60, "cleanse 2 of 3")
E.CLEANSE_NUM = 0
assertEq(E.cleanseRate(90), 0, "cleanse share zero")
E.CLEANSE_NUM = 2
assertEq(E.illuminateRate(10), 20, "illuminate")
E.ILLUMINATE_MULT = 0
assertEq(E.illuminateRate(10), 0, "illuminate zero")
E.ILLUMINATE_MULT = 2
assertEq(E.rseMaxRate(), 2880, "hoenn dice")
assertEq(E.frlgMaxRate(), 1600, "kanto dice")

local R = require("src.core.game3.encounter_rules.rse").bind(E, E._h, {})
local ok, hoenn = pcall(R.encounterRate, 10, {})
if not ok then error("hoenn rate: " .. tostring(hoenn)) end
assertEq(hoenn, 160, "hoenn scale")
E.RSE_MAX_RATE = 40
ok, hoenn = pcall(R.encounterRate, 10, {})
if not ok then error("hoenn cap: " .. tostring(hoenn)) end
assertEq(hoenn, 40, "hoenn cap")
E.RSE_MAX_RATE = 2880

local Writer = require("ModWriter")
local Rate = require("EncounterRate")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, encounterRate = { musicDouble = 0, rateScale = 0, rateDice = 1 } })
  assert(not main:find("MUSIC_DOUBLE", 1, true), version)
  assert(not main:find("RATE_SCALE", 1, true), version)
  assert(main:find("RATE_DICE = 1", 1, true), version)
  assert(main:find("src.world.Encounter", 1, true), version)
  assert(not main:find("src.battle.gen2.Encounter", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, encounterRate = { musicDouble = 0, cleanseDiv = 1, rateDice = 1 } })
  assert(main:find("MUSIC_DOUBLE = 0", 1, true), version)
  assert(main:find("CLEANSE_DIV = 1", 1, true), version)
  assert(main:find("RATE_DICE = 1", 1, true), version)
  assert(main:find("src.battle.gen2.Encounter", 1, true), version)
  assert(not main:find("src.world.Encounter\")", 1, true), version)
  assert(main:find("src.world.gen2.World", 1, true), version)
  assert(not main:find("RATE_SCALE", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, encounterRate = { rateScale = 0, maxRate = 1 } }
  assert(Native.used(p), version)
  local out = {}
  Rate.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("RATE_SCALE = 0", 1, true), version)
  assert(chunk:find("FRLG_MAX_RATE = 1", 1, true), version)
  assert(not chunk:find("RSE_MAX_RATE", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, encounterRate = { maxRate = 1, illuminate = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rate.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("RSE_MAX_RATE = 1", 1, true), version)
  assert(chunk:find("ILLUMINATE_MULT = 0", 1, true), version)
  assert(not chunk:find("FRLG_MAX_RATE", 1, true), version)
end

print("PASS encounter rate")
