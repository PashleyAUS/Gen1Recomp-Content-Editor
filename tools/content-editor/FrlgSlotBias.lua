-- FireRed and LeafGreen aim a slot spin at the first prize whose cutoff
-- the roll has not reached. The last number is how often a seven try is
-- held, out of 16384. A cutoff of 0 never catches that prize. The seven
-- wait is 5 or 60 spins, and 0 waits nothing.
-- Ruby, Sapphire, and Emerald read their odds from the cartridge.

local M = {}
local COLS = {
  "Nothing", "Two cherries", "Three cherries", "Magnemite or Shellder",
  "Pikachu or Psyduck", "Team Rocket", "Seven hold",
}
local DEFAULTS = {
  { 0x1fa1, 0x2eab, 0x3630, 0x39f3, 0x3bd4, 0x3bfc, 0x0049 },
  { 0x1f97, 0x2ea2, 0x3627, 0x39e9, 0x3bca, 0x3bf8, 0x0049 },
  { 0x1f91, 0x2e9b, 0x3620, 0x39e3, 0x3bc4, 0x3bf4, 0x0049 },
  { 0x1f87, 0x2e92, 0x3617, 0x39d9, 0x3bba, 0x3bef, 0x0050 },
  { 0x1f7f, 0x2e89, 0x360e, 0x39d1, 0x3bb2, 0x3bea, 0x0050 },
  { 0x1fc9, 0x2efc, 0x3696, 0x3a63, 0x3c49, 0x3c8b, 0x0073 },
}
local WAIT = {
  { "short", "Short seven wait", 5, 0, 255, "BIAS_COOLDOWN_SHORT" },
  { "long", "Long seven wait", 60, 0, 255, "BIAS_COOLDOWN_LONG" },
  { "keepNum", "Keep the wait, numerator", 7, 0, 100, "SEVEN_KEEP_NUM" },
  { "keepDen", "Keep the wait, denominator", 10, 1, 100, "SEVEN_KEEP_DEN" },
}

local function frlg(p)
  local id = type(p) == "table" and (p.version or p.game) or ""
  if type(id) ~= "string" then return false end
  id = id:lower()
  return id == "firered" or id == "leafgreen"
end

local function cellKey(group, col)
  return "g" .. group .. "c" .. col
end

local function write(S, App, bag, key, value, default)
  require("State").ensureProjectFields(S.project)
  S.project.frlgSlotBias = S.project.frlgSlotBias or {}
  S.project.frlgSlotBias[key] = (value == default) and nil or value
  if not next(S.project.frlgSlotBias) then S.project.frlgSlotBias = nil end
  App.markDirty()
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not frlg(S) then return y end
  Kit.caption(x, y, "SLOT AIM")
  y = y + 22 * s
  Kit.text("micro", "The roll stops at the first cutoff it is still under. The last number holds a seven, out of 16384.", x, y, require("Theme").PAL.muted)
  y = y + 20 * s
  local group = tostring(S.frlgBiasGroup or "0")
  local labels = {}
  local ids = {}
  for i = 0, 5 do
    ids[i + 1] = tostring(i)
    labels[tostring(i)] = "Group " .. (i + 1)
  end
  require("ChoicePicker").field(S, {
    x = x, y = y, w = math.min(w, 280 * s), h = 28 * s,
    ids = ids, labels = labels, current = group, title = "MACHINE GROUP",
    onPick = function(id) S.frlgBiasGroup = id end,
  })
  y = y + 36 * s
  local g = tonumber(group) or 0
  if g < 0 or g > 5 then g = 0 end
  local bag = S.project.frlgSlotBias
  for col, name in ipairs(COLS) do
    local key = cellKey(g, col - 1)
    local default = DEFAULTS[g + 1][col]
    local shown = bag and bag[key]
    if shown == nil then shown = default end
    Kit.text("small", name, x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(65535, math.floor(
      require("RegList").num(App, "frlg_bias_" .. key, x + 240 * s, y, 90 * s, 28 * s, shown))))
    if v ~= shown then write(S, App, bag, key, v, default) end
    y = y + 34 * s
  end
  for _, row in ipairs(WAIT) do
    local shown = bag and bag[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(row[4], math.min(row[5], math.floor(
      require("RegList").num(App, "frlg_bias_" .. row[1], x + 240 * s, y, 90 * s, 28 * s, shown))))
    if v ~= shown then write(S, App, bag, row[1], v, row[3]) end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.frlgSlotBias
  if type(g) ~= "table" or not frlg(p) then return end
  local lines = {}
  for group = 0, 5 do
    for col = 0, 6 do
      local n = tonumber(g[cellKey(group, col)])
      if n ~= nil then
        n = math.max(0, math.min(65535, math.floor(n)))
        lines[#lines + 1] = string.format("    SlotMachine.BIAS_CHANCES[%d][%d] = %d", group, col, n)
      end
    end
  end
  for _, row in ipairs(WAIT) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(row[4], math.min(row[5], math.floor(n)))
      lines[#lines + 1] = string.format("    SlotMachine.%s = %d", row[6], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local SlotMachine = require(\"src.core.game3.slot_machine\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
