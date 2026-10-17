-- Emerald Pickup groups levels and treats two rolls as rare items.
-- Ruby and Sapphire play the flat list. FireRed and LeafGreen do too.

local M = {}
local ROWS = {
  { key = "pickupBand", label = "Levels per band", default = 10, min = 1, max = 100 },
  { key = "pickupBandCap", label = "Highest band", default = 9, min = 0, max = 99 },
  { key = "pickupRareHigh", label = "First rare roll", default = 99, min = 0, max = 255 },
  { key = "pickupRareLow", label = "Second rare roll", default = 98, min = 0, max = 255 },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project then return y end
  Kit.caption(x, y, "PICKUP BANDS")
  y = y + 22 * s
  local bag = S.project.gen3BattleRules
  for _, row in ipairs(ROWS) do
    local stored = bag and bag[row.key]
    local cur = stored == nil and row.default or stored
    Kit.text("small", row.label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(row.min, math.min(row.max, math.floor(
      require("RegList").num(App, "pickup_band_" .. row.key, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.gen3BattleRules = S.project.gen3BattleRules or {}
      S.project.gen3BattleRules[row.key] = n == row.default and nil or n
      if not next(S.project.gen3BattleRules) then S.project.gen3BattleRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

return M
