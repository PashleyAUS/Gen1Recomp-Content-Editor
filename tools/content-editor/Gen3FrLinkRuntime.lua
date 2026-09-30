-- Export source (not bytecode) for FireRed Maps (Gen3FrLink): the game side
-- of an Emerald mod that uses FireRed tilesets, maps and wild Pokemon.
--
-- The mod carries names only: tilesets "frlg__<FireRed tileset>" and map
-- layouts "frlg:<FireRed map>". Everything they point at is read here, on the
-- player's machine, from the player's own FireRed or LeafGreen import (the
-- runtime's firered/ or leafgreen/ cache). Without one the mod stops loading
-- with a message, so nothing FireRed-made ever shows up half there.
--
-- Nothing in the engine is changed. The tileset caches get a proxy that sends
-- native/frlg__<pair>/ reads to that import, the behaviour and wild
-- encounter tables get the import's rows for those tilesets (Emerald and
-- FireRed behaviours share the engine's numbering), and Gen3Map asks
-- `LayoutNative._editorFrLink.layout(source)` for FireRed layouts.
local M={}
M.PAIR="frlg__"
M.MAP="frlg:"
M.REGION="EM_KANTO_"

-- The player's FireRed or LeafGreen import: "firered/" or "leafgreen/", or
-- nil. Only a finished import of a known dump counts.
function M.find(readAt)
  local GV=require("src.core.GameVersion")
  for _,game in ipairs({"firered","leafgreen"}) do
    local prefix=GV.cachePrefix(game)
    local okR,marker=pcall(readAt,prefix.."rom-cache.complete")
    local sha=okR and type(marker)=="string" and marker:match("^rom%-cache%-v%d+%-"..game..":(%x+)")
    if sha then
      for _,rev in ipairs(GV.revisions(game)) do
        if rev.sha1==sha:lower() then return prefix,game end
      end
    end
  end
end

--- "…/native/frlg__X/…" -> "…/native/X/…", or nil for other paths.
function M.redirect(path)
  if type(path)~="string" then return nil end
  local out,n=path:gsub("/native/"..M.PAIR.."([^/]+)/","/native/%1/",1)
  return n>0 and out or nil
end

function M.install(mod,cfg)
  local CacheFs=require("src.import.CacheFs")
  local prefix=M.find(CacheFs.readAt)
  if not prefix then error(cfg.message,0) end
  local function read(rel) return CacheFs.readAt(prefix..rel) end
  local function lua(rel)
    local bytes=read(rel)
    local chunk=bytes and load(bytes,"="..rel,"t",{})
    if not chunk then return nil end
    local ok,value=pcall(chunk)
    return ok and type(value)=="table" and value or nil
  end
  local Runtime=require("src.mods.Runtime")
  local T=require("src.core.game3.tileset_native")
  local Layout=require("src.core.game3.layout_native")
  local NativePack=require("src.import.gba.native_pack")
  local Interactions=require("src.core.game3.scripting.interaction_scripts")
  local Encounters=require("src.core.game3.encounters")
  local NATIVE="data/generated/gba/native"

  -- Tiles and tile animations: frlg__ tileset folders read from the import.
  -- Atlases baked from them are not written anywhere.
  local function proxy(cache)
    if type(cache)~="table" or rawget(cache,"_editorFrLink") then return cache end
    return setmetatable({_editorFrLink=true},{__index=function(self,k)
      local v=cache[k]
      if type(v)~="function" then return v end
      return function(me,p,...)
        if me==self then me=cache end
        local fr=M.redirect(p)
        if fr then
          if k=="read" then return read(fr) end
          if k=="exists" then return read(fr)~=nil end
          if k=="write" then return false end
        end
        return v(me,p,...)
      end
    end})
  end
  local okA,Anim=pcall(require,"src.core.game3.tileset_anim")
  local function proxyAll()
    T._cache=proxy(T._cache)
    if okA and Anim then Anim._cache=proxy(Anim._cache) end
  end
  if not T._editorFrLinkDispatch then
    T._editorFrLinkDispatch=true
    local install=T.install
    T.install=function(...) return Runtime.call("editor.gen3.frlink.tiles",install,...) end
  end
  mod.hooks:wrap("editor.gen3.frlink.tiles",function(proceed,...)
    local a,b=proceed(...);proxyAll();return a,b
  end)
  proxyAll()

  -- Behaviours and wild encounter types of the import's tilesets.
  local pack
  local function objects()
    if pack==nil then pack=lua("data/generated/gba/objects/pack.lua") or false end
    return pack or nil
  end
  local function rows(all,kind)
    local p=objects()
    if type(all)~="table" or not p then return end
    for base,row in pairs(p[kind] or {}) do all[M.PAIR..base]=row end
  end
  if not Interactions._editorFrLinkDispatch then
    Interactions._editorFrLinkDispatch=true
    local install=Interactions.install
    Interactions.install=function(...) return Runtime.call("editor.gen3.frlink.behaviors",install,...) end
  end
  mod.hooks:wrap("editor.gen3.frlink.behaviors",function(proceed,...)
    local a,b=proceed(...);rows(Interactions.behaviors,"behaviors");return a,b
  end)
  if not Encounters._editorFrLinkDispatch then
    Encounters._editorFrLinkDispatch=true
    local install=Encounters.installEncounterTypes
    Encounters.installEncounterTypes=function(...) return Runtime.call("editor.gen3.frlink.encounters",install,...) end
  end
  mod.hooks:wrap("editor.gen3.frlink.encounters",function(proceed,...)
    local a,b=proceed(...);rows(Encounters._encounterTypes,"encounterTypes");return a,b
  end)
  rows(Interactions.behaviors,"behaviors")
  rows(Encounters._encounterTypes,"encounterTypes")

  -- Import region: FireRed's wild Pokemon on the EM_KANTO_ maps (the
  -- species numbers are the same in both games). The mod's own lists win.
  if cfg.region then
    local wild
    local function fillWild()
      local all=Encounters._tables
      if type(all)~="table" then return end
      if wild==nil then wild=lua("data/generated/gba/encounters.lua") or false end
      for key,t in pairs(wild or {}) do
        if type(key)=="string" and (key:sub(1,3)=="FR_" or key:sub(1,6)=="SEVII_") then
          local id=M.REGION..key:gsub("^FR_","")
          if all[id]==nil then all[id]=t end
        end
      end
    end
    if not Encounters._editorFrLinkWild then
      Encounters._editorFrLinkWild=true
      local base=Encounters.loadFromMod
      Encounters.loadFromMod=function(...) return Runtime.call("editor.gen3.frlink.wild",base,...) end
    end
    mod.hooks:wrap("editor.gen3.frlink.wild",function(proceed,...)
      local a,b=proceed(...);fillWild();return a,b
    end)
    fillWild()
  end

  -- FireRed map layouts, for Gen3Map's map layouts ("frlg:FR_…" sources).
  local manifest,layouts
  Layout._editorFrLink={
    layout=function(source)
      if type(source)~="string" or source:sub(1,#M.MAP)~=M.MAP then return nil end
      local id=source:sub(#M.MAP+1)
      layouts=layouts or {}
      if layouts[id]==nil then
        manifest=manifest or lua(NATIVE.."/manifest.lua") or {}
        local info=(manifest.layouts or {})[id]
        local blob=info and read(NATIVE.."/"..(info.file or ("layouts/"..id..".mid")))
        local decoded=blob and NativePack.decodeMidLayout(blob)
        layouts[id]=decoded and Layout.fromDecoded(decoded,id,M.PAIR..info.pair) or false
      end
      return layouts[id] or nil
    end,
  }
end

return M
