-- Cuts applied to a wild encounter rate after the map's own number.
-- Gen 1 rolls the map rate as it is. Gen 2 changes it for the radio and a
-- Cleanse Tag. Gen 3 changes it for the bike, flutes, Cleanse Tag, and abilities.
-- FireRed's dice tops out at 1600. Hoenn's tops out at 2880.

local M = {}

local function shown(bag, key, default)
  if bag and bag[key] ~= nil then return tonumber(bag[key]) or default end
  return default
end

local function write(S, App, key, value, default)
  S.project.encounterRate = S.project.encounterRate or {}
  local bag = S.project.encounterRate
  bag[key] = (value == default) and nil or value
  if not next(bag) then S.project.encounterRate = nil end
  App.markDirty()
end

local function knob(S, App, x, y, key, label, default, minV, maxV)
  local Kit = require("Kit")
  local s = Kit.scale
  Kit.caption(x, y, label)
  local bag = S.project and S.project.encounterRate
  local old = shown(bag, key, default)
  local value = math.floor(math.max(minV, math.min(maxV,
    require("RegList").num(App, "enc_rate_" .. key, x + 280 * s, y, 90 * s, 28 * s, old))))
  if value ~= old then write(S, App, key, value, default) end
  return y + 36 * s
end

function M.draw(S, x, y, w, App)
  local Generation = require("Generation")
  if not S.project then return y end
  if Generation.isGen2(S) then
    y = knob(S, App, x, y, "musicDouble", "Radio double", 2, 0, 16)
    y = knob(S, App, x, y, "musicHalf", "Radio half", 2, 1, 256)
    y = knob(S, App, x, y, "cleanseDiv", "Cleanse Tag divisor", 2, 1, 256)
    return knob(S, App, x, y, "rateDice", "Encounter roll", 256, 1, 65535)
  end
  if not Generation.isGen3(S) then
    return knob(S, App, x, y, "rateDice", "Encounter roll", 256, 1, 65535)
  end
  local maxDefault = Generation.isRse(S) and 2880 or 1600
  y = knob(S, App, x, y, "rateScale", "Rate scale", 16, 0, 256)
  y = knob(S, App, x, y, "bikeNum", "Bike percent", 80, 0, 1000)
  y = knob(S, App, x, y, "bikeDen", "Bike percent of", 100, 1, 10000)
  y = knob(S, App, x, y, "fluteUp", "White Flute divisor", 2, 1, 256)
  y = knob(S, App, x, y, "fluteDown", "Black Flute divisor", 2, 1, 256)
  y = knob(S, App, x, y, "cleanseNum", "Cleanse Tag share", 2, 0, 1000)
  y = knob(S, App, x, y, "cleanseDen", "Cleanse Tag of", 3, 1, 10000)
  y = knob(S, App, x, y, "stenchDiv", "Stench divisor", 2, 1, 256)
  y = knob(S, App, x, y, "illuminate", "Illuminate multiplier", 2, 0, 16)
  y = knob(S, App, x, y, "maxRate", "Encounter dice", maxDefault, 1, 65535)
  y = knob(S, App, x, y, "newTile", "New tile chance", 60, 0, 65535)
  y = knob(S, App, x, y, "newTileDice", "New tile roll", 100, 1, 65535)
  if Generation.id(S) == "emerald" then
    y = knob(S, App, x, y, "whiteSmoke", "White Smoke divisor", 2, 1, 256)
    y = knob(S, App, x, y, "arenaTrap", "Arena Trap multiplier", 2, 0, 16)
    y = knob(S, App, x, y, "sandVeil", "Sand Veil divisor", 2, 1, 256)
    y = knob(S, App, x, y, "pyramidNum", "Pyramid Stench share", 3, 0, 1000)
    y = knob(S, App, x, y, "pyramidDen", "Pyramid Stench of", 4, 1, 10000)
  end
  return y
end

local function take(bag, key, minV, maxV)
  local n = tonumber(bag[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

local GEN3_FIELDS = {
  { "rateScale", "RATE_SCALE", 0, 256 },
  { "bikeNum", "BIKE_NUM", 0, 1000 },
  { "bikeDen", "BIKE_DEN", 1, 10000 },
  { "fluteUp", "FLUTE_UP_DIV", 1, 256 },
  { "fluteDown", "FLUTE_DOWN_DIV", 1, 256 },
  { "cleanseNum", "CLEANSE_NUM", 0, 1000 },
  { "cleanseDen", "CLEANSE_DEN", 1, 10000 },
  { "stenchDiv", "STENCH_DIV", 1, 256 },
  { "illuminate", "ILLUMINATE_MULT", 0, 16 },
  { "whiteSmoke", "WHITE_SMOKE_DIV", 1, 256 },
  { "arenaTrap", "ARENA_TRAP_MULT", 0, 16 },
  { "sandVeil", "SAND_VEIL_DIV", 1, 256 },
  { "pyramidNum", "PYRAMID_STENCH_NUM", 0, 1000 },
  { "pyramidDen", "PYRAMID_STENCH_DEN", 1, 10000 },
  { "newTile", "NEW_TILE_CHANCE", 0, 65535 },
  { "newTileDice", "NEW_TILE_DICE", 1, 65535 },
}

function M.emit(p, encode, out)
  local g = p.encounterRate
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen = ver and require("Generation").num({version=ver}) or p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local gen3 = gen == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local lines = {}
  if gen2 then
    local musicDouble = take(g, "musicDouble", 0, 16)
    local musicHalf = take(g, "musicHalf", 1, 256)
    local cleanseDiv = take(g, "cleanseDiv", 1, 256)
    local rateDice = take(g, "rateDice", 1, 65535)
    if musicDouble == nil and musicHalf == nil and cleanseDiv == nil and rateDice == nil then return end
    lines[#lines + 1] = "    local World = require(\"src.world.gen2.World\")"
    if musicDouble ~= nil then lines[#lines + 1] = "    World.MUSIC_DOUBLE = " .. musicDouble end
    if musicHalf ~= nil then lines[#lines + 1] = "    World.MUSIC_HALF_DIV = " .. musicHalf end
    if cleanseDiv ~= nil then lines[#lines + 1] = "    World.CLEANSE_DIV = " .. cleanseDiv end
    if rateDice ~= nil then
      lines[#lines + 1] = "    local Encounter = require(\"src.battle.gen2.Encounter\")"
      lines[#lines + 1] = "    Encounter.RATE_DICE = " .. rateDice
    end
  elseif gen == 1 or ver == "red" or ver == "blue" or ver == "yellow" then
    local rateDice = take(g, "rateDice", 1, 65535)
    if rateDice == nil then return end
    lines[#lines + 1] = "    local Encounter = require(\"src.world.Encounter\")"
    lines[#lines + 1] = "    Encounter.RATE_DICE = " .. rateDice
  elseif gen3 then
    local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
    local maxRate = take(g, "maxRate", 1, 65535)
    local any = maxRate ~= nil
    if not any then
      for _, row in ipairs(GEN3_FIELDS) do
        if take(g, row[1], row[3], row[4]) ~= nil then any = true break end
      end
    end
    if not any then return end
    lines[#lines + 1] = "    local Encounters = require(\"src.core.game3.encounters\")"
    for _, row in ipairs(GEN3_FIELDS) do
      local n = take(g, row[1], row[3], row[4])
      if n ~= nil then lines[#lines + 1] = "    Encounters." .. row[2] .. " = " .. n end
    end
    if maxRate ~= nil then
      local field = rse and "RSE_MAX_RATE" or "FRLG_MAX_RATE"
      lines[#lines + 1] = "    Encounters." .. field .. " = " .. maxRate
    end
  else
    return
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
