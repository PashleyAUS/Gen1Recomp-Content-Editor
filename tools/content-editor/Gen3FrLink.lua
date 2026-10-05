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
-- Signs and everyday people (talkers, Poke Mart clerks, Pokemon Center
-- nurses) come along as the steps they show; other people and scripts stay
-- in FireRed (the two games' scripts differ) and are made in the editor.
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
M.NAME = "FireRed"

--- Rebuild the editor's map and tileset lists (after the switch or Import
-- region changed what's in them).
function M.refresh(S)
  if not (S and S.data) then return end
  S.data._editorMaps, S.data._editorTilesets = nil, nil
  pcall(function() require("Gen3Workspace").prepare(S) end)
end

--- GAME PATCHES > FireRed Maps > Wild Pokemon: Kanto's own encounter tables
-- on the Import region maps. On unless turned off (off: they have none
-- until you make some).
function M.wildEnabled(project) return (project or {}).gen3FrWild ~= false end

--- GAME PATCHES > FireRed Maps > PokeNav text: what the PokeNav's first entry
-- says on the Kanto maps (it names Hoenn otherwise). Empty = the default.
M.NAV_DEFAULT = { label = "REGION MAP", desc = "Check the map of the region." }
M.NAV_MAX = { label = 10, desc = 40 }
local NAV_FIELD = { label = "gen3FrNavLabel", desc = "gen3FrNavDesc" }
function M.navText(project, which)
  local v = (project or {})[NAV_FIELD[which]]
  if type(v) == "string" and v:match("%S") then return v end
  return M.NAV_DEFAULT[which]
end
--- Set one of them ("label" or "desc"); true when it changed.
function M.setNavText(S, which, value)
  local p = S.project
  local field = NAV_FIELD[which]
  if not (p and field) then return false end
  value = tostring(value or ""):gsub("[%c]", " "):sub(1, M.NAV_MAX[which])
  if which == "label" then value = value:upper() end
  local new = (value:match("%S") and value ~= M.NAV_DEFAULT[which]) and value or nil
  if p[field] == new then return false end
  p[field] = new
  return true
end
function M.setWild(S, on)
  local p = S.project
  if M.wildEnabled(p) == (on == true) then return false end
  if on then p.gen3FrWild = nil else p.gen3FrWild = false end
  local base = S.data and S.data._gen3EditorContent and S.data._gen3EditorContent.encounters
  if base then
    if on then M.addWild(S, base)
    else
      -- take FireRed's lists back out of the editor (lists you edited stay yours)
      for id, rec in pairs(base) do
        if type(rec) == "table" and rec._editorFrWild then base[id] = nil end
      end
    end
  end
  return true
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
  if fs and fs.getInfo and fs.getInfo(rel, "file") then return require("Gen3CacheBlob").decode(rel, fs.read(rel)) end
  for _, root in ipairs(M._roots or diskRoots()) do
    local f = io.open(root .. "/" .. rel, "rb")
    if f then local b = f:read("*a"); f:close(); return require("Gen3CacheBlob").decode(rel, b) end
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
function M.reset()
  link = nil; M._manifest, M._layouts, M._headers, M._wild, M._pack, M._furniture = nil, nil, nil, nil, nil, nil
  M._scripts, M._texts, M._events = nil, nil, nil
end

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
local function pack()
  if M._pack == nil then
    local bytes = M.read("data/generated/gba/objects/pack.lua")
    local chunk = bytes and load(bytes, "=frlg_pack", "t", {})
    local ok, value = pcall(chunk or error)
    M._pack = ok and type(value) == "table" and value or false
  end
  return M._pack or nil
end

function M.behaviors(pair)
  if not M.isPair(pair) then return nil end
  local p = pack()
  return p and (p.behaviors or {})[pair:sub(#M.PAIR + 1)] or nil
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

-- Emerald music for a FireRed map (FireRed's songs aren't Emerald's): by its
-- name for Pokemon Centers, Marts and Gyms, else by its type -- towns and
-- cities, routes, the sea, caves, buildings.
local function musicFor(S, id, mapType)
  local maps = (S.data or {}).maps or {}
  local pick = ({ [1] = "EM_LITTLEROOT_TOWN", [2] = "EM_RUSTBORO_CITY", [3] = "EM_ROUTE101", [5] = "EM_ROUTE105",
    [6] = "EM_ROUTE105", [4] = "EM_GRANITE_CAVE_1F", [9] = "EM_GRANITE_CAVE_1F",
    [8] = "EM_LITTLEROOT_TOWN_BRENDANS_HOUSE_1F" })[tonumber(mapType)]
  if tostring(id):find("POKEMON_CENTER", 1, true) or tostring(id):find("_POKECENTER", 1, true) then pick = "EM_OLDALE_TOWN_POKEMON_CENTER_1F"
  elseif tostring(id):find("_MART$") then pick = "EM_OLDALE_TOWN_MART"
  elseif tostring(id):find("_GYM$") then pick = "EM_RUSTBORO_CITY_GYM" end
  for _, cand in ipairs({ pick, "EM_LITTLEROOT_TOWN" }) do
    local def = cand and maps[cand]
    if def and def.music then return def.music end
  end
end

-- Signs ----------------------------------------------------------------------
-- FireRed's sign scripts can't run in Emerald as they are (FireRed's specials,
-- flags and variables mean other things there), so each sign is read the
-- way the player sees it -- its messages, Pokemon pictures and braille, on
-- the path where no story flag is set -- and rebuilt from those as steps:
--   { "text", "g3:<text>" } | { "braille", "g3:<text>" }
--   | { "pic", species, x, y } | { "unpic" }
-- Only FireRed's names for the texts are kept; the game reads the words
-- from the player's import (Gen3FrLinkRuntime). Machines that are signs in
-- FireRed (slot machines, vending machines, menus) aren't signs here.
local SIGN_QUIET = { lockall = 1, releaseall = 1, lock = 1, release = 1, faceplayer = 1, special = 1,
  specialvar = 1, setvar = 1, copyvar = 1, checkflag = 1, compare_var_to_value = 1, compare_var_to_var = 1,
  compare = 1, playse = 1, waitse = 1, textcolor = 1, delay = 1, waitstate = 1, waitmessage = 1,
  waitbuttonpress = 1, closemessage = 1, goto_if = 1, call_if = 1, setflag = 1, clearflag = 1,
  addvar = 1, subvar = 1, checkitem = 1 }
local MSGBOX = { [2] = true, [3] = true, [4] = true, [6] = true } -- NPC, sign, default, auto-close

local function scriptsAndText()
  if M._scripts == nil then
    local function lua(rel)
      local bytes = M.read(rel)
      local chunk = bytes and load(bytes, "=" .. rel, "t", {})
      local ok, value = pcall(chunk or error)
      return ok and type(value) == "table" and value or nil
    end
    M._scripts = lua("data/generated/gba/scripts/scripts.lua") or false
    M._texts = lua("data/generated/gba/scripts/text.lua") or false
    -- the import's named scripts (furniture and the like) keep their words in its pack
    if M._texts then
      setmetatable(M._texts, { __index = function(_, k)
        local p = pack()
        return p and type(p.text) == "table" and p.text[k] or nil
      end })
    end
    M._events = lua("data/generated/gba/scripts/events.lua") or false
  end
  return M._scripts or nil, M._texts or nil, M._events or nil
end

-- People (Import region > People, marts & nurses) read their scripts the
-- same way, with a few more steps: { "say", "g3:<text>" } (a message the
-- next step follows, like a clerk's before the shop), { "mart", "g3:<list>" }
-- (FireRed's shop list, read from the import in the game) and
-- { "nurse", localId } (Emerald's own Pokemon Center nurse).
local PERSON_QUIET = { playmoncry = 1, waitmoncry = 1, checkplayergender = 1, textcolor = 1 }
for k in pairs(SIGN_QUIET) do PERSON_QUIET[k] = 1 end

-- FireRed's nurse script: the one every nurse calls.
local function nurseScript()
  if M._nurse == nil then
    local scripts, _, events = scriptsAndText()
    local count = {}
    for _, map in pairs(events or {}) do
      for _, o in ipairs(map.objects or {}) do
        if o.sprite == "SPRITE_NURSE" then
          for _, op in ipairs((scripts or {})[o.scriptKey] or {}) do
            if op.op == "call" and op.target then count[op.target] = (count[op.target] or 0) + 1; break end
          end
        end
      end
    end
    local best, n = false, 0
    for k, c in pairs(count) do if c > n then best, n = k, c end end
    M._nurse = best
  end
  return M._nurse or nil
end

local function walk(key, person)
  local scripts, texts = scriptsAndText()
  if not (scripts and texts) then return nil, "no scripts" end
  local quiet, nurse = person and PERSON_QUIET or SIGN_QUIET, person and nurseScript()
  local steps, stack, seen = {}, {}, {}
  -- a script's key, or its list of commands (the import's named scripts)
  local list, i, word, guard = type(key) == "table" and key or scripts[key], 1, nil, 0
  if not list then return nil, "missing" end
  while list do
    guard = guard + 1
    if guard > 500 then return nil, "loop" end
    local op = list[i]; i = i + 1
    local name = op and op.op
    if not op or name == "return" then
      if #stack == 0 then break end
      local back = table.remove(stack); list, i = back[1], back[2]
    elseif name == "end" then break
    elseif name == "call" and nurse and op.target == nurse then
      steps[#steps + 1] = { "nurse" }
    elseif person and name == "pokemart" then
      local list = op.items or op.ptr or op[1]
      if type(list) ~= "string" then return nil, "mart" end
      steps[#steps + 1] = { "mart", list }
    elseif person and name == "waitbuttonpress" then
      local last = steps[#steps]
      if last and last[1] == "say" then last[1] = "text" end
    elseif name == "goto" or name == "call" then
      if name == "goto" then
        if seen[op.target] then return nil, "loop" end
        seen[op.target] = true
      else stack[#stack + 1] = { list, i } end
      list, i = scripts[op.target], 1
      if not list then return nil, "missing" end
    elseif name == "loadword" then
      if (op.dest or op[1]) == 0 then word = op.value or op[2] end
    elseif name == "callstd" or name == "message" then
      local t = name == "message" and (op.text or op.ptr or op[1]) or word
      if name == "callstd" and not MSGBOX[op.std or op[1]] then return nil, "menu" end
      if not (t and texts[t]) then return nil, "no text" end
      steps[#steps + 1] = { (person and name == "message") and "say" or "text", t }; word = nil
    elseif name == "braillemessage" then
      local t = op.ptr or op[1]
      if not (t and texts[t]) then return nil, "no text" end
      steps[#steps + 1] = { "braille", t }
    elseif name == "showmonpic" then
      steps[#steps + 1] = { "pic", op[1], op[2], op[3] }
    elseif name == "hidemonpic" then
      steps[#steps + 1] = { "unpic" }
    elseif not quiet[name] then return nil, tostring(name)
    end
  end
  local shown = false
  for _, step in ipairs(steps) do if step[1] ~= "unpic" and step[1] ~= "pic" then shown = true end end
  if not shown then return nil, "nothing to read" end
  if person then
    for _, step in ipairs(steps) do
      if step[1] == "nurse" then return { { "nurse" } } end -- the nurse's own script does the talking
    end
  end
  return steps
end

--- A FireRed sign as steps (see above), or nil and why not.
function M.signSteps(key) return walk(key, false) end
--- A FireRed person's script as steps, or nil and why not.
function M.personSteps(key) return walk(key, true) end

-- FireRed's furniture tiles (shelves, dressers, trash bins, signs, ...): the
-- game reads a message when the player faces one. Emerald has no interaction
-- for them, so their FireRed scripts are rebuilt here the way signs are.
-- { behaviour, FireRed's script, only when facing up }
local FURNITURE = { { 0x82, "PokeMartShelf" }, { 0x87, "PokecenterSign", true }, { 0x88, "PokemartSign", true },
  { 0x89, "Cabinet" }, { 0x8A, "Kitchen" }, { 0x8B, "Dresser" }, { 0x8C, "Snacks" }, { 0x90, "Food" },
  { 0x91, "Indigo_UltimateGoal" }, { 0x92, "Indigo_HighestAuthority" }, { 0x93, "Blueprints" },
  { 0x94, "Painting" }, { 0x95, "PowerPlantMachine" }, { 0x96, "Telephone" }, { 0x97, "Computer" },
  { 0x98, "AdvertisingPoster" }, { 0x99, "TastyFood" }, { 0x9A, "TrashBin" }, { 0x9B, "Cup" },
  { 0x9C, "PolishedWindow" }, { 0x9D, "BeautifulSkyWindow" }, { 0x9E, "BlinkingLights" },
  { 0x9F, "NeatlyLinedUpTools" }, { 0xA0, "ImpressiveMachine" }, { 0xA1, "VideoGame" }, { 0xA2, "Burglary" } }

--- { [behaviour as text] = { script = "frlg:furn:<behaviour>", facing = "up"? } }
-- and the steps of each script, read from the import's own named scripts.
function M.furniture()
  if M._furniture == nil then
    M._furniture = false
    local scripts = (pack() or {}).scripts
    if type(scripts) == "table" then
      local rows, steps = {}, {}
      for _, f in ipairs(FURNITURE) do
        local got = scripts["EventScript_" .. f[2]] and walk(scripts["EventScript_" .. f[2]], false)
        if got then
          local key = M.MAP .. "furn:" .. f[1]
          rows[tostring(f[1])] = { script = key, facing = f[3] and "up" or nil }
          steps[key] = got
        end
      end
      if next(rows) then M._furniture = { rows = rows, steps = steps } end
    end
  end
  return M._furniture and M._furniture.rows or nil, M._furniture and M._furniture.steps or nil
end

--- A FireRed map's signs as Emerald bgEvents, recording their steps in
-- project.gen3FrSigns. Returns the bgEvents and how many were left out.
function M.signsFor(project, fid)
  local _, _, events = scriptsAndText()
  local out, left = {}, 0
  for _, bg in ipairs(((events or {})[fid] or {}).bgEvents or {}) do
    if bg.type == "sign" and bg.scriptKey then
      local key = M.MAP .. bg.scriptKey
      project.gen3FrSigns = project.gen3FrSigns or {}
      local steps = project.gen3FrSigns[key]
      if not steps then
        steps = M.signSteps(bg.scriptKey)
        if steps then project.gen3FrSigns[key] = steps end
      end
      if steps then
        out[#out + 1] = { x = bg.x, y = bg.y, elevation = bg.elevation or 0, kind = bg.kind or 0, type = "sign", scriptKey = key }
      else left = left + 1 end
    end
  end
  return out, left
end

-- People, marts & nurses ------------------------------------------------------
--- GAME PATCHES > FireRed Maps > People, marts & nurses: FireRed's everyday
-- people on the Import region maps -- the ones that talk, Poke Mart clerks
-- and Pokemon Center nurses. On unless turned off. Trainers, item balls and
-- story people (anyone FireRed hides or shows with a flag) stay out.
function M.peopleEnabled(project) return (project or {}).gen3FrPeople ~= false end

-- Emerald's look-alike of a FireRed sprite, for the editor's map view (the
-- game draws FireRed's own sprite from the import) and Emerald movement
-- numbers for FireRed's.
local LOOKS = { CLERK = "MART_EMPLOYEE", FISHER = "FISHERMAN", OLD_MAN_1 = "OLD_MAN", OLD_MAN_2 = "OLD_MAN",
  BOY = "BOY_1", MAN = "MAN_1", BALDING_MAN = "MAN_2", COOLTRAINER_M = "MAN_3", COOLTRAINER_F = "WOMAN_2",
  POKE_MANIAC = "MANIAC", ROCKER = "MAN_4", SCIENTIST = "SCIENTIST_1", POLICEMAN = "POLICEMAN", CHEF = "COOK",
  CABLE_CLUB_RECEPTIONIST = "LINK_RECEPTIONIST", UNION_ROOM_RECEPTIONIST = "LINK_RECEPTIONIST",
  WORKER_M = "HIKER", GBA_KID = "GAMEBOY_KID", CAPTAIN = "SAILOR" }
local function constants()
  if M._const == nil then
    local ok, C = pcall(require, "src.core.game3.constants")
    local okF, fr = pcall(function() return C.of("firered") end)
    local okE, em = pcall(function() return C.of("emerald") end)
    M._const = ok and okF and okE and { fr = fr, em = em } or false
  end
  return M._const or nil
end
local function emeraldLook(sprite)
  local c = constants()
  local E = c and c.em.event_objects and c.em.event_objects.byName or {}
  local name = tostring(sprite or ""):gsub("^SPRITE_", "")
  return E["OBJ_EVENT_GFX_" .. name] or E["OBJ_EVENT_GFX_" .. (LOOKS[name] or "")] or E.OBJ_EVENT_GFX_MAN_1 or 19
end
local function emeraldMovement(mt)
  local c = constants()
  local name = c and ((c.fr.movement.byId or {}).MOVEMENT_TYPE_ or {})[mt]
  return name and c.em.movement.byName[name] or mt
end

--- A FireRed map's people as Emerald objects, recording their steps in
-- project.gen3FrTalk. Returns the objects and how many were left out.
function M.peopleFor(project, fid)
  local _, _, events = scriptsAndText()
  local out, left = {}, 0
  for _, o in ipairs(((events or {})[fid] or {}).objects or {}) do
    local gid = tonumber(o.graphicsId or o.graphics)
    local story = (tonumber(o.flag) or 0) ~= 0 or (tonumber(o.trainerType) or 0) ~= 0
    local steps
    if not story and o.scriptKey and gid and gid < 240 then
      local key = M.MAP .. o.scriptKey
      project.gen3FrTalk = project.gen3FrTalk or {}
      steps = project.gen3FrTalk[key]
      if not steps then
        steps = M.personSteps(o.scriptKey)
        if steps then
          if steps[1][1] == "nurse" then steps = { { "nurse", o.localId } } end
          project.gen3FrTalk[key] = steps
        end
      end
      if steps then
        local look = emeraldLook(o.sprite)
        out[#out + 1] = { x = o.x, y = o.y, elevation = o.elevation or 0, localId = o.localId, index = o.localId,
          graphicsId = look, graphics = look, frlgGfx = gid, kind = 0, flag = 0, trainerType = 0, trainerRange = 0,
          sight = 0, movementType = emeraldMovement(o.movementType), movement = o.movement, range = o.range,
          rangeX = o.rangeX or 0, rangeY = o.rangeY or 0, scriptKey = key }
      end
    end
    if not steps then left = left + 1 end
  end
  return out, left
end

local function ownRegionMaps(p)
  local out = {}
  for _, fid in ipairs(M.maps()) do
    local id = M.regionId(fid)
    if p.gen3 and p.gen3.maps and p.gen3.maps[id] and ((p.gen3MapLayouts or {})[id] or {}).source == M.mapSource(fid) then
      out[#out + 1] = { fid, p.gen3.maps[id] }
    end
  end
  return out
end
local function hasPeople(def)
  for _, o in ipairs(def.objects or {}) do if o.frlgGfx then return true end end
  return false
end
-- Adds FireRed's people to Import region maps that have none yet.
local function addPeople(p)
  local n = 0
  for _, row in ipairs(ownRegionMaps(p)) do
    local def = row[2]
    if not hasPeople(def) then
      local list = M.peopleFor(p, row[1])
      def.objects = def.objects or {}
      local used = {}
      for _, o in ipairs(def.objects) do used[tonumber(o.localId) or -1] = true end
      for _, o in ipairs(list) do
        if not used[o.localId] then def.objects[#def.objects + 1] = o; n = n + 1 end
      end
    end
  end
  return n
end
function M.setPeople(S, on)
  local p = S.project
  if M.peopleEnabled(p) == (on == true) then return false end
  if on then p.gen3FrPeople = nil else p.gen3FrPeople = false end
  if p.gen3FrRegion then
    if on then addPeople(p)
    else
      -- take FireRed's people back out (people you made stay)
      for _, row in ipairs(ownRegionMaps(p)) do
        local keep = {}
        for _, o in ipairs(row[2].objects or {}) do if not o.frlgGfx then keep[#keep + 1] = o end end
        row[2].objects = keep
      end
      p.gen3FrTalk = nil
    end
    M.addTalk(S)
    M.refresh(S)
  end
  return true
end

--- The Import region signs and people in the editor: their scripts (the
-- Emerald ones the game builds) and FireRed's words, from the import, so
-- Dialog and Events show and edit them like any other. Only what you change
-- is saved in the mod (as its own text / script); the rest still comes from
-- the player's import in the game.
function M.addTalk(S)
  local p, data = S.project, S.data
  if not (p and data and (p.gen3FrSigns or p.gen3FrTalk) and data.gen3Scripts and M.editor()) then return end
  local _, texts = scriptsAndText()
  if not texts then return end
  local textBase = (data._gen3EditorContent or {}).text
  local copy = require("src.mods.Merge").deepCopy
  local nurse
  for _, o in ipairs(((data.maps or {}).EM_OLDALE_TOWN_POKEMON_CENTER_1F or {}).objects or {}) do
    for _, op in ipairs(data.gen3Scripts[o.scriptKey] or {}) do
      if op.op == "call" and op.target and not nurse then nurse = op.target end
    end
  end
  local function add(bag, build)
    for key, steps in pairs(bag or {}) do
      if data.gen3Scripts[key] == nil then data.gen3Scripts[key] = build(steps) end
      for _, step in ipairs(steps) do
        local t = (step[1] == "text" or step[1] == "say" or step[1] == "braille") and step[2]
        local full = t and (M.MAP .. t)
        if full and texts[t] then
          if data.gen3Text and data.gen3Text[full] == nil then data.gen3Text[full] = copy(texts[t]) end
          if textBase and textBase[full] == nil then textBase[full] = copy(texts[t]) end
        end
      end
    end
  end
  add(p.gen3FrSigns, R.signOps)
  add(M.peopleEnabled(p) and p.gen3FrTalk or nil, function(steps) return R.personOps(steps, nurse) end)
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
  local added, skipped, signs, signsLeft = 0, 0, 0, 0
  for _, fid in ipairs(ids) do
    local id = known[fid]
    local info = (((M.manifest() or {}).layouts) or {})[fid]
    local ours = p.gen3.maps[id] and (p.gen3MapLayouts[id] or {}).source == M.mapSource(fid)
    if ours and not next(p.gen3.maps[id].bgEvents or {}) then
      -- brought in before signs were: give it its signs now
      local rows, left = M.signsFor(p, fid)
      p.gen3.maps[id].bgEvents = rows
      signs, signsLeft = signs + #rows, signsLeft + left
      skipped = skipped + 1
    elseif exists(id) or not info then skipped = skipped + 1
    else
      local header = M.header(fid) or {}
      local def = { id = id, name = id, width = info.width, height = info.height, pair = M.pairName(info.pair),
        objects = {}, bgEvents = {}, coordEvents = {}, mapScripts = {}, warps = {}, connections = {} }
      for _, key in ipairs({ "mapType", "weather", "regionMapSectionId", "showMapName", "allowEscaping",
          "allowRunning", "bikingAllowed", "floorNum", "battleType" }) do
        if header[key] ~= nil then def[key] = header[key] end
      end
      -- the map keeps its own song, played from the player's import (Gen3ForeignMusic)
      def.music = require("Gen3ForeignMusic").fromImport(M.editor(), header.music) or musicFor(S, fid, header.mapType)
      for _, w in ipairs(warps[fid] or {}) do
        def.warps[#def.warps + 1] = { x = w.x, y = w.y, destMap = known[w.destMap] or w.destMap, destWarp = w.destWarp }
      end
      local rows = {}
      for _, c in ipairs(connections[fid] or {}) do
        if known[c.map] then rows[#rows + 1] = { dir = c.dir, map = known[c.map], offset = c.offset } end
      end
      def.connections = require("Gen3Connections").normalize(rows)
      local signRows, left = M.signsFor(p, fid)
      def.bgEvents = signRows
      signs, signsLeft = signs + #signRows, signsLeft + left
      p.gen3MapLayouts[id] = { source = M.mapSource(fid), width = info.width, height = info.height, blank = false }
      p.gen3.maps[id] = def
      p.gen3Modes.maps[id] = "register"
      added = added + 1
    end
  end
  p.gen3FrRegion = true
  local people = M.peopleEnabled(p) and addPeople(p) or 0
  M.addTalk(S)
  M.refresh(S)
  if S.data and S.data.encounters then M.addWild(S, S.data.encounters) end
  return added, skipped, signs, signsLeft, people
end

--- Import region's wild Pokemon in the editor: FireRed's lists as the
-- EM_KANTO_ maps' own (Encounters tab), from the import. Edited ones are
-- saved as the mod's own lists (new records); the rest come from the
-- player's import in the game. `base` is the editor's encounter catalog.
function M.addWild(S, base)
  if not (S.project and S.project.gen3FrRegion and M.wildEnabled(S.project) and M.editor()) then return end
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
  -- the import also keys routes as FR_ROUTE1 next to FR_ROUTE_1; only real maps
  local known = {}
  for _, id in ipairs(M.maps()) do known[id] = true end
  for key, t in pairs(M._wild) do
    if known[key] and type(t) == "table" then
      local id = M.regionId(key)
      if base[id] == nil then
        local rec = copy(t)
        rec.mapGroup, rec.mapNum, rec.variants = nil, nil, nil
        rec.id, rec._isNew, rec._editorFrWild = id, true, true
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
  local furniture, furnitureSteps = M.furniture()
  local signs = project.gen3FrSigns
  if furniture then
    signs = {}
    for key, steps in pairs(project.gen3FrSigns or {}) do signs[key] = steps end
    for key, steps in pairs(furnitureSteps) do signs[key] = steps end
  end
  out[#out + 1] = "local frLink=(function()\n" .. assert(love.filesystem.read("tools/content-editor/Gen3FrLinkRuntime.lua"),
    "Gen3FrLinkRuntime.lua missing") .. "\nend)()\nfrLink.install(mod," .. encode({ message = M.MESSAGE, wild = project.gen3FrRegion == true and M.wildEnabled(project),
    furniture = furniture, signs = signs, people = M.peopleEnabled(project) and project.gen3FrTalk or nil,
    respawn = project.gen3FrRegion == true and M.peopleEnabled(project) }) .. ")"
  -- FireRed's own tile behaviours (spinners, the Icefall Cave ice), run by the
  -- game's FireRed code in Emerald
  local steps = {}
  local scripts, _, events = scriptsAndText()
  local Tiles = require("Gen3RegionTilesRuntime")
  for id, spec in pairs(project.gen3MapLayouts or {}) do
    if M.isMap(spec.source) and (project.gen3 or {}).maps and project.gen3.maps[id] then
      local ms = events and events[spec.source:sub(#M.MAP + 1)] and events[spec.source:sub(#M.MAP + 1)].mapScripts
      local name = type(ms) == "table" and Tiles.scan(scripts, ms.onResume, Tiles.NAMES.firered)
      if name then steps[id] = name end
    end
  end
  out[#out + 1] = "local regionTiles=(function()\n" .. assert(love.filesystem.read("tools/content-editor/Gen3RegionTilesRuntime.lua"),
    "Gen3RegionTilesRuntime.lua missing") .. "\nend)()\nregionTiles.install(mod," .. encode({ host = "rse", origin = "firered", pair = M.PAIR, steps = steps }) .. ")"
  -- Town Map and Fly for the imported region: FireRed's own screen, with the
  -- towns the player has walked into
  if project.gen3FrRegion == true then
    local MapRT = require("Gen3RegionMapRuntime")
    local visits = {}
    for id, spec in pairs(project.gen3MapLayouts or {}) do
      if M.isMap(spec.source) and (project.gen3 or {}).maps and project.gen3.maps[id] then
        local eid = spec.source:sub(#M.MAP + 1)
        local ms = events and events[eid] and events[eid].mapScripts
        local ids = type(ms) == "table" and MapRT.scanFlags(scripts, ms.onTransition, function(op) return op == "setworldmapflag" end) or {}
        if #ids > 0 then visits[id] = ids end
      end
    end
    out[#out + 1] = "local regionMap=(function()\n" .. assert(love.filesystem.read("tools/content-editor/Gen3RegionMapRuntime.lua"),
    "Gen3RegionMapRuntime.lua missing") .. "\nend)()\nregionMap.install(mod," .. encode({ host = "rse", origin = "firered", cross = true, region = M.REGION, prefix = "FR_", secBase = 0, visits = visits,
      nav = { label = M.navText(project, "label"), desc = M.navText(project, "desc") } }) .. ")"
  end
end

return M
