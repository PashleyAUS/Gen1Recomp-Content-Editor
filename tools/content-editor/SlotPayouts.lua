-- Game Corner coin payouts. 0 pays nothing for that line.
-- Red, Blue, and Yellow share one machine. Gold, Silver, and Crystal share another.
-- FireRed and LeafGreen share a third. Ruby, Sapphire, and Emerald share a fourth.

local M = {}

local ROWS = {
  gen1 = {
    { "seven", "7", 300 }, { "bar", "Bar", 100 }, { "cherry", "Cherry", 8 },
    { "mouse", "Mouse", 15 }, { "fish", "Fish", 15 }, { "bird", "Bird", 15 },
  },
  gen2 = {
    { "seven", "7", 300 }, { "pokeball", "Poké Ball", 50 }, { "cherry", "Cherry", 6 },
    { "pikachu", "Pikachu", 8 }, { "squirtle", "Squirtle", 10 }, { "staryu", "Staryu", 15 },
  },
  frlg = {
    { "none", "No match", 0 }, { "cherries2", "Two cherries", 2 },
    { "cherries3", "Three cherries", 6 }, { "magshell", "Magnemite / Shellder", 8 },
    { "pikapsy", "Pikachu / Psyduck", 15 }, { "rocket", "Rocket", 100 },
    { "seven", "7", 300 },
  },
  rse = {
    { "cherry", "Cherry", 2 }, { "topbot", "Cherry, top or bottom", 4 },
    { "replay", "Replay", 0 }, { "lotad", "Lotad", 6 }, { "azurill", "Azurill", 12 },
    { "power", "Power", 3 }, { "mixed7", "Mixed 7s", 90 },
    { "red7", "Red 7s", 300 }, { "blue7", "Blue 7s", 300 },
  },
}

local GEN2_INDEX = { seven = 0, pokeball = 4, cherry = 8, pikachu = 12, squirtle = 16, staryu = 20 }
local FRLG_INDEX = { none = 0, cherries2 = 1, cherries3 = 2, magshell = 3, pikapsy = 4, rocket = 5, seven = 6 }
local RSE_INDEX = { cherry = 0, topbot = 1, replay = 2, lotad = 3, azurill = 4, power = 5, mixed7 = 6, red7 = 7, blue7 = 8 }
local GEN1_KEY = { seven = "7", bar = "BAR", cherry = "CHERRY", mouse = "MOUSE", fish = "FISH", bird = "BIRD" }

local function family(p)
  local ver = p.version
  local gen = p.generation
  if gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal" then return "gen2" end
  if ver == "ruby" or ver == "sapphire" or ver == "emerald" then return "rse" end
  if ver == "firered" or ver == "leafgreen" or gen == 3 then return "frlg" end
  return "gen1"
end

function M.rows(S)
  return ROWS[family(S)]
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not S.project then return y end
  local rows = M.rows(S)
  if not rows then return y end
  Kit.caption(x, y, "SLOT PAYOUTS")
  y = y + 22 * s
  local g = S.project.slotPayouts
  for i, row in ipairs(rows) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(0, math.min(9999, math.floor(
      require("RegList").num(App, "slot_pay_" .. row[1], x + 220 * s, y, 80 * s, 28 * s, shown))))
    if v ~= shown then
      require("State").ensureProjectFields(S.project)
      S.project.slotPayouts = S.project.slotPayouts or {}
      S.project.slotPayouts[row[1]] = (v == row[3]) and nil or v
      if not next(S.project.slotPayouts) then S.project.slotPayouts = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

local function take(bag, key)
  local n = tonumber(bag[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < 0 then n = 0 end
  if n > 9999 then n = 9999 end
  return n
end

function M.emit(p, encode, out)
  local g = p.slotPayouts
  if type(g) ~= "table" then return end
  local which = family(p)
  local lines = {}
  if which == "gen1" then
    lines[#lines + 1] = "    local SlotMachine = require(\"src.ui.SlotMachine\")"
    for _, row in ipairs(ROWS.gen1) do
      local n = take(g, row[1])
      if n ~= nil then
        lines[#lines + 1] = string.format("    SlotMachine.PAYOUTS[%q] = %d", GEN1_KEY[row[1]], n)
      end
    end
  elseif which == "gen2" then
    lines[#lines + 1] = "    local SlotMachine = require(\"src.ui.gen2.SlotMachine\")"
    for _, row in ipairs(ROWS.gen2) do
      local n = take(g, row[1])
      if n ~= nil then
        lines[#lines + 1] = string.format("    SlotMachine.PAYOUTS[%d] = %d", GEN2_INDEX[row[1]], n)
      end
    end
  elseif which == "frlg" then
    lines[#lines + 1] = "    local SlotMachine = require(\"src.core.game3.slot_machine\")"
    for _, row in ipairs(ROWS.frlg) do
      local n = take(g, row[1])
      if n ~= nil then
        lines[#lines + 1] = string.format("    SlotMachine.PAYOUT_TABLE[%d] = %d", FRLG_INDEX[row[1]], n)
      end
    end
  else
    lines[#lines + 1] = "    local Slots = require(\"src.core.game3.rse.slot_machine\")"
    lines[#lines + 1] = "    Slots.PAYOUTS = Slots.PAYOUTS or {}"
    local any = false
    for _, row in ipairs(ROWS.rse) do
      local n = take(g, row[1])
      if n ~= nil then
        any = true
        lines[#lines + 1] = string.format("    Slots.PAYOUTS[%d] = %d", RSE_INDEX[row[1]], n)
      end
    end
    if not any then return end
  end
  if #lines < 2 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
