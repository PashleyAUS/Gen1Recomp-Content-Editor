-- How the other Berry Blender players hit. A roll above a best line is
-- perfect. 0 on a "below this" check never matches. Ruby, Sapphire, and
-- Emerald share these seats. The other games have no blender.

local M = {}
local GROUPS = {
  { id = "speed", label = "Speeds", rows = {
    { "oppSlow", "Slow under", 500, 0, 65535, "OPP_SLOW" },
    { "oppFast", "Fast at", 1500, 0, 65535, "OPP_FAST" },
    { "oppMissDelay", "Miss delay", 5, 0, 255, "OPP_MISS_DELAY" },
    { "oppNearFrom", "Later seats, window from", 20, 0, 255, "OPP_NEAR_FROM" },
    { "oppNearTo", "Later seats, window to", 40, 0, 255, "OPP_NEAR_TO" },
  } },
  { id = "second", label = "Second player", rows = {
    { "opp1MedBest", "Medium, perfect above", 80, 0, 100, "OPP1_MED_BEST" },
    { "opp1MedGoodFrom", "Medium, good from", 21, 0, 100, "OPP1_MED_GOOD_FROM" },
    { "opp1MedGoodSpan", "Medium, good width", 60, 0, 100, "OPP1_MED_GOOD_SPAN" },
    { "opp1MedMiss", "Medium, miss below", 10, 0, 100, "OPP1_MED_MISS" },
    { "opp1FastCap", "Fast, good at or below", 90, 0, 100, "OPP1_FAST_CAP" },
    { "opp1FastGoodFrom", "Fast, good from", 71, 0, 100, "OPP1_FAST_GOOD_FROM" },
    { "opp1FastGoodSpan", "Fast, good width", 20, 0, 100, "OPP1_FAST_GOOD_SPAN" },
    { "opp1FastMiss", "Fast, miss below", 30, 0, 100, "OPP1_FAST_MISS" },
  } },
  { id = "third", label = "Third player", rows = {
    { "opp2SlowBest", "Slow, perfect above", 66, 0, 100, "OPP2_SLOW_BEST" },
    { "opp2Best", "Otherwise, perfect above", 65, 0, 100, "OPP2_BEST" },
    { "opp2Good", "Otherwise, good above", 40, 0, 100, "OPP2_GOOD" },
    { "opp2Miss", "Otherwise, miss below", 10, 0, 100, "OPP2_MISS" },
  } },
  { id = "fourth", label = "Fourth player", rows = {
    { "opp3SlowBest", "Slow, perfect above", 88, 0, 100, "OPP3_SLOW_BEST" },
    { "opp3Best", "Otherwise, perfect above", 60, 0, 100, "OPP3_BEST" },
    { "opp3Good", "Otherwise, good above", 55, 0, 100, "OPP3_GOOD" },
    { "opp3Miss", "Otherwise, miss below", 5, 0, 100, "OPP3_MISS" },
  } },
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
  Kit.caption(x, y, "OTHER PLAYERS")
  y = y + 22 * s
  local ids, labels = {}, {}
  for i, group in ipairs(GROUPS) do
    ids[i] = group.id
    labels[group.id] = group.label
  end
  local current = S.blenderOppGroup or "speed"
  if not labels[current] then current = "speed" end
  require("ChoicePicker").field(S, {
    x = x, y = y, w = math.min(w, 280 * s), h = 28 * s,
    ids = ids, labels = labels, current = current, title = "WHICH PLAYER",
    onPick = function(id) S.blenderOppGroup = id end,
  })
  y = y + 36 * s
  local rows = GROUPS[1].rows
  for _, group in ipairs(GROUPS) do
    if group.id == current then rows = group.rows end
  end
  local g = S.project.gen3Blender
  for _, row in ipairs(rows) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(row[4], math.min(row[5], math.floor(
      require("RegList").num(App, "blend_opp_" .. row[1], x + 260 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.gen3Blender = S.project.gen3Blender or {}
      S.project.gen3Blender[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.gen3Blender) then S.project.gen3Blender = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.gen3Blender
  if type(g) ~= "table" or not rse(p) then return end
  local lines = {}
  for _, group in ipairs(GROUPS) do
    for _, row in ipairs(group.rows) do
      local n = tonumber(g[row[1]])
      if n ~= nil then
        n = math.max(row[4], math.min(row[5], math.floor(n)))
        lines[#lines + 1] = string.format("    Blender.%s = %d", row[6], n)
      end
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Blender = require(\"src.core.game3.rse.berry_blender\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
