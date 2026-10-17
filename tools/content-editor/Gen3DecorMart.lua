-- Turns a shop override into the id list the mart screen sells.
-- Item shelves stay item indexes. Ruby, Sapphire, and Emerald decoration
-- shelves stay decoration indexes and keep the decoration mart type.
local M = {}

function M.apply(stock, rec, itemIndex, decorIndex)
  if type(stock) == "table" and type(stock.items) == "table" and (stock.martType or stock.kind == "decorations") then
    local martType = stock.martType or (rec and rec.martType) or "DECOR"
    if not rec then rec = { kind = "decorations", martType = martType } end
    stock = stock.items
  end
  if type(stock) ~= "table" then return nil, rec end
  local decor = rec and (rec.martType == "DECOR" or rec.martType == "DECOR2" or rec.kind == "decorations")
  local output = {}
  for i, id in ipairs(stock) do
    if decor then
      output[i] = assert(decorIndex(id) or tonumber(id), "Unknown decoration " .. tostring(id))
    else
      output[i] = assert(itemIndex(id) or tonumber(id), "Unknown shop item " .. tostring(id))
    end
  end
  return output, rec
end

return M
