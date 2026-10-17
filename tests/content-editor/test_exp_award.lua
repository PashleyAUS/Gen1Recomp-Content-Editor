-- A defeated Pokémon's experience uses the battle-rules divisor and percents.

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

local Experience = require("src.core.game3.battle.experience")
Experience.expYield = function() return 70 end
local Pokemon = require("src.core.game3.pokemon")
Pokemon.gainEVs = function() end
Experience.apply = function(_, amount) return { gained = amount, levels = {} } end

local function award(extra, opts)
  local mon = { species = 1, hp = 20, level = 5, maxHp = 20 }
  if extra then
    for k, v in pairs(extra) do mon[k] = v end
  end
  local bench = { species = 1, hp = 20, level = 5, maxHp = 20, item = opts and opts.share and 182 or nil }
  local st = {
    wild = opts and opts.trainer ~= true,
    player = { mon = mon, partyIndex = 1 },
    playerParty = { mon, bench },
  }
  local awards = Experience.awardFoe(st, { species = 16, level = 10, mon = { level = 10 } }, opts)
  return awards[1] and awards[1].amount
end

Experience.DIVISOR = 10
Experience.TRAINER_NUM = 200
assertEq(award(nil, { trainer = true }), 140, "trainer experience")
Experience.SHARE_DIV = 5
assertEq(award(nil, { share = true }), 14, "exp share split")
Experience.DIVISOR = 7
Experience.TRAINER_NUM = 150
Experience.SHARE_DIV = 2

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { expShareDiv = 5 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ expShareDiv = 5 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Experience.SHARE_DIV = battleRules.expShareDiv", 1, true), version)
end

print("PASS exp award")
