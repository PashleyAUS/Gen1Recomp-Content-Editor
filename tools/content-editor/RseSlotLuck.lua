-- Ruby, Sapphire, and Emerald. A lucky visit adds this much to the first
-- regular prize and takes the same amount off the last one. 0 leaves the
-- lucky visit on the ordinary odds. Pika Power bolts stop at 16, and 0
-- never adds one. FireRed and LeafGreen use a different machine.

local M = {}
local ROWS = {
  { "nudge", "Lucky visit, prize shift", 10, 0, 255, "LUCKY_NUDGE" },
  { "boltCap", "Pika Power bolts", 16, 0, 16, "BOLT_CAP" },
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
  Kit.caption(x, y, "SLOT LUCK")
  y = y + 22 * s
  Kit.text("micro", "The shift is added to the first regular prize and taken off the last.", x, y, require("Theme").PAL.muted)
  y = y + 20 * s
  local g = S.project.rseSlotLuck
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(row[4], math.min(row[5], math.floor(
      require("RegList").num(App, "rse_slot_" .. row[1], x + 260 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.rseSlotLuck = S.project.rseSlotLuck or {}
      S.project.rseSlotLuck[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.rseSlotLuck) then S.project.rseSlotLuck = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.rseSlotLuck
  if type(g) ~= "table" or not rse(p) then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(row[4], math.min(row[5], math.floor(n)))
      lines[#lines + 1] = string.format("    Slots.%s = %d", row[6], n)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Slots = require(\"src.core.game3.rse.slot_machine\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
