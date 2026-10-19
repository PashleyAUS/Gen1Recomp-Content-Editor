-- Berry Crush silk starts at 50. Powder keeps that score out of 100.
-- The crusher's goal depth is the berries' difficulty divided by 32.
-- A divisor of 0 yields no powder or no depth.
-- FireRed, LeafGreen, Ruby, Sapphire, and Emerald share this game.

local M = {}
local ROWS = {
  { "silkBase", "Silk base", 50, 0, 255, "SILK_BASE" },
  { "powderDen", "Powder out of", 100, 0, 1000, "POWDER_DEN" },
  { "depthDiv", "Depth divisor", 32, 0, 256, "DEPTH_DIV" },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isGen3(S) or not S.project then return y end
  Kit.caption(x, y, "BERRY CRUSH")
  y = y + 22 * s
  local g = S.project.berryCrush
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(row[4], math.min(row[5], math.floor(
      require("RegList").num(App, "crush_" .. row[1], x + 220 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.berryCrush = S.project.berryCrush or {}
      S.project.berryCrush[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.berryCrush) then S.project.berryCrush = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.berryCrush
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen3 = p.generation == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  if not gen3 then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(row[4], math.min(row[5], math.floor(n)))
      lines[#lines + 1] = string.format("    Rules.%s = %d", row[6], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Rules = require(\"src.core.game3.minigames.berry_crush.rules\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
