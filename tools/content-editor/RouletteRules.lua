-- Hoenn roulette multiplies the bet by 3, then 4, then 6, then 12.
-- The last step is also what one number pays. 0 pays nothing for that step.
-- Ruby, Sapphire, and Emerald share this wheel. The other games do not have it.

local M = {}
local HOURS = {
  { "luckyAfter", "Lucky after hour", "LUCKY_AFTER", 3 },
  { "luckyBefore", "Lucky before hour", "LUCKY_BEFORE", 10 },
  { "bothBefore", "Both Pokémon before hour", "BOTH_BEFORE", 11 },
  { "angleBefore", "First angle before hour", "ANGLE_BEFORE", 13 },
}

local ROWS = {
  { "step1", "First color", 3 },
  { "step2", "Second color, or first Pokémon", 4 },
  { "step3", "Third color, or second Pokémon", 6 },
  { "step4", "Last hit, or one number", 12 },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isRse(S) or not S.project then return y end
  Kit.caption(x, y, "ROULETTE")
  y = y + 22 * s
  local g = S.project.rouletteRules
  local balls = g and g.balls
  if balls == nil then balls = 6 end
  Kit.text("small", "Balls in a round", x, y + 4 * s, require("Theme").PAL.caption)
  local count = math.max(0, math.min(12, math.floor(
    require("RegList").num(App, "roulette_balls", x + 280 * s, y, 80 * s, 28 * s, balls))))
  if count ~= balls then
    require("State").ensureProjectFields(S.project)
    S.project.rouletteRules = S.project.rouletteRules or {}
    S.project.rouletteRules.balls = (count == 6) and nil or count
    if not next(S.project.rouletteRules) then S.project.rouletteRules = nil end
    App.markDirty()
  end
  y = y + 34 * s
  for _, row in ipairs(HOURS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[4] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(24, math.floor(
      require("RegList").num(App, "roulette_" .. row[1], x + 280 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.rouletteRules = S.project.rouletteRules or {}
      S.project.rouletteRules[row[1]] = (v == row[4]) and nil or v
      if not next(S.project.rouletteRules) then S.project.rouletteRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  Kit.caption(x, y, "MULTIPLIERS")
  y = y + 22 * s
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(9999, math.floor(
      require("RegList").num(App, "roulette_" .. row[1], x + 280 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.rouletteRules = S.project.rouletteRules or {}
      S.project.rouletteRules[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.rouletteRules) then S.project.rouletteRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.rouletteRules
  if type(g) ~= "table" then return end
  local ver = p.version
  if ver ~= "ruby" and ver ~= "sapphire" and ver ~= "emerald" then return end
  local lines = {}
  local balls = tonumber(g.balls)
  if balls ~= nil then
    balls = math.max(0, math.min(12, math.floor(balls)))
    lines[#lines + 1] = "    Roulette.BALLS_PER_ROUND = " .. balls
  end
  for _, row in ipairs(HOURS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(0, math.min(24, math.floor(n)))
      lines[#lines + 1] = "    Roulette." .. row[3] .. " = " .. n
    end
  end
  for i, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(0, math.min(9999, math.floor(n)))
      lines[#lines + 1] = string.format("    Roulette.MULTIPLIERS[%d] = %d", i, n)
    end
  end
  if #lines == 0 then return end
  if g.step4 ~= nil then
    local top = math.max(0, math.min(9999, math.floor(tonumber(g.step4) or 12)))
    lines[#lines + 1] = "    Roulette.MAX_MULTIPLIER = " .. top
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Roulette = require(\"src.core.game3.rse.roulette\")"
  out[#out + 1] = "    Roulette.MULTIPLIERS = Roulette.MULTIPLIERS or {}"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
