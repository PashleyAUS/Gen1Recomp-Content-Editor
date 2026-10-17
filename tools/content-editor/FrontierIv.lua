-- Frontier trainer IVs climb with the trainer number. The last
-- number is the IV for everyone past the ladder. Effort points split
-- the pool across the stats that are set. Ruby, Sapphire, and Emerald
-- share this. FireRed and LeafGreen do not.

local M = {}
local STEPS = {
  { 99, 3 }, { 119, 6 }, { 139, 9 }, { 159, 12 }, { 179, 15 }, { 199, 18 }, { 219, 21 },
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
  Kit.caption(x, y, "FRONTIER TRAINER STATS")
  y = y + 22 * s
  local ids, labels = {}, {}
  for i, step in ipairs(STEPS) do
    ids[i] = tostring(i)
    labels[tostring(i)] = "Through " .. step[1] .. ", IV " .. step[2]
  end
  local current = tostring(S.frontierIvRow or "1")
  if not labels[current] then current = "1" end
  require("ChoicePicker").field(S, {
    x = x, y = y, w = math.min(w, 320 * s), h = 28 * s,
    ids = ids, labels = labels, current = current, title = "IV STEP",
    onPick = function(id) S.frontierIvRow = id end,
  })
  y = y + 36 * s
  local index = tonumber(current) or 1
  local vanilla = STEPS[index]
  local bag = S.project.frontierIv
  local function cell(field, label, fallback, max)
    local stored = bag and bag[field] and bag[field][index]
    local cur = stored == nil and fallback or stored
    Kit.text("small", label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(0, math.min(max, math.floor(
      require("RegList").num(App, "fiv_" .. field .. index, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.frontierIv = S.project.frontierIv or {}
      S.project.frontierIv[field] = S.project.frontierIv[field] or {}
      S.project.frontierIv[field][index] = n == fallback and nil or n
      if not next(S.project.frontierIv[field]) then S.project.frontierIv[field] = nil end
      if S.project.frontierIv.max == nil and S.project.frontierIv.evs == nil and not next(S.project.frontierIv) then
        S.project.frontierIv = nil
      end
      App.markDirty()
    end
    y = y + 34 * s
  end
  cell("cuts", "Trainers through", vanilla[1], 9999)
  cell("ivs", "Their IVs", vanilla[2], 31)
  local function knob(key, label, fallback, max)
    local stored = bag and bag[key]
    local cur = stored == nil and fallback or stored
    Kit.text("small", label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(0, math.min(max, math.floor(
      require("RegList").num(App, "fiv_" .. key, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.frontierIv = S.project.frontierIv or {}
      S.project.frontierIv[key] = n == fallback and nil or n
      if not next(S.project.frontierIv) then S.project.frontierIv = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  knob("max", "Everyone past the ladder", 31, 31)
  knob("evs", "Effort point pool", 510, 1530)
  return y
end

function M.emit(p, encode, out)
  local g = p.frontierIv
  if type(g) ~= "table" or not rse(p) then return end
  local lines = {}
  for i, step in ipairs(STEPS) do
    local cut = g.cuts and tonumber(g.cuts[i])
    local iv = g.ivs and tonumber(g.ivs[i])
    if cut ~= nil then
      cut = math.max(0, math.min(9999, math.floor(cut)))
      lines[#lines + 1] = string.format("    D.IV_STEPS[%d][1] = %d", i, cut)
    end
    if iv ~= nil then
      iv = math.max(0, math.min(31, math.floor(iv)))
      lines[#lines + 1] = string.format("    D.IV_STEPS[%d][2] = %d", i, iv)
    end
  end
  if g.max ~= nil then
    lines[#lines + 1] = "    D.MAX_PER_STAT_IVS = " .. math.max(0, math.min(31, math.floor(g.max)))
  end
  if g.evs ~= nil then
    lines[#lines + 1] = "    D.MAX_TOTAL_EVS = " .. math.max(0, math.min(1530, math.floor(g.evs)))
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local D = require(\"src.core.game3.rse.frontier.trainers\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
