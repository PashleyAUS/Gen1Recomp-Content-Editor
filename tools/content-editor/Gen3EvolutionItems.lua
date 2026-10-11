-- Preserve custom item numbers when species are materialized before items.
local M = {}
function M.compile(project)
  local g = project.gen3 or {}
  local items, fixes = {}, {}
  for id, rec in pairs(g.items or {}) do
    if type(rec) == "table" and tonumber(rec.index) then items[id] = tonumber(rec.index) end
  end
  for id, rec in pairs(g.pokemon or {}) do
    for i, row in ipairs(rec.evolutions or {}) do
      if (row.method == "EVO_ITEM" or row.method == "EVO_TRADE_ITEM") and items[row.item] then
        fixes[id] = fixes[id] or { index = rec.index, rows = {} }
        fixes[id].rows[i] = items[row.item]
      end
    end
  end
  return next(fixes) and fixes or nil
end
function M.emit(project, encode, out)
  local fixes = M.compile(project)
  if not fixes then return end
  out[#out + 1] = "local evolutionItems=" .. encode(fixes) .. [=[
  mod.events:on("game.ready",function()
    local Pokemon=require("src.core.game3.pokemon")
    local byNum={}
    for id,fix in pairs(evolutionItems) do
      local num=fix.index or Pokemon.speciesFromName(id)
      if tonumber(num) then byNum[tonumber(num)]=fix.rows end
    end
    local evolutions=Pokemon.evolutions
    Pokemon.evolutions=function(species)
      local rows=evolutions(species)
      local num=species
      if type(num)=="table" then num=Pokemon.speciesOf(num) end
      if type(num)=="string" then num=Pokemon.speciesFromName(num) or tonumber(num) end
      for i,item in pairs(byNum[tonumber(num)] or {}) do
        local row=rows[i]
        if type(row)=="table" then
          if row.param~=nil or row[2]==nil then row.param=item else row[2]=item end
        end
      end
      return rows
    end
    for num in pairs(byNum) do Pokemon.evolutions(num) end
  end)
]=]
end
return M
