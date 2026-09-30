-- FireRed maps (Emerald projects, GAME PATCHES > FireRed Maps): FireRed's
-- tilesets and maps in an Emerald mod, read from the player's own FireRed or
-- LeafGreen import.
--
-- With the patch on (project.gen3FrLink) the editor offers:
--   * every FireRed tileset, "frlg__<FireRed tileset>" (e.g.
--     frlg__pallet_outdoor), wherever Emerald's are offered (map builder,
--     Create / resize, Around the map);
--   * FireRed's maps in MAPS > Import template map: a new map builder map
--     with that map's blocks, collision and border on its FireRed tileset;
--   * Import region: every FireRed map at once as EM_KANTO_<name>, joined
--     by FireRed's own connections and warps, with its wild Pokemon. They are
--     map layouts naming the FireRed map (gen3MapLayouts[id].source =
--     "frlg:<map>"), so the project holds no FireRed blocks.
-- People, signs and scripts stay in FireRed (the two games' scripts differ);
-- they are made in the editor.
--
-- The mod carries names only, never tiles, layouts or lists. The game side
-- is Gen3FrLinkRuntime; a player without a FireRed or LeafGreen import can't
-- turn the mod on (it stops with M.MESSAGE). The editor needs one too.
local M = {}
local R = require("Gen3FrLinkRuntime")
M.PAIR, M.MAP = R.PAIR, R.MAP
M.MESSAGE = "This mod uses FireRed maps and tilesets. Import FireRed or LeafGreen (USA) in the launcher, then turn the mod on again."
M.redirect = R.redirect
M.REGION = R.REGION

--- Rebuild the editor's map and tileset lists (after the switch or Import
-- region changed what's in them).
function M.refresh(S)
  if not (S and S.data) then return end
  S.data._editorMaps, S.data._editorTilesets = nil, nil
  pcall(function() require("Gen3Workspace").prepare(S) end)
end

--- GAME PATCHES > FireRed Maps (Emerald).
function M.enabled(project)
  project = project or {}
  return project.gen3FrLink == true and (project.game or project.version) == "emerald"
end
function M.setEnabled(project, on)
  if (project.gen3FrLink == true) == (on == true) then return false end
  project.gen3FrLink = on == true or nil
  return true
end

function M.isPair(p) return type(p) == "string" and p:sub(1, #M.PAIR) == M.PAIR end
function M.isMap(id) return type(id) == "string" and id:sub(1, #M.MAP) == M.MAP end
function M.pairName(base) return M.PAIR .. base end
function M.mapSource(id) return M.MAP .. id end
function M.label(p)
  if M.isPair(p) then return "FireRed: " .. p:sub(#M.PAIR + 1):gsub("_rom_", " / ") end
  return (tostring(p):gsub("_rom_", " / "))
end

-- Editor side -----------------------------------------------------------------

local link -- { prefix, game, read } or false
local function diskRoots()
  local roots = {}
  local okD, DataSource = pcall(require, "DataSource")
  if okD and type(DataSource) == "table" and DataSource.loadPrefs then
    local okP, prefs = pcall(DataSource.loadPrefs)
    if okP and type(prefs) == "table" and type(prefs.recompRoot) == "string" and prefs.recompRoot ~= "" then
      roots[#roots + 1] = (prefs.recompRoot:gsub("[/\\]+$", ""))
    end
  end
  local appdata = os.getenv("APPDATA")
  if appdata then
    roots[#roots + 1] = appdata .. "/LOVE/pokemon-love2d"
    roots[#roots + 1] = appdata .. "/pokemon-love2d"
  end
  local home = os.getenv("HOME")
  if home then roots[#roots + 1] = home .. "/.local/share/love/pokemon-love2d" end
  return roots
end

-- Reads save-folder paths ("firered/…"): the editor's own folder first, then
-- the linked Gen1Recomp folder and the game's save folders.
local function readAny(rel)
  local fs = love and love.filesystem
  if fs and fs.getInfo and fs.getInfo(rel, "file") then return fs.read(rel) end
  for _, root in ipairs(M._roots or diskRoots()) do
    local f = io.open(root .. "/" .. rel, "rb")
    if f then local b = f:read("*a"); f:close(); return b end
  end
end

--- The FireRed / LeafGreen import the editor can use, or nil.
function M.editor()
  if link == nil then
    link = false
    local prefix, game = R.find(readAny)
    if prefix then
      local cache = {}
      link = { prefix = prefix, game = game, read = function(rel)
        if cache[rel] == nil then cache[rel] = readAny(prefix .. rel) or false end
        return cache[rel] or nil
      end }
    end
  end
  return link or nil
end
function M.reset() link = nil; M._manifest, M._layouts, M._headers, M._wild, M._pack = nil, nil, nil, nil, nil end

--- FireRed bytes for a cache path, or nil. `path` may name a frlg__ tileset
-- folder (native/frlg__X/…) or be a plain FireRed cache path.
function M.read(path)
  local l = M.editor()
  if not l then return nil end
  return l.read(M.redirect(path) or path)
end

local function decode(bytes)
  if not bytes then return nil end
  local value = require("Gen3Decode").decode(bytes, { allowArray = true, allowComments = true,
    maxBytes = 16 * 1024 * 1024, maxNodes = 1000000, maxTableEntries = 500000,
    maxDepth = 64, maxStringBytes = 4 * 1024 * 1024 })
  return type(value) == "table" and value or nil
end

function M.manifest()
  if M._manifest == nil then
    M._manifest = decode(M.read("data/generated/gba/native/manifest.lua")) or false
  end
  return M._manifest or nil
end

--- FireRed tilesets as editor tileset ids: { "frlg__…", … }, labels.
function M.pairs()
  local ids, labels, seen = {}, {}, {}
  for _, info in pairs((M.manifest() or {}).layouts or {}) do
    if info.pair and not seen[info.pair] then
      seen[info.pair] = true
      local id = M.pairName(info.pair)
      ids[#ids + 1] = id; labels[id] = M.label(id)
    end
  end
  table.sort(ids)
  return ids, labels
end

--- FireRed maps that can start an Emerald map: { "FR_…", … }, labels.
function M.maps()
  local ids, labels = {}, {}
  for id in pairs((M.manifest() or {}).layouts or {}) do
    if id:match("^FR_") or id:match("^SEVII_") then
      ids[#ids + 1] = id
      labels[id] = id:gsub("^FR_", ""):gsub("^SEVII_", "Sevii "):gsub("_", " ")
    end
  end
  table.sort(ids)
  return ids, labels
end

--- A FireRed map's layout ("frlg:FR_…"), with its tileset as frlg__…
function M.layout(source)
  if not M.isMap(source) then return nil, "Not a FireRed map" end
  if not M.editor() then return nil, "Import FireRed or LeafGreen to use FireRed maps" end
  local id = source:sub(#M.MAP + 1)
  M._layouts = M._layouts or {}
  if M._layouts[id] == nil then
    local info = ((M.manifest() or {}).layouts or {})[id]
    local blob = info and M.read("data/generated/gba/native/" .. (info.file or ("layouts/" .. id .. ".mid")))
    local decoded = blob and require("src.import.gba.native_pack").decodeMidLayout(blob)
    M._layouts[id] = decoded and require("src.core.game3.layout_native").fromDecoded(decoded, id, M.pairName(info.pair)) or false
  end
  if not M._layouts[id] then return nil, "FireRed map " .. id .. " is missing from the import" end
  return M._layouts[id]
end

-- FireRed's own names for a few maps (pokefirered map_groups -> engine ids).
local HAND = {
  PalletTown_PlayersHouse_1F = "FR_PLAYERS_HOUSE_1F", PalletTown_PlayersHouse_2F = "FR_PLAYERS_HOUSE_2F",
  PalletTown_RivalsHouse = "FR_RIVALS_HOUSE", PalletTown_ProfessorOaksLab = "FR_OAKS_LAB",
  PewterCity_Gym = "FR_PEWTER_CITY_GYM", OneIsland = "SEVII_ONE_ISLAND",
  OneIsland_KindleRoad = "SEVII_ONE_ISLAND_KINDLE_ROAD", OneIsland_TreasureBeach = "SEVII_ONE_ISLAND_TREASURE_BEACH",
  OneIsland_PokemonCenter_1F = "SEVII_ONE_ISLAND_POKECENTER", OneIsland_PokemonCenter_2F = "SEVII_ONE_ISLAND_POKECENTER_2F",
  OneIsland_Harbor = "SEVII_ONE_ISLAND_HARBOR", OneIsland_House1 = "SEVII_ONE_ISLAND_HOUSE1",
  OneIsland_House2 = "SEVII_ONE_ISLAND_HOUSE2",
}
local function engineId(pret)
  if HAND[pret] then return HAND[pret] end
  local s = pret:gsub("Route(%d+)", "Route_%1"):gsub("(%l)(%u)", "%1_%2"):gsub("-", "_"):upper():gsub("_+", "_")
  return "FR_" .. s
end

--- A FireRed map's header (map type, cave, …), or nil.
function M.header(id)
  if not M._headers then
    M._headers = {}
    local census = M.read("data/generated/gba/map_tree/census.json")
    local okJ, Json = pcall(require, "src.link.Json")
    local c = census and okJ and Json.decode(census)
    for _, group in ipairs((c or {}).groups or {}) do
      for _, map in ipairs(group.maps or {}) do
        M._headers[engineId(map.id)] = map.slot
      end
    end
  end
  local slot = M._headers[id]
  if type(slot) == "string" then
    local okJ, Json = pcall(require, "src.link.Json")
    local header = okJ and Json.decode(M.read("data/generated/gba/map_tree/maps/" .. slot .. "/header.json") or "")
    M._headers[id] = type(header) == "table" and header or false
  end
  return M._headers[id] or nil
end

--- The behaviours of a FireRed tileset (frlg__…): { [block] = behaviour }.
function M.behaviors(pair)
  if not M.isPair(pair) then return nil end
  if M._pack == nil then
    local bytes = M.read("data/generated/gba/objects/pack.lua")
    local chunk = bytes and load(bytes, "=frlg_pack", "t", {})
    local ok, value = pcall(chunk or error)
    M._pack = ok and type(value) == "table" and value or false
  end
  return M._pack and (M._pack.behaviors or {})[pair:sub(#M.PAIR + 1)] or nil
end

--- A FireRed map as a map builder source (MAPS > Import template map): its
-- blocks, collision, heights and border on its FireRed tileset. No events.
function M.templateSource(S, source)
  local layout, err = M.layout(source)
  if not layout then return nil, err end
  local L = require("LayeredMap")
  local runtime = L.runtimeSourceId(layout.pair)
  local behaviors = M.behaviors(layout.pair) or {}
  local cells, collision, elevation, nativeCollision, nativeBehavior = {}, {}, {}, {}, {}
  for y = 0, layout.height - 1 do for x = 0, layout.width - 1 do
    local i = y * layout.width + x + 1
    local c = layout:cellAt(x, y)
    cells[i] = { source = runtime, tile = c.mid }
    collision[i] = require("Gen3Collision").mode(c.coll); elevation[i] = c.elev; nativeCollision[i] = c.coll
    nativeBehavior[i] = behaviors[c.mid]
  end end
  local copy = require("src.mods.Merge").deepCopy
  return { id = source, cellWidth = layout.width, cellHeight = layout.height, baseTileset = layout.pair,
    layers = { { id = "ground", name = "Ground", visible = true, export = true, opacity = 1, cells = cells } },
    collision = collision, gen3Elevation = elevation, gen3Collision = nativeCollision, gen3Behavior = nativeBehavior,
    gen3Border = { pair = layout.pair, width = layout.borderWidth, height = layout.borderHeight, mids = copy(layout.borderMids) } }
end

--- FireRed maps for MAPS > Import template map (Emerald): ids "frlg:FR_…".
function M.templateMaps(project)
  local ids, labels = {}, {}
  if not M.enabled(project) or not M.editor() then return ids, labels end
  local frIds, frLabels = M.maps()
  for _, id in ipairs(frIds) do
    local key = M.mapSource(id)
    ids[#ids + 1] = key; labels[key] = "FireRed: " .. frLabels[id] .. "  (" .. id .. ")"
  end
  return ids, labels
end

-- Export ----------------------------------------------------------------------

--- The Emerald id a FireRed map gets from Import region: EM_KANTO_<name>.
function M.regionId(id) return M.REGION .. tostring(id):gsub("^FR_", "") end

-- Emerald music for a FireRed map, by its type (FireRed's songs aren't
-- Emerald's): towns and cities, routes and sea, caves, buildings.
local function musicFor(S, mapType)
  local pick = ({ [1] = "EM_LITTLEROOT_TOWN", [2] = "EM_LITTLEROOT_TOWN", [3] = "EM_ROUTE101", [5] = "EM_ROUTE101",
    [6] = "EM_ROUTE101", [4] = "EM_GRANITE_CAVE_1F", [9] = "EM_GRANITE_CAVE_1F" })[tonumber(mapType)] or "EM_LITTLEROOT_TOWN"
  local def = ((S.data or {}).maps or {})[pick]
  return def and def.music
end

--- GAME PATCHES > FireRed Maps > Import region: every FireRed map as
-- EM_KANTO_<name>, joined by FireRed's connections and warps. Maps the
-- project already has are left alone. Returns added, skipped (or nil, why).
function M.importRegion(S)
  if not M.enabled(S.project) then return nil, "Turn FireRed Maps on first" end
  if not M.editor() then return nil, "Import FireRed or LeafGreen first" end
  local warps = decode(M.read("data/generated/gba/warps.lua")) or {}
  local connections = decode(M.read("data/generated/gba/connections.lua")) or {}
  local ids = M.maps()
  if #ids == 0 then return nil, "The FireRed import has no maps" end
  local known = {}
  for _, id in ipairs(ids) do known[id] = M.regionId(id) end
  local p = S.project
  p.gen3MapLayouts = p.gen3MapLayouts or {}
  p.gen3 = p.gen3 or {}; p.gen3.maps = p.gen3.maps or {}
  p.gen3Modes = p.gen3Modes or {}; p.gen3Modes.maps = p.gen3Modes.maps or {}
  local exists = function(id)
    return ((S.data or {}).maps or {})[id] or p.gen3.maps[id] or (p.maps or {})[id] or (p.layeredMaps or {})[id]
  end
  local added, skipped = 0, 0
  for _, fid in ipairs(ids) do
    local id = known[fid]
    local info = (((M.manifest() or {}).layouts) or {})[fid]
    if exists(id) or not info then skipped = skipped + 1
    else
      local header = M.header(fid) or {}
      local def = { id = id, name = id, width = info.width, height = info.height, pair = M.pairName(info.pair),
        objects = {}, bgEvents = {}, coordEvents = {}, mapScripts = {}, warps = {}, connections = {} }
      for _, key in ipairs({ "mapType", "weather", "regionMapSectionId", "showMapName", "allowEscaping",
          "allowRunning", "bikingAllowed", "floorNum", "battleType" }) do
        if header[key] ~= nil then def[key] = header[key] end
      end
      def.music = musicFor(S, header.mapType)
      for _, w in ipairs(warps[fid] or {}) do
        def.warps[#def.warps + 1] = { x = w.x, y = w.y, destMap = known[w.destMap] or w.destMap, destWarp = w.destWarp }
      end
      local rows = {}
      for _, c in ipairs(connections[fid] or {}) do
        if known[c.map] then rows[#rows + 1] = { dir = c.dir, map = known[c.map], offset = c.offset } end
      end
      def.connections = require("Gen3Connections").normalize(rows)
      p.gen3MapLayouts[id] = { source = M.mapSource(fid), width = info.width, height = info.height, blank = false }
      p.gen3.maps[id] = def
      p.gen3Modes.maps[id] = "register"
      added = added + 1
    end
  end
  p.gen3FrRegion = true
  M.refresh(S)
  if S.data and S.data.encounters then M.addWild(S, S.data.encounters) end
  return added, skipped
end

--- Import region's wild Pokemon in the editor: FireRed's lists as the
-- EM_KANTO_ maps' own (Encounters tab), from the import. Edited ones are
-- saved as the mod's own lists (new records); the rest come from the
-- player's import in the game. `base` is the editor's encounter catalog.
function M.addWild(S, base)
  if not (S.project and S.project.gen3FrRegion and M.editor()) then return end
  M._wild = M._wild or decode(M.read("data/generated/gba/encounters.lua")) or {}
  local copy = require("src.mods.Merge").deepCopy
  -- the editor names species (PIDGEY); the import numbers them (16, the same
  -- in both games)
  local names = {}
  for id, rec in pairs(require("Gen3").catalog(S.data, "pokemon")) do
    if tonumber(rec.index) then names[tonumber(rec.index)] = id end
  end
  local function named(area)
    for _, slot in ipairs((area or {}).slots or {}) do
      if type(slot.species) == "number" then slot.species = names[slot.species] or slot.species end
    end
  end
  for key, t in pairs(M._wild) do
    if type(key) == "string" and (key:sub(1, 3) == "FR_" or key:sub(1, 6) == "SEVII_") and type(t) == "table" then
      local id = M.regionId(key)
      if base[id] == nil then
        local rec = copy(t)
        rec.mapGroup, rec.mapNum, rec.variants = nil, nil, nil
        rec.id, rec._isNew = id, true
        for _, k in ipairs({ "land", "grass", "water", "rocks", "fishing" }) do named(rec[k]) end
        base[id] = rec
      end
    end
  end
end

--- Does the project use anything from FireRed?
function M.used(project)
  project = project or {}
  if project.gen3FrRegion then return true end
  for _, spec in pairs(project.gen3MapLayouts or {}) do
    if M.isMap(spec.source) or M.isPair(spec.pair) then return true end
  end
  for _, border in pairs(project.gen3Borders or {}) do
    if M.isPair(border.borderPair) then return true end
  end
  for _, source in pairs(project.layeredMaps or {}) do
    if M.isPair(source.baseTileset) or M.isPair((source.gen3Border or {}).pair) then return true end
    for _, layer in ipairs(source.layers or {}) do
      for _, cell in pairs(layer.cells or {}) do
        if type(cell) == "table" and type(cell.source) == "string" and cell.source:find(M.PAIR, 1, true) then return true end
      end
    end
  end
  for _, rec in pairs(project.gen3VoidMaps or {}) do
    if M.isPair(rec.pair) then return true end
    for _, cell in pairs(rec.cells or {}) do if M.isPair(cell.p) then return true end end
  end
  return false
end

function M.emit(project, encode, out)
  if not M.used(project) then return end
  assert((project.game or project.version) == "emerald", "FireRed maps and tilesets can only be used in Emerald projects")
  out[#out + 1] = "local frLink=(function()\n" .. assert(love.filesystem.read("tools/content-editor/Gen3FrLinkRuntime.lua"),
    "Gen3FrLinkRuntime.lua missing") .. "\nend)()\nfrLink.install(mod," .. encode({ message = M.MESSAGE, region = project.gen3FrRegion == true }) .. ")"
end

return M
