-- A slow third player scores a perfect hit on a roll above 66, and a
-- good hit otherwise. Raising that line to 100 makes the same roll good.
-- A slow line of 0 is never slow. Ruby, Sapphire, and Emerald share it.

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

local Blender = require("src.core.game3.rse.berry_blender")
local function seat(speed, pct)
  return {
    speed = speed,
    perfectOpponents = false,
    rand = function() return pct * 655 end,
    recv = { [2] = {}, [3] = {} },
    playerIdToArrowId = { [2] = 0, [3] = 0 },
    arrowPos = 0,
    T = { arrowHitRangeStart = { [1] = 0 } },
  }
end

local slow = seat(100, 67)
Blender.opponent2(slow, nil, { [0] = 0 })
assertEq(slow.recv[2][2], Blender.CMD.BEST, "67 is a perfect hit")
Blender.OPP2_SLOW_BEST = 100
local raised = seat(100, 67)
Blender.opponent2(raised, nil, { [0] = 0 })
assertEq(raised.recv[2][2], Blender.CMD.GOOD, "100 makes 67 a good hit")
Blender.OPP2_SLOW_BEST = 66
Blender.OPP_SLOW = 0
local fast = seat(100, 30)
Blender.opponent2(fast, nil, { [0] = 0 })
assertEq(fast.recv[2][2], nil, "a slow line of 0 is not the slow table")
Blender.OPP_SLOW = 500

local Opponents = require("BlenderOpponents")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Opponents.emit({ version = version, gen3Blender = { opp2SlowBest = 100, oppSlow = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("OPP2_SLOW_BEST = 100", 1, true), version)
  assert(main:find("OPP_SLOW = 0", 1, true), version)
  assert(main:find("src.core.game3.rse.berry_blender", 1, true), version)
end
local out = {}
Opponents.emit({ version = "firered", gen3Blender = { oppSlow = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("OPP_SLOW", 1, true), "firered")

print("PASS blender opponents")
