-- Pokerus odds are data. Gen 2 reads Pokerus.*, and Gen 3 reads Pokemon.*.

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

local function scripted(values)
  local i = 0
  return function()
    i = i + 1
    return values[i] or 0
  end
end

local Pokerus = require("src.core.gen2.Pokerus")
local spreadDefault = Pokerus.SPREAD_CHANCE
local contractDefault = Pokerus.CONTRACT_THRESHOLD
assertEq(spreadDefault, 85, "cart spread")
assertEq(contractDefault, 3, "cart contract")

local party = { { pokerus = 0x13 }, { pokerus = 0 } }
assertEq(Pokerus.give(party, { random = scripted({ 0, 200 }) }), 2, "cart spread walks forward")
assertEq(party[2].pokerus ~= 0, true, "neighbour caught it")

party = { { pokerus = 0x13 }, { pokerus = 0 } }
Pokerus.SPREAD_CHANCE = 0
assertEq(Pokerus.give(party, { random = scripted({ 0, 200 }) }), nil, "spread 0 stays put")
assertEq(party[2].pokerus, 0, "neighbour stays clean")
Pokerus.SPREAD_CHANCE = spreadDefault

local fresh = { { pokerus = 0 } }
assertEq(Pokerus.give(fresh, {
  reachedGoldenrod = true,
  random = scripted({ 0, 2, 0, 16 }),
}), 1, "cart contract")
assertEq(fresh[1].pokerus ~= 0, true, "the mon is infected")

fresh = { { pokerus = 0 } }
Pokerus.CONTRACT_THRESHOLD = 0
assertEq(Pokerus.give(fresh, {
  reachedGoldenrod = true,
  random = scripted({ 0, 0, 0, 16 }),
}), nil, "threshold 0 never contracts")
assertEq(fresh[1].pokerus, 0, "still clean")
Pokerus.CONTRACT_THRESHOLD = contractDefault

local Writer = require("ModWriter")
local function project(version)
  return {
    version = version, generation = 2,
    pokerus = { spreadChance = 0, contractThreshold = 256 },
  }
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain(project(version))
  assert(main:find("Pokerus.SPREAD_CHANCE = pokerus.spreadChance", 1, true), version .. " spread")
  assert(main:find("Pokerus.CONTRACT_THRESHOLD = pokerus.contractThreshold", 1, true), version .. " contract")
end
local red = Writer.emitMain({ version = "red", generation = 1,
  pokerus = { spreadChance = 0 } })
assert(not red:find("Pokerus.SPREAD_CHANCE", 1, true), "red stays quiet")

local Pokemon = require("src.core.game3.pokemon")
Pokemon.POKERUS_ENABLED = true
Pokemon.POKERUS_CONTRACT_BELOW = 0
local calls = { 0 }
package.loaded["src.core.game3.rng"] = {
  Random = function()
    return table.remove(calls, 1) or 1
  end,
}
local gen3 = { { species = 1 }, { species = 1 } }
Pokemon.randomlyGivePartyPokerus(gen3, {})
assertEq(gen3[1].pokerus, nil, "contract 0 never infects")

Pokemon.POKERUS_CONTRACT_BELOW = 65536
calls = { 0, 0, 1 }
Pokemon.randomlyGivePartyPokerus(gen3, {})
assertEq(type(gen3[1].pokerus), "number", "contract always infects")

gen3 = { { species = 1, pokerus = 0x11 }, { species = 1, pokerus = 0 } }
Pokemon.POKERUS_SPREAD_DENOM = 1
calls = { 0 }
Pokemon.partySpreadPokerus(gen3, {})
assertEq(gen3[2].pokerus, 0x11, "spread 1 in 1 copies the byte")
Pokemon.POKERUS_ENABLED = nil
Pokemon.POKERUS_CONTRACT_BELOW = nil
Pokemon.POKERUS_SPREAD_DENOM = 3

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { pokerusSpreadDenom = 1, pokerusContractBelow = 0 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ pokerusSpreadDenom = 1, pokerusContractBelow = 0 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("POKERUS_SPREAD_DENOM", 1, true), version .. " spread")
  assert(chunk:find("POKERUS_CONTRACT_BELOW", 1, true), version .. " contract")
  assert(chunk:find("POKERUS_ENABLED = true", 1, true), version .. " enabled")
end

print("PASS pokerus")
