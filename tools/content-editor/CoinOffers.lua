-- The Game Corner sells 50 coins for ¥1000 and 500 coins for ¥10000.
-- 0 coins is an empty pack. 0 cost is free.
-- Gold, Silver, and Crystal share this counter. The other games buy coins from scripts.

local M = {}
local ROWS = {
  { "small", "smallCost", "Small pack", "Small price", 50, 1000 },
  { "large", "largeCost", "Large pack", "Large price", 500, 10000 },
}

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  if not require("Generation").isGen2(S) or not S.project then return y end
  Kit.caption(x, y, "COIN PACKS")
  y = y + 22 * s
  local g = S.project.coinOffers
  for _, row in ipairs(ROWS) do
    local coins = g and g[row[1]]
    if coins == nil then coins = row[5] end
    local price = g and g[row[2]]
    if price == nil then price = row[6] end
    Kit.text("small", row[3], x, y + 4 * s, require("Theme").PAL.caption)
    local c = math.max(0, math.min(9999, math.floor(
      require("RegList").num(App, "coin_" .. row[1], x + 140 * s, y, 70 * s, 28 * s, coins))))
    Kit.text("small", row[4], x + 230 * s, y + 4 * s, require("Theme").PAL.caption)
    local p = math.max(0, math.min(999999, math.floor(
      require("RegList").num(App, "coin_" .. row[2], x + 340 * s, y, 90 * s, 28 * s, price))))
    if c ~= coins or p ~= price then
      require("State").ensureProjectFields(S.project)
      S.project.coinOffers = S.project.coinOffers or {}
      S.project.coinOffers[row[1]] = (c == row[5]) and nil or c
      S.project.coinOffers[row[2]] = (p == row[6]) and nil or p
      if not next(S.project.coinOffers) then S.project.coinOffers = nil end
      App.markDirty()
    end
    y = y + 34 * s
  end
  return y
end

function M.emit(p, encode, out)
  local g = p.coinOffers
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen2 = p.generation == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  if not gen2 then return end
  local lines = {}
  local packs = {
    { 1, "small", "smallCost", 50, 1000 },
    { 2, "large", "largeCost", 500, 10000 },
  }
  for _, row in ipairs(packs) do
    local amount = tonumber(g[row[2]])
    local cost = tonumber(g[row[3]])
    if amount ~= nil or cost ~= nil then
      if amount == nil then amount = row[4] end
      if cost == nil then cost = row[5] end
      amount = math.max(0, math.min(9999, math.floor(amount)))
      cost = math.max(0, math.min(999999, math.floor(cost)))
      lines[#lines + 1] = string.format(
        "    PrizeMenu.COIN_OFFERS[%d] = { amount = %d, cost = %d }", row[1], amount, cost)
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local PrizeMenu = require(\"src.ui.gen2.PrizeMenu\")"
  out[#out + 1] = "    PrizeMenu.COIN_OFFERS = PrizeMenu.COIN_OFFERS or {}"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "    PrizeMenu.applyCoinOffers()"
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
