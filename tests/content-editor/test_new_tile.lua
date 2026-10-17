-- Stepping onto a new patch of grass allows a battle on a roll under 60.
-- 0 never allows that first step. 100 on a roll of 100 always does.
-- Red, Blue, Yellow, Gold, Silver, and Crystal do not use this gate.

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
assertEq(E.allowsNewTile(0), true, "0 allows")
assertEq(E.allowsNewTile(59), true, "59 allows")
assertEq(E.allowsNewTile(60), false, "60 denies")
E.NEW_TILE_CHANCE = 0
assertEq(E.allowsNewTile(0), false, "chance zero")
E.NEW_TILE_CHANCE = 100
assertEq(E.allowsNewTile(99), true, "chance 100")
E.NEW_TILE_CHANCE = 60

local Writer = require("ModWriter")
local Rate = require("EncounterRate")
for _, version in ipairs({ "red", "blue", "yellow", "gold", "silver", "crystal" }) do
  local gen = (version == "gold" or version == "silver" or version == "crystal") and 2 or 1
  local main = Writer.emitMain({ version = version, generation = gen, encounterRate = { newTile = 0 } })
  assert(not main:find("NEW_TILE_CHANCE", 1, true), version)
end
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, encounterRate = { newTile = 0, newTileDice = 1 } }
  assert(Native.used(p), version)
  local out = {}
  Rate.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("NEW_TILE_CHANCE = 0", 1, true), version)
  assert(chunk:find("NEW_TILE_DICE = 1", 1, true), version)
end

print("PASS new tile")
