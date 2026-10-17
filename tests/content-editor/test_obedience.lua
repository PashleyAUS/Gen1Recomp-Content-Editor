-- A traded Pokémon obeys up to the badge level. The cart uses 10, 30, 50, and 70.

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
local function gen2(owned)
  return Battle.obedienceLevel({
    hasBadge = function(_, _, name) return owned[name] == true end,
  })
end
assertEq(gen2({}), 10, "gen2 none")
assertEq(gen2({ HIVE = true }), 30, "gen2 hive")
assertEq(gen2({ HIVE = true, FOG = true, STORM = true }), 70, "gen2 storm")
Battle.OBEDIENCE_LEVELS.hive = 40
assertEq(gen2({ HIVE = true }), 40, "gen2 edited")
Battle.OBEDIENCE_LEVELS.hive = 30

local Engine = require("src.core.game3.battle.engine")
local function gen3(badges)
  local old = Engine.hasBadge
  Engine.hasBadge = function(_, n) return badges[n] == true end
  local cap = Engine.obedienceCap({})
  Engine.hasBadge = old
  return cap
end
assertEq(gen3({}), 10, "gen3 none")
assertEq(gen3({ [2] = true }), 30, "gen3 second")
assertEq(gen3({ [2] = true, [4] = true, [6] = true }), 70, "gen3 sixth")
Engine.OBEDIENCE_LEVELS.second = 35
assertEq(gen3({ [2] = true }), 35, "gen3 edited")
Engine.OBEDIENCE_LEVELS.second = 30

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, obedience = { hive = 40 } })
assert(not red:find("OBEDIENCE_LEVELS", 1, true), "red skips obedience")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, obedience = { hive = 40, storm = 80 },
  })
  assert(main:find("Battle.OBEDIENCE_LEVELS.hive = 40", 1, true), version)
  assert(main:find("Battle.OBEDIENCE_LEVELS.storm = 80", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = {
    version = version, generation = 3,
    gen3BattleRules = { obedienceNone = 12, obedienceSixth = 80 },
  }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function(t)
    return "{ obedienceNone = " .. t.obedienceNone .. ", obedienceSixth = " .. t.obedienceSixth .. " }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Engine.OBEDIENCE_LEVELS.none = battleRules.obedienceNone", 1, true), version)
  assert(chunk:find("Engine.OBEDIENCE_LEVELS.sixth = battleRules.obedienceSixth", 1, true), version)
end

print("PASS obedience")
