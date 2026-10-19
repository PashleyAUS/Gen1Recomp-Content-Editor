-- Which encounter slot a roll lands in.
-- Gen 1's Good and Super Rods miss on an odd byte, then pick among four.
-- Gen 2 grass and water use cumulative percents. Fishing rolls out of 256.
-- Gen 3 land and water use weights. Each rod has its own cumulative bands.
-- FireRed's fishing slots are numbered from 1. Hoenn's are numbered from 0.
-- The editor stores the band cuts; the slot numbers stay with the cart.

local M = {}

local GRASS = { 30, 60, 80, 90, 95, 99, 100 }
local WATER2 = { 60, 90, 100 }
local LAND = { 20, 20, 10, 10, 10, 10, 5, 5, 4, 4, 1, 1 }
local WATER3 = { 60, 30, 5, 4, 1 }
local OLD = { 70, 100 }
local GOOD = { 60, 80, 100 }
local SUPER = { 40, 80, 95, 99, 100 }

local function shown(bag, key, default)
  local value = bag and bag[key]
  if type(default) == "table" then
    if type(value) == "table" then return table.concat(value, ", ") end
    return table.concat(default, ", ")
  end
  if value ~= nil then return tonumber(value) or default end
  return default
end

local function sameList(a, b)
  if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then return false end
  for i = 1, #a do
    if a[i] ~= b[i] then return false end
  end
  return true
end

local function write(S, App, key, value, default)
  S.project.encounterSlots = S.project.encounterSlots or {}
  local bag = S.project.encounterSlots
  local same = value == default or sameList(value, default)
  bag[key] = same and nil or value
  if not next(bag) then S.project.encounterSlots = nil end
  App.markDirty()
end

local function parseList(text, count, defaults)
  local nums = {}
  for part in tostring(text):gmatch("[^,]+") do
    local n = tonumber(part)
    if n then
      n = math.floor(n)
      if n < 0 then n = 0 end
      if n > 65535 then n = 65535 end
      nums[#nums + 1] = n
    end
  end
  while #nums < count do nums[#nums + 1] = defaults[#nums + 1] or 0 end
  while #nums > count do nums[#nums] = nil end
  return nums
end

local function num(S, App, x, y, key, label, default, minV, maxV)
  local Kit = require("Kit")
  local s = Kit.scale
  Kit.caption(x, y, label)
  local bag = S.project and S.project.encounterSlots
  local old = shown(bag, key, default)
  local value = math.floor(math.max(minV, math.min(maxV,
    require("RegList").num(App, "enc_slot_" .. key, x + 280 * s, y, 90 * s, 28 * s, old))))
  if value ~= old then write(S, App, key, value, default) end
  return y + 36 * s
end

local function csv(S, App, x, y, w, key, label, defaults)
  local Kit = require("Kit")
  local s = Kit.scale
  Kit.caption(x, y, label)
  local bag = S.project and S.project.encounterSlots
  local old = shown(bag, key, defaults)
  local value = require("RegList").field(App, "enc_slot_" .. key, x + 280 * s, y, math.max(120 * s, w - 300 * s), 28 * s, old, old)
  if value ~= old then
    write(S, App, key, parseList(value, #defaults, defaults), defaults)
  end
  return y + 36 * s
end

function M.draw(S, x, y, w, App)
  local Generation = require("Generation")
  if not S.project then return y end
  if Generation.isGen2(S) then
    y = csv(S, App, x, y, w, "grass", "Grass slot percents", GRASS)
    y = csv(S, App, x, y, w, "water", "Water slot percents", WATER2)
    y = num(S, App, x, y, "slotDice", "Slot roll", 100, 1, 65535)
    return num(S, App, x, y, "fishDice", "Fishing roll", 256, 1, 65535)
  end
  if Generation.isGen3(S) then
    y = csv(S, App, x, y, w, "land", "Grass slot weights", LAND)
    y = csv(S, App, x, y, w, "water", "Water slot weights", WATER3)
    y = num(S, App, x, y, "fishTotal", "Fishing roll", 100, 1, 65535)
    y = csv(S, App, x, y, w, "old", "Old Rod bands", OLD)
    y = csv(S, App, x, y, w, "good", "Good Rod bands", GOOD)
    return csv(S, App, x, y, w, "super", "Super Rod bands", SUPER)
  end
  y = num(S, App, x, y, "biteMod", "Rod miss modulus", 2, 0, 255)
  y = num(S, App, x, y, "slotSpan", "Rod slot span", 4, 1, 16)
  y = num(S, App, x, y, "fishRoll", "Rod roll", 256, 1, 65535)
  y = num(S, App, x, y, "rodUsed", "Rod use pause", 80, 0, 255)
  y = num(S, App, x, y, "rodCast", "Rod cast pause", 10, 0, 255)
  y = num(S, App, x, y, "rodWait", "Rod wait", 100, 0, 255)
  y = num(S, App, x, y, "rodShake", "Rod shake", 30, 0, 255)
  y = num(S, App, x, y, "rodShakeStep", "Rod shake step", 3, 1, 255)
  return num(S, App, x, y, "rodBubble", "Rod bubble", 60, 0, 255)
end

local function take(bag, key, minV, maxV)
  local n = tonumber(bag[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

local function takeList(bag, key, count)
  local list = bag[key]
  if type(list) ~= "table" then return nil end
  local out = {}
  for i = 1, count do
    local n = math.floor(tonumber(list[i]) or 0)
    if n < 0 then n = 0 end
    if n > 65535 then n = 65535 end
    out[i] = n
  end
  return "{ " .. table.concat(out, ", ") .. " }"
end

function M.emit(p, encode, out)
  local g = p.encounterSlots
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen = ver and require("Generation").num({version=ver}) or p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local gen3 = gen == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local lines = {}
  if gen2 then
    local grass = takeList(g, "grass", 7)
    local water = takeList(g, "water", 3)
    local slotDice = take(g, "slotDice", 1, 65535)
    local fishDice = take(g, "fishDice", 1, 65535)
    if not grass and not water and slotDice == nil and fishDice == nil then return end
    lines[#lines + 1] = "    local Encounter = require(\"src.battle.gen2.Encounter\")"
    if grass then lines[#lines + 1] = "    Encounter.GRASS_SLOT_CHANCES = " .. grass end
    if water then lines[#lines + 1] = "    Encounter.WATER_SLOT_CHANCES = " .. water end
    if slotDice ~= nil then lines[#lines + 1] = "    Encounter.SLOT_DICE = " .. slotDice end
    if fishDice ~= nil then lines[#lines + 1] = "    Encounter.FISH_DICE = " .. fishDice end
  elseif gen3 then
    local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
    local prefix = rse and "RSE_FISH_" or "FRLG_FISH_"
    local land = takeList(g, "land", 12)
    local water = takeList(g, "water", 5)
    local fishTotal = take(g, "fishTotal", 1, 65535)
    local old = takeList(g, "old", 2)
    local good = takeList(g, "good", 3)
    local super = takeList(g, "super", 5)
    if not land and not water and fishTotal == nil and not old and not good and not super then return end
    lines[#lines + 1] = "    local Encounters = require(\"src.core.game3.encounters\")"
    if land then lines[#lines + 1] = "    Encounters.LAND_WEIGHTS = " .. land end
    if water then lines[#lines + 1] = "    Encounters.WATER_WEIGHTS = " .. water end
    if fishTotal ~= nil then lines[#lines + 1] = "    Encounters.FISH_TOTAL = " .. fishTotal end
    if old then lines[#lines + 1] = "    Encounters." .. prefix .. "OLD = " .. old end
    if good then lines[#lines + 1] = "    Encounters." .. prefix .. "GOOD = " .. good end
    if super then lines[#lines + 1] = "    Encounters." .. prefix .. "SUPER = " .. super end
  else
    local biteMod = take(g, "biteMod", 0, 255)
    local slotSpan = take(g, "slotSpan", 1, 16)
    local fishRoll = take(g, "fishRoll", 1, 65535)
    local rodUsed = take(g, "rodUsed", 0, 255)
    local rodCast = take(g, "rodCast", 0, 255)
    local rodWait = take(g, "rodWait", 0, 255)
    local rodShake = take(g, "rodShake", 0, 255)
    local rodStep = take(g, "rodShakeStep", 1, 255)
    local rodBubble = take(g, "rodBubble", 0, 255)
    local rod = rodUsed ~= nil or rodCast ~= nil or rodWait ~= nil
      or rodShake ~= nil or rodStep ~= nil or rodBubble ~= nil
    if biteMod == nil and slotSpan == nil and fishRoll == nil and not rod then return end
    lines[#lines + 1] = "    local World = require(\"src.world.OverworldController\")"
    if biteMod ~= nil then lines[#lines + 1] = "    World.FISH_BITE_MOD = " .. biteMod end
    if slotSpan ~= nil then lines[#lines + 1] = "    World.FISH_SLOT_SPAN = " .. slotSpan end
    if fishRoll ~= nil then lines[#lines + 1] = "    World.FISH_ROLL = " .. fishRoll end
    if rod then
      lines[#lines + 1] = "    World.FISH_ANIM = World.FISH_ANIM or {}"
      if rodUsed ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.used = " .. rodUsed end
      if rodCast ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.cast = " .. rodCast end
      if rodWait ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.wait = " .. rodWait end
      if rodShake ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.shake = " .. rodShake end
      if rodStep ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.shakeStep = " .. rodStep end
      if rodBubble ~= nil then lines[#lines + 1] = "    World.FISH_ANIM.bubble = " .. rodBubble end
    end
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
