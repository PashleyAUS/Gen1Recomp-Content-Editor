local M={}
function M.natural(a,b)
  local function key(s) return tostring(s):gsub("%d+",function(n) return string.format("%012d",tonumber(n)) end) end
  return key(a)<key(b)
end
function M.map(id)
  local g,n=tostring(id):match("^(%d+):(%d+)$")
  if g then id=require("src.import.gba.map_catalog").mapIdFor(g,n) or id end
  return tostring(id):gsub("^FR_",""):gsub("^EM_",""):gsub("^SEVII_",""):gsub("_"," ")
end
--- Encounter tables: the game has several ids for one map (FR_ROUTE_1,
-- ROUTE_1, "3:19"); the Encounters list shows one per map name. Returns
-- { [name] = id }: a table the project has edited wins, then the last
-- named (not "group:num") id.
function M.preferredEncounterIds(projectTbl, dataTbl)
  local seen, ids = {}, {}
  for id in pairs(projectTbl or {}) do seen[id] = true; ids[#ids + 1] = id end
  for id in pairs(dataTbl or {}) do if not seen[id] then ids[#ids + 1] = id end end
  table.sort(ids)
  local preferred = {}
  for _, id in ipairs(ids) do
    local ok, name = pcall(M.map, id)
    name = ok and name or tostring(id)
    local old = preferred[name]
    if not old or (projectTbl or {})[id] or (not (projectTbl or {})[old] and not tostring(id):match("^%d+:")) then
      preferred[name] = id
    end
  end
  return preferred
end
--- "LittlerootTown_EventScript_Mom" -> "LittlerootTown EventScript Mom".
function M.script(id)
  local s = tostring(id or "")
  if s == "" then return s end
  return (s:gsub("_", " "))
end

--- The current game's name for a numbered constant, or nil.
-- prefix is the byId group, such as "FLAG_" or "OBJ_EVENT_GFX_".
function M.constant(S, kind, prefix, id)
  local n = tonumber(id)
  local game = S and require("Generation").id(S)
  if not n or not game then return nil end
  local ok, name = pcall(function()
    return require("src.core.game3.constants").of(game):name(kind, n, prefix)
  end)
  if not ok or type(name) ~= "string" or name == "" then return nil end
  local rest = name
  if prefix and name:sub(1, #prefix) == prefix then rest = name:sub(#prefix + 1) end
  rest = rest:gsub("_", " "):lower()
  return (rest:gsub("(%a)([%w']*)", function(a, b) return a:upper() .. b end))
end

function M.scriptMaps(S)
  local result={};local scripts=require("Gen3").catalog(S.data,"map_scripts")
  for map,rec in pairs(S.data.maps or {}) do
    local seen={}
    local function visit(v,depth)
      if depth>40 then return end
      if type(v)=="table" then for _,c in pairs(v) do visit(c,depth+1) end
      elseif type(v)=="string" and scripts[v] and not seen[v] then
        seen[v]=true;result[v]=result[v] or {};result[v][map]=true;visit(scripts[v],depth+1)
      end
    end
    for _,kind in ipairs({"objects","bgEvents","coordEvents","mapScripts"}) do visit(rec[kind],0) end
  end
  return result
end
return M
