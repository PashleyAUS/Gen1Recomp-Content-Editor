-- Trainer 99 has 3 IVs. Trainer 100 has 6. Trainer 220 has 31.
-- A first cutoff of 0 gives trainer 1 the next step. A first IV of 0
-- gives trainer 99 nothing. A past-the-ladder IV of 0 gives trainer
-- 220 nothing. Two effort stats split 510 into 255. A pool of 0 gives
-- nothing. Ruby, Sapphire, and Emerald share this. FireRed does not.

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
assertEq(D.fixedIvs(99), 3, "trainer 99 has 3 IVs")
assertEq(D.fixedIvs(100), 6, "trainer 100 has 6 IVs")
assertEq(D.fixedIvs(220), 31, "trainer 220 has 31 IVs")
D.IV_STEPS[1][1] = 0
assertEq(D.fixedIvs(0), 3, "trainer 0 still uses the first step")
assertEq(D.fixedIvs(1), 6, "trainer 1 uses the next step")
D.IV_STEPS[1][1] = 99
D.IV_STEPS[1][2] = 0
assertEq(D.fixedIvs(99), 0, "a first IV of 0 is 0")
D.IV_STEPS[1][2] = 3
D.MAX_PER_STAT_IVS = 0
assertEq(D.fixedIvs(220), 0, "a past-the-ladder IV of 0 is 0")
D.MAX_PER_STAT_IVS = 31
assertEq(D.evShare(3), 255, "two stats split 510 into 255")
assertEq(D.evShare(0), 0, "no stats get no effort")
D.MAX_TOTAL_EVS = 0
assertEq(D.evShare(3), 0, "a pool of 0 gives nothing")
D.MAX_TOTAL_EVS = 510

local Iv = require("FrontierIv")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Iv.emit({ version = version, frontierIv = { ivs = { [1] = 0 }, evs = 0 } }, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("IV_STEPS[1][2] = 0", 1, true), version)
  assert(main:find("MAX_TOTAL_EVS = 0", 1, true), version)
end
local out = {}
Iv.emit({ version = "firered", frontierIv = { evs = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_TOTAL_EVS", 1, true), "firered")

print("PASS frontier ivs")
