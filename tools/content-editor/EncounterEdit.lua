-- Shared wild-encounter editors (grass/water/fishing) for Maps + Encounters tabs.

local Kit = require("Kit")
local Theme = require("Theme")
local State = require("State")
local SpeciesPicker = require("SpeciesPicker")
local Generation = require("Generation")
local PAL = Theme.PAL

local EncounterEdit = {}

EncounterEdit.KINDS = {
  { id = "grass", label = "GRASS" },
  { id = "water", label = "WATER" },
  { id = "super", label = "SUPER" },
  { id = "old", label = "OLD" },
  { id = "good", label = "GOOD" },
}

EncounterEdit.KINDS_GEN2 = {
  { id = "grass", label = "GRASS" },
  { id = "water", label = "WATER" },
  { id = "fish", label = "FISH" },
  { id = "tree", label = "TREE" },
}

local TOD = { "MORN", "DAY", "NITE" }

local function copySlot(slot)
  if type(slot) ~= "table" then return { level = 5, species = "PIDGEY" } end
  local out = { level = slot.level, species = slot.species }
  if type(slot.chance) == "number" then out.chance = slot.chance end
  if type(slot.form) == "string" and slot.form ~= "" then out.form = slot.form end
  if type(slot.timeGroup) == "number" then out.timeGroup = slot.timeGroup end
  if type(slot.day) == "table" then out.day = copySlot(slot.day) end
  if type(slot.nite) == "table" then out.nite = copySlot(slot.nite) end
  return out
end

function EncounterEdit.cloneSlots(slots)
  local out = {}
  for i, slot in ipairs(slots or {}) do
    out[i] = copySlot(slot)
  end
  return out
end

local function cloneTodSlots(slots)
  if type(slots) ~= "table" then return { MORN = {}, DAY = {}, NITE = {} } end
  if slots.MORN or slots.DAY or slots.NITE then
    local out = {}
    for _, tod in ipairs(TOD) do
      out[tod] = EncounterEdit.cloneSlots(slots[tod])
    end
    return out
  end
  -- Flat Gen1-style list → copy into all ToD buckets.
  local flat = EncounterEdit.cloneSlots(slots)
  return { MORN = flat, DAY = EncounterEdit.cloneSlots(flat),
    NITE = EncounterEdit.cloneSlots(flat) }
end

function EncounterEdit.cloneEncounters(enc)
  if type(enc) ~= "table" then return nil end
  local out = {}
  for _, kind in ipairs({ "grass", "water" }) do
    local band = enc[kind]
    if type(band) == "table" then
      if band.rates or (band.slots and band.slots.MORN) then
        out[kind] = {
          map = band.map,
          rates = band.rates and {
            MORN = band.rates.MORN, DAY = band.rates.DAY, NITE = band.rates.NITE,
          } or nil,
          rate = band.rate,
          slots = cloneTodSlots(band.slots),
        }
        if kind == "water" then
          out[kind].slots = EncounterEdit.cloneSlots(
            type(band.slots) == "table" and not band.slots.MORN and band.slots
              or (band.slots and band.slots.DAY) or band.slots)
          out[kind].rates = nil
        end
      else
        out[kind] = {
          rate = band.rate or 0,
          slots = EncounterEdit.cloneSlots(band.slots),
        }
      end
    end
  end
  return out
end

function EncounterEdit.resolveEncounters(S, mapId, mapDef)
  if mapDef and mapDef.encounters then return mapDef.encounters, true end
  if Generation.isGen2(S) then
    local root = S.data and (S.data.gen2Encounters or S.data.encounters)
    if type(root) == "table" and (root.grass or root.water) then
      return {
        grass = root.grass and root.grass[mapId],
        water = root.water and root.water[mapId],
      }, false
    end
    return nil, false
  end
  if S.data and S.data.encounters and S.data.encounters[mapId] then
    return S.data.encounters[mapId], false
  end
  return nil, false
end

function EncounterEdit.resolveSuperRod(S, mapId, mapDef)
  if mapDef and mapDef.superRod then return mapDef.superRod, true end
  if S.data and S.data.field and S.data.field.superRod
      and S.data.field.superRod[mapId] then
    return S.data.field.superRod[mapId], false
  end
  return nil, false
end

local function defaultFishing(S)
  local FieldDefaults = require("src.world.FieldDefaults")
  return FieldDefaults.field(S.data, "fishing") or {}
end

function EncounterEdit.resolveOldRod(S)
  State.ensureProjectFields(S.project)
  if S.project.fishing and S.project.fishing.OLD_ROD then
    return S.project.fishing.OLD_ROD, true
  end
  return defaultFishing(S).OLD_ROD, false
end

function EncounterEdit.resolveGoodRod(S)
  State.ensureProjectFields(S.project)
  if S.project.fishing and S.project.fishing.GOOD_ROD then
    return S.project.fishing.GOOD_ROD, true
  end
  return defaultFishing(S).GOOD_ROD, false
end

local function ensureEncounterBand(map, kind)
  map.encounters = map.encounters or {}
  if not map.encounters[kind] then
    map.encounters[kind] = { rate = 0, slots = {} }
  end
  map.encounters[kind].slots = map.encounters[kind].slots or {}
  return map.encounters[kind]
end

local function seedGen2Band(S, map, mapId, kind)
  if map.encounters and type(map.encounters[kind]) == "table" then
    return map.encounters[kind]
  end
  -- Prefer the global Gold grass/water tables even if map.encounters is an
  -- empty owned stub (resolveEncounters would otherwise short-circuit).
  local root = S and S.data and (S.data.gen2Encounters or S.data.encounters)
  local band = type(root) == "table" and root[kind] and root[kind][mapId]
  if type(band) == "table" then
    local cloned = EncounterEdit.cloneEncounters({ [kind] = band })
    return cloned and cloned[kind]
  end
  return nil
end

local function ensureGen2Grass(map, mapId, S)
  map.encounters = map.encounters or {}
  local g = map.encounters.grass
  if type(g) ~= "table" or not g.rates then
    g = seedGen2Band(S, map, mapId, "grass")
    if type(g) ~= "table" or not g.rates then
      g = {
        map = mapId,
        rates = { MORN = 25, DAY = 25, NITE = 25 },
        slots = {
          MORN = { { level = 3, species = "PIDGEY" } },
          DAY = { { level = 3, species = "PIDGEY" } },
          NITE = { { level = 3, species = "HOOTHOOT" } },
        },
      }
    end
    map.encounters.grass = g
  end
  g.slots = cloneTodSlots(g.slots)
  g.rates = g.rates or { MORN = 25, DAY = 25, NITE = 25 }
  return g
end

local function ensureGen2Water(map, mapId, S)
  map.encounters = map.encounters or {}
  local w = map.encounters.water
  local needs = type(w) ~= "table" or type(w.slots) ~= "table"
    or (type(w.slots) == "table" and w.slots.MORN ~= nil)
  if needs then
    w = seedGen2Band(S, map, mapId, "water")
    local flatOk = type(w) == "table" and type(w.slots) == "table"
      and w.slots.MORN == nil
    if not flatOk then
      w = {
        map = mapId,
        rate = 5,
        slots = { { level = 5, species = "TENTACOOL" } },
      }
    end
    map.encounters.water = w
  end
  w.slots = w.slots or {}
  return w
end

local function field(App, id, x, y, w, h, value, ph)
  local v = Kit.textfield(id, x, y, w, h, value, ph)
  if v ~= tostring(value or "") then App.markDirty() end
  return v
end

local function readForm(App, id, x, y, w, h, current)
  local v = field(App, id, x, y, w, h, current or "", "FORM")
  v = v:upper():gsub("%s+", "_"):gsub("[^A-Z0-9_]", "")
  if v == "" or v == "FORM" then return nil end
  return v
end

local function drawSlotRows(S, App, px, py, propW, listBottom, fh, s,
    kindKey, slots, onChange, onDelete, maxSlots)
  Kit.text("micro", "Slots (level, species, form)", px + 10 * s, py, PAL.caption)
  py = py + 16 * s
  for si = 1, #(slots or {}) do
    if py + fh > listBottom - 36 * s then break end
    local slot = slots[si]
    local lx = px + 10 * s
    local lvl = tonumber(field(App, "enc_lv_" .. kindKey .. si, lx, py, 40 * s, fh,
      tostring(slot.level or 1), "1")) or 1
    local formW = 56 * s
    local spW = math.max(70 * s, propW - (lx - px) - 48 * s - formW - 42 * s - 12 * s)
    local sp = slot.species or "PIDGEY"
    SpeciesPicker.field(S, {
      x = lx + 48 * s, y = py, w = spW, h = fh,
      current = sp,
      title = "ENCOUNTER SPECIES",
      onPick = function(id)
        onChange(si, {
          level = math.max(1, slot.level or 1), species = id, form = slot.form,
        })
      end,
    })
    local formVal = readForm(App, "enc_fm_" .. kindKey .. si,
      lx + 48 * s + spW + 4 * s, py, formW, fh, slot.form)
    if lvl ~= (slot.level or 1) or formVal ~= (slot.form or nil) then
      onChange(si, { level = math.max(1, lvl), species = sp, form = formVal })
    end
    if Kit.button(px + propW - 42 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      onDelete(si)
      break
    end
    py = py + math.max(fh, 26 * s) + 4 * s
  end
  if #(slots or {}) < (maxSlots or 10) and py + 30 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "+ Slot", { kind = "accent" }) then
      onChange(#(slots or {}) + 1, { level = 5, species = "MAGIKARP" }, true)
    end
    py = py + 32 * s
  end
  return py
end

-- Gold `species = 0` is TimeFishGroups: the level byte is the group index,
-- and day vs nite pick the real mon. pret/pokegold data/wild/fish.asm.
local GOLD_TIME_FISH = {
  [0] = { day = "CORSOLA", dayLevel = 20, nite = "STARYU", niteLevel = 20 },
  [1] = { day = "CORSOLA", dayLevel = 40, nite = "STARYU", niteLevel = 40 },
  [2] = { day = "SHELLDER", dayLevel = 20, nite = "SHELLDER", niteLevel = 20 },
  [3] = { day = "SHELLDER", dayLevel = 40, nite = "SHELLDER", niteLevel = 40 },
  [4] = { day = "GOLDEEN", dayLevel = 20, nite = "GOLDEEN", niteLevel = 20 },
  [5] = { day = "GOLDEEN", dayLevel = 40, nite = "GOLDEEN", niteLevel = 40 },
  [6] = { day = "POLIWAG", dayLevel = 20, nite = "POLIWAG", niteLevel = 20 },
  [7] = { day = "POLIWAG", dayLevel = 40, nite = "POLIWAG", niteLevel = 40 },
  [8] = { day = "DRATINI", dayLevel = 20, nite = "DRATINI", niteLevel = 20 },
  [9] = { day = "DRATINI", dayLevel = 40, nite = "DRATINI", niteLevel = 40 },
  [10] = { day = "QWILFISH", dayLevel = 20, nite = "QWILFISH", niteLevel = 20 },
  [11] = { day = "QWILFISH", dayLevel = 40, nite = "QWILFISH", niteLevel = 40 },
  [12] = { day = "REMORAID", dayLevel = 20, nite = "REMORAID", niteLevel = 20 },
  [13] = { day = "REMORAID", dayLevel = 40, nite = "REMORAID", niteLevel = 40 },
  [14] = { day = "GYARADOS", dayLevel = 20, nite = "GYARADOS", niteLevel = 20 },
  [15] = { day = "GYARADOS", dayLevel = 40, nite = "GYARADOS", niteLevel = 40 },
  [16] = { day = "DRATINI", dayLevel = 10, nite = "DRATINI", niteLevel = 10 },
  [17] = { day = "DRATINI", dayLevel = 10, nite = "DRATINI", niteLevel = 10 },
  [18] = { day = "HORSEA", dayLevel = 20, nite = "HORSEA", niteLevel = 20 },
  [19] = { day = "HORSEA", dayLevel = 40, nite = "HORSEA", niteLevel = 40 },
  [20] = { day = "TENTACOOL", dayLevel = 20, nite = "TENTACOOL", niteLevel = 20 },
  [21] = { day = "TENTACOOL", dayLevel = 40, nite = "TENTACOOL", niteLevel = 40 },
}

local function isTimeFishSlot(slot)
  local sp = slot and slot.species
  return sp == 0 or sp == "0"
end

local function timePair(row, which)
  if type(row) ~= "table" then return nil, nil end
  local slot = row[which]
  if type(slot) == "table" then
    return slot.species or slot[1], slot.level or slot[2]
  end
  if which == "day" then
    local species = row.day or row.daySpecies or row.species or row[1]
    if type(species) == "table" then return timePair({ day = species }, "day") end
    return species, row.dayLevel or row.level or row[2]
  end
  local species = row.nite or row.niteSpecies or row[3] or row.day or row[1]
  if type(species) == "table" then return timePair({ nite = species }, "nite") end
  return species, row.niteLevel or row[4] or row.dayLevel or row[2]
end

local function timeFishSource(S)
  local owned = S and S.project and S.project.timeFishGroups
  if type(owned) == "table" and next(owned) then return owned end
  local root = S and S.data and (S.data.gen2Encounters or S.data.encounters)
  local groups = root and (root.timeFishGroups or root.fishTimeGroups)
  if type(groups) == "table" and next(groups) then return groups end
  return nil
end

local function timeFishGroup(S, index)
  index = tonumber(index) or 0
  local groups = timeFishSource(S)
  if type(groups) == "table" then
    local row = groups[index]
    if type(row) ~= "table" then row = groups[tostring(index)] end
    if type(row) ~= "table" then row = groups[index + 1] end
    if type(row) == "table" then
      local day, dayLevel = timePair(row, "day")
      local nite, niteLevel = timePair(row, "nite")
      return { day = day, dayLevel = dayLevel, nite = nite, niteLevel = niteLevel }
    end
  end
  return GOLD_TIME_FISH[index]
end

-- Fishing / headbutt-tree slots carry a chance (0-255) alongside level+species.
local function drawChanceSlotRows(S, App, px, py, propW, listBottom, fh, s,
    kindKey, slots, onChange, onDelete, maxSlots)
  Kit.text("micro", "Slots (chance, level, species, form)", px + 10 * s, py, PAL.caption)
  py = py + 16 * s
  for si = 1, #(slots or {}) do
    if py + fh > listBottom - 36 * s then break end
    local slot = slots[si]
    local lx = px + 10 * s
    local timeSlot = isTimeFishSlot(slot)
    local tg = timeSlot and timeFishGroup(S, slot.level)
    local shownLevel = (tg and (tg.dayLevel or tg.niteLevel)) or (slot.level or 1)
    local shownSpecies = slot.species or "MAGIKARP"
    local shownLabel = nil
    if tg then
      shownSpecies = tg.day or shownSpecies
      if tg.nite and tg.nite ~= tg.day then
        shownLabel = tostring(tg.day) .. "/" .. tostring(tg.nite)
      else
        shownLabel = tostring(tg.day or "TIME")
      end
    elseif timeSlot then
      shownSpecies = nil
      shownLabel = "TIME " .. tostring(slot.level or 0)
    end
    local chance = tonumber(field(App, "enc_ch_" .. kindKey .. si, lx, py, 44 * s, fh,
      tostring(slot.chance or 0), "0")) or 0
    local lvl = tonumber(field(App, "enc_cl_" .. kindKey .. si, lx + 48 * s, py, 40 * s, fh,
      tostring(shownLevel), "1")) or 1
    local formW = 56 * s
    local spW = math.max(64 * s, propW - (lx - px) - 96 * s - formW - 42 * s - 12 * s)
    SpeciesPicker.field(S, {
      x = lx + 92 * s, y = py, w = spW, h = fh,
      current = shownSpecies,
      label = shownLabel,
      title = "ENCOUNTER SPECIES",
      tooltip = tg and "Gen 2 time-of-day fish (day / night). Edit the pair on the Time fish tab, or pick a species to make this a fixed slot."
        or nil,
      onPick = function(id)
        onChange(si, {
          chance = math.max(0, math.min(255, slot.chance or 0)),
          level = math.max(1, shownLevel or 1), species = id, form = slot.form,
        })
      end,
    })
    local formVal = readForm(App, "enc_cfm_" .. kindKey .. si,
      lx + 92 * s + spW + 4 * s, py, formW, fh, slot.form)
    if chance ~= (slot.chance or 0) or lvl ~= shownLevel
        or formVal ~= (slot.form or nil) then
      if timeSlot and lvl == shownLevel then
        onChange(si, {
          chance = math.max(0, math.min(255, chance)),
          level = slot.level, species = 0, form = formVal,
        })
      else
        onChange(si, {
          chance = math.max(0, math.min(255, chance)),
          level = math.max(1, lvl),
          species = (tg and tg.day) or slot.species or "MAGIKARP",
          form = formVal,
        })
      end
    end
    if Kit.button(px + propW - 42 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      onDelete(si)
      break
    end
    py = py + math.max(fh, 26 * s) + 4 * s
  end
  if #(slots or {}) < (maxSlots or 10) and py + 30 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "+ Slot", { kind = "accent" }) then
      onChange(#(slots or {}) + 1, { chance = 0, level = 5, species = "MAGIKARP" }, true)
    end
    py = py + 32 * s
  end
  return py
end

local FISH_RODS = { "old", "good", "super" }

-- Clone project.fishGroups[group] from data.gen2Encounters/encounters on
-- first edit so authored slots start from the vanilla table.
local function ensureFishGroup(S, group)
  S.project.fishGroups = S.project.fishGroups or {}
  if S.project.fishGroups[group] then return S.project.fishGroups[group] end
  local root = S.data and (S.data.gen2Encounters or S.data.encounters)
  local base = type(root) == "table" and root.fishGroups and root.fishGroups[group]
  local cloned = { old = {}, good = {}, super = {} }
  if type(base) == "table" then
    for _, rod in ipairs(FISH_RODS) do
      local rows = base[rod]
      if type(rows) == "table" then
        for i, row in ipairs(rows) do
          cloned[rod][i] = copySlot(row)
        end
      end
    end
  end
  S.project.fishGroups[group] = cloned
  return cloned
end

-- Clone project.treeSets[setId] from data.gen2Encounters/encounters on
-- first edit (shared by headbutt trees and Rock Smash rocks).
local function ensureTreeSet(S, setId)
  S.project.treeSets = S.project.treeSets or {}
  if S.project.treeSets[setId] then return S.project.treeSets[setId] end
  local root = S.data and (S.data.gen2Encounters or S.data.encounters)
  local base = type(root) == "table" and root.treeSets and root.treeSets[setId]
  local cloned = { common = {}, rare = {} }
  if type(base) == "table" then
    for _, listName in ipairs({ "common", "rare" }) do
      local rows = base[listName]
      if type(rows) == "table" then
        for i, row in ipairs(rows) do
          cloned[listName][i] = copySlot(row)
        end
      end
    end
  end
  S.project.treeSets[setId] = cloned
  return cloned
end

local function collectTreeSetIds(S, root)
  local seen, ids = {}, {}
  if type(root) == "table" and type(root.treeSets) == "table" then
    for id in pairs(root.treeSets) do
      if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
  end
  for id in pairs(S.project.treeSets or {}) do
    if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

-- Advance to the next known set id; starts at the first id when cur is
-- unset or unrecognized (e.g. "(none)").
local function cycleSetId(list, cur)
  if not list or #list == 0 then return cur end
  local idx = 0
  for i, v in ipairs(list) do
    if v == cur then idx = i; break end
  end
  local n = idx + 1
  if n > #list then n = 1 end
  return list[n]
end

local function isKindKnown(list, id)
  for _, k in ipairs(list) do
    if k.id == id then return true end
  end
  return false
end

local function drawGen2Wild(S, map, mutate, App, px, py, propW, listBottom, fh, s)
  local mapId = map.id or S.mapId
  local enc = EncounterEdit.resolveEncounters(S, mapId, map)
  S.mapEncKind = isKindKnown(EncounterEdit.KINDS_GEN2, S.mapEncKind)
    and S.mapEncKind or "grass"
  S.mapEncTod = S.mapEncTod or "DAY"
  local sx, sy = px + 10 * s, py
  for _, kind in ipairs(EncounterEdit.KINDS_GEN2) do
    local on = S.mapEncKind == kind.id
    local bw = Kit.textWidth("micro", kind.label) + 14 * s
    if Kit.chip(sx, sy, bw, fh, kind.label, on, PAL.green) then
      S.mapEncKind = kind.id
    end
    sx = sx + bw + 4 * s
  end
  py = sy + fh + 8 * s

  local kind = S.mapEncKind
  if kind == "grass" then
    local band = enc and enc.grass
    if not band then
      Kit.text("micro", "No grass encounters (ToD) on this map.",
        px + 10 * s, py, PAL.faint)
      py = py + 18 * s
      if Kit.button(px + 10 * s, py, propW - 20 * s, 28 * s, "+ Add grass",
          { kind = "good" }) then
        map = mutate()
        ensureGen2Grass(map, mapId, S)
        App.markDirty()
      end
      return py + 36 * s
    end
    Kit.text("micro", "Rates MORN / DAY / NITE", px + 10 * s, py, PAL.caption)
    py = py + 14 * s
    local rates = band.rates or {}
    local rx = px + 10 * s
    for _, tod in ipairs(TOD) do
      local cur = rates[tod] or 0
      local v = tonumber(field(App, "enc_g2r_" .. tod, rx, py, 50 * s, fh,
        tostring(cur), "0")) or 0
      if v ~= cur then
        map = mutate()
        local g = ensureGen2Grass(map, mapId, S)
        g.rates = g.rates or {}
        g.rates[tod] = math.max(0, math.min(255, v))
      end
      Kit.text("micro", tod, rx, py + fh + 2 * s, PAL.faint)
      rx = rx + 58 * s
    end
    py = py + fh + 18 * s
    sx = px + 10 * s
    for _, tod in ipairs(TOD) do
      local on = S.mapEncTod == tod
      local bw = Kit.textWidth("micro", tod) + 14 * s
      if Kit.chip(sx, py, bw, fh, tod, on, PAL.blue) then
        S.mapEncTod = tod
      end
      sx = sx + bw + 4 * s
    end
    py = py + fh + 8 * s
    local tod = S.mapEncTod
    local slots = (band.slots and band.slots[tod]) or {}
    py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s,
      "g2g_" .. tod, slots,
      function(si, slot, isAdd)
        map = mutate()
        local g = ensureGen2Grass(map, mapId, S)
        g.slots[tod] = g.slots[tod] or {}
        if isAdd then g.slots[tod][#g.slots[tod] + 1] = slot
        else g.slots[tod][si] = slot end
        App.markDirty()
      end,
      function(si)
        map = mutate()
        local g = ensureGen2Grass(map, mapId, S)
        table.remove(g.slots[tod], si)
        App.markDirty()
      end, 7)
    if py + 36 * s <= listBottom then
      if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "Clear grass",
          { kind = "ghost" }) then
        map = mutate()
        if map.encounters then map.encounters.grass = nil end
        App.markDirty()
      end
      py = py + 36 * s
    end
    return py
  end

  if kind == "fish" then
    local group = map.fishGroup
    Kit.text("micro", "Map fish group: " .. tostring(group or "FISHGROUP_NONE")
      .. " (edit on the Group / Map header row above)", px + 10 * s, py, PAL.muted)
    py = py + 20 * s
    if not group or group == "" or group == "FISHGROUP_NONE" then
      Kit.text("micro", "No fish group set on this map.", px + 10 * s, py, PAL.faint)
      return py + 20 * s
    end
    S.mapEncRod = (S.mapEncRod == "old" or S.mapEncRod == "good" or S.mapEncRod == "super")
      and S.mapEncRod or "old"
    sx = px + 10 * s
    for _, rod in ipairs(FISH_RODS) do
      local on = S.mapEncRod == rod
      local label = rod:upper()
      local bw = Kit.textWidth("micro", label) + 14 * s
      if Kit.chip(sx, py, bw, fh, label, on, PAL.blue) then
        S.mapEncRod = rod
      end
      sx = sx + bw + 4 * s
    end
    py = py + fh + 8 * s
    local fg = ensureFishGroup(S, group)
    local rod = S.mapEncRod
    return drawChanceSlotRows(S, App, px, py, propW, listBottom, fh, s,
      "fish_" .. group .. "_" .. rod, fg[rod],
      function(si, slot, isAdd)
        fg[rod] = fg[rod] or {}
        if isAdd then fg[rod][#fg[rod] + 1] = slot else fg[rod][si] = slot end
        App.markDirty()
      end,
      function(si)
        table.remove(fg[rod], si)
        App.markDirty()
      end, 10)
  end

  if kind == "tree" then
    S.project.trees = S.project.trees or {}
    S.project.rocks = S.project.rocks or {}
    local root = S.data and (S.data.gen2Encounters or S.data.encounters)
    local setIds = collectTreeSetIds(S, root)

    Kit.text("micro", "Tree set (headbutt)", px + 10 * s, py, PAL.caption)
    py = py + 16 * s
    local curTree = S.project.trees[mapId]
      or (type(root) == "table" and root.trees and root.trees[mapId])
    if Kit.button(px + 10 * s, py, propW - 20 * s, 28 * s,
        Kit.ellipsize("small", tostring(curTree or "(none)"), propW - 30 * s),
        { kind = "ghost", tooltip = "Cycle headbutt tree set for this map" }) then
      S.project.trees[mapId] = cycleSetId(setIds, curTree)
      App.markDirty()
    end
    py = py + 32 * s

    Kit.text("micro", "Rock set (Rock Smash, optional)", px + 10 * s, py, PAL.caption)
    py = py + 16 * s
    local curRock = S.project.rocks[mapId]
      or (type(root) == "table" and root.rocks and root.rocks[mapId])
    if Kit.button(px + 10 * s, py, propW - 92 * s, 28 * s,
        Kit.ellipsize("small", tostring(curRock or "(none)"), propW - 102 * s),
        { kind = "ghost", tooltip = "Cycle Rock Smash set for this map" }) then
      S.project.rocks[mapId] = cycleSetId(setIds, curRock)
      App.markDirty()
    end
    if S.project.rocks[mapId] and Kit.button(px + propW - 78 * s, py, 68 * s, 28 * s,
        "Clear", { kind = "danger" }) then
      S.project.rocks[mapId] = nil
      App.markDirty()
    end
    py = py + 32 * s

    local setId = S.project.trees[mapId]
      or (type(root) == "table" and root.trees and root.trees[mapId])
    if not setId then
      Kit.text("micro", "No tree set on this map.", px + 10 * s, py, PAL.faint)
      return py + 20 * s
    end
    local ts = ensureTreeSet(S, setId)
    S.mapEncTreeList = (S.mapEncTreeList == "common" or S.mapEncTreeList == "rare")
      and S.mapEncTreeList or "common"
    sx = px + 10 * s
    for _, listName in ipairs({ "common", "rare" }) do
      local on = S.mapEncTreeList == listName
      local label = listName:upper()
      local bw = Kit.textWidth("micro", label) + 14 * s
      if Kit.chip(sx, py, bw, fh, label, on, PAL.blue) then
        S.mapEncTreeList = listName
      end
      sx = sx + bw + 4 * s
    end
    py = py + fh + 8 * s
    local listName = S.mapEncTreeList
    return drawChanceSlotRows(S, App, px, py, propW, listBottom, fh, s,
      "tree_" .. setId .. "_" .. listName, ts[listName],
      function(si, slot, isAdd)
        ts[listName] = ts[listName] or {}
        if isAdd then ts[listName][#ts[listName] + 1] = slot else ts[listName][si] = slot end
        App.markDirty()
      end,
      function(si)
        table.remove(ts[listName], si)
        App.markDirty()
      end, 10)
  end

  -- water
  local band = enc and enc.water
  if not band then
    Kit.text("micro", "No water encounters on this map.",
      px + 10 * s, py, PAL.faint)
    py = py + 18 * s
    if Kit.button(px + 10 * s, py, propW - 20 * s, 28 * s, "+ Add water",
        { kind = "good" }) then
      map = mutate()
      ensureGen2Water(map, mapId, S)
      App.markDirty()
    end
    return py + 36 * s
  end
  Kit.text("micro", "Rate (0-255)", px + 10 * s, py, PAL.caption)
  py = py + 14 * s
  local rate = tonumber(field(App, "enc_g2w_rate", px + 10 * s, py, 70 * s, fh,
    tostring(band.rate or 0), "0")) or 0
  if rate ~= (band.rate or 0) then
    map = mutate()
    ensureGen2Water(map, mapId, S).rate = math.max(0, math.min(255, rate))
  end
  py = py + fh + 8 * s
  py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s, "g2w", band.slots,
    function(si, slot, isAdd)
      map = mutate()
      local w = ensureGen2Water(map, mapId, S)
      if isAdd then w.slots[#w.slots + 1] = slot else w.slots[si] = slot end
      App.markDirty()
    end,
    function(si)
      map = mutate()
      table.remove(ensureGen2Water(map, mapId, S).slots, si)
      App.markDirty()
    end, 3)
  if py + 36 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "Clear water",
        { kind = "ghost" }) then
      map = mutate()
      if map.encounters then map.encounters.water = nil end
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

-- Draw wild encounter editor for a map. mutate() must return an owned map def.
function EncounterEdit.drawWild(S, map, mutate, App, px, py, propW, listBottom, fh, s)
  if not map then
    Kit.text("micro", "Select a map.", px + 10 * s, py, PAL.faint)
    return py + 20 * s
  end
  State.ensureProjectFields(S.project)
  if Generation.isGen2(S) then
    return drawGen2Wild(S, map, mutate, App, px, py, propW, listBottom, fh, s)
  end
  local mapId = map.id or S.mapId
  local enc = EncounterEdit.resolveEncounters(S, mapId, map)
  local superSlots = EncounterEdit.resolveSuperRod(S, mapId, map)

  S.mapEncKind = S.mapEncKind or "grass"
  local sx, sy = px + 10 * s, py
  for _, kind in ipairs(EncounterEdit.KINDS) do
    local on = S.mapEncKind == kind.id
    local bw = Kit.textWidth("micro", kind.label) + 14 * s
    if sx + bw > px + propW - 10 * s then
      sx = px + 10 * s
      sy = sy + fh + 4 * s
    end
    if Kit.chip(sx, sy, bw, fh, kind.label, on, PAL.green) then
      S.mapEncKind = kind.id
    end
    sx = sx + bw + 4 * s
  end
  py = sy + fh + 10 * s

  local kind = S.mapEncKind

  if kind == "grass" or kind == "water" then
    local band = enc and enc[kind]
    if not band then
      Kit.text("micro", "No " .. kind .. " encounters on this map.",
        px + 10 * s, py, PAL.faint)
      py = py + 18 * s
      if Kit.button(px + 10 * s, py, propW - 20 * s, 28 * s, "+ Add " .. kind,
          { kind = "good" }) then
        map = mutate()
        local b = ensureEncounterBand(map, kind)
        b.rate = kind == "grass" and 25 or 5
        b.slots = {
          { level = kind == "grass" and 3 or 5,
            species = kind == "grass" and "PIDGEY" or "TENTACOOL" },
        }
        App.markDirty()
      end
      return py + 36 * s
    end

    Kit.text("micro", "Rate (0-255)", px + 10 * s, py, PAL.caption)
    py = py + 14 * s
    local rate = tonumber(field(App, "enc_rate_" .. kind, px + 10 * s, py, 70 * s, fh,
      tostring(band.rate or 0), "0")) or 0
    if rate ~= (band.rate or 0) then
      map = mutate()
      ensureEncounterBand(map, kind).rate = math.max(0, math.min(255, rate))
    end
    py = py + fh + 8 * s

    py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s, kind, band.slots,
      function(si, slot, isAdd)
        map = mutate()
        local b = ensureEncounterBand(map, kind)
        if isAdd then b.slots[#b.slots + 1] = slot
        else b.slots[si] = slot end
        App.markDirty()
      end,
      function(si)
        map = mutate()
        table.remove(ensureEncounterBand(map, kind).slots, si)
        App.markDirty()
      end, 10)

    if py + 36 * s <= listBottom then
      if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "Clear " .. kind,
          { kind = "ghost" }) then
        map = mutate()
        if map.encounters then map.encounters[kind] = nil end
        App.markDirty()
      end
      py = py + 36 * s
    end
    return py

  elseif kind == "super" then
    Kit.text("micro", "Super Rod group for this map (field.superRod).",
      px + 10 * s, py, PAL.muted)
    py = py + 18 * s
    if not superSlots then
      Kit.text("micro", "No Super Rod table here.", px + 10 * s, py, PAL.faint)
      py = py + 18 * s
      if Kit.button(px + 10 * s, py, propW - 20 * s, 28 * s, "+ Add Super Rod",
          { kind = "good" }) then
        map = mutate()
        map.superRod = { { level = 15, species = "POLIWAG" } }
        App.markDirty()
      end
      return py + 36 * s
    end
    py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s, "super", superSlots,
      function(si, slot, isAdd)
        map = mutate()
        map.superRod = map.superRod or EncounterEdit.cloneSlots(superSlots)
        if isAdd then map.superRod[#map.superRod + 1] = slot
        else map.superRod[si] = slot end
        App.markDirty()
      end,
      function(si)
        map = mutate()
        map.superRod = map.superRod or EncounterEdit.cloneSlots(superSlots)
        table.remove(map.superRod, si)
        App.markDirty()
      end, 10)
    if py + 36 * s <= listBottom then
      if Kit.button(px + 10 * s, py, 110 * s, 28 * s, "Clear Super",
          { kind = "ghost" }) then
        map = mutate()
        map.superRod = {}
        App.markDirty()
      end
      py = py + 36 * s
    end
    return py

  elseif kind == "old" then
    Kit.text("micro", "Old Rod (global -- always hooks this mon).",
      px + 10 * s, py, PAL.muted)
    py = py + 18 * s
    local def = select(1, EncounterEdit.resolveOldRod(S))
      or { always = { species = "MAGIKARP", level = 5 } }
    local always = def.always or { species = "MAGIKARP", level = 5 }
    Kit.text("micro", "Level", px + 10 * s, py, PAL.caption)
    py = py + 14 * s
    local lvl = tonumber(field(App, "enc_old_lv", px + 10 * s, py, 50 * s, fh,
      tostring(always.level or 5), "5")) or 5
    local sp = always.species or "MAGIKARP"
    local formW = 56 * s
    SpeciesPicker.field(S, {
      x = px + 70 * s, y = py, w = math.max(80 * s, propW - 90 * s - formW), h = fh,
      current = sp,
      title = "OLD ROD SPECIES",
      onPick = function(id)
        S.project.fishing.OLD_ROD = {
          always = {
            level = math.max(1, always.level or 5), species = id, form = always.form,
          },
        }
        App.markDirty()
      end,
    })
    local formVal = readForm(App, "enc_old_fm",
      px + propW - formW - 8 * s, py, formW, fh, always.form)
    if lvl ~= (always.level or 5) or formVal ~= (always.form or nil) then
      S.project.fishing.OLD_ROD = {
        always = { level = math.max(1, lvl), species = sp, form = formVal },
      }
      App.markDirty()
    end
    py = py + fh + 10 * s
    if S.project.fishing.OLD_ROD
        and Kit.button(px + 10 * s, py, 120 * s, 28 * s, "Revert Old",
          { kind = "danger" }) then
      S.project.fishing.OLD_ROD = nil
      App.markDirty()
    end
    return py + 36 * s
  end

  -- good
  Kit.text("micro", "Good Rod (global pool -- ~1/3 bite).",
    px + 10 * s, py, PAL.muted)
  py = py + 18 * s
  local def = select(1, EncounterEdit.resolveGoodRod(S)) or {
    pool = {
      { species = "GOLDEEN", level = 10 },
      { species = "POLIWAG", level = 10 },
    },
  }
  local pool = def.pool or {}
  py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s, "good", pool,
    function(si, slot, isAdd)
      local cur = EncounterEdit.resolveGoodRod(S)
      local base = (cur and cur.pool)
        and EncounterEdit.cloneSlots(cur.pool)
        or EncounterEdit.cloneSlots(pool)
      if isAdd then base[#base + 1] = slot else base[si] = slot end
      S.project.fishing.GOOD_ROD = { pool = base }
      App.markDirty()
    end,
    function(si)
      local cur = EncounterEdit.resolveGoodRod(S)
      local base = (cur and cur.pool)
        and EncounterEdit.cloneSlots(cur.pool)
        or EncounterEdit.cloneSlots(pool)
      table.remove(base, si)
      S.project.fishing.GOOD_ROD = { pool = base }
      App.markDirty()
    end, 8)
  if S.project.fishing.GOOD_ROD and py + 36 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 120 * s, 28 * s, "Revert Good",
        { kind = "danger" }) then
      S.project.fishing.GOOD_ROD = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

-- Fallback when the cache has no encounters.bugContest. Same eleven rows
-- BugContest.MONS uses, including the chance-255 fallthrough.
local BUG_CONTEST_FALLBACK = {
  { chance = 20, species = "CATERPIE", min = 7, max = 18 },
  { chance = 20, species = "WEEDLE", min = 7, max = 18 },
  { chance = 10, species = "METAPOD", min = 9, max = 18 },
  { chance = 10, species = "KAKUNA", min = 9, max = 18 },
  { chance = 5, species = "BUTTERFREE", min = 12, max = 15 },
  { chance = 5, species = "BEEDRILL", min = 12, max = 15 },
  { chance = 10, species = "VENONAT", min = 10, max = 16 },
  { chance = 10, species = "PARAS", min = 10, max = 17 },
  { chance = 5, species = "SCYTHER", min = 13, max = 14 },
  { chance = 5, species = "PINSIR", min = 13, max = 14 },
  { chance = 255, species = "VENOMOTH", min = 30, max = 40 },
}

function EncounterEdit.vanillaBugContest(S)
  local root = S and S.data and (S.data.gen2Encounters or S.data.encounters)
  local rows = root and root.bugContest
  if type(rows) == "table" and #rows > 0 then return rows end
  return BUG_CONTEST_FALLBACK
end

local function copyContestRow(row)
  row = type(row) == "table" and row or {}
  local minL = math.max(1, math.min(100, tonumber(row.min) or 1))
  local maxL = math.max(minL, math.min(100, tonumber(row.max) or minL))
  local species = row.species
  if type(species) ~= "string" or species == "" then species = "CATERPIE" end
  return {
    chance = math.max(0, math.min(255, tonumber(row.chance) or 0)),
    species = species,
    min = minL,
    max = maxL,
  }
end

-- Copy the vanilla pool into the project on the first edit.
function EncounterEdit.ensureBugContest(S)
  if type(S.project.bugContest) == "table" then return S.project.bugContest end
  local cloned = {}
  for i, row in ipairs(EncounterEdit.vanillaBugContest(S)) do
    cloned[i] = copyContestRow(row)
  end
  S.project.bugContest = cloned
  return cloned
end

function EncounterEdit.contestRules(S)
  local owned = S.project and S.project.bugContestRules
  if type(owned) == "table" then return owned, true end
  return { balls = 20, minutes = 20 }, false
end

function EncounterEdit.ensureContestRules(S)
  if type(S.project.bugContestRules) ~= "table" then
    S.project.bugContestRules = { balls = 20, minutes = 20 }
  end
  return S.project.bugContestRules
end

function EncounterEdit.drawBugContest(S, App, px, py, propW, listBottom, fh, s)
  local rules, rulesOwned = EncounterEdit.contestRules(S)
  Kit.text("micro", "Park Balls          minutes", px + 10 * s, py, PAL.caption)
  py = py + 16 * s
  local balls = tonumber(field(App, "bug_balls", px + 10 * s, py, 56 * s, fh,
    tostring(rules.balls or 20), "20")) or 20
  local minutes = tonumber(field(App, "bug_minutes", px + 80 * s, py, 56 * s, fh,
    tostring(rules.minutes or 20), "20")) or 20
  if balls ~= (rules.balls or 20) or minutes ~= (rules.minutes or 20) then
    local rec = EncounterEdit.ensureContestRules(S)
    rec.balls = math.max(1, math.min(99, balls))
    rec.minutes = math.max(1, math.min(99, minutes))
  end
  if rulesOwned and Kit.button(px + 150 * s, py, 90 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.bugContestRules = nil
    App.markDirty()
  end
  py = py + fh + 8 * s
  Kit.text("micro",
    "How many Park Balls the player gets, and how many minutes the contest lasts.",
    px + 10 * s, py, PAL.faint)
  py = py + 18 * s
  local scoreRows = {
    { "hpMult", "Max HP ×", 4, 0, 255 },
    { "statAdd", "Each stat +", 1, 0, 255 },
    { "itemBonus", "Held item +", 1, 0, 255 },
    { "hpDiv", "Current HP ÷", 8, 0, 256 },
    { "scoreBump", "Rival bump", 8, 0, 256 },
    { "dvDef", "Defense DV", 16, 0, 255 },
    { "dvAtk", "Attack DV", 8, 0, 255 },
    { "dvSpc", "Special DV", 4, 0, 255 },
    { "dvSpd", "Speed DV", 1, 0, 255 },
    { "tallRate", "Tall grass", 102, 0, 256 },
    { "grassRate", "Park grass", 51, 0, 256 },
    { "chooseLimit", "Species under", 200, 1, 256 },
    { "chooseDiv", "Species ÷", 2, 1, 256 },
  }
  local function shownScore(key, fallback)
    if rules[key] == nil then return fallback end
    return rules[key]
  end
  for i, row in ipairs(scoreRows) do
    if py + fh > listBottom - 70 * s then break end
    local col = (i - 1) % 3
    local shown = shownScore(row[1], row[3])
    if col == 0 then
      local park = row[1] == "tallRate" or row[1] == "chooseDiv"
      Kit.text("micro", park and "Park" or "Score", px + 10 * s, py, PAL.caption)
    end
    local lx = px + (70 + col * 150) * s
    local raw = field(App, "bug_score_" .. row[1], lx, py, 48 * s, fh, tostring(shown), tostring(row[3]))
    local n = tonumber(raw)
    if n ~= nil then
      n = math.max(row[4], math.min(row[5], math.floor(n)))
      if n ~= shown then
        local rec = EncounterEdit.ensureContestRules(S)
        rec[row[1]] = (n == row[3]) and nil or n
        rules = rec
      end
    end
    Kit.text("micro", row[2], lx + 52 * s, py + 4 * s, PAL.faint)
    if col == 2 then py = py + fh + 6 * s end
  end
  py = py + 8 * s

  local owned = type(S.project.bugContest) == "table"
  local rows = owned and S.project.bugContest or EncounterEdit.vanillaBugContest(S)
  Kit.text("micro", "chance    min   max    species", px + 10 * s, py, PAL.caption)
  py = py + 16 * s
  for i = 1, #rows do
    if py + fh > listBottom - 70 * s then break end
    local row = rows[i]
    local lx = px + 10 * s
    local chance = tonumber(field(App, "bug_ch_" .. i, lx, py, 48 * s, fh,
      tostring(row.chance or 0), "0")) or 0
    local minL = tonumber(field(App, "bug_min_" .. i, lx + 52 * s, py, 40 * s, fh,
      tostring(row.min or 1), "1")) or 1
    local maxL = tonumber(field(App, "bug_max_" .. i, lx + 96 * s, py, 40 * s, fh,
      tostring(row.max or 1), "1")) or 1
    local spW = math.max(80 * s, propW - 200 * s)
    SpeciesPicker.field(S, {
      x = lx + 140 * s, y = py, w = spW, h = fh,
      current = row.species,
      title = "CONTEST SPECIES",
      onPick = function(id)
        local list = EncounterEdit.ensureBugContest(S)
        local cur = list[i] or copyContestRow(row)
        cur.species = id
        list[i] = cur
        App.markDirty()
      end,
    })
    if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      local list = EncounterEdit.ensureBugContest(S)
      table.remove(list, i)
      if #list == 0 then S.project.bugContest = nil end
      App.markDirty()
      break
    end
    if chance ~= (row.chance or 0) or minL ~= (row.min or 1) or maxL ~= (row.max or 1) then
      local list = EncounterEdit.ensureBugContest(S)
      list[i] = copyContestRow({
        chance = chance, min = minL, max = maxL, species = row.species,
      })
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 110 * s, 28 * s, "+ Species", { kind = "accent" }) then
      local list = EncounterEdit.ensureBugContest(S)
      list[#list + 1] = { chance = 10, species = "CATERPIE", min = 5, max = 15 }
      App.markDirty()
    end
    if owned and Kit.button(px + 128 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.bugContest = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  Kit.text("micro",
    owned and "Save replaces the contest pool. Revert restores the vanilla table."
      or "Showing the vanilla pool. A change is saved for Gold, Silver, and Crystal.",
    px + 10 * s, py, PAL.faint)
  py = py + 28 * s
  return EncounterEdit.drawContestants(S, App, px, py, propW, fh, s)
end

function EncounterEdit.vanillaContestants()
  local ok, BugContest = pcall(require, "src.core.gen2.BugContest")
  if ok and type(BugContest) == "table" and type(BugContest.CONTESTANTS) == "table" then
    return BugContest.CONTESTANTS
  end
  return {}
end

local function copyContestant(row)
  row = type(row) == "table" and row or {}
  local mons = {}
  for i = 1, 3 do
    local mon = type(row.mons) == "table" and row.mons[i] or {}
    local species = mon.species
    if type(species) ~= "string" or species == "" then species = "CATERPIE" end
    mons[i] = {
      species = species,
      score = math.max(0, math.min(65535, tonumber(mon.score) or 0)),
    }
  end
  local className = tostring(row.class or "BUG_CATCHER"):upper():gsub("%s+", "_"):gsub("[^%w_]", "")
  if className == "" then className = "BUG_CATCHER" end
  return {
    class = className,
    trainer = math.max(1, math.min(255, tonumber(row.trainer) or 1)),
    name = tostring(row.name or ""):upper():gsub("[^%w ]", ""),
    mons = mons,
  }
end

function EncounterEdit.ensureContestants(S)
  if type(S.project.bugContestants) == "table" then return S.project.bugContestants end
  local cloned = {}
  for i, row in ipairs(EncounterEdit.vanillaContestants()) do
    cloned[i] = copyContestant(row)
  end
  S.project.bugContestants = cloned
  return cloned
end

function EncounterEdit.drawContestants(S, App, px, py, propW, fh, s)
  local owned = type(S.project.bugContestants) == "table"
  local list = owned and S.project.bugContestants or EncounterEdit.vanillaContestants()
  if #list == 0 then return py end
  Kit.text("small", "Rival trainers", px + 10 * s, py, PAL.caption)
  py = py + 20 * s
  Kit.text("micro",
    "The judge rolls one of each trainer's three Pokémon. The score is that catch's points, plus a small random bump.",
    px + 10 * s, py, PAL.faint)
  py = py + 28 * s
  S.bugContestantSlot = math.max(1, math.min(#list, tonumber(S.bugContestantSlot) or 1))
  local sx = px + 10 * s
  for i, row in ipairs(list) do
    local label = (type(row.name) == "string" and row.name ~= "" and row.name) or tostring(i)
    local bw = Kit.textWidth("micro", label) + 14 * s
    if sx + bw > px + propW - 10 * s then
      sx = px + 10 * s
      py = py + fh + 4 * s
    end
    if Kit.chip(sx, py, bw, fh, label, S.bugContestantSlot == i, PAL.green) then
      S.bugContestantSlot = i
    end
    sx = sx + bw + 4 * s
  end
  py = py + fh + 10 * s
  local index = S.bugContestantSlot
  local row = list[index]
  local nameW = math.max(80 * s, math.min(160 * s, propW * 0.34))
  local classW = math.max(90 * s, propW - nameW - 80 * s)
  local name = field(App, "bug_nm_" .. index, px + 10 * s, py, nameW, fh, row.name or "", "DON")
    :upper():gsub("[^%w ]", "")
  local className = field(App, "bug_cl_" .. index, px + nameW + 16 * s, py, classW, fh,
    row.class or "", "BUG_CATCHER"):upper():gsub("%s+", "_"):gsub("[^%w_]", "")
  py = py + fh + 4 * s
  local trainer = tonumber(field(App, "bug_tr_" .. index, px + 10 * s, py, 48 * s, fh,
    tostring(row.trainer or 1), "1")) or 1
  Kit.text("micro", "trainer # in that class", px + 66 * s, py + 6 * s, PAL.faint)
  if name ~= (row.name or "") or className ~= (row.class or "")
      or trainer ~= (row.trainer or 1) then
    local bag = EncounterEdit.ensureContestants(S)
    local cur = bag[index]
    cur.name = name
    cur.class = className ~= "" and className or "BUG_CATCHER"
    cur.trainer = math.max(1, math.min(255, trainer))
  end
  py = py + fh + 6 * s
  local mons = row.mons or {}
  for mi = 1, 3 do
    local mon = mons[mi] or { species = "CATERPIE", score = 0 }
    local spW = math.max(100 * s, propW - 140 * s)
    SpeciesPicker.field(S, {
      x = px + 10 * s, y = py, w = spW, h = fh,
      current = mon.species,
      title = "CONTESTANT SPECIES",
      onPick = function(id)
        local bag = EncounterEdit.ensureContestants(S)
        bag[index].mons[mi].species = id
        App.markDirty()
      end,
    })
    local score = tonumber(field(App, "bug_sc_" .. index .. "_" .. mi,
      px + spW + 16 * s, py, 64 * s, fh, tostring(mon.score or 0), "0")) or 0
    if score ~= (mon.score or 0) then
      local bag = EncounterEdit.ensureContestants(S)
      bag[index].mons[mi].score = math.max(0, math.min(65535, score))
    end
    py = py + fh + 4 * s
  end
  if owned and Kit.button(px + 10 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
    S.project.bugContestants = nil
    App.markDirty()
  end
  py = py + 32 * s
  return py
end

-- Fallback when the cache has no roamMons. Crystal's ROM seeds two beasts;
-- the cache is what the editor shows when it is present.
local ROAM_FALLBACK = {
  { species = "RAIKOU", level = 40, map = "ROUTE_42" },
  { species = "ENTEI", level = 40, map = "ROUTE_37" },
  { species = "SUICUNE", level = 40, map = "ROUTE_38" },
}

local ROAM_MAP_FALLBACK = {
  { map = "ROUTE_29", to = { "ROUTE_30", "ROUTE_46" } },
  { map = "ROUTE_30", to = { "ROUTE_29", "ROUTE_31" } },
  { map = "ROUTE_31", to = { "ROUTE_30", "ROUTE_32", "ROUTE_36" } },
  { map = "ROUTE_32", to = { "ROUTE_36", "ROUTE_31", "ROUTE_33" } },
  { map = "ROUTE_33", to = { "ROUTE_32", "ROUTE_34" } },
  { map = "ROUTE_34", to = { "ROUTE_33", "ROUTE_35" } },
  { map = "ROUTE_35", to = { "ROUTE_34", "ROUTE_36" } },
  { map = "ROUTE_36", to = { "ROUTE_35", "ROUTE_31", "ROUTE_32", "ROUTE_37" } },
  { map = "ROUTE_37", to = { "ROUTE_36", "ROUTE_38", "ROUTE_42" } },
  { map = "ROUTE_38", to = { "ROUTE_37", "ROUTE_39", "ROUTE_42" } },
  { map = "ROUTE_39", to = { "ROUTE_38" } },
  { map = "ROUTE_42", to = { "ROUTE_43", "ROUTE_44", "ROUTE_37", "ROUTE_38" } },
  { map = "ROUTE_43", to = { "ROUTE_42", "ROUTE_44" } },
  { map = "ROUTE_44", to = { "ROUTE_42", "ROUTE_43", "ROUTE_45" } },
  { map = "ROUTE_45", to = { "ROUTE_44", "ROUTE_46" } },
  { map = "ROUTE_46", to = { "ROUTE_45", "ROUTE_29" } },
}

local function encounterRoot(S)
  return S and S.data and (S.data.gen2Encounters or S.data.encounters)
end

function EncounterEdit.vanillaRoamMons(S)
  local rows = encounterRoot(S)
  rows = rows and rows.roamMons
  if type(rows) == "table" and #rows > 0 then return rows end
  return ROAM_FALLBACK
end

function EncounterEdit.vanillaRoamMaps(S)
  local rows = encounterRoot(S)
  rows = rows and rows.roamMaps
  if type(rows) == "table" and #rows > 0 then return rows end
  return ROAM_MAP_FALLBACK
end

local function mapId(text)
  text = tostring(text or ""):upper():gsub("%s+", "_"):gsub("[^%w_]", "")
  return text
end

local function copyRoamMon(row)
  row = type(row) == "table" and row or {}
  local species = row.species
  if type(species) ~= "string" or species == "" then species = "RAIKOU" end
  return {
    species = species,
    level = math.max(1, math.min(100, tonumber(row.level) or 40)),
    map = mapId(row.map ~= "" and row.map or "ROUTE_42"),
  }
end

local function copyRoamMap(row)
  row = type(row) == "table" and row or {}
  local to = {}
  if type(row.to) == "table" then
    for _, dest in ipairs(row.to) do
      local id = mapId(dest)
      if id ~= "" then to[#to + 1] = id end
    end
  end
  return { map = mapId(row.map ~= "" and row.map or "ROUTE_29"), to = to }
end

function EncounterEdit.ensureRoamMons(S)
  if type(S.project.roamMons) == "table" then return S.project.roamMons end
  local cloned = {}
  for i, row in ipairs(EncounterEdit.vanillaRoamMons(S)) do
    cloned[i] = copyRoamMon(row)
  end
  S.project.roamMons = cloned
  return cloned
end

function EncounterEdit.ensureRoamMaps(S)
  if type(S.project.roamMaps) == "table" then return S.project.roamMaps end
  local cloned = {}
  for i, row in ipairs(EncounterEdit.vanillaRoamMaps(S)) do
    cloned[i] = copyRoamMap(row)
  end
  S.project.roamMaps = cloned
  return cloned
end

local function joinMaps(list)
  return table.concat(list or {}, ", ")
end

function EncounterEdit.drawRoamers(S, App, px, py, propW, listBottom, fh, s)
  Kit.text("small", "Starting beasts", px + 10 * s, py, PAL.caption)
  py = py + 20 * s
  local ownedMons = type(S.project.roamMons) == "table"
  local mons = ownedMons and S.project.roamMons or EncounterEdit.vanillaRoamMons(S)
  for i = 1, #mons do
    if py + fh > listBottom - 80 * s then break end
    local row = mons[i]
    local lx = px + 10 * s
    local spW = math.max(90 * s, propW * 0.34)
    SpeciesPicker.field(S, {
      x = lx, y = py, w = spW, h = fh,
      current = row.species,
      title = "ROAMING SPECIES",
      onPick = function(id)
        local list = EncounterEdit.ensureRoamMons(S)
        local cur = list[i] or copyRoamMon(row)
        cur.species = id
        list[i] = cur
        App.markDirty()
      end,
    })
    local level = tonumber(field(App, "roam_lv_" .. i, lx + spW + 6 * s, py, 44 * s, fh,
      tostring(row.level or 40), "40")) or 40
    local mapW = math.max(80 * s, propW - spW - 120 * s)
    local map = mapId(field(App, "roam_map_" .. i, lx + spW + 54 * s, py, mapW, fh,
      row.map or "", "ROUTE_42"))
    if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      local list = EncounterEdit.ensureRoamMons(S)
      table.remove(list, i)
      if #list == 0 then S.project.roamMons = nil end
      App.markDirty()
      break
    end
    if level ~= (row.level or 40) or map ~= (row.map or "") then
      local list = EncounterEdit.ensureRoamMons(S)
      list[i] = copyRoamMon({ species = row.species, level = level, map = map })
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "+ Beast", { kind = "accent" }) then
      local list = EncounterEdit.ensureRoamMons(S)
      list[#list + 1] = { species = "RAIKOU", level = 40, map = "ROUTE_42" }
      App.markDirty()
    end
    if ownedMons and Kit.button(px + 118 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.roamMons = nil
      App.markDirty()
    end
    py = py + 40 * s
  end

  Kit.text("small", "Routes they can walk", px + 10 * s, py, PAL.caption)
  py = py + 18 * s
  Kit.text("micro", "Map, then the routes it connects to, separated by commas.",
    px + 10 * s, py, PAL.faint)
  py = py + 16 * s
  local ownedMaps = type(S.project.roamMaps) == "table"
  local maps = ownedMaps and S.project.roamMaps or EncounterEdit.vanillaRoamMaps(S)
  for i = 1, #maps do
    if py + fh > listBottom - 40 * s then break end
    local row = maps[i]
    local lx = px + 10 * s
    local mapW = 120 * s
    local map = mapId(field(App, "roam_from_" .. i, lx, py, mapW, fh,
      row.map or "", "ROUTE_29"))
    local shown = joinMaps(row.to)
    local toW = math.max(80 * s, propW - mapW - 70 * s)
    local typed = field(App, "roam_to_" .. i, lx + mapW + 6 * s, py, toW, fh, shown, "ROUTE_30, ROUTE_46")
    if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      local list = EncounterEdit.ensureRoamMaps(S)
      table.remove(list, i)
      if #list == 0 then S.project.roamMaps = nil end
      App.markDirty()
      break
    end
    local dests = {}
    for part in tostring(typed):gmatch("[^,]+") do
      local id = mapId(part)
      if id ~= "" then dests[#dests + 1] = id end
    end
    if map ~= (row.map or "") or joinMaps(dests) ~= shown then
      local list = EncounterEdit.ensureRoamMaps(S)
      list[i] = { map = map ~= "" and map or "ROUTE_29", to = dests }
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 100 * s, 28 * s, "+ Route", { kind = "accent" }) then
      local list = EncounterEdit.ensureRoamMaps(S)
      list[#list + 1] = { map = "ROUTE_29", to = { "ROUTE_30" } }
      App.markDirty()
    end
    if ownedMaps and Kit.button(px + 118 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.roamMaps = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

local SWARM_KEY = { grass = "swarmGrass", water = "swarmWater" }

local function swarmVanilla(S, mapId, kind)
  local root = encounterRoot(S)
  local table_ = root and root[SWARM_KEY[kind]]
  local row = table_ and table_[mapId]
  if type(row) == "table" then return row end
  return nil
end

-- Maps that still have a swarm after project deletes. A false entry removes
-- that kind; the map stays while the other kind is still there.
function EncounterEdit.swarmMapIds(S)
  local candidates, seen = {}, {}
  local function note(id)
    if type(id) == "string" and id ~= "" and not seen[id] then
      seen[id] = true
      candidates[#candidates + 1] = id
    end
  end
  local root = encounterRoot(S) or {}
  for id in pairs(root.swarmGrass or {}) do note(id) end
  for id in pairs(root.swarmWater or {}) do note(id) end
  for id in pairs(S.project and S.project.swarmGrass or {}) do note(id) end
  for id in pairs(S.project and S.project.swarmWater or {}) do note(id) end
  local ids = {}
  for _, id in ipairs(candidates) do
    local alive = false
    for _, kind in ipairs({ "grass", "water" }) do
      local key = SWARM_KEY[kind]
      local owned = S.project and S.project[key] and S.project[key][id]
      if owned == false then
        -- deleted
      elseif type(owned) == "table" or swarmVanilla(S, id, kind) then
        alive = true
      end
    end
    if alive then ids[#ids + 1] = id end
  end
  table.sort(ids)
  return ids
end

function EncounterEdit.swarmBand(S, mapId, kind)
  local key = SWARM_KEY[kind]
  local owned = S.project and S.project[key] and S.project[key][mapId]
  if owned == false then return nil, "deleted" end
  if type(owned) == "table" then return owned, "owned" end
  local vanilla = swarmVanilla(S, mapId, kind)
  if vanilla then return vanilla, "vanilla" end
  return nil, "missing"
end

function EncounterEdit.ensureSwarm(S, mapId, kind)
  local key = SWARM_KEY[kind]
  S.project[key] = S.project[key] or {}
  local cur = S.project[key][mapId]
  if type(cur) == "table" then return cur end
  local cloned = EncounterEdit.cloneEncounters({ [kind] = swarmVanilla(S, mapId, kind) })
  local band = cloned and cloned[kind]
  if kind == "grass" then
    if type(band) ~= "table" or not band.rates then
      band = {
        map = mapId,
        rates = { MORN = 15, DAY = 15, NITE = 15 },
        slots = {
          MORN = { { level = 3, species = "PIDGEY" } },
          DAY = { { level = 3, species = "PIDGEY" } },
          NITE = { { level = 3, species = "RATTATA" } },
        },
      }
    end
  else
    if type(band) ~= "table" or type(band.slots) ~= "table" then
      band = {
        map = mapId,
        rate = 5,
        slots = { { level = 5, species = "MAGIKARP" } },
      }
    end
  end
  band.map = mapId
  S.project[key][mapId] = band
  return band
end

function EncounterEdit.clearSwarm(S, mapId, kind)
  local key = SWARM_KEY[kind]
  S.project[key] = S.project[key] or {}
  if swarmVanilla(S, mapId, kind) then
    S.project[key][mapId] = false
  else
    S.project[key][mapId] = nil
  end
end

local FISH_SWARM_VANILLA = {
  { flag = 1, from = "FISHGROUP_QWILFISH", to = "FISHGROUP_QWILFISH_SWARM" },
  { flag = 2, from = "FISHGROUP_REMORAID", to = "FISHGROUP_REMORAID_SWARM" },
}

local function copyFishSwarm(row)
  row = type(row) == "table" and row or {}
  return {
    flag = math.max(0, math.min(255, math.floor(tonumber(row.flag) or 0))),
    from = mapId(row.from),
    to = mapId(row.to),
  }
end

function EncounterEdit.vanillaFishSwarms()
  local copy = {}
  for i, row in ipairs(FISH_SWARM_VANILLA) do
    copy[i] = copyFishSwarm(row)
  end
  return copy
end

function EncounterEdit.ensureFishSwarms(S)
  State.ensureProjectFields(S.project)
  if type(S.project.fishSwarmGroups) ~= "table" then
    S.project.fishSwarmGroups = EncounterEdit.vanillaFishSwarms()
  end
  return S.project.fishSwarmGroups
end

function EncounterEdit.drawFishSwarms(S, App, px, py, propW, listBottom, fh, s)
  Kit.text("small", "Fishing swarm swaps", px + 10 * s, py, PAL.caption)
  py = py + 18 * s
  Kit.text("micro",
    "While a swarm flag is set, maps using the first group fish the second group instead.",
    px + 10 * s, py, PAL.faint)
  py = py + 16 * s
  local owned = type(S.project.fishSwarmGroups) == "table"
  local rows = owned and S.project.fishSwarmGroups or EncounterEdit.vanillaFishSwarms()
  for i = 1, #rows do
    if py + fh > listBottom - 40 * s then break end
    local row = rows[i]
    local lx = px + 10 * s
    local flag = tonumber(field(App, "fswarm_flag_" .. i, lx, py, 36 * s, fh,
      tostring(row.flag or 0), "1")) or 0
    flag = math.max(0, math.min(255, math.floor(flag)))
    local from = mapId(field(App, "fswarm_from_" .. i, lx + 42 * s, py,
      math.max(80 * s, (propW - 130 * s) / 2), fh, row.from or "", "FISHGROUP_QWILFISH"))
    local to = mapId(field(App, "fswarm_to_" .. i, lx + 48 * s + math.max(80 * s, (propW - 130 * s) / 2),
      py, math.max(80 * s, (propW - 130 * s) / 2), fh, row.to or "", "FISHGROUP_QWILFISH_SWARM"))
    if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      local list = EncounterEdit.ensureFishSwarms(S)
      table.remove(list, i)
      App.markDirty()
      break
    end
    if flag ~= (row.flag or 0) or from ~= (row.from or "") or to ~= (row.to or "") then
      local list = EncounterEdit.ensureFishSwarms(S)
      list[i] = copyFishSwarm({ flag = flag, from = from, to = to })
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 90 * s, 28 * s, "+ Swap", { kind = "accent" }) then
      local list = EncounterEdit.ensureFishSwarms(S)
      list[#list + 1] = { flag = 3, from = "FISHGROUP_POND", to = "FISHGROUP_POND" }
      App.markDirty()
    end
    if owned and Kit.button(px + 108 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.fishSwarmGroups = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

function EncounterEdit.drawSwarm(S, mapId, App, px, py, propW, listBottom, fh, s)
  if not mapId then
    Kit.text("micro", "Select a swarm map, or add one.", px + 10 * s, py, PAL.faint)
    return py + 20 * s
  end
  S.swarmKind = (S.swarmKind == "water") and "water" or "grass"
  local sx = px + 10 * s
  for _, kind in ipairs({ "grass", "water" }) do
    local label = kind:upper()
    local bw = Kit.textWidth("micro", label) + 14 * s
    if Kit.chip(sx, py, bw, fh, label, S.swarmKind == kind, PAL.green) then
      S.swarmKind = kind
    end
    sx = sx + bw + 4 * s
  end
  py = py + fh + 8 * s
  local kind = S.swarmKind
  local band, state = EncounterEdit.swarmBand(S, mapId, kind)
  if not band then
    local why = state == "deleted" and "This swarm was removed."
      or ("No " .. kind .. " swarm on this map.")
    Kit.text("micro", why, px + 10 * s, py, PAL.faint)
    py = py + 18 * s
    if Kit.button(px + 10 * s, py, 140 * s, 28 * s, "+ Add " .. kind,
        { kind = "good" }) then
      EncounterEdit.ensureSwarm(S, mapId, kind)
      App.markDirty()
    end
    return py + 36 * s
  end
  if kind == "grass" then
    Kit.text("micro", "Rates MORN / DAY / NITE", px + 10 * s, py, PAL.caption)
    py = py + 14 * s
    local rates = band.rates or {}
    local rx = px + 10 * s
    for _, tod in ipairs(TOD) do
      local cur = rates[tod] or 0
      local v = tonumber(field(App, "sw_r_" .. mapId .. tod, rx, py, 50 * s, fh,
        tostring(cur), "0")) or 0
      if v ~= cur then
        local g = EncounterEdit.ensureSwarm(S, mapId, "grass")
        g.rates = g.rates or {}
        g.rates[tod] = math.max(0, math.min(255, v))
      end
      Kit.text("micro", tod, rx, py + fh + 2 * s, PAL.faint)
      rx = rx + 58 * s
    end
    py = py + fh + 18 * s
    S.swarmTod = S.swarmTod or "DAY"
    sx = px + 10 * s
    for _, tod in ipairs(TOD) do
      local bw = Kit.textWidth("micro", tod) + 14 * s
      if Kit.chip(sx, py, bw, fh, tod, S.swarmTod == tod, PAL.blue) then
        S.swarmTod = tod
      end
      sx = sx + bw + 4 * s
    end
    py = py + fh + 8 * s
    local tod = S.swarmTod
    local slots = (band.slots and band.slots[tod]) or {}
    py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s,
      "swg_" .. mapId .. tod, slots,
      function(si, slot, isAdd)
        local g = EncounterEdit.ensureSwarm(S, mapId, "grass")
        g.slots[tod] = g.slots[tod] or {}
        if isAdd then g.slots[tod][#g.slots[tod] + 1] = slot
        else g.slots[tod][si] = slot end
        App.markDirty()
      end,
      function(si)
        local g = EncounterEdit.ensureSwarm(S, mapId, "grass")
        table.remove(g.slots[tod], si)
        App.markDirty()
      end, 7)
  else
    Kit.text("micro", "Rate (0-255)", px + 10 * s, py, PAL.caption)
    py = py + 14 * s
    local rate = tonumber(field(App, "sw_w_" .. mapId, px + 10 * s, py, 70 * s, fh,
      tostring(band.rate or 0), "0")) or 0
    if rate ~= (band.rate or 0) then
      EncounterEdit.ensureSwarm(S, mapId, "water").rate = math.max(0, math.min(255, rate))
    end
    py = py + fh + 8 * s
    py = drawSlotRows(S, App, px, py, propW, listBottom, fh, s,
      "sww_" .. mapId, band.slots,
      function(si, slot, isAdd)
        local w = EncounterEdit.ensureSwarm(S, mapId, "water")
        if isAdd then w.slots[#w.slots + 1] = slot else w.slots[si] = slot end
        App.markDirty()
      end,
      function(si)
        table.remove(EncounterEdit.ensureSwarm(S, mapId, "water").slots, si)
        App.markDirty()
      end, 3)
  end
  if py + 36 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 120 * s, 28 * s, "Remove " .. kind,
        { kind = "ghost" }) then
      EncounterEdit.clearSwarm(S, mapId, kind)
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

-- Crystal headbutt: these species are asleep for the listed time of day.
-- Gold and Silver do not consult the list.
local ASLEEP_FALLBACK = {
  DAY = { "VENONAT", "HOOTHOOT", "NOCTOWL", "SPINARAK", "HERACROSS" },
  NITE = { "CATERPIE", "METAPOD", "BUTTERFREE", "WEEDLE", "KAKUNA", "BEEDRILL",
           "SPEAROW", "EKANS", "EXEGGCUTE", "LEDYBA", "AIPOM" },
}
ASLEEP_FALLBACK.MORN = ASLEEP_FALLBACK.DAY

function EncounterEdit.vanillaAsleep(S)
  local rows = encounterRoot(S)
  rows = rows and rows.treeMonsAsleep
  if type(rows) == "table" and (rows.MORN or rows.DAY or rows.NITE) then
    return rows
  end
  return ASLEEP_FALLBACK
end

function EncounterEdit.ensureAsleep(S)
  if type(S.project.treeMonsAsleep) == "table" then return S.project.treeMonsAsleep end
  local src = EncounterEdit.vanillaAsleep(S)
  local cloned = {}
  for _, tod in ipairs(TOD) do
    cloned[tod] = {}
    for i, species in ipairs(src[tod] or {}) do
      cloned[tod][i] = species
    end
  end
  S.project.treeMonsAsleep = cloned
  return cloned
end

function EncounterEdit.drawAsleep(S, App, px, py, propW, listBottom, fh, s)
  local sleep = tonumber(S.project and S.project.treeSleepTurns)
  if sleep == nil then sleep = 7 end
  local raw = field(App, "tree_sleep", px + 10 * s, py, 56 * s, fh, tostring(sleep), "7")
  local n = tonumber(raw)
  if n ~= nil then
    n = math.max(0, math.min(255, math.floor(n)))
    if n ~= sleep then
      S.project.treeSleepTurns = (n == 7) and nil or n
    end
  end
  Kit.text("micro", "Sleep turns", px + 74 * s, py + 4 * s, PAL.faint)
  py = py + fh + 8 * s
  S.asleepTod = S.asleepTod or "DAY"
  local sx = px + 10 * s
  for _, tod in ipairs(TOD) do
    local bw = Kit.textWidth("micro", tod) + 14 * s
    if Kit.chip(sx, py, bw, fh, tod, S.asleepTod == tod, PAL.blue) then
      S.asleepTod = tod
    end
    sx = sx + bw + 4 * s
  end
  py = py + fh + 8 * s
  local tod = S.asleepTod
  local owned = type(S.project.treeMonsAsleep) == "table"
  local list = owned and S.project.treeMonsAsleep[tod]
    or (EncounterEdit.vanillaAsleep(S)[tod] or {})
  for i = 1, #list do
    if py + fh > listBottom - 70 * s then break end
    local species = list[i]
    SpeciesPicker.field(S, {
      x = px + 10 * s, y = py, w = math.max(120 * s, propW - 60 * s), h = fh,
      current = species,
      title = "ASLEEP SPECIES",
      onPick = function(id)
        local rows = EncounterEdit.ensureAsleep(S)
        rows[tod][i] = id
        App.markDirty()
      end,
    })
    if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
      local rows = EncounterEdit.ensureAsleep(S)
      table.remove(rows[tod], i)
      App.markDirty()
      break
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 110 * s, 28 * s, "+ Species", { kind = "accent" }) then
      local rows = EncounterEdit.ensureAsleep(S)
      rows[tod][#rows[tod] + 1] = "CATERPIE"
      App.markDirty()
    end
    if owned and Kit.button(px + 128 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.treeMonsAsleep = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  Kit.text("micro",
    "Crystal headbutt only. A species on this list is asleep when it falls out of a tree at this time of day.",
    px + 10 * s, py, PAL.faint)
  return py + 20 * s
end

local function fallbackTimeFish()
  local out = {}
  for index, row in pairs(GOLD_TIME_FISH) do
    out[index] = {
      day = { species = row.day, level = row.dayLevel },
      nite = { species = row.nite, level = row.niteLevel },
    }
  end
  return out
end

function EncounterEdit.vanillaTimeFish(S)
  local owned = timeFishSource(S)
  if owned then return owned end
  return fallbackTimeFish()
end

function EncounterEdit.timeFishIndices(groups)
  local maxIndex = -1
  for key in pairs(groups or {}) do
    local n = tonumber(key)
    if n and n > maxIndex then maxIndex = n end
  end
  local ids = {}
  for index = 0, maxIndex do
    local row = groups[index] or groups[tostring(index)]
    if type(row) == "table" then ids[#ids + 1] = index end
  end
  return ids
end

function EncounterEdit.ensureTimeFish(S)
  if type(S.project.timeFishGroups) == "table" then return S.project.timeFishGroups end
  local src = EncounterEdit.vanillaTimeFish(S)
  local cloned = {}
  for _, index in ipairs(EncounterEdit.timeFishIndices(src)) do
    local row = src[index] or src[tostring(index)] or {}
    local daySpecies, dayLevel = timePair(row, "day")
    local niteSpecies, niteLevel = timePair(row, "nite")
    cloned[index] = {
      day = { species = daySpecies or "MAGIKARP", level = math.max(0, tonumber(dayLevel) or 1) },
      nite = { species = niteSpecies or daySpecies or "MAGIKARP", level = math.max(0, tonumber(niteLevel) or 1) },
    }
  end
  S.project.timeFishGroups = cloned
  return cloned
end

function EncounterEdit.drawTimeFish(S, App, px, py, propW, listBottom, fh, s)
  local owned = type(S.project.timeFishGroups) == "table"
  local groups = owned and S.project.timeFishGroups or EncounterEdit.vanillaTimeFish(S)
  Kit.text("micro", "Group    day species / level          night species / level",
    px + 10 * s, py, PAL.caption)
  py = py + 16 * s
  for _, index in ipairs(EncounterEdit.timeFishIndices(groups)) do
    if py + fh > listBottom - 70 * s then break end
    local row = groups[index] or groups[tostring(index)] or {}
    local daySpecies, dayLevel = timePair(row, "day")
    local niteSpecies, niteLevel = timePair(row, "nite")
    Kit.text("micro", tostring(index), px + 10 * s, py + 6 * s, PAL.faint)
    local col = px + 36 * s
    local spW = math.max(90 * s, (propW - 160 * s) / 2)
    SpeciesPicker.field(S, {
      x = col, y = py, w = spW, h = fh,
      current = daySpecies,
      title = "DAY SPECIES",
      onPick = function(id)
        local list = EncounterEdit.ensureTimeFish(S)
        list[index].day.species = id
        App.markDirty()
      end,
    })
    local dLvl = tonumber(field(App, "tf_dl_" .. index, col + spW + 4 * s, py, 40 * s, fh,
      tostring(dayLevel or 1), "1")) or 1
    local nx = col + spW + 48 * s
    SpeciesPicker.field(S, {
      x = nx, y = py, w = spW, h = fh,
      current = niteSpecies,
      title = "NIGHT SPECIES",
      onPick = function(id)
        local list = EncounterEdit.ensureTimeFish(S)
        list[index].nite.species = id
        App.markDirty()
      end,
    })
    local nLvl = tonumber(field(App, "tf_nl_" .. index, nx + spW + 4 * s, py, 40 * s, fh,
      tostring(niteLevel or 1), "1")) or 1
    if dLvl ~= (tonumber(dayLevel) or 1) or nLvl ~= (tonumber(niteLevel) or 1) then
      local list = EncounterEdit.ensureTimeFish(S)
      list[index].day.level = math.max(0, math.min(100, dLvl))
      list[index].nite.level = math.max(0, math.min(100, nLvl))
    end
    py = py + fh + 4 * s
  end
  if py + 32 * s <= listBottom and owned then
    if Kit.button(px + 10 * s, py, 90 * s, 28 * s, "Revert", { kind = "ghost" }) then
      S.project.timeFishGroups = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  Kit.text("micro",
    "A rod slot with species 0 uses this group: day from morning through afternoon, night after dark. Save updates every rod that points at a group you changed.",
    px + 10 * s, py, PAL.faint)
  return py + 28 * s
end

-- data/wild/flee_mons.asm. Crystal's always-flee list ends at Entei.
local FLEE_ALWAYS = {
  gs = { "RAIKOU", "ENTEI", "SUICUNE" },
  crystal = { "RAIKOU", "ENTEI" },
}
local FLEE_OFTEN = {
  "CUBONE", "ARTICUNO", "ZAPDOS", "MOLTRES",
  "QUAGSIRE", "DELIBIRD", "PHANPY", "TEDDIURSA",
}
local FLEE_SOMETIMES = {
  "MAGNEMITE", "GRIMER", "TANGELA", "MR__MIME",
  "EEVEE", "PORYGON", "DRATINI", "DRAGONAIR",
  "TOGETIC", "UMBREON", "UNOWN", "SNUBBULL", "HERACROSS",
}

local function copyNames(list)
  local out = {}
  for i, id in ipairs(list or {}) do out[i] = id end
  return out
end

function EncounterEdit.vanillaFlee(S, key)
  if key == "always" then
    if Generation.engine(S) == "crystal" then return FLEE_ALWAYS.crystal end
    return FLEE_ALWAYS.gs
  end
  if key == "often" then return FLEE_OFTEN end
  return FLEE_SOMETIMES
end

function EncounterEdit.ensureFlee(S, key)
  State.ensureProjectFields(S.project)
  S.project.fleeMons = S.project.fleeMons or {}
  if type(S.project.fleeMons[key]) ~= "table" then
    S.project.fleeMons[key] = copyNames(EncounterEdit.vanillaFlee(S, key))
  end
  return S.project.fleeMons[key]
end

local function fleeOwned(S)
  return type(S.project.fleeMons) == "table" and next(S.project.fleeMons) ~= nil
end

local function clearFleeKey(S, key)
  if type(S.project.fleeMons) ~= "table" then return end
  S.project.fleeMons[key] = nil
  if next(S.project.fleeMons) == nil then S.project.fleeMons = nil end
end

local FLEE_LISTS = {
  { key = "always", title = "Always flees" },
  { key = "often", title = "Often flees (about half the time)" },
  { key = "sometimes", title = "Sometimes flees (about 1 in 10)" },
}

function EncounterEdit.drawFlee(S, App, px, py, propW, listBottom, fh, s)
  local function rollField(label, key, vanilla, id)
    Kit.text("small", label, px + 10 * s, py, PAL.caption)
    local stored = S.project.fleeMons and tonumber(S.project.fleeMons[key])
    local shown = stored or vanilla
    local typed = tonumber(field(App, id, px + 220 * s, py, 64 * s, fh,
      tostring(shown), tostring(vanilla))) or shown
    typed = math.max(0, math.min(256, math.floor(typed)))
    if typed ~= shown then
      S.project.fleeMons = S.project.fleeMons or {}
      S.project.fleeMons[key] = typed == vanilla and nil or typed
      if next(S.project.fleeMons) == nil then S.project.fleeMons = nil end
    end
    py = py + fh + 6 * s
  end
  rollField("Often threshold (0-256)", "oftenRoll", 128, "flee_often_roll")
  rollField("Sometimes threshold (0-256)", "sometimesRoll", 26, "flee_sometimes_roll")
  Kit.text("micro",
    "A wild Pokémon flees when its roll is under the threshold. 128 is about half; 26 is about 1 in 10. 0 never, 256 always.",
    px + 10 * s, py, PAL.faint)
  py = py + 32 * s

  for _, spec in ipairs(FLEE_LISTS) do
    if py + fh > listBottom then break end
    Kit.text("small", spec.title, px + 10 * s, py, PAL.caption)
    local owned = type(S.project.fleeMons) == "table"
      and type(S.project.fleeMons[spec.key]) == "table"
    if owned and Kit.button(px + propW - 80 * s, py - 2 * s, 70 * s, 22 * s, "Revert",
        { kind = "ghost" }) then
      clearFleeKey(S, spec.key)
      App.markDirty()
    end
    py = py + 22 * s
    local list = owned and S.project.fleeMons[spec.key]
      or EncounterEdit.vanillaFlee(S, spec.key)
    for i = 1, #list do
      if py + fh > listBottom - 36 * s then break end
      local species = list[i]
      SpeciesPicker.field(S, {
        x = px + 10 * s, y = py, w = math.max(120 * s, propW - 56 * s), h = fh,
        current = species,
        title = "FLEE SPECIES",
        onPick = function(id)
          local ownedList = EncounterEdit.ensureFlee(S, spec.key)
          ownedList[i] = id
          App.markDirty()
        end,
      })
      if Kit.button(px + propW - 36 * s, py, 28 * s, fh, "X", { kind = "danger" }) then
        local ownedList = EncounterEdit.ensureFlee(S, spec.key)
        table.remove(ownedList, i)
        App.markDirty()
        break
      end
      py = py + fh + 4 * s
    end
    if py + 32 * s <= listBottom then
      if Kit.button(px + 10 * s, py, 110 * s, 28 * s, "+ Species", { kind = "accent" }) then
        local ownedList = EncounterEdit.ensureFlee(S, spec.key)
        ownedList[#ownedList + 1] = "RATTATA"
        App.markDirty()
      end
      py = py + 36 * s
    end
  end
  if fleeOwned(S) and py + 32 * s <= listBottom then
    if Kit.button(px + 10 * s, py, 140 * s, 28 * s, "Revert all", { kind = "ghost" }) then
      S.project.fleeMons = nil
      App.markDirty()
    end
    py = py + 36 * s
  end
  return py
end

return EncounterEdit
