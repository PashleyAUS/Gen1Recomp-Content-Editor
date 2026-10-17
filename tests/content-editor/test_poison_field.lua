-- Overworld poison ticks every 4 steps for 1 HP until those two numbers are edited.
-- 0 steps never ticks. 0 damage ticks without taking HP.

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

local Overworld = require("src.world.OverworldController")
assertEq(Overworld.poisonInterval(nil), 4, "gen1 interval")
assertEq(Overworld.poisonDamage(nil), 1, "gen1 damage")
Overworld.POISON_INTERVAL = 0
assertEq(Overworld.poisonInterval(nil), 0, "gen1 interval zero")
Overworld.POISON_DAMAGE = 0
assertEq(Overworld.poisonDamage(nil), 0, "gen1 damage zero")
Overworld.POISON_INTERVAL = nil
Overworld.POISON_DAMAGE = nil
assertEq(Overworld.poisonFlashFrames(), 4, "gen1 flash")
Overworld.POISON_FLASH = 0
assertEq(Overworld.poisonFlashFrames(), 0, "gen1 flash zero")
Overworld.POISON_FLASH = 4

local Steps = require("src.world.gen2.StepEvents")
assertEq(Steps.poisonPeriod(), 4, "gen2 period")
local mon = { status = "psn", hp = 10 }
Steps.POISON_DAMAGE = 3
local event = Steps.poisonStep({ mon })
assertEq(mon.hp, 7, "gen2 damage")
assertEq(event.kind, "poisonHurt", "gen2 hurt")
Steps.POISON_DAMAGE = 0
mon.hp = 10
Steps.poisonStep({ mon })
assertEq(mon.hp, 10, "gen2 damage zero")
Steps.POISON_PERIOD = 0
assertEq(Steps.poisonPeriod(), 0, "gen2 period zero")
Steps.POISON_DAMAGE = 1
Steps.POISON_PERIOD = 4
local World = require("src.world.gen2.World")
local flashed = setmetatable({}, { __index = World })
World.poisonBGFlash(flashed)
assertEq(flashed.poisonFlash, 4, "gen2 flash")
World.POISON_FLASH = 0
World.poisonBGFlash(flashed)
assertEq(flashed.poisonFlash, 0, "gen2 flash zero")
World.POISON_FLASH = 4

local G3 = require("src.core.game3.step_events")
assertEq(G3.poisonPeriod(), 4, "gen3 period")
assertEq(G3.poisonDamageAmount(), 1, "gen3 damage")
G3.POISON_PERIOD = 1
G3.POISON_DAMAGE = 4
local session = {
  version = "firered",
  party = { { status = "PSN", hp = 10, level = 5 } },
  vars = {},
}
local ok, err = pcall(G3.onStepTaken, session, {})
if not ok then error("gen3 step: " .. tostring(err)) end
assertEq(session.party[1].hp, 6, "gen3 tick")
G3.POISON_DAMAGE = 0
session.party[1].hp = 10
session.poisonSteps = 0
session.vars = {}
G3.onStepTaken(session, {})
assertEq(session.party[1].hp, 10, "gen3 damage zero")
G3.POISON_PERIOD = 0
session.poisonSteps = 0
session.vars = {}
session.party[1].hp = 10
G3.POISON_DAMAGE = 5
G3.onStepTaken(session, {})
assertEq(session.party[1].hp, 10, "gen3 period zero")
G3.POISON_PERIOD = 1
session.poisonSteps = 0
session.party[1].hp = 10
session.party[1].status = "PSN"
G3.onStepTaken(session, {})
assertEq(G3._poisonFlashTimer, 4 / 60, "gen3 flash")
G3.POISON_FLASH = 0
session.poisonSteps = 0
session.party[1].hp = 10
session.party[1].status = "PSN"
G3.onStepTaken(session, {})
assertEq(G3._poisonFlashTimer, 0, "gen3 flash zero")
G3.POISON_FLASH = 4
G3.POISON_PERIOD = 4
G3.POISON_DAMAGE = 1

local Writer = require("ModWriter")
local Poison = require("PoisonField")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, poisonField = { interval = 0, damage = 0, flash = 0 } })
  assert(main:find("POISON_INTERVAL = 0", 1, true), version)
  assert(main:find("POISON_DAMAGE = 0", 1, true), version)
  assert(main:find("POISON_FLASH = 0", 1, true), version)
  assert(main:find("src.world.OverworldController", 1, true), version)
  assert(not main:find("src.world.gen2.StepEvents", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, poisonField = { interval = 1, flash = 0 } })
  assert(main:find("POISON_PERIOD = 1", 1, true), version)
  assert(main:find("src.world.gen2.StepEvents", 1, true), version)
  assert(main:find("src.world.gen2.World\").POISON_FLASH = 0", 1, true), version)
  assert(not main:find("POISON_INTERVAL", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald", "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, poisonField = { damage = 0, flash = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Poison.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("POISON_DAMAGE = 0", 1, true), version)
  assert(chunk:find("POISON_FLASH = 0", 1, true), version)
  assert(chunk:find("src.core.game3.step_events", 1, true), version)
  assert(not chunk:find("POISON_INTERVAL", 1, true), version)
end

print("PASS poison field")
