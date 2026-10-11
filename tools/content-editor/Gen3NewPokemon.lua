-- New Pokemon (FireRed / LeafGreen): evolutions into the mod's own species.
--
-- The editor numbers new species from 440 up (after the game's own list).
-- Two things stop evolutions into them in the game, fixed from main.lua (the
-- engine isn't changed):
--  * FireRed only lets a Pokemon evolve into a species above #151 once the
--    National Pokedex is on (pokefirered party_menu.c / evolution_scene.c).
--    The mod's new species skip that rule; the game's own keep it.
--  * The game fills in each species' evolutions one species at a time, so an
--    evolution into a new species that isn't filled in yet ends up with no
--    target (nothing happens). The right species numbers are put back.

local M = {}

--- What the game needs, or nil when the mod adds no species:
-- new = { [index] = true }, fixes = { [species id] = { [row] = target index } }.
function M.compile(project)
  local records = ((project.gen3 or {}).pokemon) or {}
  local modes = ((project.gen3Modes or {}).pokemon) or {}
  local new, byId, entries, national = {}, {}, {}, {}
  for id, rec in pairs(records) do
    if modes[id] == "register" and type(rec) == "table" and tonumber(rec.index) then
      new[tonumber(rec.index)] = true
      byId[id] = tonumber(rec.index)
      national[tonumber(rec.index)] = tonumber(rec.dex)
      local dex = rec.dexEntry or {}
      entries[tonumber(rec.index)] = {
        category = dex.kind or "???", height = dex.height or 0,
        weight = dex.weight or 0, description = "", description2 = "",
        pokemonScale = 256, pokemonOffset = 0,
        trainerScale = 256, trainerOffset = 0,
      }
    end
  end
  if not next(new) then return nil end
  local fixes, indices = {}, {}
  for id, rec in pairs(records) do
    for i, row in ipairs(type(rec) == "table" and rec.evolutions or {}) do
      local target = type(row) == "table" and byId[row.species]
      if target then
        fixes[id] = fixes[id] or {}
        fixes[id][i] = target
      end
    end
    if fixes[id] and byId[id] then indices[id] = byId[id] end
  end
  return { new = new, fixes = fixes, indices = indices, entries = entries, national = national }
end

function M.emit(project, encode, out)
  local data = M.compile(project)
  if not data then return end
  out[#out + 1] = "  local newPokemon=" .. encode(data) .. "\n" .. [=[
  -- New Pokemon evolve without the National Pokedex, and evolutions into
  -- them keep their target (Gen3NewPokemon.lua).
  local dexInstalled=false
  local nationalInstalled=false
  mod.events:on("game.ready",function()
    -- The catch screen reads a separate species-keyed Pokédex pack, not
    -- Pokemon._dex (which the content registry updates by national number).
    if not dexInstalled then
    local okD,DexData=pcall(require,"src.core.game3.pokedex_data")
    if okD and type(DexData)=="table" and type(DexData.init)=="function" then
      local init=DexData.init
      DexData.init=function(...)
        local result=init(...)
        for species,entry in pairs(newPokemon.entries) do DexData._entries[species]=entry end
        return result
      end
    end
    -- Emerald and Ruby/Sapphire read that pack through Mapsec instead.
    local okM,Mapsec=pcall(require,"src.ui.game3.rse.mapsec")
    if okM and type(Mapsec)=="table" and type(Mapsec.readLua)=="function" then
      local read=Mapsec.readLua
      Mapsec.readLua=function(path,...)
        local pack=read(path,...)
        if path=="pokemon/pokedex/entries.lua" and type(pack)=="table" then
          for species,entry in pairs(newPokemon.entries) do pack[species]=entry end
        end
        return pack
      end
    end
    dexInstalled=true
    end
    local okE,Evolution=pcall(require,"src.core.game3.evolution")
    if okE and type(Evolution)=="table" and type(Evolution.nationalAllows)=="function" and not Evolution._newPokemonPatched then
      local allows=Evolution.nationalAllows
      Evolution.nationalAllows=function(target,session)
        if newPokemon.new[tonumber(target) or -1] then return true end
        return allows(target,session)
      end
      Evolution._newPokemonPatched=true
    end
    local okP,Pokemon=pcall(require,"src.core.game3.pokemon")
    if not okP or type(Pokemon)~="table" then return end
    local function mendNational()
      local pack=Pokemon._national
      if not pack then return end
      pack.toNational=pack.toNational or {};pack.toSpecies=pack.toSpecies or {}
      for species,nat in pairs(newPokemon.national) do
        pack.toNational[species]=nat
        -- Forms keep their parent's reverse mapping.
        local old=pack.toSpecies[nat]
        if not old or old==0 or (nat>386 and (not newPokemon.new[old] or species<old)) then
          pack.toSpecies[nat]=species
        end
      end
    end
    mendNational()
    if not nationalInstalled and type(Pokemon.onReload)=="function" then
      Pokemon.onReload(mendNational)
      nationalInstalled=true
    end
    if type(Pokemon.evolutions)~="function" then return end
    local byNum
    local function fixesFor(num)
      if not byNum then
        byNum={}
        for id,rows in pairs(newPokemon.fixes) do
          local n=newPokemon.indices[id] or (Pokemon.speciesFromName and Pokemon.speciesFromName(id))
          if tonumber(n) then byNum[tonumber(n)]=rows end
        end
      end
      return byNum[num]
    end
    local function mend(num,rows)
      local fix=type(rows)=="table" and fixesFor(num)
      if not fix then return end
      for i,target in pairs(fix) do
        local row=rows[i]
        if type(row)=="table" and (tonumber(row.target or row[3]) or 0)~=target then
          if row.target~=nil or row[3]==nil then row.target=target else row[3]=target end
        end
      end
    end
    if not Pokemon._newPokemonPatched then
      local evolutions=Pokemon.evolutions
      Pokemon.evolutions=function(species)
        local rows=evolutions(species)
        local num=species
        if type(num)=="table" then num=Pokemon.speciesOf(num) end
        if type(num)=="string" then num=(Pokemon.speciesFromName and Pokemon.speciesFromName(num)) or tonumber(num) end
        if tonumber(num) then mend(tonumber(num),rows) end
        return rows
      end
      Pokemon._newPokemonPatched=true
    end
    -- breeding reads the table directly
    for id in pairs(newPokemon.fixes) do
      local n=newPokemon.indices[id] or (Pokemon.speciesFromName and Pokemon.speciesFromName(id))
      if tonumber(n) then pcall(Pokemon.evolutions,tonumber(n)) end
    end
  end)
]=]
end

return M
