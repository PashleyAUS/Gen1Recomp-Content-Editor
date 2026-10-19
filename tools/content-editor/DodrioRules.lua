-- A Dodrio berry is worth 10, 30, or 50 points. A miss takes 50 away.
-- The prize is given at 3000 points. 0 points is no score, or a prize for any game.
-- FireRed, LeafGreen, Ruby, Sapphire, and Emerald share this game.

local M = {}
local ROWS = {
  { "blue", "Blue berry", 10 },
  { "green", "Green berry", 30 },
  { "gold", "Gold berry", 50 },
  { "missed", "Miss takes", 50 },
  { "prize", "Prize at", 3000 },
}
local INDEX = { blue = 0, green = 1, gold = 2, missed = 3 }

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isGen3(S) or not S.project then return y end
  Kit.caption(x, y, "DODRIO BERRIES")
  y = y + 22 * s
  local g = S.project.dodrioRules
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    local maxV = row[1] == "prize" and 999990 or 9999
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(maxV, math.floor(
      require("RegList").num(App, "dodrio_" .. row[1], x + 220 * s, y, 90 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.dodrioRules = S.project.dodrioRules or {}
      S.project.dodrioRules[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.dodrioRules) then S.project.dodrioRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.dodrioRules
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen3 = p.generation == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  if not gen3 then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    if row[1] ~= "prize" then
      local n = tonumber(g[row[1]])
      if n ~= nil then
        n = math.max(0, math.min(9999, math.floor(n)))
        lines[#lines + 1] = string.format("    Rules.SCORE_MULT[%d] = %d", INDEX[row[1]], n)
      end
    end
  end
  local prize = tonumber(g.prize)
  if prize ~= nil then
    prize = math.max(0, math.min(999990, math.floor(prize)))
    lines[#lines + 1] = "    Rules.PRIZE_SCORE = " .. prize
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Rules = require(\"src.core.game3.minigames.dodrio_berry_picking.rules\")"
  out[#out + 1] = "    Rules.SCORE_MULT = Rules.SCORE_MULT or {}"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
