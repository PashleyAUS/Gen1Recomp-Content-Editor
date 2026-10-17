-- Gold, Silver, and Crystal. The first row whose rate is at least the
-- catch rate is how often the ball wobbles again. A roll under that
-- chance wobbles. 0 wobbles before the click or the break means the
-- first check is the verdict. Red and the Game Boy Advance do not use it.

local M = {}
local ROWS = {
  { 1, 63 }, { 2, 75 }, { 3, 84 }, { 4, 90 }, { 5, 95 }, { 7, 103 },
  { 10, 113 }, { 15, 126 }, { 20, 134 }, { 30, 149 }, { 40, 160 },
  { 50, 169 }, { 60, 177 }, { 80, 191 }, { 100, 201 }, { 120, 211 },
  { 140, 220 }, { 160, 227 }, { 180, 234 }, { 200, 240 }, { 220, 246 },
  { 240, 251 }, { 254, 253 }, { 255, 255 },
}

local function gen2(p)
  local ver = p and p.version
  local gen = p and p.generation
  return gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not gen2(S) then return y end
  Kit.caption(x, y, "BALL WOBBLE")
  y = y + 22 * s
  local bag = S.project.wobbleOdds
  local shown = bag and bag.limit
  if shown == nil then shown = 3 end
  Kit.text("small", "Wobbles before the verdict", x, y + 4 * s, require("Theme").PAL.caption)
  local v = math.max(0, math.min(10, math.floor(
    require("RegList").num(App, "wobble_limit", x + 280 * s, y, 70 * s, 28 * s, shown))))
  if v ~= shown then
    require("State").ensureProjectFields(S.project)
    S.project.wobbleOdds = S.project.wobbleOdds or {}
    S.project.wobbleOdds.limit = v == 3 and nil or v
    if not next(S.project.wobbleOdds) then S.project.wobbleOdds = nil end
    App.markDirty()
  end
  y = y + 34 * s
  local ids, labels = {}, {}
  for i, row in ipairs(ROWS) do
    ids[i] = tostring(i)
    labels[tostring(i)] = "Rate " .. row[1]
  end
  local current = tostring(S.wobbleRow or "1")
  if not labels[current] then current = "1" end
  require("ChoicePicker").field(S, {
    x = x, y = y, w = math.min(w, 280 * s), h = 28 * s,
    ids = ids, labels = labels, current = current, title = "WOBBLE ROW",
    onPick = function(id) S.wobbleRow = id end,
  })
  y = y + 36 * s
  local index = tonumber(current) or 1
  local vanilla = ROWS[index]
  local function cell(field, slot, fallback, max)
    local stored = bag and bag[field] and bag[field][index]
    local cur = stored == nil and fallback or stored
    Kit.text("small", slot, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(0, math.min(max, math.floor(
      require("RegList").num(App, "wobble_" .. field .. index, x + 220 * s, y, 70 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.wobbleOdds = S.project.wobbleOdds or {}
      S.project.wobbleOdds[field] = S.project.wobbleOdds[field] or {}
      S.project.wobbleOdds[field][index] = n == fallback and nil or n
      if not next(S.project.wobbleOdds[field]) then S.project.wobbleOdds[field] = nil end
      if not next(S.project.wobbleOdds) then S.project.wobbleOdds = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  cell("rates", "Applies at rate", vanilla[1], 255)
  cell("chances", "Wobble again below", vanilla[2], 255)
  return y
end

function M.emit(p, encode, out)
  local g = p.wobbleOdds
  if type(g) ~= "table" or not gen2(p) then return end
  local lines = {}
  if g.limit ~= nil then
    local n = math.max(0, math.min(10, math.floor(tonumber(g.limit) or 3)))
    lines[#lines + 1] = string.format("    Catching.WOBBLE_LIMIT = %d", n)
  end
  for i, row in ipairs(ROWS) do
    local rate = g.rates and tonumber(g.rates[i])
    local chance = g.chances and tonumber(g.chances[i])
    if rate ~= nil then
      rate = math.max(0, math.min(255, math.floor(rate)))
      lines[#lines + 1] = string.format("    Catching.WOBBLE_PROBABILITIES[%d][1] = %d", i, rate)
    end
    if chance ~= nil then
      chance = math.max(0, math.min(255, math.floor(chance)))
      lines[#lines + 1] = string.format("    Catching.WOBBLE_PROBABILITIES[%d][2] = %d", i, chance)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Catching = require(\"src.battle.gen2.Catching\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
