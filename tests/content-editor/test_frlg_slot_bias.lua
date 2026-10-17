-- FireRed and LeafGreen read the aim table on each spin. Replacing the
-- table still changes the result. A cutoff of 0 never catches that prize.
-- A seven wait of 0 stores nothing. The peek icons follow the last group.

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

local Slot = require("src.core.game3.slot_machine")
local Rng = require("src.core.game3.rng")
local savedRandom = Rng.Random
local saved = Slot.BIAS_CHANCES
local function use(values)
  local n = 0
  Rng.Random = function()
    n = n + 1
    return values[n] or 0
  end
end

local function spin(cooldown, rolls)
  use(rolls)
  local st = { machineIdx = 0, machineBias = 0, biasCooldown = cooldown }
  Slot.calcBias(st)
  return st
end
-- 11468 is floor(0.7 * 16383). Just under it refreshes the wait.
local kept = spin(1, { 0, 11467, 1 })
assertEq(kept.biasCooldown, 4, "just under the cart line refreshes the wait")
local dropped = spin(1, { 0, 11468 })
assertEq(dropped.biasCooldown, 0, "the cart line itself counts down")

local aimed = { machineIdx = 0, machineBias = 0, biasCooldown = 0 }
-- rval 0 is under the first cutoff, so the spin aims at nothing.
-- The follow-up roll is 0, which is under the seven-hold cutoff.
use({ 0, 0, 1 })
Slot.BIAS_COOLDOWN_SHORT = 0
assertEq(Slot.calcBias(aimed), 0, "a low roll aims at nothing")
assertEq(aimed.biasCooldown, 0, "a short wait of 0 stores nothing")
Slot.BIAS_COOLDOWN_SHORT = 5

Slot.BIAS_CHANCES = {
  [0] = { [0] = 0, [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0 },
}
use({ 100 })
local seven = { machineIdx = 0, machineBias = 0, biasCooldown = 0 }
assertEq(Slot.calcBias(seven), 6, "every cutoff at 0 aims at a seven")
Slot.BIAS_CHANCES = saved

local before = Slot.iconAt(0, -1)
Slot.BIAS_CHANCES[5][6] = 0x0100
assertEq(Slot.iconAt(0, -1), 1, "the peek icon follows the seven-hold byte")
Slot.BIAS_CHANCES[5][6] = 0x0073
assertEq(Slot.iconAt(0, -1), before, "the cart peek icon returns")

Rng.Random = savedRandom

local Bias = require("FrlgSlotBias")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local out = {}
  local project = { version = version, generation = 3, frlgSlotBias = { g0c0 = 0, short = 0 } }
  assert(Native.used(project), version .. " counts")
  Bias.emit(project, function() return "{}" end, out)
  local main = table.concat(out, "\n")
  assert(main:find("BIAS_CHANCES[0][0] = 0", 1, true), version)
  assert(main:find("BIAS_COOLDOWN_SHORT = 0", 1, true), version)
  assert(main:find("src.core.game3.slot_machine", 1, true), version)
end
local out = {}
Bias.emit({ version = "emerald", generation = 3, frlgSlotBias = { g0c0 = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("BIAS_CHANCES", 1, true), "emerald")
out = {}
Bias.emit({ version = "gold", generation = 2, frlgSlotBias = { g0c0 = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("BIAS_CHANCES", 1, true), "gold")

print("PASS frlg slot bias")
