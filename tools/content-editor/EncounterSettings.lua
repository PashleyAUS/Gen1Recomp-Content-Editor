-- Global encounter rules live apart from the map tables and scroll independently.
local M = {}

function M.draw(S, x, y, w, h, App)
  local Pane = require("FormPane")
  local first, view = Pane.begin(S, "encounterSettingsScroll", x, y, w, h)
  local bottom = first
  for _, name in ipairs({ "EncounterGrace", "EncounterRate", "EncounterSlots", "WildOdds", "Gen2Clock" }) do
    bottom = require(name).draw(S, x, bottom, view.contentW, App)
  end
  Pane.finish(S, "encounterSettingsScroll", first, bottom, view)
end

return M
