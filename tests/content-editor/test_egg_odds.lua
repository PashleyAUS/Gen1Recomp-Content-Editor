-- Day-Care egg odds. The cart bands stay until they are edited. Zero is a real chance.

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

local Breeding = require("src.core.gen2.Breeding")
assertEq(Breeding.eggChance(230), 80, "gen2 best")
assertEq(Breeding.eggChance(169), 30, "gen2 fair")
assertEq(Breeding.eggChance(50), 10, "gen2 low")
local data = { breeding = { eggHigh = 0, eggBase = 256 } }
assertEq(Breeding.eggChance(230, data), 0, "gen2 best can be zero")
assertEq(Breeding.eggChance(50, data), 256, "gen2 low can be certain")

local oldGender = Breeding.genderOf
Breeding.genderOf = function(_, mon) return mon.gender or "unknown" end
local pokemon = {
  PIKACHU = { eggGroups = { "EGG_FAIRY", "EGG_FAIRY" } },
  RAICHU = { eggGroups = { "EGG_FAIRY", "EGG_FAIRY" } },
  NIDORAN_F = { eggGroups = { "EGG_MONSTER", "EGG_MONSTER" } },
}
local function mon(species, gender, otId, defense)
  return { species = species, gender = gender, otId = otId, dvs = { defense = defense, special = 0 } }
end
local plain = { pokemon = pokemon }
local female = mon("PIKACHU", "female", 1, 1)
local male = mon("PIKACHU", "male", 2, 2)
assertEq(Breeding.vanillaCompatibility(plain, female, male), 254, "same species")
assertEq(Breeding.vanillaCompatibility(plain, female, mon("PIKACHU", "male", 1, 2)), 177, "same trainer")
assertEq(Breeding.vanillaCompatibility(plain, female, mon("RAICHU", "male", 2, 2)), 128, "other species")
local tuned = { pokemon = pokemon, breeding = { sameSpecies = 200, otherSpecies = 0, sameOtCut = 0 } }
assertEq(Breeding.vanillaCompatibility(tuned, female, male), 200, "same species score")
assertEq(Breeding.vanillaCompatibility(tuned, female, mon("PIKACHU", "male", 1, 2)), 200, "a cut of 0 keeps the score")
assertEq(Breeding.vanillaCompatibility(tuned, female, mon("RAICHU", "male", 2, 2)), 0, "other species can refuse")
assertEq(Breeding.compatibilityText(200), "friendly", "200 is friendly")
assertEq(Breeding.compatibilityText(200, { breeding = { caresAt = 200 } }), "cares", "cares can start at 200")
assertEq(Breeding.compatibilityText(200, { breeding = { caresAt = 255, friendlyAt = 255 } }), "interest", "both lines can sit at 255")
assertEq(Breeding.compatibilityText(0, { breeding = { friendlyAt = 0 } }), "none", "zero stays no interest")
local nido = { pokemon = pokemon, breeding = { nidoranFemale = 0 } }
local mother = mon("NIDORAN_F", "female", 1, 1)
local father = mon("NIDORAN_F", "male", 2, 2)
assertEq(Breeding.eggSpecies(nido, mother, father, function() return 0 end), "NIDORAN_M", "a line of 0 is always male")
nido.breeding.nidoranFemale = 256
assertEq(Breeding.eggSpecies(nido, mother, father, function() return 200 end), "NIDORAN_F", "a line of 256 is always female")
local line = {
  pokemon = {
    BULBASAUR = { index = 1, evolutions = { { into = "IVYSAUR" } } },
    IVYSAUR = { index = 2, evolutions = { { into = "VENUSAUR" } } },
    VENUSAUR = { index = 3 },
  },
}
assertEq(Breeding.baseForm(line, "VENUSAUR"), "BULBASAUR", "two steps back")
line.breeding = { baseWalks = 1 }
assertEq(Breeding.baseForm(line, "VENUSAUR"), "IVYSAUR", "one step back")
line.breeding.baseWalks = 0
assertEq(Breeding.baseForm(line, "VENUSAUR"), "VENUSAUR", "no steps keeps the parent")
Breeding.genderOf = oldGender

local G3 = require("src.core.game3.breeding")
assertEq(G3.compatScore("PARENTS_LOW_COMPATIBILITY", 20), 20, "gen3 low")
assertEq(G3.compatScore("PARENTS_MED_COMPATIBILITY", 50), 50, "gen3 mid")
assertEq(G3.compatScore("PARENTS_MAX_COMPATIBILITY", 70), 70, "gen3 high")
G3.PARENTS_MAX_COMPATIBILITY = 0
assertEq(G3.compatScore("PARENTS_MAX_COMPATIBILITY", 70), 0, "gen3 high can be zero")
G3.PARENTS_MAX_COMPATIBILITY = 70
local Pokemon = require("src.core.game3.pokemon")
local savedNames, savedEvos = Pokemon._names, Pokemon._evolutions
Pokemon._names = Pokemon._names or {}
Pokemon._evolutions = {
  [1] = { { target = 2 } },
  [2] = { { target = 3 } },
  [3] = { { target = 4 } },
  [4] = { { target = 5 } },
  [5] = { { target = 6 } },
  [6] = { { target = 7 } },
}
assertEq(G3.eggSpecies(7), 2, "five steps back")
G3.EVOS_PER_MON = 0
assertEq(G3.eggSpecies(7), 7, "no steps keeps the parent")
G3.EVOS_PER_MON = 1
assertEq(G3.eggSpecies(7), 6, "one step back")
G3.EVOS_PER_MON = 5
Pokemon._names, Pokemon._evolutions = savedNames, savedEvos
local function parents(a, b)
  return { { item = a }, { item = b } }
end
assertEq(G3.alterEggSpeciesWithIncenseItem(360, parents(0, 0)), 202, "wynaut without incense")
assertEq(G3.alterEggSpeciesWithIncenseItem(360, parents(221, 0)), 360, "lax incense keeps wynaut")
assertEq(G3.alterEggSpeciesWithIncenseItem(350, parents(0, 0)), 183, "azurill without incense")
assertEq(G3.alterEggSpeciesWithIncenseItem(350, parents(0, 220)), 350, "sea incense keeps azurill")
G3.WYNAUT = 25
G3.WOBBUFFET = 26
G3.LAX_INCENSE = 0
assertEq(G3.alterEggSpeciesWithIncenseItem(25, parents(1, 1)), 26, "a chosen baby still needs its incense")
assertEq(G3.alterEggSpeciesWithIncenseItem(25, parents(0, 1)), 25, "item 0 counts as holding it")
G3.WYNAUT = 360
G3.WOBBUFFET = 202
G3.LAX_INCENSE = 221
assertEq(G3.eggIsMale(32767), false, "32767 is female")
assertEq(G3.eggIsMale(32768), true, "32768 is male")
assertEq(G3.swapMaleEgg(29, false), 29, "a female personality stays Nidoran female")
assertEq(G3.swapMaleEgg(29, true), 32, "a male personality is Nidoran male")
assertEq(G3.swapMaleEgg(387, true), 386, "a male personality is Volbeat")
G3.EGG_GENDER_MALE = 0
assertEq(G3.eggIsMale(0), true, "a line of 0 makes every egg male")
G3.EGG_GENDER_MALE = 65535
assertEq(G3.eggIsMale(65534), false, "65534 stays under the last value")
assertEq(G3.eggIsMale(65535), true, "only 65535 is male")
G3.EGG_GENDER_MALE = 32768
G3.NIDORAN_F = 0
G3.NIDORAN_M = 1
assertEq(G3.swapMaleEgg(0, true), 1, "species 0 can be the female that swaps")
G3.NIDORAN_F = 29
G3.NIDORAN_M = 32

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    breeding = { eggHigh = 0, eggBase = 256, sameSpecies = 0, sameOtCut = 0, nidoranFemale = 0, baseWalks = 0 },
  })
  assert(main:find("eggHigh", 1, true), version .. " high")
  assert(main:find("eggBase", 1, true), version .. " base")
  assert(main:find("sameSpecies = 0", 1, true), version .. " score")
  assert(main:find("nidoranFemale = 0", 1, true), version .. " nidoran")
  assert(main:find("baseWalks = 0", 1, true), version .. " steps")
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  breeding = { eggHigh = 0 },
})
assert(not red:find("eggHigh", 1, true), "red has no eggs")
local gold = Writer.emitMain({ version = "gold", generation = 2, gen3Hatch = { wynaut = 0, maleAt = 0 } })
assert(not gold:find("WYNAUT", 1, true), "gold has no incense babies")
assert(not gold:find("EGG_GENDER_MALE", 1, true), "gold has no male egg line")

local Hatch = require("Gen3Breeding")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Hatch.emitHatch({
    version = version, generation = 3,
    gen3Hatch = { compatLow = 0, compatMid = 40, compatMax = 100, baseWalks = 0, wynaut = 0, laxIncense = 0, nidoranF = 0, maleAt = 0 },
  }, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("PARENTS_LOW_COMPATIBILITY = 0", 1, true), version)
  assert(chunk:find("PARENTS_MED_COMPATIBILITY = 40", 1, true), version)
  assert(chunk:find("PARENTS_MAX_COMPATIBILITY = 100", 1, true), version)
  assert(chunk:find("EVOS_PER_MON = 0", 1, true), version)
  assert(chunk:find("WYNAUT = 0", 1, true), version)
  assert(chunk:find("LAX_INCENSE = 0", 1, true), version)
  assert(chunk:find("NIDORAN_F = 0", 1, true), version)
  assert(chunk:find("EGG_GENDER_MALE = 0", 1, true), version)
end

print("PASS egg odds")
