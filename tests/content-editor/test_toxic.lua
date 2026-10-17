-- Toxic damage keeps each generation's step until the fraction or cap is edited.

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

local Battle = require("src.battle.gen2.Battle")
local function toxic(maxHp, counter)
  local mon = { toxicCounter = counter }
  local dmg = Battle.STATUSES.toxic.residual(nil, mon, maxHp)
  return dmg, mon.toxicCounter
end

local dmg, nextCounter = toxic(80, 1)
assertEq(dmg, 5, "gen2 first step")
assertEq(nextCounter, 2, "gen2 counter")
dmg = toxic(80, 2)
assertEq(dmg, 10, "gen2 second step")
Battle.TOXIC_FRACTION = 8
dmg = toxic(80, 1)
assertEq(dmg, 10, "gen2 edited fraction")
Battle.TOXIC_FRACTION = 16

local Status = require("src.core.game3.battle.status")
local function ticks()
  local lost
  local battler = { status = "TOX", toxicCounter = 0 }
  local ad = {
    isFainted = function() return false end,
    maxHp = function() return 80 end,
    sayText = function() return "hurt" end,
    applyHpLoss = function(_, _, n) lost = n end,
  }
  Status.tickChip(battler, ad)
  local first = lost
  Status.tickChip(battler, ad)
  return first, lost, battler.toxicCounter
end

local first, second, counter = ticks()
assertEq(first, 5, "gen3 first")
assertEq(second, 10, "gen3 second")
assertEq(counter, 2, "gen3 counter")
Status.TOXIC_CAP = 1
first, second, counter = ticks()
assertEq(first, 5, "gen3 capped first")
assertEq(second, 5, "gen3 capped second")
assertEq(counter, 1, "gen3 capped counter")
Status.TOXIC_CAP = 15
Status.TOXIC_FRACTION = 8
first = ticks()
assertEq(first, 10, "gen3 edited fraction")
Status.TOXIC_FRACTION = 16

local Writer = require("ModWriter")
local red = Writer.emitMain({
  version = "red", generation = 1, ailments = { toxicFraction = 8 },
})
assert(not red:find("TOXIC_FRACTION", 1, true), "red skips toxic")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, ailments = { toxicFraction = 8 },
  })
  assert(main:find("toxicFraction = 8", 1, true), version .. " value")
  assert(main:find("Battle.TOXIC_FRACTION = ailments.toxicFraction", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { toxicCap = 4 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function(v) return "{ toxicCap = 4 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Status.TOXIC_CAP = battleRules.toxicCap", 1, true), version)
end

require("Rules")
print("PASS toxic")
