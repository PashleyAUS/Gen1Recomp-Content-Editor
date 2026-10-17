-- Overworld poison: how many steps between ticks, and how much HP each tick takes.
-- 0 steps means poison never ticks. 0 damage ticks without taking HP.

local M = {}

function M.get(S, key, default)
  local g = S.project and S.project.poisonField
  if g and g[key] ~= nil then return g[key] end
  return default
end

function M.set(S, App, key, value, default)
  require("State").ensureProjectFields(S.project)
  S.project.poisonField = S.project.poisonField or {}
  S.project.poisonField[key] = (value == default) and nil or value
  if not next(S.project.poisonField) then S.project.poisonField = nil end
  App.markDirty()
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
  local g = p.poisonField
  if type(g) ~= "table" then return end
  local interval = take(g, "interval", 0, 255)
  local damage = take(g, "damage", 0, 255)
  local flash = take(g, "flash", 0, 255)
  if interval == nil and damage == nil and flash == nil then return end
  local ver = p.version
  local gen = p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local gen3 = gen == 3 or ver == "ruby" or ver == "sapphire" or ver == "emerald"
    or ver == "firered" or ver == "leafgreen"
  local target
  local periodName
  local damageName
  if gen3 then
    target = "src.core.game3.step_events"
    periodName = "POISON_PERIOD"
    damageName = "POISON_DAMAGE"
  elseif gen2 then
    target = "src.world.gen2.StepEvents"
    periodName = "POISON_PERIOD"
    damageName = "POISON_DAMAGE"
  else
    target = "src.world.OverworldController"
    periodName = "POISON_INTERVAL"
    damageName = "POISON_DAMAGE"
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Poison = require(\"" .. target .. "\")"
  if interval ~= nil then out[#out + 1] = "    Poison." .. periodName .. " = " .. interval end
  if damage ~= nil then out[#out + 1] = "    Poison." .. damageName .. " = " .. damage end
  if flash ~= nil and gen2 then
    out[#out + 1] = "    require(\"src.world.gen2.World\").POISON_FLASH = " .. flash
  elseif flash ~= nil then
    out[#out + 1] = "    Poison.POISON_FLASH = " .. flash
  end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
