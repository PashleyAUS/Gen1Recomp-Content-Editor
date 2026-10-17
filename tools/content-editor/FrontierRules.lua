-- Shared Battle Frontier limits. The Pyramid keeps its own streak.
-- Ruby, Sapphire, and Emerald share these. FireRed and LeafGreen do not.

local M = {}
local ROWS = {
  { key = "streak", label = "Streak ceiling", field = "MAX_STREAK", default = 9999, min = 0, max = 99999 },
  { key = "points", label = "Battle Point ceiling", field = "MAX_BATTLE_FRONTIER_POINTS", default = 9999, min = 0, max = 99999 },
  { key = "level50", label = "Level 50 mode", field = "FRONTIER_MAX_LEVEL_50", default = 50, min = 1, max = 100 },
  { key = "openMin", label = "Open level floor", field = "FRONTIER_MIN_LEVEL_OPEN", default = 60, min = 0, max = 100 },
  { key = "tentMin", label = "Battle Tent floor", field = "TENT_MIN_LEVEL", default = 30, min = 0, max = 100 },
  { key = "stages", label = "Battles per challenge", field = "STAGES_PER_CHALLENGE", default = 7, min = 1, max = 100 },
  { key = "tentStages", label = "Tent battles", field = "TENT_STAGES_PER_CHALLENGE", default = 3, min = 1, max = 100 },
  { key = "brain", label = "Brain bonus", field = "BRAIN_BONUS", default = 10, min = 0, max = 9999 },
  { key = "card", label = "Frontier Pass ceiling", field = "CARD_POINT_CAP", default = 65535, min = 0, max = 999999 },
  { key = "pikeRooms", label = "Pike rooms", field = "NUM_PIKE_ROOMS", module = "src.core.game3.rse.frontier.pike", assign = "Pike", default = 14, min = 1, max = 100 },
  { key = "pikeSleep", label = "Pike sleep turns", field = "STATUS1_SLEEP_TURNS", module = "src.core.game3.rse.frontier.pike", assign = "Pike", default = 7, min = 0, max = 255 },
  { key = "pikeWild1", label = "Pike wild set 1 through", field = "WILD_SET_1", module = "src.core.game3.rse.frontier.pike", assign = "Pike", default = 20, min = 0, max = 999 },
  { key = "pikeWild2", label = "Pike wild set 2 through", field = "WILD_SET_2", module = "src.core.game3.rse.frontier.pike", assign = "Pike", default = 40, min = 0, max = 999 },
  { key = "pikeWild3", label = "Pike wild set 3 through", field = "WILD_SET_3", module = "src.core.game3.rse.frontier.pike", assign = "Pike", default = 60, min = 0, max = 999 },
  { key = "highTier", label = "High-tier Pokémon above", field = "FRONTIER_MONS_HIGH_TIER", default = 849, min = 0, max = 9999 },
  { key = "lowBan", label = "Also ban high tier at level", field = "LOW_BAN_LEVEL", default = 20, min = 0, max = 100 },
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
  Kit.caption(x, y, "BATTLE FRONTIER")
  y = y + 22 * s
  local bag = S.project.frontierRules
  for _, row in ipairs(ROWS) do
    local stored = bag and bag[row.key]
    local cur = stored == nil and row.default or stored
    Kit.text("small", row.label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(row.min, math.min(row.max, math.floor(
      require("RegList").num(App, "frontier_" .. row.key, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.frontierRules = S.project.frontierRules or {}
      S.project.frontierRules[row.key] = n == row.default and nil or n
      if not next(S.project.frontierRules) then S.project.frontierRules = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return require("FrontierIv").draw(S, x, y + 12 * s, w, App)
end

function M.emit(p, encode, out)
  local g = p.frontierRules
  if type(g) ~= "table" or not rse(p) then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row.key])
    if n ~= nil then
      n = math.max(row.min, math.min(row.max, math.floor(n)))
      if row.module then
        out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
        out[#out + 1] = "    local " .. row.assign .. " = require(\"" .. row.module .. "\")"
        out[#out + 1] = string.format("    %s.%s = %d", row.assign, row.field, n)
        out[#out + 1] = "  end)"
        out[#out + 1] = ""
      else
        lines[#lines + 1] = string.format("    D.%s = %d", row.field, n)
      end
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local D = require(\"src.core.game3.rse.frontier.trainers\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
