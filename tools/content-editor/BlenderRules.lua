-- The Berry Blender turns top speed into Pokéblock flavor.
-- floor(speed / divisor) plus the base. A flavor above the gold line is gold.
-- A press inside the hit window scores. The perfect window is a slice of it.
-- A width of 0 never scores that hit. A blend length of 0 finishes immediately.
-- Ruby, Sapphire, and Emerald share the blender. The other games do not have it.

local M = {}
local ROWS = {
  { "rpmDiv", "Speed divisor", 333, 1, 65535 },
  { "rpmAdd", "Flavor base", 100, 0, 9999 },
  { "goldAt", "Gold above", 50, 0, 255 },
  { "roundAbove", "Round up above", 4, 0, 9 },
  { "hitSpan", "Hit window", 48, 0, 256 },
  { "bestFrom", "Perfect starts", 20, 0, 256 },
  { "bestSpan", "Perfect width", 8, 0, 256 },
  { "progressCap", "Blend length", 1000, 0, 65535 },
  { "bestGain", "Perfect progress divisor", 55, 1, 255 },
  { "goodGain", "Good progress divisor", 70, 1, 255 },
  { "speedFast", "Fast speed at", 1500, 0, 65535 },
  { "bestSlow", "Perfect speed, slow", 384, 0, 65535 },
  { "bestFast", "Perfect speed, fast", 128, 0, 65535 },
  { "goodSpeed", "Good speed", 256, 0, 65535 },
  { "missSpeed", "Miss slows by", 256, 0, 65535 },
  { "minSpeed", "Slowest arrow", 128, 0, 65535 },
  { "slowEvery", "Arrow coasts after", 5, 0, 255 },
  { "fallDrop", "Drop distance", 22528, 0, 65535 },
  { "fallStep", "Drop step", 512, 0, 65535 },
  { "div1", "1 player divisor", 1, 1, 255 },
  { "div2", "2 player divisor", 2, 1, 255 },
  { "div3", "3 player divisor", 3, 1, 255 },
  { "div4", "4 player divisor", 4, 1, 255 },
}
local FIELD = {
  rpmDiv = "RPM_DIV", rpmAdd = "RPM_ADD", goldAt = "GOLD_AT", roundAbove = "ROUND_ABOVE",
  hitSpan = "HIT_SPAN", bestFrom = "BEST_FROM", bestSpan = "BEST_SPAN",
  progressCap = "MAX_PROGRESS_BAR", bestGain = "BEST_GAIN_DIV", goodGain = "GOOD_GAIN_DIV",
  speedFast = "SPEED_FAST", bestSlow = "SPEED_BEST_SLOW", bestFast = "SPEED_BEST_FAST",
  goodSpeed = "SPEED_GOOD", missSpeed = "SPEED_MISS", minSpeed = "MIN_ARROW_SPEED",
  slowEvery = "SLOWDOWN_AT", fallDrop = "ARROW_FALL_ROTATION", fallStep = "FALL_STEP",
}
local DIV = { div1 = 1, div2 = 2, div3 = 3, div4 = 4 }

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isRse(S) or not S.project then return y end
  Kit.caption(x, y, "BERRY BLENDER")
  y = y + 22 * s
  local g = S.project.gen3Blender
  for _, row in ipairs(ROWS) do
    local shown = g and g[row[1]]
    if shown == nil then shown = row[3] end
    Kit.text("small", row[2], x, y + 4 * s, require("Theme").PAL.caption)
    local v = math.max(row[4], math.min(row[5], math.floor(
      require("RegList").num(App, "blend_" .. row[1], x + 220 * s, y, 80 * s, 28 * s, shown))))
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
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  if ver ~= "ruby" and ver ~= "sapphire" and ver ~= "emerald" then return end
  local lines = {}
  for _, row in ipairs(ROWS) do
    local n = tonumber(g[row[1]])
    if n ~= nil then
      n = math.max(row[4], math.min(row[5], math.floor(n)))
      if DIV[row[1]] then
        lines[#lines + 1] = string.format("    Blender.SPEED_DIV[%d] = %d", DIV[row[1]], n)
      else
        lines[#lines + 1] = string.format("    Blender.%s = %d", FIELD[row[1]], n)
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
