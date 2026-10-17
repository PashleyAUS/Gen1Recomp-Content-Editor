-- The flat Pickup list. The first row whose number is above the roll
-- is the item. 0 on a row lets the roll fall through. The last row is
-- what remains. Emerald uses level bands instead.

local M = {}
local ROWS = {
  { 139, 15 }, { 133, 25 }, { 134, 35 }, { 135, 45 }, { 136, 55 }, { 137, 65 },
  { 140, 75 }, { 298, 80 }, { 69, 85 }, { 68, 90 }, { 110, 95 }, { 163, 96 },
  { 164, 97 }, { 165, 98 }, { 166, 99 }, { 167, 1 },
}

local function frlg(p)
  local id = type(p) == "table" and (p.version or p.game) or ""
  if type(id) ~= "string" then return false end
  id = id:lower()
  return id == "firered" or id == "leafgreen" or id == "ruby" or id == "sapphire"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not frlg(S) then return y end
  Kit.caption(x, y, "PICKUP ITEMS")
  y = y + 22 * s
  local ids, labels = {}, {}
  for i, row in ipairs(ROWS) do
    ids[i] = tostring(i)
    labels[tostring(i)] = "Row " .. i .. ", item " .. row[1]
  end
  local current = tostring(S.pickupRow or "1")
  if not labels[current] then current = "1" end
  require("ChoicePicker").field(S, {
    x = x, y = y, w = math.min(w, 320 * s), h = 28 * s,
    ids = ids, labels = labels, current = current, title = "PICKUP ROW",
    onPick = function(id) S.pickupRow = id end,
  })
  y = y + 36 * s
  local index = tonumber(current) or 1
  local vanilla = ROWS[index]
  local bag = S.project.gen3Pickup
  local function cell(field, label, fallback, max)
    local stored = bag and bag[field] and bag[field][index]
    local cur = stored == nil and fallback or stored
    Kit.text("small", label, x, y + 4 * s, require("Theme").PAL.caption)
    local n = math.max(0, math.min(max, math.floor(
      require("RegList").num(App, "pickup_" .. field .. index, x + 220 * s, y, 80 * s, 28 * s, cur))))
    if n ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.gen3Pickup = S.project.gen3Pickup or {}
      S.project.gen3Pickup[field] = S.project.gen3Pickup[field] or {}
      S.project.gen3Pickup[field][index] = n == fallback and nil or n
      if not next(S.project.gen3Pickup[field]) then S.project.gen3Pickup[field] = nil end
      if not next(S.project.gen3Pickup) then S.project.gen3Pickup = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  cell("items", "Item", vanilla[1], 999)
  cell("cuts", "Above the roll", vanilla[2], 100)
  return y
end

function M.emit(p, encode, out)
  local g = p.gen3Pickup
  if type(g) ~= "table" or not frlg(p) then return end
  local lines = {}
  for i, row in ipairs(ROWS) do
    local item = g.items and tonumber(g.items[i])
    local cut = g.cuts and tonumber(g.cuts[i])
    if item ~= nil then
      item = math.max(0, math.min(999, math.floor(item)))
      lines[#lines + 1] = string.format("    Prize.PICKUP_ITEMS[%d][1] = %d", i, item)
    end
    if cut ~= nil then
      cut = math.max(0, math.min(100, math.floor(cut)))
      lines[#lines + 1] = string.format("    Prize.PICKUP_ITEMS[%d][2] = %d", i, cut)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Prize = require(\"src.core.game3.battle.prize\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
