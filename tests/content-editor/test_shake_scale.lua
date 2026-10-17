-- A full-HP catch rate of 45 is not a sure catch. A roll of 0 still
-- shakes when the numerator is the cartridge value. A numerator of 0
-- never shakes. FireRed, LeafGreen, Ruby, Sapphire, and Emerald share it.

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

local Catching = require("src.core.game3.battle.catching")
local foe = { mon = { hp = 100, maxHp = 100, level = 50 } }
local function toss()
  return Catching.tryCatch(4, foe, {}, nil, function() return 0 end)
end
local caught, shakes = toss()
assertEq(caught, true, "a zero roll still catches")
assertEq(shakes, 4, "four shakes")
Catching.SHAKE_NUM = 0
caught, shakes = toss()
assertEq(caught, false, "a numerator of 0 never shakes")
assertEq(shakes, 0, "no shakes")
Catching.SHAKE_NUM = 1048560

local Rules = require("Gen3BattleRules")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emitCatchMath({ version = version, gen3CatchMath = { shakeNum = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("Catching.SHAKE_NUM = 0", 1, true), version)
  assert(main:find("src.core.game3.battle.catching", 1, true), version)
end

print("PASS shake scale")
