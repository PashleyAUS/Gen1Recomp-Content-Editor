-- Teach older runtimes about authored map IDs, including Continue saves.
local M = {}
M.source = [=[
  do
    local MapIds = require("src.core.game3.map_ids")
    local original = MapIds.isGame3Map
    MapIds.isGame3Map = function(id, gameId)
      if original(id, gameId) then return true end
      local version = gameId or require("src.core.GameVersion").get()
      return version == authoredVersion and authoredMaps[id] == true
        and mod.content.maps:get(id) ~= nil
    end
  end
]=]
function M.emit(project, encode, out)
  local ids = {}
  for id in pairs((project.gen3 or {}).maps or {}) do ids[id] = true end
  out[#out+1] = "do local authoredMaps=" .. encode(ids)
    .. "; local authoredVersion=" .. encode(project.game or project.version)
    .. "\n" .. M.source .. "\nend"
end
return M
