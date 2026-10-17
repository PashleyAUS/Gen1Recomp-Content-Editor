-- Badge boosts and infatuation keep the cart until they are edited.

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

local Gen1 = require("src.battle.Damage")
local boulder = {
  badges = { BOULDERBADGE = true },
  badgeBoosts = { { badge = "BOULDERBADGE", stat = "attack", num = 9, den = 8 } },
}
assertEq(Gen1.applyBadgeBoost(boulder, "attack", 80), 90, "gen1 cart eighth")
boulder.badgeBoosts[1].num = 2
boulder.badgeBoosts[1].den = 1
assertEq(Gen1.applyBadgeBoost(boulder, "attack", 100), 200, "gen1 doubled")

local Battle = require("src.battle.gen2.Battle")
local Damage = require("src.battle.gen2.Damage")
assertEq(Battle.boostStat(80), 90, "gen2 stat eighth")
assertEq(Damage.badgeTypeExtra(80), 10, "gen2 type eighth")
Battle.BADGE_BOOST_DIVISOR = 2
Damage.BADGE_TYPE_DIVISOR = 2
assertEq(Battle.boostStat(80), 120, "gen2 stat half")
assertEq(Damage.badgeTypeExtra(80), 40, "gen2 type half")
Battle.BADGE_BOOST_DIVISOR = 0
Damage.BADGE_TYPE_DIVISOR = 0
assertEq(Battle.boostStat(80), 80, "gen2 stat off")
assertEq(Damage.badgeTypeExtra(80), 0, "gen2 type off")
Battle.BADGE_BOOST_DIVISOR = 8
Damage.BADGE_TYPE_DIVISOR = 8

assertEq(Battle.attractFails(function() return 0 end), false, "gen2 low roll attacks")
assertEq(Battle.attractFails(function() return 128 end), true, "gen2 high roll fails")
Battle.ATTRACT_FAIL = 0
assertEq(Battle.attractFails(function() return 0 end), true, "gen2 always fails")
Battle.ATTRACT_FAIL = 256
assertEq(Battle.attractFails(function() return 255 end), false, "gen2 always attacks")
Battle.ATTRACT_FAIL = 128

local Rules = require("src.core.game3.battle.rules")
assertEq(Rules.attract.fails(function() return 0 end), false, "gen3 low roll attacks")
assertEq(Rules.attract.fails(function() return 128 end), true, "gen3 high roll fails")
Rules.attract.FAIL = 0
assertEq(Rules.attract.fails(function() return 0 end), true, "gen3 always fails")
Rules.attract.FAIL = 128

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1,
    badgeBoosts = { { badge = "BOULDERBADGE", stat = "attack", num = 2, den = 1 } } })
  assert(main:find("constants:override(\"badgeBoosts\"", 1, true), version)
  assert(not main:find("BADGE_BOOST_DIVISOR", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2,
    badgeBoost = { divisor = 2 },
    ailments = { attractFail = 0 } })
  assert(main:find("BADGE_BOOST_DIVISOR = divisor", 1, true), version)
  assert(main:find("BADGE_TYPE_DIVISOR = divisor", 1, true), version)
  assert(main:find("Battle.ATTRACT_FAIL = ailments.attractFail", 1, true), version)
  assert(not main:find("badgeBoosts", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { attractFail = 0 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ attractFail = 0 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Rules.attract.FAIL = battleRules.attractFail", 1, true), version)
end

require("Rules")
print("PASS badge attract")
