-- Wild battles wait out the cart's grace period until that wait is edited.
-- Zero means the next step may roll. The three generations do not share a formula.

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
assertEq(Overworld.wildGrace(), 3, "gen1 cart grace")
Overworld.WILD_GRACE = 0
assertEq(Overworld.wildGrace(), 0, "gen1 zero")
Overworld.WILD_GRACE = 3

local World = require("src.world.gen2.World")
assertEq(World.cooldownCount(), 5, "gen2 cart counter")
World.WILD_COOLDOWN = 2
local step = { wildCooldown = World.cooldownCount() }
assertEq(World.wildCooldownStep(step), true, "gen2 first step waits")
assertEq(World.wildCooldownStep(step), false, "gen2 second step may roll")
World.WILD_COOLDOWN = 0
assertEq(World.cooldownCount(), 0, "gen2 zero")
World.WILD_COOLDOWN = 5

local Frlg = require("src.core.game3.encounter_rules.frlg")
local E = {}
local R = Frlg.bind(E, {})
assertEq(R.mapBaseCooldown("land", 80), 0, "frlg busy routes wait nothing")
assertEq(R.mapBaseCooldown("land", 5), 8, "frlg quiet routes wait 8")
assertEq(R.mapBaseCooldown("land", 20), 6, "frlg 20 is 6")
E.COOLDOWN_MAX = 0
assertEq(R.mapBaseCooldown("land", 5), 0, "frlg longest wait can be zero")
E.COOLDOWN_MAX = 8
E.COOLDOWN_LEAK = 0
local _, leak = R.cooldownMinSteps("land", 20)
assertEq(leak, 0, "frlg leak can be zero")

local Rse = require("src.core.game3.encounter_rules.rse")
local gate = { _immunitySteps = 0, IMMUNITY_STEPS = 0 }
local Rs = Rse.bind(gate, {}, {})
pcall(function() Rs.step("map", "land", {}) end)
assertEq(gate._immunitySteps, 0, "rse zero does not spend a grace step")
gate.IMMUNITY_STEPS = 1
assertEq(Rs.step("map", "land", {}), nil, "rse one step blocks")
assertEq(gate._immunitySteps, 1, "rse counted the step")

local Writer = require("ModWriter")
local Grace = require("EncounterGrace")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, encounterGrace = { steps = 0 } })
  assert(main:find("WILD_GRACE = 0", 1, true), version)
  assert(not main:find("WILD_COOLDOWN", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, encounterGrace = { steps = 0 } })
  assert(main:find("WILD_COOLDOWN = 0", 1, true), version)
  assert(not main:find("WILD_GRACE", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, encounterGrace = { steps = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Grace.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("IMMUNITY_STEPS = 0", 1, true), version)
  assert(not chunk:find("COOLDOWN_MAX", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, encounterGrace = { maxWait = 0, leak = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Grace.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("COOLDOWN_MAX = 0", 1, true), version)
  assert(chunk:find("COOLDOWN_LEAK = 0", 1, true), version)
  assert(not chunk:find("IMMUNITY_STEPS", 1, true), version)
end

print("PASS encounter grace")
