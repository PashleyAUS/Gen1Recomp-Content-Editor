-- Gold, Silver, and Crystal aim a spin at the first symbol whose cutoff
-- is at least the roll. The numbers are cumulative, and 255 is still the
-- last row, so a roll always lands somewhere. 0 catches only a roll of 0
-- when no earlier row caught it.
-- Red, Blue, Yellow, and the Game Boy Advance machines use other odds.

local M = {}
local NORMAL = {
  { "n7", "7", 1 }, { "nball", "Poké Ball", 3 }, { "nstar", "Staryu", 10 },
  { "nsquir", "Squirtle", 20 }, { "npika", "Pikachu", 40 }, { "ncherry", "Cherry", 48 },
}
local LUCKY = {
  { "l7", "7", 2 }, { "lball", "Poké Ball", 3 }, { "lstar", "Staryu", 8 },
  { "lsquir", "Squirtle", 16 }, { "lpika", "Pikachu", 30 }, { "lcherry", "Cherry", 80 },
}

local function gen2(p)
  local ver = p and p.version
  local gen = p and p.generation
  return gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
end

local function rows(S, App, x, y, s, title, list)
  local Kit = require("Kit")
  Kit.text("small", title, x, y + 4 * s, require("Theme").PAL.caption)
  y = y + 28 * s
  local g = S.project.slotBias
  for i, row in ipairs(list) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x + 12 * s, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(255, math.floor(
      require("RegList").num(App, "slot_bias_" .. row[1], x + 160 * s, y, 70 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.slotBias = S.project.slotBias or {}
      S.project.slotBias[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.slotBias) then S.project.slotBias = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project or not gen2(S) then return y end
  Kit.caption(x, y, "SLOT AIM")
  y = y + 22 * s
  Kit.text("micro", "The first cutoff the roll reaches is the symbol the reels chase.", x, y, require("Theme").PAL.muted)
  y = y + 20 * s
  y = rows(S, App, x, y, s, "Normal machine", NORMAL)
  y = rows(S, App, x, y, s, "Lucky machine", LUCKY)
  local shown = S.project.slotBias and S.project.slotBias.chase
  if shown == nil then shown = 4 end
  Kit.text("small", "Slots a reel will chase", x, y + 4 * s, require("Theme").PAL.caption)
  local v = math.max(0, math.min(15, math.floor(
    require("RegList").num(App, "slot_bias_chase", x + 220 * s, y, 70 * s, 28 * s, shown))))
  if v ~= shown then
    require("State").ensureProjectFields(S.project)
    S.project.slotBias = S.project.slotBias or {}
    S.project.slotBias.chase = (v == 4) and nil or v
    if not next(S.project.slotBias) then S.project.slotBias = nil end
    App.markDirty()
  end
  return y + 34 * s
end

local function emitRows(lines, list, field)
  return function(g)
    for i, row in ipairs(list) do
      local n = tonumber(g[row[1]])
      if n ~= nil then
        n = math.max(0, math.min(255, math.floor(n)))
        lines[#lines + 1] = string.format("    SlotMachine.%s[%d][1] = %d", field, i, n)
      end
    end
  end
end

function M.emit(p, encode, out)
  local g = p.slotBias
  if type(g) ~= "table" or not gen2(p) then return end
  local lines = {}
  emitRows(lines, NORMAL, "BIAS_NORMAL")(g)
  emitRows(lines, LUCKY, "BIAS_LUCKY")(g)
  local chase = tonumber(g.chase)
  if chase ~= nil then
    chase = math.max(0, math.min(15, math.floor(chase)))
    lines[#lines + 1] = string.format("    SlotMachine.MANIP_COUNTER = %d", chase)
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local SlotMachine = require(\"src.ui.gen2.SlotMachine\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
