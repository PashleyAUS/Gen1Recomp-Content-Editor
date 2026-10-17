-- Pokémon above 849 are banned at level 50 and at level 20. 849 is
-- allowed. Level 21 is allowed. A Battle Tent allows them. A cutoff
-- of 0 bans Pokémon 1. A ban level of 0 bans a high-tier Pokémon at
-- level 0 and leaves level 30 alone. Ruby, Sapphire, and Emerald
-- share this. FireRed does not.

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

local D = require("src.core.game3.rse.frontier.trainers")
assertEq(D.bansHighTier(50, 850, false), true, "850 is banned at level 50")
assertEq(D.bansHighTier(50, 849, false), false, "849 is allowed")
assertEq(D.bansHighTier(20, 850, false), true, "850 is banned at level 20")
assertEq(D.bansHighTier(21, 850, false), false, "level 21 is allowed")
assertEq(D.bansHighTier(50, 850, true), false, "a tent allows 850")
D.FRONTIER_MONS_HIGH_TIER = 0
assertEq(D.bansHighTier(50, 1, false), true, "a cutoff of 0 bans Pokémon 1")
D.FRONTIER_MONS_HIGH_TIER = 849
D.LOW_BAN_LEVEL = 0
assertEq(D.bansHighTier(0, 850, false), true, "a ban level of 0 bans level 0")
assertEq(D.bansHighTier(30, 850, false), false, "level 30 stays allowed")
D.LOW_BAN_LEVEL = 20

local Rules = require("FrontierRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, frontierRules = { highTier = 0, lowBan = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("FRONTIER_MONS_HIGH_TIER = 0", 1, true), version)
  assert(main:find("LOW_BAN_LEVEL = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", frontierRules = { highTier = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("FRONTIER_MONS_HIGH_TIER", 1, true), "firered")

print("PASS frontier tier")
