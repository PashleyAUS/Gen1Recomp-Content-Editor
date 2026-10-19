-- How many coins a slot spin takes.
-- Red, Blue, and Yellow, and Gold, Silver, and Crystal, charge a price for
-- each line set. 0 is a free spin of that set. The lines themselves stay put.
-- FireRed, LeafGreen, Ruby, Sapphire, and Emerald cap how many coins one spin
-- can take. 0 means a spin cannot start.

local M = {}

local LINES = {
  { "three", "3 lines", 3 },
  { "two", "2 lines", 2 },
  { "one", "1 line", 1 },
}

local function family(p)
  local ver = p and (p.game or p.version)
  local gen = ver and require("Generation").num({version=ver}) or (p and p.generation)
  if gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal" then return "gen2" end
  if ver == "ruby" or ver == "sapphire" or ver == "emerald" then return "rse" end
  if ver == "firered" or ver == "leafgreen" or gen == 3 then return "frlg" end
  return "gen1"
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project then return y end
  local which = family(S)
  Kit.caption(x, y, "SLOT BET")
  y = y + 22 * s
  local g = S.project.slotBets
  if which == "gen1" or which == "gen2" then
    for _, row in ipairs(LINES) do
      local shown = g and g[row[1]]
      if shown == nil then shown = row[3] end
      Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
      local v = math.max(0, math.min(9999, math.floor(
        require("RegList").num(App, "slot_bet_" .. row[1], x + 220 * s, y, 80 * s, 28 * s, shown))))
      if v ~= shown then
        require("State").ensureProjectFields(S.project)
        S.project.slotBets = S.project.slotBets or {}
        S.project.slotBets[row[1]] = (v == row[3]) and nil or v
        if not next(S.project.slotBets) then S.project.slotBets = nil end
        App.markDirty()
      end
      y = y + 34 * s
    end
    return y
  end
  local shown = g and g.max
  if shown == nil then shown = 3 end
  Kit.text("small", "Coins per spin", x, y + 4 * s, require("Theme").PAL.caption)
  local v = math.max(0, math.min(9999, math.floor(
    require("RegList").num(App, "slot_bet_max", x + 220 * s, y, 80 * s, 28 * s, shown))))
  if v ~= shown then
    require("State").ensureProjectFields(S.project)
    S.project.slotBets = (v == 3) and nil or { max = v }
    App.markDirty()
  end
  return y + 34 * s
end

function M.emit(p, encode, out)
  local g = p.slotBets
  if type(g) ~= "table" then return end
  local which = family(p)
  local lines = {}
  if which == "gen1" or which == "gen2" then
    local path = which == "gen1" and "src.ui.SlotMachine" or "src.ui.gen2.SlotMachine"
    local any = false
    for _, row in ipairs(LINES) do
      local n = tonumber(g[row[1]])
      if n ~= nil then
        any = true
        n = math.max(0, math.min(9999, math.floor(n)))
        lines[#lines + 1] = string.format("    SlotMachine.BET_COST[%d] = %d", row[3], n)
      end
    end
    if not any then return end
    table.insert(lines, 1, "    local SlotMachine = require(\"" .. path .. "\")")
  else
    local n = tonumber(g.max)
    if n == nil then return end
    n = math.max(0, math.min(9999, math.floor(n)))
    local path = which == "rse" and "src.core.game3.rse.slot_machine" or "src.core.game3.slot_machine"
    local name = which == "rse" and "Slots" or "SlotMachine"
    lines[1] = "    local " .. name .. " = require(\"" .. path .. "\")"
    lines[2] = string.format("    %s.MAX_BET = %d", name, n)
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
