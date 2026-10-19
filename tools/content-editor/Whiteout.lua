-- How much money a blackout takes. Gen 1, Gen 2, and Hoenn divide the wallet.
-- FireRed and LeafGreen charge the lead's level times a badge multiplier.

local M = {}

local BADGE_DEFAULT = { 2, 4, 6, 9, 12, 16, 20, 25, 30 }

local function bag(S)
  return S.project and S.project.whiteout
end

function M.get(S, key, default)
  local w = bag(S)
  if w and w[key] ~= nil then return w[key] end
  return default
end

function M.set(S, App, key, value, default)
  require("State").ensureProjectFields(S.project)
  S.project.whiteout = S.project.whiteout or {}
  local same = value == default
  if type(value) == "table" and type(default) == "table" then
    same = #value == #default
    if same then
      for i = 1, #value do
        if value[i] ~= default[i] then same = false break end
      end
    end
  end
  S.project.whiteout[key] = same and nil or value
  if not next(S.project.whiteout) then S.project.whiteout = nil end
  App.markDirty()
end

function M.badgeDefault()
  local copy = {}
  for i, n in ipairs(BADGE_DEFAULT) do copy[i] = n end
  return copy
end

local function take(g, key, minV, maxV)
  local n = tonumber(g[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

function M.emit(p, encode, out)
  local g = p.whiteout
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen = ver and require("Generation").num({version=ver}) or p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local frlg = ver == "firered" or ver == "leafgreen"
  local lines = {}
  if frlg then
    local factor = take(g, "levelFactor", 0, 255)
    local mults = g.badgeMult
    if factor == nil and type(mults) ~= "table" then return end
    lines[#lines + 1] = "    local Bridge = require(\"src.core.game3.battle_bridge\")"
    if factor ~= nil then lines[#lines + 1] = "    Bridge.LOSS_LEVEL_FACTOR = " .. factor end
    if type(mults) == "table" then
      local parts = {}
      for i = 1, 9 do
        local n = math.floor(tonumber(mults[i]) or BADGE_DEFAULT[i])
        if n < 0 then n = 0 end
        if n > 9999 then n = 9999 end
        parts[i] = tostring(n)
      end
      lines[#lines + 1] = "    Bridge.BADGE_LOSS_MULT = { " .. table.concat(parts, ", ") .. " }"
    end
  elseif rse or (gen == 3 and not frlg and rse) then
    local div = take(g, "div", 1, 100)
    if div == nil then return end
    lines[#lines + 1] = "    require(\"src.core.game3.battle_bridge\").WHITEOUT_DIV = " .. div
  elseif gen == 3 and not frlg then
    local div = take(g, "div", 1, 100)
    if div == nil then return end
    lines[#lines + 1] = "    require(\"src.core.game3.battle_bridge\").WHITEOUT_DIV = " .. div
  elseif gen2 then
    local div = take(g, "div", 1, 100)
    if div == nil then return end
    lines[#lines + 1] = "    require(\"src.script.gen2.CallAsm\").MONEY_DIV = " .. div
  else
    local div = take(g, "div", 1, 100)
    if div == nil then return end
    lines[#lines + 1] = "    require(\"src.world.OverworldController\").BLACKOUT_DIV = " .. div
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
