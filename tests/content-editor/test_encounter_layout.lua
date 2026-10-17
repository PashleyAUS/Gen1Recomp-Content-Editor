-- Map tables must retain the viewport even when global settings are very long.
package.path = "tools/content-editor/?.lua;" .. package.path
local settingsRows, finished = 0, false
package.loaded.Kit = { scale = 1 }
package.loaded.Theme = { PAL = {} }
package.loaded.Gen3ContentAdapter = { prepare = function() end }
package.loaded.Gen3DayNight = { syncCrystalPopulation = function() return false end }
package.loaded.RegList = {
  modeChips = function(S, key, modes, x, y)
    S[key] = S[key] or modes[1].id
    return y + 32
  end,
  mergeIds = function() return {} end,
  drawList = function(S, App, x, y, w, h)
    assert(y == 140 and h == 560, "global settings displaced map tables")
    error("MAP_VIEW_REACHED")
  end,
}
package.loaded.Gen3Labels = { preferredEncounterIds = function() return {} end }
package.loaded.FormPane = {
  begin = function(S, key, x, y, w, h)
    assert(h == 560, "settings must use remaining viewport")
    return y - 200, { contentW = w - 12, h = h }
  end,
  finish = function(S, key, first, bottom, view)
    assert(bottom - first == 5000, "settings content height lost")
    finished = true
  end,
}
for _, name in ipairs({ "EncounterGrace", "EncounterRate", "EncounterSlots", "WildOdds", "Gen2Clock" }) do
  package.loaded[name] = { draw = function(S, x, y, w)
    settingsRows = settingsRows + 1
    assert(w == 988, "settings must respect scrollbar gutter")
    return y + 1000
  end }
end
local Forms = require("Gen3EncounterForms")
local S = { project = { encounters = {} }, data = { encounters = {} } }
local ok, err = pcall(Forms.draw, S, 0, 100, 1000, 600, {})
assert(not ok and tostring(err):find("MAP_VIEW_REACHED", 1, true), tostring(err))
assert(settingsRows == 0, "wild view rendered settings")
S.g3EncounterSection = "settings"
Forms.draw(S, 0, 100, 1000, 600, {})
assert(settingsRows == 5 and finished, "settings did not finish their scroll pane")
print("PASS encounter layout")
