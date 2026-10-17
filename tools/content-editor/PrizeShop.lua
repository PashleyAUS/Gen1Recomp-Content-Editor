-- Game Corner prize prices for Gold, Silver, and Crystal.
-- Buena's Blue Card prices are Crystal only. 0 coins or 0 points is free.

local M = {}

local COUNTERS = {
  { id = "CELADON_TM", label = "Celadon TMs", rows = {
    { "TM32", 1500 }, { "TM29", 3500 }, { "TM15", 7500 },
  }},
  { id = "CELADON_MON", label = "Celadon Pokémon", rows = {
    { "Mr. Mime", 3333, 15 }, { "Eevee", 6666, 15 }, { "Porygon", 9999, 20 },
  }},
  { id = "GOLDENROD_TM", label = "Goldenrod TMs", rows = {
    { "TM25", 5500 }, { "TM14", 5500 }, { "TM38", 5500 },
  }},
  { id = "GOLDENROD_MON", label = "Goldenrod Pokémon", rows = {
    { "Abra", 200, 10 }, { "Ekans", 700, 10 }, { "Dratini", 2100, 10 },
  }},
}

local BUENA = {
  { "Ultra Ball", 2 }, { "Full Restore", 2 }, { "Nugget", 3 },
  { "Rare Candy", 3 }, { "Protein", 5 }, { "Iron", 5 },
  { "Carbos", 5 }, { "Calcium", 5 }, { "HP Up", 5 },
}

local function gen2(p)
  local ver = p and p.version
  return p and (p.generation == 2 or ver == "gold" or ver == "silver" or ver == "crystal")
end

local function crystal(p)
  return p and (p.version == "crystal")
end

local function storeCell(bag, key, index, value, default)
  bag[key] = bag[key] or {}
  bag[key][index] = value == default and nil or value
  if not next(bag[key]) then bag[key] = nil end
end

function M.draw(S, App, viewX, fy, fh, s)
  local Kit = require("Kit")
  local PAL = require("Theme").PAL
  local Generation = require("Generation")
  if not Generation.isGen2(S) then return fy end
  fy = fy + 16 * s
  Kit.caption(viewX, fy, "GAME CORNER PRIZES")
  fy = fy + 22 * s
  Kit.text("micro", "Coins for each prize. 0 is free. A prize Pokémon also has the level it arrives at.",
    viewX, fy, PAL.muted)
  fy = fy + 28 * s
  local shop = S.project.prizeShop
  for _, counter in ipairs(COUNTERS) do
    Kit.text("small", counter.label, viewX, fy + 4 * s, PAL.caption)
    fy = fy + fh
    local owned = shop and shop[counter.id]
    for i, row in ipairs(counter.rows) do
      local cost = owned and owned.costs and owned.costs[i]
      if cost == nil then cost = row[2] end
      Kit.text("small", row[1], viewX + 12 * s, fy + 6 * s, PAL.caption)
      local v = math.floor(require("RegList").num(App, "prz_" .. counter.id .. i,
        viewX + 160 * s, fy, 72 * s, fh, cost))
      v = math.max(0, math.min(9999, v))
      local level = row[3]
      local lv
      if level then
        local curL = owned and owned.levels and owned.levels[i]
        if curL == nil then curL = level end
        Kit.text("small", "Lv", viewX + 250 * s, fy + 6 * s, PAL.caption)
        lv = math.floor(require("RegList").num(App, "przlv_" .. counter.id .. i,
          viewX + 280 * s, fy, 56 * s, fh, curL))
        lv = math.max(1, math.min(100, lv))
        if lv ~= curL then
          require("State").ensureProjectFields(S.project)
          S.project.prizeShop = S.project.prizeShop or {}
          local bag = S.project.prizeShop[counter.id] or {}
          storeCell(bag, "levels", i, lv, level)
          if not next(bag) then bag = nil end
          S.project.prizeShop[counter.id] = bag
          if not next(S.project.prizeShop) then S.project.prizeShop = nil end
          App.markDirty()
        end
      end
      if v ~= cost then
        require("State").ensureProjectFields(S.project)
        S.project.prizeShop = S.project.prizeShop or {}
        local bag = S.project.prizeShop[counter.id] or {}
        storeCell(bag, "costs", i, v, row[2])
        if not next(bag) then bag = nil end
        S.project.prizeShop[counter.id] = bag
        if not next(S.project.prizeShop) then S.project.prizeShop = nil end
        App.markDirty()
      end
      fy = fy + fh + 4 * s
    end
  end
  if not Generation.isCrystal(S) then return fy end
  fy = fy + 12 * s
  Kit.caption(viewX, fy, "BUENA'S PRIZES")
  fy = fy + 22 * s
  Kit.text("micro", "Blue Card points. 0 is free. The card stores no more than the cap. 0 stores nothing.",
    viewX, fy, PAL.muted)
  fy = fy + 28 * s
  local buena = S.project.buenaPrizes
  local cap = buena and buena.cap
  if cap == nil then cap = 30 end
  Kit.text("small", "Point cap", viewX, fy + 6 * s, PAL.caption)
  local capV = math.floor(require("RegList").num(App, "buena_cap", viewX + 160 * s, fy, 72 * s, fh, cap))
  capV = math.max(0, math.min(255, capV))
  if capV ~= cap then
    require("State").ensureProjectFields(S.project)
    S.project.buenaPrizes = S.project.buenaPrizes or {}
    S.project.buenaPrizes.cap = capV == 30 and nil or capV
    if not next(S.project.buenaPrizes) then S.project.buenaPrizes = nil end
    App.markDirty()
  end
  fy = fy + fh + 4 * s
  for i, row in ipairs(BUENA) do
    local cur = buena and buena.costs and buena.costs[i]
    if cur == nil then cur = row[2] end
    Kit.text("small", row[1], viewX + 12 * s, fy + 6 * s, PAL.caption)
    local v = math.floor(require("RegList").num(App, "buena_" .. i, viewX + 160 * s, fy, 72 * s, fh, cur))
    v = math.max(0, math.min(255, v))
    if v ~= cur then
      require("State").ensureProjectFields(S.project)
      S.project.buenaPrizes = S.project.buenaPrizes or {}
      storeCell(S.project.buenaPrizes, "costs", i, v, row[2])
      if not next(S.project.buenaPrizes) then S.project.buenaPrizes = nil end
      App.markDirty()
    end
    fy = fy + fh + 4 * s
  end
  return fy
end

function M.emit(p, encode, out)
  if gen2(p) and type(p.prizeShop) == "table" then
    local lines = {}
    for _, counter in ipairs(COUNTERS) do
      local bag = p.prizeShop[counter.id]
      if type(bag) == "table" then
        if type(bag.costs) == "table" then
          for i, row in ipairs(counter.rows) do
            local n = tonumber(bag.costs[i])
            if n ~= nil then
              n = math.max(0, math.min(9999, math.floor(n)))
              lines[#lines + 1] = string.format(
                "    PrizeMenu.PRIZE_COSTS.%s = PrizeMenu.PRIZE_COSTS.%s or {}", counter.id, counter.id)
              lines[#lines + 1] = string.format(
                "    PrizeMenu.PRIZE_COSTS.%s[%d] = %d", counter.id, i, n)
            end
          end
        end
        if type(bag.levels) == "table" then
          for i, row in ipairs(counter.rows) do
            if row[3] then
              local n = tonumber(bag.levels[i])
              if n ~= nil then
                n = math.max(1, math.min(100, math.floor(n)))
                lines[#lines + 1] = string.format(
                  "    PrizeMenu.PRIZE_LEVELS.%s = PrizeMenu.PRIZE_LEVELS.%s or {}", counter.id, counter.id)
                lines[#lines + 1] = string.format(
                  "    PrizeMenu.PRIZE_LEVELS.%s[%d] = %d", counter.id, i, n)
              end
            end
          end
        end
      end
    end
    if #lines > 0 then
      out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
      out[#out + 1] = "    local PrizeMenu = require(\"src.ui.gen2.PrizeMenu\")"
      out[#out + 1] = "    PrizeMenu.PRIZE_COSTS = PrizeMenu.PRIZE_COSTS or {}"
      out[#out + 1] = "    PrizeMenu.PRIZE_LEVELS = PrizeMenu.PRIZE_LEVELS or {}"
      for _, line in ipairs(lines) do out[#out + 1] = line end
      out[#out + 1] = "    PrizeMenu.applyPrizeOverrides()"
      out[#out + 1] = "  end)"
      out[#out + 1] = ""
    end
  end
  if not crystal(p) or type(p.buenaPrizes) ~= "table" then return end
  local lines = {}
  local cap = tonumber(p.buenaPrizes.cap)
  if cap ~= nil then
    cap = math.max(0, math.min(255, math.floor(cap)))
    lines[#lines + 1] = string.format("    Prizes.POINT_CAP = %d", cap)
  end
  if type(p.buenaPrizes.costs) == "table" then
    for i, row in ipairs(BUENA) do
      local n = tonumber(p.buenaPrizes.costs[i])
      if n ~= nil then
        n = math.max(0, math.min(255, math.floor(n)))
        lines[#lines + 1] = string.format("    Prizes.COSTS[%d] = %d", i, n)
      end
    end
  end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Prizes = require(\"src.core.gen2.BuenaPrizes\")"
  out[#out + 1] = "    Prizes.COSTS = Prizes.COSTS or {}"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
