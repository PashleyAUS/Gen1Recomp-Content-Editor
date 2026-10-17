-- Writes the wallet and coin ceilings into the mod the runtime reads.

local M = {}

function M.emit(p, encode, out)
  local c = p.constants
  if type(c) ~= "table" then return end
  local function take(key, default)
    local n = tonumber(c[key])
    if n == nil then return nil end
    n = math.floor(n)
    if n < 0 then n = 0 end
    if n > 99999999 then n = 99999999 end
    if n == default then return nil end
    return n
  end
  local money = take("moneyCap", 999999)
  local coins = take("coinCap", 9999)
  if money == nil and coins == nil then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Caps = require(\"src.core.MoneyCaps\")"
  if money ~= nil then out[#out + 1] = "    Caps.MAX_MONEY = " .. money end
  if coins ~= nil then out[#out + 1] = "    Caps.MAX_COINS = " .. coins end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
