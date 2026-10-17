-- Pokémon Jump scores 10 points for each cleared vine.
-- Two players in sync add 50, three add 100, four add 200, and five add 500.
-- Berries start at 5000 points. A score of 0 on the first tier gives that prize for any game.
-- FireRed, LeafGreen, Ruby, Sapphire, and Emerald share this game.

local M = {}
local ROWS = {
  { "points", "Points per vine", 10, 99990 },
  { "bonus2", "Two in sync", 50, 99990 },
  { "bonus3", "Three in sync", 100, 99990 },
  { "bonus4", "Four in sync", 200, 99990 },
  { "bonus5", "Five in sync", 500, 99990 },
  { "prize1", "1 berry at", 5000, 999990 },
  { "prize2", "2 berries at", 8000, 999990 },
  { "prize3", "3 berries at", 12000, 999990 },
  { "prize4", "4 berries at", 16000, 999990 },
  { "prize5", "5 berries at", 20000, 999990 },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isGen3(S) or not S.project then return y end
  Kit.caption(x, y, "POKÉMON JUMP")
  y = y + 22 * s
  local g = S.project.jumpRules
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(row[4], math.floor(
      require("RegList").num(App, "jump_" .. row[1], x + 220 * s, y, 90 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.jumpRules = S.project.jumpRules or {}
      S.project.jumpRules[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.jumpRules) then S.project.jumpRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.jumpRules
  if type(g) ~= "table" then return end
  local ver = p.version
  local gen3 = p.generation == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  if not gen3 then return end
  local lines = {}
  local points = tonumber(g.points)
  if points ~= nil then
    points = math.max(0, math.min(99990, math.floor(points)))
    lines[#lines + 1] = "    Game.JUMP_POINTS = " .. points
  end
  for n = 2, 5 do
    local v = tonumber(g["bonus" .. n])
    if v ~= nil then
      v = math.max(0, math.min(99990, math.floor(v)))
      lines[#lines + 1] = string.format("    Game.SCORE_BONUS[%d] = %d", n, v)
    end
  end
  for i = 1, 5 do
    local v = tonumber(g["prize" .. i])
    if v ~= nil then
      v = math.max(0, math.min(999990, math.floor(v)))
      lines[#lines + 1] = string.format("    Game.PRIZE_TIERS[%d] = { score = %d }", i, v)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Game = require(\"src.core.game3.minigames.pokemon_jump.game\")"
  out[#out + 1] = "    Game.SCORE_BONUS = Game.SCORE_BONUS or {}"
  out[#out + 1] = "    Game.PRIZE_TIERS = Game.PRIZE_TIERS or {}"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
