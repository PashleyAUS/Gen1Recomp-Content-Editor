-- Steps after a battle before another wild encounter can start.
-- Each generation keeps its own cart formula.

local M = {}

local function shown(bag, key, default)
  if bag and bag[key] ~= nil then return tonumber(bag[key]) or default end
  return default
end

local function write(S, App, key, value, default)
  S.project.encounterGrace = S.project.encounterGrace or {}
  local bag = S.project.encounterGrace
  bag[key] = (value == default) and nil or value
  if not next(bag) then S.project.encounterGrace = nil end
  App.markDirty()
end

local function knob(S, App, x, y, w, key, label, default, minV, maxV)
  local Kit = require("Kit")
  local s = Kit.scale
  Kit.caption(x, y, label)
  local bag = S.project and S.project.encounterGrace
  local old = shown(bag, key, default)
  local value = math.floor(math.max(minV, math.min(maxV,
    require("RegList").num(App, "enc_grace_" .. key, x + 280 * s, y, 90 * s, 28 * s, old))))
  if value ~= old then write(S, App, key, value, default) end
  return y + 36 * s
end

function M.draw(S, x, y, w, App)
  local Generation = require("Generation")
  local Kit = require("Kit")
  if not S.project then return y end
  if Generation.isGen3(S) then
    if Generation.isRse(S) then
      return knob(S, App, x, y, w, "steps", "Steps after an encounter", 4, 0, 255)
    end
    y = knob(S, App, x, y, w, "freeAt", "No wait at this rate", 80, 0, 255)
    y = knob(S, App, x, y, w, "maxWait", "Longest wait", 8, 0, 255)
    y = knob(S, App, x, y, w, "band", "Rate band", 10, 1, 255)
    return knob(S, App, x, y, w, "leak", "Chance during the wait", 5, 0, 100)
  end
  if Generation.isGen2(S) then
    return knob(S, App, x, y, w, "steps", "Wild cooldown", 5, 0, 255)
  end
  return knob(S, App, x, y, w, "steps", "Steps after a wild battle", 3, 0, 255)
end

local function take(bag, key, minV, maxV)
  local n = tonumber(bag[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

function M.emit(p, encode, out)
  local g = p.encounterGrace
  if type(g) ~= "table" then return end
  local ver = p.version
  local gen = p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local gen3 = gen == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local lines = {}
  if gen3 and rse then
    local steps = take(g, "steps", 0, 255)
    if steps == nil then return end
    lines[#lines + 1] = "    require(\"src.core.game3.encounters\").IMMUNITY_STEPS = " .. steps
  elseif gen3 then
    local freeAt = take(g, "freeAt", 0, 255)
    local maxWait = take(g, "maxWait", 0, 255)
    local band = take(g, "band", 1, 255)
    local leak = take(g, "leak", 0, 100)
    if freeAt == nil and maxWait == nil and band == nil and leak == nil then return end
    lines[#lines + 1] = "    local Encounters = require(\"src.core.game3.encounters\")"
    if freeAt ~= nil then lines[#lines + 1] = "    Encounters.COOLDOWN_FREE_AT = " .. freeAt end
    if maxWait ~= nil then lines[#lines + 1] = "    Encounters.COOLDOWN_MAX = " .. maxWait end
    if band ~= nil then lines[#lines + 1] = "    Encounters.COOLDOWN_BAND = " .. band end
    if leak ~= nil then lines[#lines + 1] = "    Encounters.COOLDOWN_LEAK = " .. leak end
  elseif gen2 then
    local steps = take(g, "steps", 0, 255)
    if steps == nil then return end
    lines[#lines + 1] = "    require(\"src.world.gen2.World\").WILD_COOLDOWN = " .. steps
  else
    local steps = take(g, "steps", 0, 255)
    if steps == nil then return end
    lines[#lines + 1] = "    require(\"src.world.OverworldController\").WILD_GRACE = " .. steps
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
