-- Card Flip costs 3 coins a hand. A matching square pays 6, 9, 12, 18, or 72.
-- 0 is a free hand, or a square that pays nothing.
-- Gold, Silver, and Crystal share this game. The others do not have it.

local M = {}
local ROWS = {
  { "bet", "Coins per hand", 3, "BET" },
  { "monPair", "Pokémon pair", 6, "PAYOUT_MON_PAIR" },
  { "levelPair", "Level pair", 9, "PAYOUT_LEVEL_PAIR" },
  { "mon", "One Pokémon", 12, "PAYOUT_MON" },
  { "level", "One level", 18, "PAYOUT_LEVEL" },
  { "card", "Exact card", 72, "PAYOUT_CARD" },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  local Generation = require("Generation")
  if not Generation.isGen2(S) or not S.project then return y end
  Kit.caption(x, y, "CARD FLIP COINS")
  y = y + 22 * s
  local g = S.project.cardFlipRules
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(9999, math.floor(
      require("RegList").num(App, "card_flip_" .. row[1], x + 220 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.cardFlipRules = S.project.cardFlipRules or {}
      S.project.cardFlipRules[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.cardFlipRules) then S.project.cardFlipRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.cardFlipRules
  if type(g) ~= "table" then return end
  local ver = p.version
  local gen = p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  if not gen2 then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(0, math.min(9999, math.floor(n)))
      lines[#lines + 1] = string.format("    CardFlip.%s = %d", row[4], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local CardFlip = require(\"src.ui.gen2.CardFlip\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
