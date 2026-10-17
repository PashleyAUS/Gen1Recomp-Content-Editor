-- An egg inherits 3 IVs until that count is edited. Zero inherits none.

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

local Profile = require("src.core.game3.profile")
local savedProfile = Profile.forSession
Profile.forSession = function() return {} end

local Rng = require("src.core.game3.rng")
local savedRandom = Rng.Random
Rng.Random = function() return 0 end

local Breeding = require("src.core.game3.breeding")
local parent = { ivs = { hp = 11, atk = 12, def = 13, spe = 14, spa = 15, spd = 16 } }
local dc = { parent, parent }

local function fresh()
  return {}
end

local egg = fresh()
Breeding.inheritIVs(egg, dc, {})
assertEq(egg.ivs.hp, 11, "first iv")
assertEq(egg.ivs.atk, 12, "second iv")
assertEq(egg.ivs.def, 13, "third iv")
assertEq(egg.ivs.spe, nil, "the other three stay rolled")

Breeding.INHERITED_IV_COUNT = 0
egg = fresh()
Breeding.inheritIVs(egg, dc, {})
assertEq(egg.ivs.hp, nil, "zero inherits nothing")

Breeding.INHERITED_IV_COUNT = 6
egg = fresh()
Breeding.inheritIVs(egg, dc, {})
assertEq(egg.ivs.spd, 16, "all six")
Breeding.INHERITED_IV_COUNT = 3

Profile.forSession = savedProfile
Rng.Random = savedRandom

local Hatch = require("Gen3Breeding")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Hatch.emitHatch({
    version = version, generation = 3,
    gen3Hatch = { ivCount = 0 },
  }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("INHERITED_IV_COUNT = 0", 1, true), version)
end

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, gen3Hatch = { ivCount = 0 } })
assert(not red:find("INHERITED_IV_COUNT", 1, true), "red has no egg ivs")

print("PASS inherited ivs")
