-- Gen 2's lucky number pays first prize at 5 matching digits, second at 3, third at 2.
-- Hoenn's lottery pays once 2 digits match. 0 means that line is won by any ID.
-- Gold, Silver, and Crystal share the radio show. Ruby, Sapphire, and Emerald share the corner.

local M = {}

local function gen2(p)
  local ver = p.version
  return p.generation == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
end

local function rse(p)
  local ver = p.version
  return ver == "ruby" or ver == "sapphire" or ver == "emerald"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  local Generation = require("Generation")
  if not S.project then return y end
  local rows
  if Generation.isGen2(S) then
    rows = {
      { "first", "First prize digits", 5 },
      { "second", "Second prize digits", 3 },
      { "third", "Third prize digits", 2 },
    }
  elseif Generation.isRse(S) then
    rows = { { "minDigits", "Digits to win", 2 } }
  else
    return y
  end
  Kit.caption(x, y, "LOTTERY")
  y = y + 22 * s
  local g = S.project.lotteryOdds
  for _, row in ipairs(rows) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(5, math.floor(
      require("RegList").num(App, "lotto_" .. row[1], x + 220 * s, y, 70 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.lotteryOdds = S.project.lotteryOdds or {}
      S.project.lotteryOdds[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.lotteryOdds) then S.project.lotteryOdds = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.lotteryOdds
  if type(g) ~= "table" then return end
  local lines = {}
  if gen2(p) then
    local map = { first = "LUCKY_FIRST", second = "LUCKY_SECOND", third = "LUCKY_THIRD" }
    for key, field in pairs(map) do
      local n = tonumber(g[key])
      if n ~= nil then
        n = math.max(0, math.min(5, math.floor(n)))
        lines[#lines + 1] = string.format("    Specials.%s = %d", field, n)
      end
    end
    if #lines == 0 then return end
    out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
    out[#out + 1] = "    local Specials = require(\"src.script.gen2.Specials\")"
  elseif rse(p) then
    local n = tonumber(g.minDigits)
    if n == nil then return end
    n = math.max(0, math.min(5, math.floor(n)))
    lines[#lines + 1] = "    Lottery.MIN_DIGITS = " .. n
    out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
    out[#out + 1] = "    local Lottery = require(\"src.core.game3.rse.lottery\")"
  else
    return
  end
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
