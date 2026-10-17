-- Reflect and Light Screen double defense until the multiplier is edited.

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
assertEq(Gen1.applyScreen(50), 100, "gen1 cart")
Gen1.SCREEN_MULT = 3
assertEq(Gen1.applyScreen(50), 150, "gen1 triple")
Gen1.SCREEN_MULT = 2

local Gen2 = require("src.battle.gen2.Damage")
assertEq(Gen2.applyScreen(40), 80, "gen2 cart")
Gen2.SCREEN_MULT = 1
assertEq(Gen2.applyScreen(40), 40, "gen2 off")
Gen2.SCREEN_MULT = 2

local Gen3 = require("src.core.game3.battle.damage")
assertEq(Gen3.screenDamage(8, false), 4, "gen3 half")
assertEq(Gen3.screenDamage(8, true), 4, "gen3 double battle")
Gen3.SCREEN_DIV = 1
assertEq(Gen3.screenDamage(8, false), 8, "gen3 screen off")
Gen3.SCREEN_DIV = 2
Gen3.DOUBLE_SCREEN_NUM = 1
Gen3.DOUBLE_SCREEN_DEN = 1
assertEq(Gen3.screenDamage(8, true), 8, "gen3 double off")
Gen3.DOUBLE_SCREEN_NUM = 2
Gen3.DOUBLE_SCREEN_DEN = 3

local Writer = require("ModWriter")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, screenRules = { mult = 3 } })
  assert(main:find("require(\"src.battle.Damage\").SCREEN_MULT = mult", 1, true), version)
  assert(not main:find("gen2.Damage", 1, true), version)
end
local Battle = require("src.battle.gen2.Battle")
local side = {}
Battle.MOVE_EFFECTS.EFFECT_REFLECT({
  screens = { player = side },
  sideOf = function() return "player" end,
  emit = function() end,
  monName = function() return "A" end,
}, {})
assertEq(side.reflect, 5, "gen2 screen turns")
Battle.SCREEN_TURNS = 2
side = {}
Battle.MOVE_EFFECTS.EFFECT_SAFEGUARD({
  screens = { player = side },
  sideOf = function() return "player" end,
  emit = function() end,
  monName = function() return "A" end,
}, {})
assertEq(side.safeguard, 2, "gen2 screen turns edited")
Battle.SCREEN_TURNS = 5

for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, screenRules = { mult = 3, turns = 8 } })
  assert(main:find("require(\"src.battle.gen2.Damage\").SCREEN_MULT = mult", 1, true), version)
  assert(main:find("require(\"src.battle.gen2.Battle\").SCREEN_TURNS = turns", 1, true), version)
end
local redTurns = Writer.emitMain({ version = "red", generation = 1, screenRules = { turns = 8 } })
assert(not redTurns:find("SCREEN_TURNS", 1, true), "red has no screen timer")

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3,
    gen3BattleRules = { screenDiv = 1, doubleScreenNum = 1, doubleScreenDen = 1 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function()
    return "{ screenDiv = 1, doubleScreenNum = 1, doubleScreenDen = 1 }"
  end, out)
  local chunk = table.concat(out, "\n")
  assert(loadstring(chunk), version .. " compiles")
  assert(chunk:find("Damage.SCREEN_DIV = battleRules.screenDiv", 1, true), version)
  assert(chunk:find("Damage.DOUBLE_SCREEN_NUM = battleRules.doubleScreenNum", 1, true), version)
  assert(chunk:find("Damage.DOUBLE_SCREEN_DEN = battleRules.doubleScreenDen", 1, true), version)
  local timed = {}
  Gen3BattleRules.emit({ version = version, generation = 3, gen3BattleRules = {
    screenTurns = 8, mistTurns = 2,
  } }, function() return "{ screenTurns = 8, mistTurns = 2 }" end, timed)
  local duration = table.concat(timed, "\n")
  assert(loadstring(duration), version .. " duration compiles")
  assert(duration:find("Capabilities.screenDefaultTurns = battleRules.screenTurns", 1, true), version)
  assert(duration:find("Capabilities.mistDefaultTurns = battleRules.mistTurns", 1, true), version)
end

require("Rules")
print("PASS screens")
