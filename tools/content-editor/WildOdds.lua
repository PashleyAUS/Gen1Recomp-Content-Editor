-- Wild held-item chances, and how often a headbutt tree has a Pokémon.
-- Gen 1 has neither. FireRed's item roll is not Hoenn's, and Compound Eyes
-- is an Emerald change on top of the Hoenn roll.

local M = {}

local function shown(bag, key, default)
  if bag and bag[key] ~= nil then return tonumber(bag[key]) or default end
  return default
end

local function write(S, App, key, value, default)
  S.project.wildOdds = S.project.wildOdds or {}
  local bag = S.project.wildOdds
  bag[key] = (value == default) and nil or value
  if not next(bag) then S.project.wildOdds = nil end
  App.markDirty()
end

local function knob(S, App, x, y, key, label, default, minV, maxV)
  local Kit = require("Kit")
  local s = Kit.scale
  Kit.caption(x, y, label)
  local bag = S.project and S.project.wildOdds
  local old = shown(bag, key, default)
  local value = math.floor(math.max(minV, math.min(maxV,
    require("RegList").num(App, "wild_odds_" .. key, x + 280 * s, y, 90 * s, 28 * s, old))))
  if value ~= old then write(S, App, key, value, default) end
  return y + 36 * s
end

function M.draw(S, x, y, w, App)
  local Generation = require("Generation")
  if not S.project then return y end
  if Generation.isGen2(S) then
    y = knob(S, App, x, y, "badGate", "Common tree chance", 1, 0, 255)
    y = knob(S, App, x, y, "goodGate", "Good tree chance", 5, 0, 255)
    y = knob(S, App, x, y, "rareGate", "Rare tree chance", 8, 0, 255)
    y = knob(S, App, x, y, "treeDice", "Tree roll", 10, 1, 65535)
    y = knob(S, App, x, y, "goodBelow", "Good tree below", 5, 0, 256)
    y = knob(S, App, x, y, "coordAdd", "Tree hash offset", 4, 0, 255)
    y = knob(S, App, x, y, "coordDiv", "Tree hash divisor", 5, 1, 65535)
    y = knob(S, App, x, y, "coordMod", "Tree hash width", 10, 1, 256)
    y = knob(S, App, x, y, "coordWrap", "Tree hash wrap", 65536, 1, 65536)
    y = knob(S, App, x, y, "listDice", "Tree list roll", 100, 1, 65535)
    y = knob(S, App, x, y, "rockGate", "Rock chance", 4, 0, 255)
    y = knob(S, App, x, y, "rockDice", "Rock roll", 10, 1, 65535)
    y = knob(S, App, x, y, "rockList", "Rock list roll", 100, 1, 65535)
    y = knob(S, App, x, y, "shakeFrames", "Headbutt shake frames", 32, 0, 255)
    y = knob(S, App, x, y, "shakeByte", "Headbutt shake size", 64, 0, 255)
    y = knob(S, App, x, y, "fishCast", "Fishing cast pause", 40, 0, 255)
    return knob(S, App, x, y, "fishBite", "Fishing bite pause", 40, 0, 255)
  end
  if not Generation.isGen3(S) then return y end
  if Generation.isRse(S) then
    y = knob(S, App, x, y, "none", "No held item below", 45, 0, 255)
    y = knob(S, App, x, y, "rareAt", "Rare held item from", 95, 0, 255)
    y = knob(S, App, x, y, "dice", "Held item roll", 100, 1, 65535)
    if Generation.id(S) == "emerald" then
      y = knob(S, App, x, y, "eyesNone", "Compound Eyes nothing below", 20, 0, 255)
      y = knob(S, App, x, y, "eyesRare", "Compound Eyes rare from", 80, 0, 255)
    end
    return y
  end
  y = knob(S, App, x, y, "bothCommon", "Both items, common below", 50, 0, 255)
  y = knob(S, App, x, y, "bothRare", "Both items, rare below", 55, 0, 255)
  y = knob(S, App, x, y, "onlyCommon", "Only a common item below", 50, 0, 255)
  y = knob(S, App, x, y, "onlyRare", "Only a rare item below", 5, 0, 255)
  return knob(S, App, x, y, "dice", "Held item roll", 100, 1, 65535)
end

local function take(bag, key, minV, maxV)
  local n = tonumber(bag[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

local GEN2_FIELDS = {
  { "badGate", "TREE_BAD_GATE", 0, 255 },
  { "goodGate", "TREE_GOOD_GATE", 0, 255 },
  { "rareGate", "TREE_RARE_GATE", 0, 255 },
  { "treeDice", "TREE_DICE", 1, 65535 },
  { "goodBelow", "TREE_GOOD_BELOW", 0, 256 },
  { "coordAdd", "TREE_COORD_ADD", 0, 255 },
  { "coordDiv", "TREE_COORD_DIV", 1, 65535 },
  { "coordMod", "TREE_COORD_MOD", 1, 256 },
  { "coordWrap", "TREE_COORD_WRAP", 1, 65536 },
  { "listDice", "TREE_LIST_DICE", 1, 65535 },
  { "rockGate", "ROCK_GATE", 0, 255 },
  { "rockDice", "ROCK_DICE", 1, 65535 },
  { "rockList", "ROCK_LIST_DICE", 1, 65535 },
  { "shakeFrames", "HEADBUTT_SHAKE_FRAMES", 0, 255 },
  { "shakeByte", "HEADBUTT_SHAKE_BYTE", 0, 255 },
  { "fishCast", "FISH_CAST_FRAMES", 0, 255 },
  { "fishBite", "FISH_BITE_FRAMES", 0, 255 },
}

local FRLG_FIELDS = {
  { "bothCommon", "HELD_BOTH_COMMON", 0, 255 },
  { "bothRare", "HELD_BOTH_RARE", 0, 255 },
  { "onlyCommon", "HELD_ONLY_COMMON", 0, 255 },
  { "onlyRare", "HELD_ONLY_RARE", 0, 255 },
  { "dice", "HELD_DICE", 1, 65535 },
}

local RSE_FIELDS = {
  { "none", "HELD_NONE", 0, 255 },
  { "rareAt", "HELD_RARE_AT", 0, 255 },
  { "dice", "HELD_DICE", 1, 65535 },
  { "eyesNone", "HELD_EYES_NONE", 0, 255 },
  { "eyesRare", "HELD_EYES_RARE", 0, 255 },
}

function M.emit(p, encode, out)
  local g = p.wildOdds
  if type(g) ~= "table" then return end
  local ver = p.version
  local gen = p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local gen3 = gen == 3 or ver == "firered" or ver == "leafgreen"
    or ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local fields
  local target
  if gen2 then
    fields = GEN2_FIELDS
    target = "src.battle.gen2.Encounter"
  elseif gen3 then
    local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
    fields = rse and RSE_FIELDS or FRLG_FIELDS
    target = "src.core.game3.encounters"
  else
    return
  end
  local lines = {}
  for _, row in ipairs(fields) do
    local n = take(g, row[1], row[3], row[4])
    if n ~= nil then lines[#lines + 1] = { row[2], n } end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Odds = require(\"" .. target .. "\")"
  for _, line in ipairs(lines) do
    out[#out + 1] = "    Odds." .. line[1] .. " = " .. line[2]
  end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
