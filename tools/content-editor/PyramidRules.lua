-- Battle Pyramid rounds and the Pickup column a roll can reach.
-- Ruby, Sapphire, and Emerald share it. FireRed and LeafGreen do not.

local M = {}
local ROWS = {
  { key = "rounds", label = "Pyramid rounds", field = "TOTAL_ROUNDS", default = 20, min = 1, max = 255 },
  { key = "columns", label = "Pickup columns", field = "PICKUP_ITEMS_PER_ROUND", default = 10, min = 1, max = 100 },
  { key = "roll", label = "Pickup roll", field = "PICKUP_ROLL", default = 100, min = 1, max = 256 },
  { key = "maxStreak", label = "Streak ceiling", field = "MAX_STREAK", default = 999, min = 0, max = 9999 },
  { key = "longStreak", label = "Long-streak prizes after", field = "LONG_STREAK", default = 41, min = 0, max = 9999 },
  { key = "highIv", label = "High wild IVs at streak", field = "WILD_HIGH_IV_STREAK", default = 140, min = 0, max = 9999 },
  { key = "bagSlots", label = "Bag slots", field = "BAG_ITEMS_COUNT", default = 10, min = 0, max = 30 },
  { key = "stack", label = "Stack size", field = "MAX_BAG_ITEM_CAPACITY", default = 99, min = 0, max = 999 },
  { key = "light", label = "Light radius", field = "MAX_LIGHT_RADIUS", default = 120, min = 0, max = 999 },
  { key = "trainers", label = "Trainers per floor", field = "MAX_TRAINERS", default = 8, min = 0, max = 16 },
  { key = "squares", label = "Floor squares", field = "NUM_SQUARES", default = 16, min = 1, max = 16 },
  { key = "hintNear", label = "Near exit hint", field = "HINT_NEAR", default = 8, min = 0, max = 255 },
  { key = "hintMid", label = "Mid exit hint", field = "HINT_MID", default = 16, min = 0, max = 255 },
  { key = "hintFar", label = "Far exit hint", field = "HINT_FAR", default = 24, min = 0, max = 255 },
  { key = "levelDrop", label = "Wild level below the row", field = "WILD_LEVEL_DROP", default = 5, min = 0, max = 100 },
  { key = "levelSpan", label = "Wild level roll", field = "WILD_LEVEL_SPAN", default = 11, min = 1, max = 256 },
  { key = "ivSpan", label = "Wild IV roll", field = "WILD_IV_SPAN", default = 32, min = 1, max = 256 },
  { key = "highIvSpan", label = "High IV roll", field = "WILD_HIGH_IV_SPAN", default = 17, min = 1, max = 256 },
  { key = "highIvBase", label = "High IV floor", field = "WILD_HIGH_IV_BASE", default = 15, min = 0, max = 31 },
}

local function rse(p)
  local id = type(p) == "table" and (p.version or p.game) or ""
  if type(id) ~= "string" then return false end
  id = id:lower()
  return id == "ruby" or id == "sapphire" or id == "emerald"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not rse(S) then return y end
  Kit.caption(x, y, "BATTLE PYRAMID")
  y = y + 22 * s
  local bag = S.project.pyramidRules
  for _, row in ipairs(ROWS) do
    local stored = bag and bag[row.key]
    local cur = stored == nil and row.default or stored
    Kit.text("small", row.label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(row.min, math.min(row.max, math.floor(
      require("RegList").num(App, "pyramid_" .. row.key, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.pyramidRules = S.project.pyramidRules or {}
      S.project.pyramidRules[row.key] = n == row.default and nil or n
      if not next(S.project.pyramidRules) then S.project.pyramidRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.pyramidRules
  if type(g) ~= "table" or not rse(p) then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row.key])
    if n ~= nil then
      n = math.max(row.min, math.min(row.max, math.floor(n)))
      lines[#lines + 1] = string.format("    Pyramid.%s = %d", row.field, n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Pyramid = require(\"src.core.game3.rse.frontier.pyramid\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
