-- Gen 3 friendship steps stay on the cart table until a band or step is edited.
-- Gen 1 has no friendship. Gen 2 already reads Happiness.CHANGES.

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

local Pokemon = require("src.core.game3.pokemon")
local function mon(friendship, extra)
  local row = { species = 1, friendship = friendship }
  for k, v in pairs(extra or {}) do row[k] = v end
  return row
end
local low = mon(0)
Pokemon.adjustFriendship(low, 0)
assertEq(low.friendship, 5, "level up")
local mid = mon(100)
Pokemon.adjustFriendship(mid, 0)
assertEq(mid.friendship, 103, "mid band")
Pokemon.FRIENDSHIP_DELTAS[0][1] = 8
local edited = mon(0)
Pokemon.adjustFriendship(edited, 0)
assertEq(edited.friendship, 8, "edited step")
Pokemon.FRIENDSHIP_DELTAS[0][1] = 5

local soothe = mon(0, { item = 184 })
Pokemon.adjustFriendship(soothe, 0)
assertEq(soothe.friendship, 7, "soothe")
Pokemon.SOOTHE_NUM = 200
soothe = mon(0, { item = 184 })
Pokemon.adjustFriendship(soothe, 0)
assertEq(soothe.friendship, 10, "soothe edited")
Pokemon.SOOTHE_NUM = 150

local faint = mon(50)
Pokemon.adjustFriendshipOnBattleFaint(faint, 10, 40)
assertEq(faint.friendship, 45, "large faint")
Pokemon.FAINT_GAP = 100
faint = mon(50)
Pokemon.adjustFriendshipOnBattleFaint(faint, 10, 40)
assertEq(faint.friendship, 49, "small faint")
Pokemon.FAINT_GAP = 29

local luxury = mon(0, { pokeball = 11 })
Pokemon.adjustFriendship(luxury, 0)
assertEq(luxury.friendship, 6, "luxury ball")
Pokemon.LUXURY_BONUS = 3
luxury = mon(0, { pokeball = 11 })
Pokemon.adjustFriendship(luxury, 0)
assertEq(luxury.friendship, 8, "luxury edited")
Pokemon.LUXURY_BONUS = 1

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = {
    version = version, generation = 3,
    gen3Friendship = { low = 80, e0t1 = 9, faintGap = 10 },
  }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emitFriendship(p, function() return "" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Pokemon.FRIENDSHIP_LOW = 80", 1, true), version)
  assert(chunk:find("Pokemon.FRIENDSHIP_DELTAS[0][1] = 9", 1, true), version)
  assert(chunk:find("Pokemon.FAINT_GAP = 10", 1, true), version)
end

require("Rules")
print("PASS friendship")
