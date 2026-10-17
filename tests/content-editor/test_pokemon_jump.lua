-- A cleared vine is worth 10 points. Two players in sync add 50.
-- The first berry prize starts at 5000. 0 points per vine adds nothing.
-- A first prize line of 0 gives that prize for a score of 0.
-- The earlier games do not have Pokémon Jump.

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

local Game = require("src.core.game3.minigames.pokemon_jump.game")
assertEq(Game.jumpPoints(), 10, "vine")
Game.JUMP_POINTS = 0
assertEq(Game.jumpPoints(), 0, "vine zero")
Game.JUMP_POINTS = nil

local g = {
  tables = {
    score_bonuses = { 0, 0, 50, 100, 200, 500 },
    prize_quantity = {
      { score = 5000, quantity = 1 },
      { score = 8000, quantity = 2 },
      { score = 12000, quantity = 3 },
      { score = 16000, quantity = 4 },
      { score = 20000, quantity = 5 },
    },
  },
  comm = { jumpScore = 5000 },
}
setmetatable(g, Game)
assertEq(Game.getScoreBonus(g, 2), 50, "two players")
assertEq(Game.getPrizeQuantity(g), 1, "one berry")
Game.SCORE_BONUS = { [2] = 0 }
assertEq(Game.getScoreBonus(g, 2), 0, "sync zero")
Game.SCORE_BONUS = nil
Game.PRIZE_TIERS = { [1] = { score = 0 } }
g.comm.jumpScore = 0
assertEq(Game.hasEnoughScoreForPrize(g), true, "prize at zero")
assertEq(Game.getPrizeQuantity(g), 1, "still one berry")
Game.PRIZE_TIERS = nil

local Rules = require("JumpRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, jumpRules = { points = 0, prize1 = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rules.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("JUMP_POINTS = 0", 1, true), version)
  assert(chunk:find("PRIZE_TIERS[1] = { score = 0 }", 1, true), version)
end
local Writer = require("ModWriter")
local main = Writer.emitMain({ version = "crystal", generation = 2, jumpRules = { points = 0 } })
assert(not main:find("JUMP_POINTS", 1, true), "crystal")

print("PASS pokemon jump")
