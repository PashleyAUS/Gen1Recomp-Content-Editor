-- A class reward of 10 times level 10 is 100. The cart keeps that in
-- two bytes, so it stays 100. Wrapping at 64 leaves 36. Gold, Silver,
-- and Crystal share the wrap. Red does not.

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

local Prize = require("src.battle.gen2.Prize")
assertEq(Prize.reward(10, 10), 100, "100 fits in two bytes")
Prize.REWARD_MOD = 64
assertEq(Prize.reward(10, 10), 36, "64 keeps the remainder")
Prize.REWARD_MOD = 65536

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, prizeRules = { rewardMod = 64 } })
  assert(main:find("rewardMod = 64", 1, true), version)
  assert(main:find("Prize.REWARD_MOD = prizeRules.rewardMod", 1, true), version)
  assert(main:find("src.battle.gen2.Prize", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, prizeRules = { rewardMod = 64 } })
assert(not red:find("REWARD_MOD", 1, true), "red")

print("PASS reward mod")
