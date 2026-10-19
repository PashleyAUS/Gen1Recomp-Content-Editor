-- Gold, Silver, and Crystal. A seven usually drops its bias. These are how
-- often it stays, and how often a visit uses the rarer of the two rates.
-- 1 always happens. 0 never does. The cartridge rates keep the original
-- bit checks. Red, Blue, Yellow, and the Game Boy Advance use other odds.

local M = {}
local ROWS = {
  { "rareVisit", "Rare streak visit, 1 in", 8, "RARE_VISIT" },
  { "streakRare", "On that visit, a 7 repeats, 1 in", 8, "STREAK_RARE" },
  { "streakPlain", "On a normal visit, a 7 repeats, 1 in", 4, "STREAK_PLAIN" },
}

local function gen2(p)
  local ver = p and (p.game or p.version)
  local gen = ver and require("Generation").num({version=ver}) or (p and p.generation)
  return gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not gen2(S) then return y end
  Kit.caption(x, y, "SEVEN STREAK")
  y = y + 22 * s
  local g = S.project.slotStreak
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(256, math.floor(
      require("RegList").num(App, "slot_streak_" .. row[1], x + 300 * s, y, 70 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.slotStreak = S.project.slotStreak or {}
      S.project.slotStreak[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.slotStreak) then S.project.slotStreak = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.slotStreak
  if type(g) ~= "table" or not gen2(p) then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(0, math.min(256, math.floor(n)))
      lines[#lines + 1] = string.format("    SlotMachine.%s = %d", row[4], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local SlotMachine = require(\"src.ui.gen2.SlotMachine\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
