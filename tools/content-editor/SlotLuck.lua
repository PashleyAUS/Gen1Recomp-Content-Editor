-- Red, Blue, and Yellow slot luck. A roll above the bar line arms sevens.
-- A roll above the win line can still match. A roll of 0 arms sure wins.
-- 255 never arms that line. 0 sure wins arms none.
-- Gold, Silver, Crystal, and the Game Boy Advance machines use other odds.

local M = {}
local ROWS = {
  { "luckyBar", "Lucky machine, sevens above", 250 },
  { "plainBar", "Other machines, sevens above", 253 },
  { "winAbove", "A match is allowed above", 210 },
  { "matchSpins", "Sure wins from a zero roll", 60 },
}
local FIELD = {
  luckyBar = "LUCKY_BAR", plainBar = "PLAIN_BAR",
  winAbove = "WIN_ABOVE", matchSpins = "MATCH_SPINS",
}

local function gen1(p)
  local ver = p and (p.game or p.version)
  return p and (p.generation == 1 or ver == "red" or ver == "blue" or ver == "yellow")
    and ver ~= "gold" and ver ~= "silver" and ver ~= "crystal"
    and p.generation ~= 2 and p.generation ~= 3
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not gen1(S) then return y end
  Kit.caption(x, y, "SLOT LUCK")
  y = y + 22 * s
  local g = S.project.slotLuck
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(255, math.floor(
      require("RegList").num(App, "slot_luck_" .. row[1], x + 280 * s, y, 70 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.slotLuck = S.project.slotLuck or {}
      S.project.slotLuck[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.slotLuck) then S.project.slotLuck = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.slotLuck
  if type(g) ~= "table" or not gen1(p) then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(0, math.min(255, math.floor(n)))
      lines[#lines + 1] = string.format("    SlotMachine.%s = %d", FIELD[row[1]], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local SlotMachine = require(\"src.ui.SlotMachine\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
