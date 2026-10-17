-- Day-Care withdrawal is 100 plus 100 per level gained.
-- A fee of 0, or 0 per level, is a real price.

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

local Daycare = require("src.core.game3.daycare")
local prev = Daycare.levelsGained
Daycare.levelsGained = function() return 2 end
assertEq(Daycare.cost({}, 10), 300, "two levels")
Daycare.WITHDRAW_FEE = 0
assertEq(Daycare.cost({}, 10), 200, "no flat fee")
Daycare.WITHDRAW_FEE_PER_LEVEL = 0
assertEq(Daycare.cost({}, 10), 0, "free")
Daycare.WITHDRAW_FEE = 100
Daycare.WITHDRAW_FEE_PER_LEVEL = 100
Daycare.levelsGained = prev

local Breeding = require("src.core.gen2.Breeding")
assertEq(Breeding.retrievePrice(2, nil), 300, "gen2 two levels")
assertEq(Breeding.retrievePrice(0, { breeding = { withdrawFee = 0, withdrawFeePerLevel = 0 } }), 0, "gen2 free")

local Hatch = require("Gen3Breeding")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3Hatch = { withdrawFee = 0, withdrawFeePerLevel = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Hatch.emitHatch(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("WITHDRAW_FEE = 0", 1, true), version)
  assert(chunk:find("WITHDRAW_FEE_PER_LEVEL = 0", 1, true), version)
end

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, gen3Hatch = { withdrawFee = 0 } })
assert(not red:find("WITHDRAW_FEE", 1, true), "red")

print("PASS daycare fee")
