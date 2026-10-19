-- When morning, day, and night start. Gold, Silver, and Crystal share
-- the clock. The hours also decide Oak's clock-set line and which
-- phone contacts are awake.

local M = {}

local function shown(bag, key, default)
  if bag and bag[key] ~= nil then return tonumber(bag[key]) or default end
  return default
end

local function write(S, App, key, value, default)
  S.project.gen2Clock = S.project.gen2Clock or {}
  local bag = S.project.gen2Clock
  bag[key] = (value == default) and nil or value
  if not next(bag) then S.project.gen2Clock = nil end
  App.markDirty()
end

function M.draw(S, x, y, w, App)
  local Generation = require("Generation")
  if not S.project or not Generation.isGen2(S) then return y end
  local Kit = require("Kit")
  local s = Kit.scale
  local rows = {
    { "morn", "Morning starts at", 4 },
    { "day", "Day starts at", 10 },
    { "nite", "Night starts at", 18 },
  }
  for _, row in ipairs(rows) do
    Kit.caption(x, y, row[2])
    local bag = S.project.gen2Clock
    local old = shown(bag, row[1], row[3])
    local value = math.floor(math.max(0, math.min(24, require("RegList").num(
      App, "gen2_clock_" .. row[1], x + 280 * s, y, 90 * s, 28 * s, old))))
    if value ~= old then write(S, App, row[1], value, row[3]) end
    y = y + 36 * s
  end
  return y
end

local FIELDS = {
  { "morn", "MORN_HOUR", 0, 24 },
  { "day", "DAY_HOUR", 0, 24 },
  { "nite", "NITE_HOUR", 0, 24 },
}

function M.emit(p, encode, out)
  local g = p.gen2Clock
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen = ver and require("Generation").num({version=ver}) or p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  if not gen2 then return end
  local lines = {}
  for _, row in ipairs(FIELDS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(row[3], math.min(row[4], math.floor(n)))
      lines[#lines + 1] = "    Palettes." .. row[2] .. " = " .. n
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Palettes = require(\"src.world.gen2.Palettes\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
