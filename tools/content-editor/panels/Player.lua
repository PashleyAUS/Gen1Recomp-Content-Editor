-- Player tab: new-game start, advanced limits/Fly, overworld sprites, pics.

local Kit = require("Kit")
local Theme = require("Theme")
local State = require("State")
local RegList = require("RegList")
local FormPane = require("FormPane")
local Preview = require("Preview")
local PalettePicker = require("PalettePicker")
local SpriteUtil = require("SpriteUtil")
local SpriteAnimPreview = require("SpriteAnimPreview")
local Generation = require("Generation")
local ItemPicker = require("ItemPicker")
local PAL = Theme.PAL

local Player = {}

local FACINGS = { "up", "down", "left", "right" }

local GEN2_PLAYER_NAME = {
  gold = "GOLD", silver = "SILVER", crystal = "CHRIS",
}
local GEN2_PLAYER_PRESETS = {
  gold = { "GOLD", "HIRO", "TAYLOR", "KARL" },
  silver = { "SILVER", "KAMON", "OSCAR", "MAX" },
  crystal = { "CHRIS", "MAT", "ALLAN", "JON" },
}

local function modesFor(S)
  if Generation.isGen3(S) then return {{id="start",label="New game"},{id="starters",label="Starters & gifts"},
    {id="overworld",label="Overworld"},{id="pics",label="Trainer pictures"}} end
  local start = { id = "start", label = "New game",
    tip = "Spawn, money, bag, and PC items" }
  local advanced = { id = "advanced", label = "Advanced",
    tip = "Limits, badges, and Fly" }
  if Generation.isGen2(S) then
    return {
      start, advanced,
      { id = "overworld", label = "Overworld",
        tip = "Walk / bike / surf sprite sheets and Chris slot remaps" },
      { id = "pics", label = "Pics",
        tip = "Battle back, Dude back, Oak-speech front (card art: UI → Badges)" },
    }
  end
  return {
    start, advanced,
    { id = "overworld", label = "Overworld",
      tip = "Walk / bike / surf / fly sprite sheets and slot remaps" },
    { id = "pics", label = "Pics",
      tip = "Battle back pic, trainer card / intro front pic" },
  }
end

local OW_SLOTS_GEN1 = {
  { id = "walk", label = "Walk", tip = "On-foot player (default SPRITE_RED)" },
  { id = "bike", label = "Bike", tip = "Bicycle (default SPRITE_RED_BIKE)" },
  { id = "surf", label = "Surf", tip = "Surfing mount (default SPRITE_SEEL)" },
  { id = "fly", label = "Fly", tip = "Fly bird anim (default SPRITE_BIRD)" },
  { id = "surfPikachu", label = "Surf Pika",
    tip = "Yellow: surf when party Pikachu (SPRITE_SURFING_PIKACHU)" },
}

local OW_SLOTS_GEN2 = {
  { id = "walk", label = "Walk", tip = "On-foot Chris (SPRITE_CHRIS)" },
  { id = "bike", label = "Bike", tip = "Bicycle (SPRITE_CHRIS_BIKE)" },
  { id = "surf", label = "Surf", tip = "Surfing mount (SPRITE_SURF)" },
  { id = "surfPikachu", label = "Surf Pika",
    tip = "Surf when party Pikachu (SPRITE_SURFING_PIKACHU)" },
}

local OW_SLOTS_KRIS = {
  { id = "walkKris", label = "Walk Kris", tip = "On-foot Kris (SPRITE_KRIS)" },
  { id = "bikeKris", label = "Bike Kris", tip = "Bicycle (SPRITE_KRIS_BIKE)" },
}

local PIC_SLOTS_GEN1 = {
  { id = "front", label = "Front",
    tip = "Trainer card / Oak intro / Hall of Fame" },
  { id = "back", label = "Back", tip = "Battle back pic (Go! …)" },
  { id = "demoBack", label = "Demo back", tip = "Old man catch tutorial" },
  { id = "oakBack", label = "Oak back", tip = "Yellow Pallet catch (Oak)" },
}

local PIC_SLOTS_GEN2 = {
  { id = "front", label = "Front",
    tip = "Oak speech / intro player pic (data.playerPic)" },
  { id = "back", label = "Back",
    tip = "Battle back pic (gen2MenuGfx.battleHud.playerBack)" },
  { id = "demoBack", label = "Dude back",
    tip = "Catch tutorial Dude (gen2MenuGfx.battleHud.dudeBack)" },
}

local PIC_SLOTS_KRIS = {
  { id = "frontFemale", label = "Front Kris",
    tip = "Oak speech / intro Kris pic (data.playerPicFemale)" },
  { id = "backFemale", label = "Back Kris",
    tip = "Battle / Hall of Fame Kris back pic (gen2MenuGfx.battleHud.playerBackFemale)" },
}

local function hasKris(S)
  if Generation.isCrystal(S) then return true end
  local sprites = S and S.data and (S.data.sprites or S.data.gen2Sprites)
  return type(sprites) == "table" and sprites.SPRITE_KRIS ~= nil
end

local function owSlots(S)
  if not Generation.isGen2(S) then return OW_SLOTS_GEN1 end
  if not hasKris(S) then return OW_SLOTS_GEN2 end
  local slots = {}
  for i = 1, #OW_SLOTS_GEN2 do slots[i] = OW_SLOTS_GEN2[i] end
  for i = 1, #OW_SLOTS_KRIS do
    slots[#slots + 1] = OW_SLOTS_KRIS[i]
  end
  return slots
end

local function picSlots(S)
  if not Generation.isGen2(S) then return PIC_SLOTS_GEN1 end
  if not hasKris(S) then return PIC_SLOTS_GEN2 end
  return {
    PIC_SLOTS_GEN2[1], PIC_SLOTS_KRIS[1],
    PIC_SLOTS_GEN2[2], PIC_SLOTS_KRIS[2],
    PIC_SLOTS_GEN2[3],
  }
end

local function defaults()
  local ok, FieldDefaults = pcall(require, "src.world.FieldDefaults")
  if ok and FieldDefaults and FieldDefaults.FIELD then
    return FieldDefaults
  end
  return nil
end

local function defaultPlayerSprites(S)
  if Generation.isGen2(S) then
    local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
    local st = ok and FieldMoves and FieldMoves.STATE_SPRITE or nil
    return {
      walk = (st and st.normal) or "SPRITE_CHRIS",
      bike = (st and st.bike) or "SPRITE_CHRIS_BIKE",
      surf = (st and st.surf) or "SPRITE_SURF",
      surfPikachu = (st and st.surf_pika) or "SPRITE_SURFING_PIKACHU",
      walkKris = "SPRITE_KRIS",
      bikeKris = "SPRITE_KRIS_BIKE",
    }
  end
  local fd = defaults()
  return (fd and fd.FIELD.playerSprites) or {
    walk = "SPRITE_RED", bike = "SPRITE_RED_BIKE", surf = "SPRITE_SEEL",
    fly = "SPRITE_BIRD", surfPikachu = "SPRITE_SURFING_PIKACHU",
  }
end

local function menuGfx(S)
  return S.data and (S.data.gen2MenuGfx or S.data.menu_gfx) or nil
end

local function defaultPlayerPics(S)
  if Generation.isGen2(S) then
    local hud = menuGfx(S) and menuGfx(S).battleHud or {}
    return {
      back = hud.playerBack or "assets/generated/battle/player_back.png",
      backFemale = hud.playerBackFemale
        or "assets/generated/battle/player_back_female.png",
      demoBack = hud.dudeBack or "assets/generated/battle/dude_back.png",
      front = (S.data and S.data.playerPic)
        or "assets/generated/intro/cal.png",
      frontFemale = (S.data and S.data.playerPicFemale)
        or "assets/generated/intro/kris.png",
    }
  end
  local fd = defaults()
  return (fd and fd.FIELD.playerPics) or {
    back = "assets/generated/battle/redb.png",
    demoBack = "assets/generated/battle/oldmanb.png",
    oakBack = "assets/generated/battle/profoakb.png",
    front = "assets/generated/trainer_card/red.png",
  }
end

local function slotSpriteId(S, slot)
  local proj = S.project and S.project.playerSprites
  if proj and type(proj[slot]) == "string" and proj[slot] ~= "" then
    return proj[slot], true
  end
  if Generation.isGen2(S) then
    local ov = S.data and S.data.gen2PlayerSprites
    if ov and type(ov[slot]) == "string" and ov[slot] ~= "" then
      return ov[slot], false
    end
    return defaultPlayerSprites(S)[slot], false
  end
  local fd = defaults()
  if fd and fd.fieldValue then
    local v = fd.fieldValue(S.data, "playerSprites", slot)
    if type(v) == "string" and v ~= "" then return v, false end
  end
  return defaultPlayerSprites(S)[slot], false
end

local function slotPicPath(S, slot)
  local proj = S.project and S.project.playerPics
  if proj and type(proj[slot]) == "string" and proj[slot] ~= "" then
    return proj[slot], true
  end
  if Generation.isGen2(S) then
    return defaultPlayerPics(S)[slot], false
  end
  local fd = defaults()
  if fd and fd.fieldValue then
    local v = fd.fieldValue(S.data, "playerPics", slot)
    if type(v) == "string" and v ~= "" then return v, false end
  end
  return defaultPlayerPics(S)[slot], false
end

local function resolveSprite(S, id)
  if not id then return nil, false end
  if S.project and S.project.sprites and S.project.sprites[id] then
    return S.project.sprites[id], true
  end
  if S.data and S.data.sprites and S.data.sprites[id] then
    return S.data.sprites[id], false
  end
  return nil, false
end

local function ensureSprite(S, id, template, App)
  State.ensureProjectFields(S.project)
  S.project.sprites = S.project.sprites or {}
  if S.project.sprites[id] then return S.project.sprites[id] end
  local copy = {}
  if type(template) == "table" then
    for k, v in pairs(template) do
      if type(v) ~= "function" then copy[k] = v end
    end
    copy._isNew = false
  else
    copy = {
      id = id,
      image = "assets/" .. tostring(id):lower() .. ".png",
      frames = 6, walker = true, _isNew = true,
    }
  end
  copy.id = copy.id or id
  S.project.sprites[id] = copy
  if App then App.markDirty() end
  return copy
end

local function setSlotSprite(S, slot, spriteId, App)
  State.ensureProjectFields(S.project)
  local def = defaultPlayerSprites(S)[slot]
  if spriteId == nil or spriteId == "" or spriteId == def then
    S.project.playerSprites[slot] = nil
  else
    S.project.playerSprites[slot] = spriteId
  end
  if App then App.markDirty() end
end

local function setSlotPic(S, slot, path, App)
  State.ensureProjectFields(S.project)
  local def = defaultPlayerPics(S)[slot]
  if path == nil or path == "" or path == def then
    S.project.playerPics[slot] = nil
  else
    S.project.playerPics[slot] = path
  end
  if App then App.markDirty() end
end

local function spritePal(S, rec)
  return SpriteAnimPreview.palette(S, rec)
end

local function drawOverworld(S, x, y, w, h, App)
  local s = Kit.scale
  State.ensureProjectFields(S.project)
  S.project.sprites = S.project.sprites or {}
  S.project.playerSprites = S.project.playerSprites or {}

  local slots = owSlots(S)
  local slotIds = {}
  for _, slot in ipairs(slots) do slotIds[#slotIds + 1] = slot.id end
  -- Drop a Gen1-only selection (fly) after switching to Gold.
  do
    local ok = false
    for _, id in ipairs(slotIds) do
      if id == S.playerOwSlot then ok = true; break end
    end
    if not ok then S.playerOwSlot = slotIds[1] or "walk" end
  end

  local formX, formW, listY, listH, shown = RegList.drawList(S, App, x, y, w, h,
    "PLAYER SPRITES", slotIds, {
      queryKey = "playerOwQuery",
      offsetKey = "playerOwOffset",
      selKey = "playerOwSlot",
      accent = PAL.green,
      listW = math.min(160 * s, w * 0.22),
      isOwned = function(id)
        local _, remapped = slotSpriteId(S, id)
        local sid = select(1, slotSpriteId(S, id))
        local _, sprOwned = resolveSprite(S, sid)
        return remapped or sprOwned
      end,
      filter = function(id, q)
        local ql = q:lower()
        if id:lower():find(ql, 1, true) then return true end
        local sid = select(1, slotSpriteId(S, id)) or ""
        return sid:lower():find(ql, 1, true) ~= nil
      end,
    })

  if not S.playerOwSlot then S.playerOwSlot = shown[1] or "walk" end
  local slot = S.playerOwSlot
  local slotMeta
  for _, row in ipairs(slots) do
    if row.id == slot then slotMeta = row; break end
  end

  local spriteId, remapped = slotSpriteId(S, slot)
  local rec, sprOwned = resolveSprite(S, spriteId)

  Kit.caption(formX, y,
    (slotMeta and slotMeta.label or slot) .. " · " .. tostring(spriteId or "?")
      .. ((remapped or sprOwned) and "" or "  (vanilla)"))

  local fy, view, viewX, viewW = RegList.beginForm(S, formX, listY, formW, listH,
    "playerOwScroll", tostring(slot) .. "|" .. tostring(spriteId),
    44 * s)
  local contentTop = fy
  local labelW = 110 * s
  local fh = 28 * s
  local prev = 72 * s

  Kit.text("micro",
    (slotMeta and slotMeta.tip) or "",
    viewX, fy, PAL.muted)
  fy = fy + 18 * s

  Kit.text("micro", Generation.isGen2(S)
      and (hasKris(S)
        and "Crystal: Chris and Kris sheets. Remap writes gen2PlayerSprites; sheet → sprites:patch."
        or Generation.label(S) .. ": ChrisStateSprites. Remap writes gen2PlayerSprites; sheet → sprites:patch.")
      or "Sheet layout: 16×(16×frames). Walkers use 6 frames — stand D/U/L, walk D/U/L; right = flip left.",
    viewX, fy, PAL.faint)
  fy = fy + 28 * s

  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end

  row("Sprite id", function(fx, fy_, fw, fh_)
    local cur = spriteId or ""
    local ph = "SPRITE_RED"
    if Generation.isGen2(S) then
      if slot == "walkKris" then ph = "SPRITE_KRIS"
      elseif slot == "bikeKris" then ph = "SPRITE_KRIS_BIKE"
      else ph = "SPRITE_CHRIS" end
    end
    local v = RegList.field(App, "pl_sid", fx, fy_, math.max(40 * s, fw - 100 * s),
      fh_, cur, ph)
    if v ~= cur and v:match("^[%w_]+$") then
      setSlotSprite(S, slot, v, App)
      spriteId = v
      rec, sprOwned = resolveSprite(S, spriteId)
    end
    if Kit.button(fx + fw - 96 * s, fy_, 96 * s, fh_, "Reset", {
        kind = "ghost", tooltip = "Restore vanilla sprite id for this slot",
      }) then
      setSlotSprite(S, slot, nil, App)
      spriteId = select(1, slotSpriteId(S, slot))
      rec, sprOwned = resolveSprite(S, spriteId)
    end
  end)

  if not rec then
    Kit.text("micro", "No sprite record for " .. tostring(spriteId)
        .. " — create one or pick an existing id.",
      viewX, fy, PAL.yellow)
    fy = fy + 20 * s
    if Kit.button(viewX, fy, 180 * s, fh, "+ Create sprite", { kind = "good" }) then
      local sid = spriteId
      if not sid or sid == "" then
        sid = "SPRITE_PLAYER_" .. tostring(slot):upper()
        setSlotSprite(S, slot, sid, App)
        spriteId = sid
      end
      ensureSprite(S, sid, nil, App)
      rec, sprOwned = resolveSprite(S, sid)
    end
    fy = fy + fh + 12 * s
    FormPane.finish(S, "playerOwScroll", contentTop, fy, view)
    return
  end

  -- Live preview (may refresh after edits)
  rec = select(1, resolveSprite(S, spriteId)) or rec
  local pal = spritePal(S, rec)
  local prevY = fy
  Preview.draw(S, rec.image, viewX + viewW - prev, prevY, prev, prev, pal)
  if type(pal) == "table" then
    Preview.drawSwatches(pal,
      viewX + viewW - prev, prevY + prev + 4 * s, prev, 12 * s)
  elseif type(pal) == "string" then
    Preview.drawNamedSwatches(S, pal,
      viewX + viewW - prev, prevY + prev + 4 * s, prev, 12 * s)
  end

  local fieldW = viewW - labelW - prev - 12 * s
  if fieldW < 120 * s then fieldW = viewW - labelW - 8 * s end

  local function ensure()
    return ensureSprite(S, spriteId, rec, App)
  end

  row = function(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, fieldW, fh)
    fy = fy + fh + 8 * s
  end

  row("Image", function(fx, fy_, fw, fh_)
    Kit.text("micro", Kit.ellipsize("micro", tostring(rec.image or ""), fw - 100 * s),
      fx, fy_ + 8 * s, PAL.muted)
    if Kit.button(fx + fw - 96 * s, fy_, 96 * s, fh_, "Browse", {
        kind = "ghost", tooltip = "Import player overworld PNG",
      }) then
      local sid = spriteId
      App.pickFile("Player sprite PNG", "PNG (*.png)|*.png|All|*.*",
        function(picked)
          local e = ensureSprite(S, sid, select(1, resolveSprite(S, sid)), App)
          App.importToMod(picked, nil, function(rel)
            e.image = rel
            Preview.invalidate()
          end)
        end)
    end
  end)

  row("Frames", function(fx, fy_, fw, fh_)
    local cur = rec.frames or 1
    local v = RegList.num(App, "pl_fr", fx, fy_, 60 * s, fh_, cur)
    v = math.max(1, math.min(16, v))
    if v ~= cur then ensure().frames = v; rec = ensure() end
  end)

  row("Walker", function(fx, fy_, fw, fh_)
    local on = rec.walker and true or false
    if Kit.chip(fx, fy_, 80 * s, fh_, on and "YES" or "NO", on, PAL.green) then
      ensure().walker = not on
      rec = ensure()
      App.markDirty()
    end
  end)

  row("TrueColor", function(fx, fy_, fw, fh_)
    local on = rec.trueColor and true or false
    if Kit.chip(fx, fy_, 80 * s, fh_, on and "YES" or "NO", on, PAL.yellow,
        nil, "YES = raw PNG colors (skip palette remap)") then
      local e = ensure()
      e.trueColor = not on
      if not e.trueColor then e.trueColor = nil end
      rec = e
      Preview.invalidate()
      App.markDirty()
    end
    Kit.text("micro",
      on and "raw PNG"
        or (Generation.isGen2(S) and "OBJ remap" or "SGB remap"),
      fx + 90 * s, fy_ + 8 * s, PAL.faint)
  end)

  if Generation.isGen2(S) then
    row("Palette", function(fx, fy_, fw, fh_)
      if rec.trueColor then
        Kit.text("small", "(ignored — TrueColor)", fx, fy_ + 6 * s, PAL.faint)
        return
      end
      local cur = rec.palette or "PAL_OW_RED"
      if Kit.button(fx, fy_, math.min(fw, 160 * s), fh_,
          Kit.ellipsize("small", cur, math.min(fw, 160 * s) - 8 * s),
          { kind = "ghost", tooltip = "Cycle PAL_OW_*" }) then
        local e = ensure()
        e.palette = RegList.cycle(SpriteUtil.OW_PALETTES, cur)
        local idx
        for i, name in ipairs(SpriteUtil.OW_PALETTES) do
          if name == e.palette then idx = i - 1; break end
        end
        if idx then e.paletteId = idx end
        rec = e
        Preview.invalidate()
        App.markDirty()
      end
      local colors = spritePal(S, rec)
      if colors then
        Preview.drawSwatches(colors, fx + fw - 80 * s,
          fy_ + (fh_ - 14 * s) / 2, 80 * s, 14 * s)
      end
    end)
    row("Palette id", function(fx, fy_, fw, fh_)
      local cur = tonumber(rec.paletteId) or 0
      local v = RegList.num(App, "pl_pid", fx, fy_, 60 * s, fh_, cur)
      v = math.max(0, math.min(7, math.floor(v)))
      if v ~= cur then
        local e = ensure()
        e.paletteId = v
        e.palette = SpriteUtil.OW_PALETTES[v + 1] or e.palette
        rec = e
        Preview.invalidate()
        App.markDirty()
      end
    end)
  else
    row("Palette", function(fx, fy_, fw, fh_)
      PalettePicker.row(S, {
        x = fx, y = fy_, w = fw, h = fh_,
        current = rec.paletteSource or "",
        effective = type(pal) == "string" and pal or nil,
        emptyLabel = "(MEWMON)",
        clearLabel = "(MEWMON default)",
        allowClear = true,
        title = "PLAYER SPRITE PALETTE",
        tooltip = "SGB palette for this overworld sheet",
        onPick = function(id)
          local e = ensure()
          e.paletteSource = id
          Preview.invalidate()
          App.markDirty()
        end,
        owner = {
          kind = "sprite",
          entityId = spriteId,
          entityLabel = spriteId,
          assign = function(id)
            local e = ensure()
            e.paletteSource = id
            Preview.invalidate()
            App.markDirty()
          end,
        },
      })
    end)
  end

  fy = fy + 4 * s
  fy = SpriteAnimPreview.draw(S, rec, viewX, fy, viewW, {
    prefix = "playerAnim", s = s,
  })
  fy = fy + 8 * s
  fy = SpriteAnimPreview.drawStrip(S, rec, viewX, fy, 40 * s, s)

  if Kit.button(viewX, fy, 140 * s, fh, "Open in GFX", {
      kind = "ghost", tooltip = "Edit this sprite on the GFX tab",
    }) then
    S.tab = "gfx"
    S.gfxMode = "sprites"
    S.spriteEditId = spriteId
  end
  fy = fy + fh + 8 * s

  if sprOwned and Kit.button(viewX, fy, 160 * s, fh, "Revert sheet", {
      kind = "danger", tooltip = "Drop mod override for this sprite record",
    }) then
    S.project.sprites[spriteId] = nil
    App.markDirty()
  end
  fy = fy + fh + 8 * s

  FormPane.finish(S, "playerOwScroll", contentTop, fy, view)
end

local function drawPics(S, x, y, w, h, App)
  local s = Kit.scale
  State.ensureProjectFields(S.project)
  S.project.playerPics = S.project.playerPics or {}

  local slots = picSlots(S)
  local slotIds = {}
  for _, slot in ipairs(slots) do slotIds[#slotIds + 1] = slot.id end
  do
    local ok = false
    for _, id in ipairs(slotIds) do
      if id == S.playerPicSlot then ok = true; break end
    end
    if not ok then S.playerPicSlot = slotIds[1] or "front" end
  end

  local formX, formW, listY, listH, shown = RegList.drawList(S, App, x, y, w, h,
    "PLAYER PICS", slotIds, {
      queryKey = "playerPicQuery",
      offsetKey = "playerPicOffset",
      selKey = "playerPicSlot",
      accent = PAL.blue,
      listW = math.min(160 * s, w * 0.22),
      isOwned = function(id)
        return select(2, slotPicPath(S, id))
      end,
    })

  if not S.playerPicSlot then S.playerPicSlot = shown[1] or "front" end
  local slot = S.playerPicSlot
  local slotMeta
  for _, row in ipairs(slots) do
    if row.id == slot then slotMeta = row; break end
  end
  local path, owned = slotPicPath(S, slot)

  Kit.caption(formX, y,
    (slotMeta and slotMeta.label or slot) .. (owned and "" or "  (vanilla)"))

  local fy, view, viewX, viewW = RegList.beginForm(S, formX, listY, formW, listH,
    "playerPicScroll", tostring(slot) .. "|" .. tostring(path),
    owned and 44 * s or 12 * s)
  local contentTop = fy
  local labelW = 100 * s
  local fh = 28 * s
  local prev = 96 * s

  Kit.text("micro", (slotMeta and slotMeta.tip) or "", viewX, fy, PAL.muted)
  fy = fy + 20 * s

  Preview.draw(S, path, viewX + viewW - prev, fy, prev, prev)
  local fieldW = viewW - labelW - prev - 12 * s

  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, fieldW, fh)
    fy = fy + fh + 8 * s
  end

  row("Path", function(fx, fy_, fw, fh_)
    local cur = path or ""
    local v = RegList.field(App, "pl_pic", fx, fy_, math.max(40 * s, fw - 100 * s),
      fh_, cur, "assets/...")
    if v ~= cur then
      setSlotPic(S, slot, v, App)
      path = v
    end
    if Kit.button(fx + fw - 96 * s, fy_, 96 * s, fh_, "Browse", {
        kind = "ghost", tooltip = "Import player pic PNG",
      }) then
      App.pickFile("Player pic PNG", "PNG (*.png)|*.png|All|*.*",
        function(picked)
          App.importToMod(picked, nil, function(rel)
            setSlotPic(S, slot, rel, App)
            Preview.invalidate()
          end)
        end)
    end
  end)

  if owned then
    if Kit.button(viewX, fy, 120 * s, fh, "Reset", {
        kind = "danger", tooltip = "Restore vanilla pic path",
      }) then
      setSlotPic(S, slot, nil, App)
    end
    fy = fy + fh + 8 * s
  end

  FormPane.finish(S, "playerPicScroll", contentTop, fy, view)
end

local function copyItemRows(src)
  local out = {}
  for i, row in ipairs(src or {}) do
    if type(row) == "table" then
      out[i] = { id = row.id, count = tonumber(row.count) or 1 }
    end
  end
  return out
end

local function parseCsvIds(s)
  local out = {}
  for part in tostring(s or ""):gmatch("[^,]+") do
    part = part:match("^%s*(.-)%s*$")
    if part ~= "" then out[#out + 1] = part end
  end
  return out
end

local function joinCsvIds(t)
  if type(t) ~= "table" then return "" end
  return table.concat(t, ", ")
end

local function copyStrList(src)
  local out = {}
  if type(src) ~= "table" then return out end
  for i, v in ipairs(src) do out[i] = v end
  return out
end

-- Crystal/Gold ignore Data.field.boot (still Red's house). New game uses
-- landmarks.spawns.SPAWN_HOME, 3000 money, empty bag/PC.
function Player.vanillaBoot(S)
  if Generation.isGen3(S) then
    local game=Generation.id(S)
    local start=require("src.core.game3.map_ids").newGameStart(game)
    local frlg=game=="firered" or game=="leafgreen"
    return {startMap=start.map,startX=start.x,startY=start.y,startFacing=start.facing or "down",startMoney=3000,
      lastHeal={map=start.healMap or start.map,x=start.healX or start.x,y=start.healY or start.y},
      playerName=frlg and "RED" or "",rivalName=frlg and "BLUE" or "",startItems={},startPcItems={{id="POTION",count=1}},namePresets={}}
  end
  if Generation.isGen2(S) then
    local lm = S.data and (S.data.gen2Landmarks or S.data.landmarks)
    local spot = lm and lm.spawns and lm.spawns.SPAWN_HOME
    local map = (type(spot) == "table" and spot.map) or "PLAYERS_HOUSE_2F"
    local x = (type(spot) == "table" and tonumber(spot.x)) or 3
    local y = (type(spot) == "table" and tonumber(spot.y)) or 3
    local ver = Generation.id(S)
    local presets = GEN2_PLAYER_PRESETS[ver] or GEN2_PLAYER_PRESETS.gold
    return {
      startMap = map, startX = x, startY = y, startFacing = "down",
      startMoney = 3000,
      playerName = GEN2_PLAYER_NAME[ver] or "GOLD",
      rivalName = "???",
      lastHeal = { map = map, x = x, y = y },
      namePresets = {
        player = copyStrList(presets),
        rival = { "SILVER" },
      },
      startItems = {},
      startPcItems = {},
    }
  end
  local b = (S.data and S.data.field and S.data.field.boot) or {}
  local map = b.startMap or "REDS_HOUSE_2F"
  local x = b.startX or 3
  local y = b.startY or 6
  local facing = b.startFacing or "down"
  if map == "REDS_HOUSE_2F" and Generation.id(S) ~= "yellow" then
    facing = "up"
  end
  local heal = b.lastHeal
  if type(heal) ~= "table" or not heal.map then
    if map == "REDS_HOUSE_2F" then
      heal = { map = "PALLET_TOWN", x = 5, y = 6 }
    else
      heal = { map = map, x = x, y = y }
    end
  end
  local presets = b.namePresets
  if type(presets) ~= "table" then
    presets = { player = { "RED", "ASH", "JACK" }, rival = { "BLUE", "GARY", "JOHN" } }
  end
  return {
    startMap = map, startX = x, startY = y, startFacing = facing,
    startMoney = b.startMoney or 3000,
    playerName = b.playerName or "RED",
    rivalName = b.rivalName or "BLUE",
    lastHeal = heal,
    namePresets = {
      player = copyStrList(presets.player),
      rival = copyStrList(presets.rival),
    },
    startItems = {},
    startPcItems = { { id = "POTION", count = 1 } },
  }
end

local function bootField(S, key)
  local b = S.project and S.project.boot
  if b and b[key] ~= nil then
    if not (type(b[key]) == "string" and b[key] == "") then
      return b[key]
    end
  end
  return Player.vanillaBoot(S)[key]
end

local function lastHealField(S, key)
  local lh = S.project and S.project.boot and S.project.boot.lastHeal
  if lh and lh[key] ~= nil then
    if not (type(lh[key]) == "string" and lh[key] == "") then
      return lh[key]
    end
  end
  local heal = Player.vanillaBoot(S).lastHeal
  return heal and heal[key]
end

local function setBoot(S, key, val, App)
  State.ensureProjectFields(S.project)
  S.project.boot[key] = val
  App.markDirty()
end

local function setLastHeal(S, key, val, App)
  State.ensureProjectFields(S.project)
  S.project.boot.lastHeal = S.project.boot.lastHeal or {}
  S.project.boot.lastHeal[key] = val
  App.markDirty()
end

local function ensureBootItemList(S, key, App)
  State.ensureProjectFields(S.project)
  if type(S.project.boot[key]) ~= "table" then
    S.project.boot[key] = copyItemRows(Player.vanillaBoot(S)[key])
    App.markDirty()
  end
  return S.project.boot[key]
end

local function drawBootItemList(S, App, key, title, x, y, w, fh, s)
  Kit.text("small", title, x, y + 6 * s, PAL.caption)
  y = y + 24 * s
  local owned = type(S.project.boot and S.project.boot[key]) == "table"
  local list = owned and S.project.boot[key]
    or copyItemRows(Player.vanillaBoot(S)[key])
  if not owned then
    Kit.text("micro", "Vanilla for this ROM. Edit to override.",
      x, y, PAL.muted)
  elseif #list == 0 then
    Kit.text("micro", "Starts with no items. Vanilla restores the original bag or PC.",
      x, y, PAL.muted)
  else
    Kit.text("micro", "Qty is how many of that item. X removes the row.",
      x, y, PAL.muted)
  end
  y = y + 20 * s
  for i, row in ipairs(list) do
    local slot = i
    ItemPicker.field(S, {
      x = x, y = y, w = w - 160 * s, h = fh,
      current = (row and row.id) or "",
      title = title,
      onPick = function(id)
        local e = ensureBootItemList(S, key, App)
        e[slot] = e[slot] or {}
        e[slot].id = id
        e[slot].count = tonumber(e[slot].count) or 1
        App.markDirty()
      end,
    })
    local count = tonumber(row and row.count) or 1
    local shown = RegList.num(App, "pl_" .. key .. "_" .. slot,
      x + w - 152 * s, y, 72 * s, fh, count)
    if shown ~= count then
      local e = ensureBootItemList(S, key, App)
      e[slot] = e[slot] or {}
      e[slot].count = math.max(1, math.floor(tonumber(shown) or 1))
      App.markDirty()
    end
    if Kit.button(x + w - 36 * s, y, 32 * s, fh, "X", { kind = "danger" }) then
      table.remove(ensureBootItemList(S, key, App), slot)
      App.markDirty()
      break
    end
    y = y + fh + 6 * s
  end
  if Kit.button(x, y, 140 * s, fh, "+ Add item", { kind = "good" }) then
    local e = ensureBootItemList(S, key, App)
    e[#e + 1] = { id = "POTION", count = 1 }
    App.markDirty()
  end
  if owned and Kit.button(x + 148 * s, y, 150 * s, fh, "Vanilla", { kind = "ghost" }) then
    S.project.boot[key] = nil
    App.markDirty()
  end
  return y + fh + 8 * s
end

local function drawStart(S, x, y, w, h, App)
  local s = Kit.scale
  local pad = 16 * s
  local fh = 28 * s
  FormPane.track(S, "playerStartScroll", S.project and S.project.id or "")
  local row, pageView = FormPane.begin(S, "playerStartScroll", x, y, w, h)
  local pageTop = row
  w = pageView.contentW or w

  Kit.caption(x, row, "NEW-GAME START")
  row = row + 24 * s
  Kit.text("micro",
    "Values shown are this ROM's vanilla new game. Change a field to override it.",
    x, row, PAL.muted)
  row = row + 22 * s

  local innerY = row
  local cardH = S._playerStartH or (760 * s)
  Kit.card(x, innerY, w, cardH, 14 * s)
  local scrollPad = 12 * s
  local viewX = x + scrollPad
  local viewW = w - 2 * scrollPad
  local fy = innerY + scrollPad
  local labelW = 120 * s

  local function bootRow(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end

  local vanilla = Player.vanillaBoot(S)
  local mapHint = tostring(vanilla.startMap or "")
  bootRow("Start map", function(fx, fy_, fw, fh_)
    local cur = tostring(bootField(S, "startMap") or "")
    local v = RegList.field(App, "pl_boot_map", fx, fy_, fw, fh_, cur, mapHint)
    if v ~= cur then setBoot(S, "startMap", v, App) end
  end)
  bootRow("Start X", function(fx, fy_, fw, fh_)
    local cur = bootField(S, "startX") or 0
    local v = RegList.num(App, "pl_boot_x", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then setBoot(S, "startX", v, App) end
  end)
  bootRow("Start Y", function(fx, fy_, fw, fh_)
    local cur = bootField(S, "startY") or 0
    local v = RegList.num(App, "pl_boot_y", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then setBoot(S, "startY", v, App) end
  end)
  bootRow("Facing", function(fx, fy_, fw, fh_)
    local cur = tostring(bootField(S, "startFacing") or "down")
    if Kit.button(fx, fy_, fw, fh_, Kit.ellipsize("small", cur, fw - 8 * s),
        { kind = "ghost" }) then
      setBoot(S, "startFacing", RegList.cycle(FACINGS, cur), App)
    end
  end)
  bootRow("Starting money", function(fx, fy_, fw, fh_)
    local cur = bootField(S, "startMoney") or 0
    local v = RegList.num(App, "pl_boot_money", fx, fy_, 100 * s, fh_, cur)
    if v ~= cur then setBoot(S, "startMoney", v, App) end
  end)
  bootRow("Last heal map", function(fx, fy_, fw, fh_)
    local cur = tostring(lastHealField(S, "map") or "")
    local v = RegList.field(App, "pl_boot_lhm", fx, fy_, fw, fh_, cur, mapHint)
    if v ~= cur then setLastHeal(S, "map", v, App) end
  end)
  bootRow("Last heal X", function(fx, fy_, fw, fh_)
    local cur = lastHealField(S, "x") or 0
    local v = RegList.num(App, "pl_boot_lhx", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then setLastHeal(S, "x", v, App) end
  end)
  bootRow("Last heal Y", function(fx, fy_, fw, fh_)
    local cur = lastHealField(S, "y") or 0
    local v = RegList.num(App, "pl_boot_lhy", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then setLastHeal(S, "y", v, App) end
  end)

  bootRow("Player", function(fx, fy_, fw, fh_)
    local cur = tostring(bootField(S, "playerName") or "")
    local v = RegList.field(App, "pl_boot_pname", fx, fy_, fw, fh_, cur,
      vanilla.playerName or "")
    if v ~= cur then setBoot(S, "playerName", v, App) end
  end)
  bootRow("Rival", function(fx, fy_, fw, fh_)
    local cur = tostring(bootField(S, "rivalName") or "")
    local v = RegList.field(App, "pl_boot_rname", fx, fy_, fw, fh_, cur,
      vanilla.rivalName or "")
    if v ~= cur then setBoot(S, "rivalName", v, App) end
  end)

  local function namePresetList(who)
    local presets = bootField(S, "namePresets")
    if type(presets) == "table" and type(presets[who]) == "table" then
      return presets[who]
    end
    local base = vanilla.namePresets
    return base and base[who]
  end

  local function setNamePresets(who, list)
    State.ensureProjectFields(S.project)
    local cur = S.project.boot.namePresets
    if type(cur) ~= "table" then
      local base = vanilla.namePresets or {}
      cur = {
        player = copyStrList(base.player),
        rival = copyStrList(base.rival),
      }
      S.project.boot.namePresets = cur
    end
    cur[who] = list
    App.markDirty()
  end

  if Generation.isGen3(S) then
    bootRow("Money cap", function(fx, fy_, fw, fh_)
      local cur = Player.constField(S, "moneyCap")
      if cur == nil then cur = 999999 end
      local v = math.max(0, math.floor(RegList.num(App, "pl_g3_money", fx, fy_, 100 * s, fh_, cur)))
      if v ~= cur then
        if v == 999999 then
          if S.project.constants then S.project.constants.moneyCap = nil end
          App.markDirty()
        else
          Player.setConst(S, "moneyCap", v, App)
        end
      end
    end)
    bootRow("Coin cap", function(fx, fy_, fw, fh_)
      local cur = Player.constField(S, "coinCap")
      if cur == nil then cur = 9999 end
      local v = math.max(0, math.floor(RegList.num(App, "pl_g3_coin", fx, fy_, 80 * s, fh_, cur)))
      if v ~= cur then
        if v == 9999 then
          if S.project.constants then S.project.constants.coinCap = nil end
          App.markDirty()
        else
          Player.setConst(S, "coinCap", v, App)
        end
      end
    end)
    if Generation.isRse(S) then
      bootRow("Blackout divisor", function(fx, fy_, fw, fh_)
        local Whiteout = require("Whiteout")
        local cur = tonumber(Whiteout.get(S, "div", 2)) or 2
        local v = math.max(1, math.floor(RegList.num(App, "pl_g3_whiteout", fx, fy_, 80 * s, fh_, cur)))
        if v ~= cur then Whiteout.set(S, App, "div", v, 2) end
      end)
    else
      bootRow("Blackout level factor", function(fx, fy_, fw, fh_)
        local Whiteout = require("Whiteout")
        local cur = tonumber(Whiteout.get(S, "levelFactor", 4)) or 4
        local v = math.max(0, math.floor(RegList.num(App, "pl_g3_wfactor", fx, fy_, 80 * s, fh_, cur)))
        if v ~= cur then Whiteout.set(S, App, "levelFactor", v, 4) end
      end)
      bootRow("Badge loss", function(fx, fy_, fw, fh_)
        local Whiteout = require("Whiteout")
        local def = table.concat(Whiteout.badgeDefault(), ", ")
        local curList = Whiteout.get(S, "badgeMult", nil)
        local cur = type(curList) == "table" and table.concat(curList, ", ") or def
        local v = RegList.field(App, "pl_g3_wbadges", fx, fy_, fw, fh_, cur, def)
        if v ~= cur then
          local nums = {}
          for part in tostring(v):gmatch("[^,]+") do
            local n = tonumber(part)
            if n then nums[#nums + 1] = math.max(0, math.floor(n)) end
          end
          while #nums < 9 do nums[#nums + 1] = Whiteout.badgeDefault()[#nums + 1] end
          Whiteout.set(S, App, "badgeMult", nums, Whiteout.badgeDefault())
        end
      end)
    end
    if Generation.isRse(S) then
      bootRow("Lottery digits", function(fx, fy_, fw, fh_)
        local g = S.project.lotteryOdds
        local cur = g and g.minDigits
        if cur == nil then cur = 2 end
        local v = math.max(0, math.min(5, math.floor(RegList.num(App, "pl_lottery", fx, fy_, 80 * s, fh_, cur))))
        if v ~= cur then
          State.ensureProjectFields(S.project)
          S.project.lotteryOdds = S.project.lotteryOdds or {}
          S.project.lotteryOdds.minDigits = (v == 2) and nil or v
          if not next(S.project.lotteryOdds) then S.project.lotteryOdds = nil end
          App.markDirty()
        end
      end)
    end
    bootRow("Poison steps", function(fx, fy_, fw, fh_)
      local PoisonField = require("PoisonField")
      local cur = tonumber(PoisonField.get(S, "interval", 4)) or 4
      local v = math.max(0, math.floor(RegList.num(App, "pl_g3_poison_steps", fx, fy_, 80 * s, fh_, cur)))
      if v ~= cur then PoisonField.set(S, App, "interval", v, 4) end
    end)
    bootRow("Poison damage", function(fx, fy_, fw, fh_)
      local PoisonField = require("PoisonField")
      local cur = tonumber(PoisonField.get(S, "damage", 1)) or 1
      local v = math.max(0, math.floor(RegList.num(App, "pl_g3_poison_dmg", fx, fy_, 80 * s, fh_, cur)))
      if v ~= cur then PoisonField.set(S, App, "damage", v, 1) end
    end)
    if not Generation.isRse(S) then
      bootRow("Vs. Seeker steps", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "seekerCharge", 100)) or 100
        local v = math.max(0, math.floor(RegList.num(App, "pl_seeker_charge", fx, fy_, 80 * s, fh_, cur)))
        if v ~= cur then Steps.set(S, App, "seekerCharge", v, 100) end
      end)
      bootRow("Rematch refuses below", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "seekerRefuse", 30)) or 30
        local v = math.max(0, math.floor(RegList.num(App, "pl_seeker_refuse", fx, fy_, 80 * s, fh_, cur)))
        if v ~= cur then Steps.set(S, App, "seekerRefuse", v, 30) end
      end)
      bootRow("Rematch roll", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "seekerDice", 100)) or 100
        local v = math.max(1, math.floor(RegList.num(App, "pl_seeker_dice", fx, fy_, 80 * s, fh_, cur)))
        if v ~= cur then Steps.set(S, App, "seekerDice", v, 100) end
      end)
    end
  end

  if not Generation.isGen3(S) then
  bootRow("Player names", function(fx, fy_, fw, fh_)
    local cur = joinCsvIds(namePresetList("player"))
    local v = RegList.field(App, "pl_boot_pnames", fx, fy_, fw, fh_, cur,
      joinCsvIds(vanilla.namePresets and vanilla.namePresets.player))
    if v ~= cur then setNamePresets("player", parseCsvIds(v)) end
  end)
  bootRow("Rival names", function(fx, fy_, fw, fh_)
    local cur = joinCsvIds(namePresetList("rival"))
    local v = RegList.field(App, "pl_boot_rnames", fx, fy_, fw, fh_, cur,
      joinCsvIds(vanilla.namePresets and vanilla.namePresets.rival))
    if v ~= cur then setNamePresets("rival", parseCsvIds(v)) end
  end)

  end
  fy = fy + 8 * s
  fy = drawBootItemList(S, App, "startItems", "Bag items",
    viewX, fy, viewW, fh, s)
  fy = drawBootItemList(S, App, "startPcItems", "PC items",
    viewX, fy, viewW, fh, s)

  S._playerStartH = math.max(120 * s, fy - innerY + scrollPad)
  row = innerY + S._playerStartH + pad
  FormPane.finish(S, "playerStartScroll", pageTop, row, pageView)
end

function Player.dataConstants(S)
  return (S.data and S.data.constants) or {}
end

function Player.constField(S, key)
  local c = S.project and S.project.constants
  if c and c[key] ~= nil then return c[key] end
  return Player.dataConstants(S)[key]
end

function Player.worldField(S, key, default)
  local c = S.project and S.project.constants
  local world = c and c.world
  if type(world) == "table" and world[key] ~= nil then return world[key] end
  local dataWorld = Player.dataConstants(S).world
  if type(dataWorld) == "table" and dataWorld[key] ~= nil then return dataWorld[key] end
  return default
end

function Player.setWorld(S, key, value, default, App)
  State.ensureProjectFields(S.project)
  local world = S.project.constants.world
  if type(world) ~= "table" then
    world = {}
    S.project.constants.world = world
  end
  world[key] = (value == default) and nil or value
  if not next(world) then S.project.constants.world = nil end
  App.markDirty()
end

function Player.setConst(S, key, val, App)
  State.ensureProjectFields(S.project)
  S.project.constants[key] = val
  App.markDirty()
end

function Player.badgeRows(S)
  local c = S.project and S.project.constants
  if c and c.badges and #c.badges > 0 then return c.badges end
  local dc = Player.dataConstants(S).badges
  if type(dc) == "table" and #dc > 0 then return dc end
  return {}
end

function Player.ensureBadges(S, App)
  State.ensureProjectFields(S.project)
  if not S.project.constants.badges or #S.project.constants.badges == 0 then
    local src = Player.dataConstants(S).badges
    S.project.constants.badges = {}
    if type(src) == "table" then
      for i, row in ipairs(src) do
        S.project.constants.badges[i] = {
          id = row.id or "",
          name = row.name or "",
        }
      end
    end
    App.markDirty()
  end
  return S.project.constants.badges
end

function Player.drawAdvanced(S, x, y, w, h, App)
  local s = Kit.scale
  local pad = 16 * s
  local fh = 28 * s
  FormPane.track(S, "playerAdvScroll", S.project and S.project.id or "")
  local row, pageView = FormPane.begin(S, "playerAdvScroll", x, y, w, h)
  local pageTop = row
  w = pageView.contentW or w

  Kit.caption(x, row, "ADVANCED")
  row = row + 24 * s
  Kit.text("micro",
    "Optional rules, capacity, and Fly. Unchanged fields keep this ROM's defaults.",
    x, row, PAL.muted)
  row = row + 22 * s

  local innerY = row
  local cardH = S._playerAdvancedH or (520 * s)
  Kit.card(x, innerY, w, cardH, 14 * s)
  local scrollPad = 12 * s
  local viewX = x + scrollPad
  local viewW = w - 2 * scrollPad
  local fy = innerY + scrollPad
  local labelW = 120 * s
  local secGap = 20 * s

  local function advRow(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end

  Kit.caption(viewX, fy, "CONSTANTS")
  fy = fy + 24 * s
  Kit.text("micro",
    "Optional rules and capacity limits.",
    viewX, fy, PAL.muted)
  fy = fy + 22 * s

  if Generation.isGen2(S) then
    advRow("Shiny rate", function(fx, fy_, fw, fh_)
      local cur = tonumber(S.project.shinyRate) or 8192
      local v = RegList.num(App, "pl_shiny_rate", fx, fy_, 80 * s, fh_, cur)
      v = math.max(1, math.floor(v))
      if v ~= cur then
        State.ensureProjectFields(S.project)
        S.project.shinyRate = v
        App.markDirty()
      end
    end)
    Kit.text("micro",
      "1 / N chance a wild/gift mon rolls forced shiny DVs (vanilla 8192).",
      viewX, fy, PAL.faint)
    fy = fy + 18 * s
  end

  advRow("Level cap", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "levelCap") or 100
    local v = RegList.num(App, "pl_const_lvl", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then Player.setConst(S, "levelCap", v, App) end
  end)
  advRow("Dex size", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "dexSize") or 151
    local v = RegList.num(App, "pl_const_dex", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then Player.setConst(S, "dexSize", v, App) end
  end)
  advRow("Dex digits", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "dexDigits") or 3
    local v = RegList.num(App, "pl_const_ddig", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then Player.setConst(S, "dexDigits", v, App) end
  end)
  advRow("Party max", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "partyMax") or 6
    local v = RegList.num(App, "pl_const_party", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then Player.setConst(S, "partyMax", v, App) end
  end)
  advRow("Bag size", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "bagSize") or 20
    local v = RegList.num(App, "pl_const_bag", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then Player.setConst(S, "bagSize", v, App) end
  end)
  advRow("Money cap", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "moneyCap")
    if cur == nil then cur = 999999 end
    local v = math.max(0, math.floor(RegList.num(App, "pl_const_money", fx, fy_, 100 * s, fh_, cur)))
    if v ~= cur then
      if v == 999999 then
        if S.project.constants then S.project.constants.moneyCap = nil end
        App.markDirty()
      else
        Player.setConst(S, "moneyCap", v, App)
      end
    end
  end)
  advRow("Coin cap", function(fx, fy_, fw, fh_)
    local cur = Player.constField(S, "coinCap")
    if cur == nil then cur = 9999 end
    local v = math.max(0, math.floor(RegList.num(App, "pl_const_coin", fx, fy_, 80 * s, fh_, cur)))
    if v ~= cur then
      if v == 9999 then
        if S.project.constants then S.project.constants.coinCap = nil end
        App.markDirty()
      else
        Player.setConst(S, "coinCap", v, App)
      end
    end
  end)
  advRow("Blackout divisor", function(fx, fy_, fw, fh_)
    local Whiteout = require("Whiteout")
    local cur = tonumber(Whiteout.get(S, "div", 2)) or 2
    local v = math.max(1, math.floor(RegList.num(App, "pl_whiteout_div", fx, fy_, 80 * s, fh_, cur)))
    if v ~= cur then Whiteout.set(S, App, "div", v, 2) end
  end)
  advRow("Poison steps", function(fx, fy_, fw, fh_)
    local PoisonField = require("PoisonField")
    local cur = tonumber(PoisonField.get(S, "interval", 4)) or 4
    local v = math.max(0, math.floor(RegList.num(App, "pl_poison_steps", fx, fy_, 80 * s, fh_, cur)))
    if v ~= cur then PoisonField.set(S, App, "interval", v, 4) end
  end)
  advRow("Poison damage", function(fx, fy_, fw, fh_)
    local PoisonField = require("PoisonField")
    local cur = tonumber(PoisonField.get(S, "damage", 1)) or 1
    local v = math.max(0, math.floor(RegList.num(App, "pl_poison_dmg", fx, fy_, 80 * s, fh_, cur)))
    if v ~= cur then PoisonField.set(S, App, "damage", v, 1) end
  end)
  advRow("Poison flash", function(fx, fy_, fw, fh_)
    local PoisonField = require("PoisonField")
    local cur = tonumber(PoisonField.get(S, "flash", 4)) or 4
    local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_poison_flash", fx, fy_, 80 * s, fh_, cur))))
    if v ~= cur then PoisonField.set(S, App, "flash", v, 4) end
  end)
  if Generation.isGen2(S) then
    advRow("Bike shop call", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bikeCall", 1024)) or 1024
      local v = math.max(0, math.floor(RegList.num(App, "pl_bike_call", fx, fy_, 100 * s, fh_, cur)))
      if v ~= cur then Steps.set(S, App, "bikeCall", v, 1024) end
    end)
    advRow("Bike step cap", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bikeCap", 65535)) or 65535
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_bike_cap", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bikeCap", v, 65535) end
    end)
    advRow("Pitfall beat", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "skyfallBeats", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_skyfall", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "skyfallBeats", v, 16) end
    end)
    advRow("Pitfall shake", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "pitfallShake", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_pitfall", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "pitfallShake", v, 16) end
    end)
    advRow("Teleport beat", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "teleportBeats", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_teleport", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "teleportBeats", v, 16) end
    end)
    advRow("Teleport lift", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "teleportLift", 96)) or 96
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_teleport_lift", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "teleportLift", v, 96) end
    end)
    advRow("Teleport rise", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "teleportRise", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_teleport_rise", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "teleportRise", v, 16) end
    end)
    advRow("Teleport fall", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "teleportFall", 0)) or 0
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_teleport_fall", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "teleportFall", v, 0) end
    end)
    advRow("Ledge arc", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = "-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0"
      local cur = Steps.get(S, "g2Ledge", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g2_ledge", fx, fy_, fw, fh_, cur, default)
      local list = Steps.arcList(v)
      local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
      if same or not list then v = default end
      if v ~= cur then Steps.set(S, App, "g2Ledge", v, default) end
    end)
    advRow("Tree shake", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "treeShake", 24)) or 24
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_tree_shake", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "treeShake", v, 24) end
    end)
    advRow("Dig step", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "digStep", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_dig_step", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "digStep", v, 16) end
    end)
    advRow("Dig spin", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "digSpin", 32)) or 32
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_dig_spin", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "digSpin", v, 32) end
    end)
    advRow("Sleep unit", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sleepUnit", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_sleep_unit", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sleepUnit", v, 16) end
    end)
    advRow("NPC step frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "npcStep", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_npc_step", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "npcStep", v, 16) end
    end)
    advRow("Spin frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spinFrames", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_spin_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spinFrames", v, 4) end
    end)
    advRow("Bounce cycle", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bouncePeriod", 32)) or 32
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_bounce", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bouncePeriod", v, 32) end
    end)
    advRow("Bounce pose", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bounceHalf", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_bounce_half", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bounceHalf", v, 16) end
    end)
    advRow("Spinner turn", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spinTurn", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_spin_turn", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spinTurn", v, 16) end
    end)
    advRow("Wander from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "wanderLo", 30)) or 30
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_wander_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "wanderLo", v, 30) end
    end)
    advRow("Wander to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "wanderHi", 180)) or 180
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_wander_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "wanderHi", v, 180) end
    end)
    advRow("Turn chance", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "turnOdds", 50)) or 50
      local v = math.max(0, math.min(100, math.floor(RegList.num(App, "pl_turn_odds", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "turnOdds", v, 50) end
    end)
    advRow("First pause from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spawnLo", 30)) or 30
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_spawn_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spawnLo", v, 30) end
    end)
    advRow("First pause to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spawnHi", 120)) or 120
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_spawn_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spawnHi", v, 120) end
    end)
    advRow("Slow spin from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "slowSpinLo", 60)) or 60
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_slow_spin_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "slowSpinLo", v, 60) end
    end)
    advRow("Slow spin to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "slowSpinHi", 180)) or 180
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_slow_spin_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "slowSpinHi", v, 180) end
    end)
    advRow("Fast spin from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fastSpinLo", 20)) or 20
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_fast_spin_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fastSpinLo", v, 20) end
    end)
    advRow("Fast spin to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fastSpinHi", 60)) or 60
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_fast_spin_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fastSpinHi", v, 60) end
    end)
    advRow("Walk frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "playerStep", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_walk_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "playerStep", v, 16) end
    end)
    advRow("Turn frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "turnFrames", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_turn_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "turnFrames", v, 4) end
    end)
    advRow("Approach gap", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "approachGap", 1)) or 1
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g2_approach", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "approachGap", v, 1) end
    end)
    advRow("Notice pause", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "noticeFrames", 30)) or 30
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g2_notice", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "noticeFrames", v, 30) end
    end)
    advRow("Fade steps", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fadeSteps", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_fade_steps", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fadeSteps", v, 4) end
    end)
    advRow("Fade frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fadeFrames", 2)) or 2
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_fade_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fadeFrames", v, 2) end
    end)
    local fadeRamps = {
      { "White fade", "fadeWhite", "FADE_WHITE" },
      { "Black fade", "fadeBlack", "FADE_BLACK" },
    }
    for _, row in ipairs(fadeRamps) do
      local label, key, cart = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[cart]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.shadeRows(v)
        if not list then
          v = default
        else
          local parts = {}
          for _, shade in ipairs(list) do
            for _, n in ipairs(shade) do parts[#parts + 1] = tostring(n) end
          end
          v = table.concat(parts, ", ")
        end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Palette poll", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "palettePoll", 60)) or 60
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_palette_poll", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "palettePoll", v, 60) end
    end)
    advRow("Map reach", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "neighborHops", 2)) or 2
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_neighbor_hops", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "neighborHops", v, 2) end
    end)
    local g2Cues = {
      { "Headbutt sound", "g2HeadbuttSfx", 109, 0, 255 },
      { "Cut sound", "g2CutSfx", 30, 0, 255 },
      { "Flash sound", "g2FlashSfx", 169, 0, 255 },
      { "Falls sound", "g2FallSfx", 81, 0, 255 },
      { "Boulder sound", "g2BoulderSfx", 27, 0, 255 },
      { "Shock emote", "g2Shock", 0, 0, 255 },
      { "Whirlpool wait", "g2Whirl", 180, 0, 255 },
      { "Heal ball", "g2HealBall", 30, 0, 255 },
      { "Heal flash", "g2HealFlash", 10, 0, 255 },
      { "Heal flashes", "g2HealFlashes", 8, 0, 255 },
      { "Heal anchor", "g2HealAnchor", 64, 0, 255 },
      { "Heal flip", "g2HealFlip", 8, 0, 255 },
    }
    for _, row in ipairs(g2Cues) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g2HealShift = {
      { "Lab x", "g2HealShiftX", 16, -512, 512 },
      { "Lab y", "g2HealShiftY", 32, -512, 512 },
    }
    for _, row in ipairs(g2HealShift) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g2HealLists = {
      { "Center lights", "g2HealPc", "HEAL_PC_MACHINE", "pair" },
      { "Center balls", "g2HealBalls", "HEAL_PC_BALLS", "triple" },
      { "Hall balls", "g2HealHof", "HEAL_HOF", "triple" },
    }
    for _, row in ipairs(g2HealLists) do
      local label, key, which, kind = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          if kind == "pair" then
            local pairs = Steps.pairList(text) or {}
            local parts = {}
            for i = 1, #pairs do parts[i] = pairs[i][1] .. "," .. pairs[i][2] end
            return table.concat(parts, ",")
          end
          local triples = Steps.tripleList(text) or {}
          local parts = {}
          for i = 1, #triples do
            parts[i] = triples[i][1] .. "," .. triples[i][2] .. "," .. (triples[i][3] and 1 or 0)
          end
          return table.concat(parts, ",")
        end
        local parsed = kind == "pair" and Steps.pairList(v) or Steps.tripleList(v)
        if not parsed or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Rod", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.G2_ROD
      local cur = Steps.get(S, "g2Rod", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g2Rod", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local rows = Steps.rodList(text) or {}
        local parts = {}
        for i = 1, #rows do
          local row = rows[i]
          parts[#parts + 1] = row.dx .. "," .. row.dy .. "," .. row.tile .. "," .. (row.flip and 1 or 0)
        end
        return table.concat(parts, ",")
      end
      if not Steps.rodList(v) or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "g2Rod", v, default) end
    end)
    advRow("Rod pose", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.G2_FISH_ROW
      local cur = Steps.get(S, "g2FishRow", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g2FishRow", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local list = Steps.holdList(text) or {}
        if #list < 4 then return "" end
        local parts = {}
        for i = 1, 4 do
          local n = list[i]
          if n > 2 then n = 2 end
          parts[i] = tostring(n)
        end
        return table.concat(parts, ",")
      end
      if flat(v) == "" or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "g2FishRow", v, default) end
    end)
    local g2TileRows = {
      { "Tower frames", "g2Tower", "G2_TOWER", "hold" },
      { "Scroll shift", "g2Scroll", "G2_SCROLL", "arc" },
      { "Water frames", "g2Water", "G2_WATER", "hold" },
      { "Whirlpool frames", "g2WhirlRows", "G2_WHIRL_ROWS", "hold" },
      { "Lava ahead", "g2Lava", "G2_LAVA", "hold" },
      { "Lava frames", "g2Lava2", "G2_LAVA2", "hold" },
    }
    for _, row in ipairs(g2TileRows) do
      local label, key, which, kind = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          local list = (kind == "arc" and Steps.arcList(text) or Steps.holdList(text)) or {}
          if #list < 8 then return "" end
          local parts = {}
          for i = 1, 8 do parts[i] = tostring(list[i]) end
          return table.concat(parts, ",")
        end
        if flat(v) == "" or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Strength pause", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "strengthPause", 3)) or 3
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_strength_pause", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "strengthPause", v, 3) end
    end)
    local g2Battle = {
      { "Text pause", "g2TextPause", 30, 0, 255 },
      { "Move delay", "g2MoveDelay", 40, 0, 255 },
      { "HP step", "g2HpStep", 2, 0, 255 },
      { "Faint row", "g2FaintRow", 2, 1, 255 },
      { "Trainer steps", "g2SlideSteps", 8, 0, 255 },
      { "Trainer step", "g2SlideStep", 2, 1, 255 },
      { "Back steps", "g2BackSteps", 9, 0, 255 },
      { "Win steps", "g2WinSteps", 6, 0, 255 },
      { "Win step", "g2WinStep", 4, 1, 255 },
      { "Win rest", "g2WinRest", 2, 0, 255 },
      { "Win delay", "g2WinDelay", 40, 0, 255 },
      { "Exit fade", "g2ExitFade", 8, 0, 255 },
      { "Exit music", "g2ExitMusic", 4, 0, 255 },
      { "Whiteout fade", "g2WhiteFade", 2, 0, 255 },
      { "Whiteout hold", "g2WhiteHold", 40, 0, 255 },
      { "Intro slide", "g2IntroSlide", 72, 0, 255 },
      { "Exp sound", "g2ExpSound", 10, 0, 255 },
      { "Exp wait", "g2ExpWait", 180, 0, 255 },
      { "Exp gap", "g2ExpGap", 3, 0, 255 },
      { "Exp burst", "g2ExpBurst", 8, 0, 255 },
      { "Exp sparks", "g2ExpSparks", 8, 0, 255 },
      { "Exp x", "g2ExpX", 76, 0, 255 },
      { "Exp y", "g2ExpY", 88, 0, 255 },
      { "Text x", "g2TextX", 1, 0, 255 },
      { "Text y", "g2TextY", 14, 0, 255 },
      { "Text width", "g2TextW", 18, 1, 255 },
      { "Text rows", "g2TextRows", 2, 1, 255 },
      { "Text step", "g2TextStep", 2, 0, 255 },
      { "Arrow x", "g2ArrowX", 18, 0, 255 },
      { "Arrow y", "g2ArrowY", 17, 0, 255 },
      { "Menu x", "g2MenuX", 8, 0, 255 },
      { "Menu gap", "g2MenuGap", 6, 0, 255 },
      { "Park x", "g2ParkX", 2, 0, 255 },
      { "Park gap", "g2ParkGap", 12, 0, 255 },
    }
    for _, row in ipairs(g2Battle) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Door white", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "mapWhite", 13)) or 13
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_map_white", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "mapWhite", v, 13) end
    end)
    advRow("Warp white", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "warpWhite", 15)) or 15
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_warp_white", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "warpWhite", v, 15) end
    end)
    local menuWhites = {
      { "Menu white", "menuWhite", 23 },
      { "Fly white", "flyWhite", 31 },
      { "Fly build", "flyBuild", 28 },
      { "Fly blank", "flyBlank", 21 },
      { "Fly icon", "flyIcon", 3 },
    }
    for _, row in ipairs(menuWhites) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local pageWhites = {
      { "Party white", "partyWhite", 11 },
      { "Party icon", "partyIcon", 3 },
      { "Bag white", "packWhite", 16 },
      { "Gear white", "gearWhite", 20 },
      { "Gear exit", "gearExit", 4 },
      { "Card white", "cardWhite", 14 },
      { "Dex white", "dexWhite", 27 },
      { "Option white", "optionWhite", 8 },
      { "Fade in", "fadeIn", 3 },
    }
    for _, row in ipairs(pageWhites) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    if not Generation.isCrystal(S) then
      advRow("Party extra", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "partyExtra", 3)) or 3
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_party_extra", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "partyExtra", v, 3) end
      end)
    end
    advRow("Walk cycle", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "walkCycle", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g2_cycle", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "walkCycle", v, 16) end
    end)
    advRow("Leg up from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "legFrom", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g2_leg_from", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "legFrom", v, 4) end
    end)
    advRow("Leg up to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "legTo", 12)) or 12
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g2_leg_to", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "legTo", v, 12) end
    end)
  elseif Generation.isGen3(S) then
    advRow("Walk frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Walk", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_walk", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Walk", v, 16) end
    end)
    local g3Fish = {
      { "Fish wait", "fishWait", 60, 0, 255 },
      { "Fish dot", "fishDot", 20, 0, 255 },
      { "Fish dots", "fishDots", 10, 0, 255 },
      { "First dots", "fishFirst", 4, 0, 255 },
      { "Waterfall", "waterfall", 32, 1, 255 },
      { "Trade fade", "tradeFade", 16, 1, 255 },
      { "Trade hold", "tradeHold", 60, 0, 255 },
      { "Trade bye", "tradeBye", 80, 0, 255 },
      { "Ball wait", "tradeDepart", 20, 0, 255 },
      { "Ball return", "tradeReturn", 33, 1, 255 },
      { "Ball close", "tradeClose", 10, 0, 255 },
      { "Screen flash", "tradeFlash", 20, 0, 255 },
      { "Arrived", "tradeArrived", 10, 0, 255 },
      { "New mon", "tradeMon", 60, 0, 255 },
      { "After mon", "tradeAfter", 60, 0, 255 },
      { "Link save", "tradeSave", 50, 0, 255 },
      { "Link jitter", "tradeJitter", 30, 0, 255 },
      { "Link close", "tradeLink", 60, 0, 255 },
    }
    for _, row in ipairs(g3Fish) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local tradeVersion = Generation.isRse(S)
      and { { "Fanfare", "tradeFanfareRs", 4 }, { "Take care", "tradeCareRs", 240 } }
      or { { "Fanfare", "tradeFanfare", 10 }, { "Take care", "tradeCare", 250 } }
    for _, row in ipairs(tradeVersion) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local sceneRows = {
      { "Trade open", "tradeOpen", 16, 0 },
      { "Anim pause", "animPause", 32, 0 },
    }
    if not Generation.isRse(S) then
      sceneRows[#sceneRows + 1] = { "Ship horn", "anneHorn", 50, 0 }
      sceneRows[#sceneRows + 1] = { "Ship smoke", "anneSmoke", 70, 0 }
      sceneRows[#sceneRows + 1] = { "Ship step", "anneSlide", 5, 1 }
      sceneRows[#sceneRows + 1] = { "Ship leave", "anneLeave", 40, 0 }
      sceneRows[#sceneRows + 1] = { "Ship gone", "boatGone", -120, -512 }
      sceneRows[#sceneRows + 1] = { "Wake step", "wakeStep", 6, 1 }
      sceneRows[#sceneRows + 1] = { "Wake cap", "wakeCap", 22, 0 }
      sceneRows[#sceneRows + 1] = { "Wake flip", "wakeFlip", 12, 1 }
      sceneRows[#sceneRows + 1] = { "Wake x", "wakeX", 80, 0 }
      sceneRows[#sceneRows + 1] = { "Wake gone", "wakeCull", -18, -512 }
      sceneRows[#sceneRows + 1] = { "Wake y", "wakeY", 109, 0 }
      sceneRows[#sceneRows + 1] = { "Wake lift", "wakeLift", 16, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke drift", "smokeStep", 4, 1 }
      sceneRows[#sceneRows + 1] = { "Smoke 1", "smokeA", 10, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke 2", "smokeB", 30, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke 3", "smokeC", 50, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke end", "smokeEnd", 80, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke x", "smokeSpawn", 49, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke gone", "smokeCull", -32, -512 }
      sceneRows[#sceneRows + 1] = { "Smoke y", "smokeY", 78, 0 }
      sceneRows[#sceneRows + 1] = { "Smoke lift", "smokeLift", 8, 0 }
      sceneRows[#sceneRows + 1] = { "Ferry cross", "ferryCross", 140, 0 }
      sceneRows[#sceneRows + 1] = { "Ferry music", "ferryMusic", 64, 0 }
      sceneRows[#sceneRows + 1] = { "Dude scroll", "dudeScroll", 120, 0 }
      sceneRows[#sceneRows + 1] = { "Oak shade", "oakDim", 8, 0 }
      sceneRows[#sceneRows + 1] = { "Oak wait", "oakWait", 4, 0 }
    end
    if Generation.versionId(S) == "emerald" then
      sceneRows[#sceneRows + 1] = { "Arena pause", "arenaPause", 64, 0 }
    end
    for _, row in ipairs(sceneRows) do
      local label, key, default, minV = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local motionRows = {
      { "Slide start", "slideStart", 180, 0, 1024 },
      { "Slide step", "slideStep", 3, 1, 255 },
      { "Ball sound", "ballSound", 11, 0, 255 },
      { "Ball fly", "ballFly", 44, 0, 255 },
      { "Ball bounce", "ballBounce", 22, 0, 255 },
      { "Ball rest", "ballRest", 20, 0, 255 },
      { "Ball end", "ballEnd", 23, 0, 255 },
      { "Zoom far", "zoomMax", 1024, 0, 4096 },
      { "Zoom near", "zoomMin", 256, 0, 4096 },
      { "Zoom step", "zoomStep", 52, 1, 255 },
      { "Zoom screen", "zoomFar", 128, 0, 4096 },
      { "Flash length", "flashAnim", 126, 0, 255 },
      { "Screen top", "gbaTop", 348, 0, 1024 },
      { "Screen pan", "panEnd", 316, 0, 1024 },
      { "Cable line", "cableEnd", 328, 0, 1024 },
      { "Cable stop", "travelEnd", 166, 0, 1024 },
      { "Link height", "linkY", 80, -512, 512 },
      { "Link off", "linkOff", -8, -512, 512 },
      { "Cross step", "crossStep", 3, 1, 255 },
      { "Cross enter", "crossEnter", -90, -512, 512 },
      { "Cross exit", "crossExit", -222, -512, 512 },
      { "Cross mons", "crossMon", -222, -512, 512 },
      { "Cross top", "crossAy", 170, -512, 512 },
      { "Cross bottom", "crossBy", -10, -512, 512 },
      { "Arrive height", "arriveY", -20, -512, 512 },
      { "Arrive stop", "arriveAt", 64, -512, 512 },
      { "Screen center", "gbaCenter", 348, 0, 1024 },
      { "Ball drop", "ballDrop", -8, -512, 512 },
      { "Ball land", "ballLand", 74, -512, 512 },
      { "Ball fall", "ballFall", 4, 1, 255 },
      { "Ball bounce at", "ballIdx", 22, 0, 255 },
      { "Ball stop", "ballStop", 108, 0, 255 },
      { "Bounce 2", "bounce2", 66, 0, 255 },
      { "Bounce 3", "bounce3", 92, 0, 255 },
      { "Bounce 4", "bounce4", 107, 0, 255 },
      { "Screen height", "screenH", 160, 1, 255 },
    }
    for _, row in ipairs(motionRows) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Ball arc", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.BALL_VEL
      local cur = Steps.get(S, "ballVel", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_ballVel", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local rows = Steps.arcList(text) or {}
        return table.concat(rows, ",")
      end
      if not Steps.arcList(v) or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "ballVel", v, default) end
    end)
    local g3HealRows = {
      { "Center x", "g3HealX", 93, 0, 255 },
      { "Center y", "g3HealY", 36, 0, 255 },
      { "Screen x", "g3HealMonX", 128, 0, 255 },
      { "Screen y", "g3HealMonY", 24, 0, 255 },
      { "Ball nudge x", "g3HealNudgeX", -4, -512, 512 },
      { "Ball nudge y", "g3HealNudgeY", -4, -512, 512 },
      { "Screen nudge x", "g3HealMonNudgeX", -16, -512, 512 },
      { "Screen nudge y", "g3HealMonNudgeY", -8, -512, 512 },
      { "Ball gap", "g3HealGap", 25, 0, 255 },
      { "Ball end", "g3HealEnd", 32, 0, 255 },
      { "Glow step", "g3HealGlow", 8, 0, 255 },
      { "Glow laps", "g3HealLaps", 3, 0, 255 },
      { "Glow rest", "g3HealRest", 30, 0, 255 },
      { "Screen laps", "g3HealMonLaps", 3, 0, 255 },
    }
    for _, row in ipairs(g3HealRows) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g3HealLists = {
      { "Ball places", "g3HealOffs", "G3_HEAL_OFFS", "pair" },
      { "Screen frames", "g3HealSeq", "G3_HEAL_SEQ", "hold" },
      { "Screen holds", "g3HealDurs", "G3_HEAL_DURS", "hold" },
      { "Glow bright", "g3GlowK", "G3_GLOW_K", "hold" },
      { "Glow colors", "g3GlowSlots", "G3_GLOW_SLOTS", "hold" },
      { "Glow lead", "g3GlowLead", "G3_GLOW_LEAD", "hold" },
    }
    for _, row in ipairs(g3HealLists) do
      local label, key, which, kind = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          if kind == "pair" then
            local pairs = Steps.pairList(text) or {}
            local parts = {}
            for i = 1, #pairs do parts[i] = pairs[i][1] .. "," .. pairs[i][2] end
            return table.concat(parts, ",")
          end
          local list = Steps.holdList(text) or {}
          return table.concat(list, ",")
        end
        local parsed = kind == "pair" and Steps.pairList(v) or Steps.holdList(v)
        if not parsed or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g3FishLists = {
      { "Fish pictures", "g3FishBase", "G3_FISH_BASE", "base" },
      { "Rod out", "g3FishOut", "G3_FISH_OUT", "hold" },
      { "Rod away", "g3FishSn", "G3_FISH_SN", "hold" },
      { "Rod away side", "g3FishWe", "G3_FISH_WE", "hold" },
      { "Rod bite", "g3FishHook", "G3_FISH_HOOK", "hold" },
      { "Rod shift", "g3FishOff", "G3_FISH_OFF", "quad" },
      { "Field move", "g3FieldMove", "G3_FIELD_MOVE", "hold" },
    }
    if not Generation.isRse(S) then
      g3FishLists[#g3FishLists + 1] = { "Seeker", "g3VsSeq", "G3_VS_SEQ", "hold" }
      g3FishLists[#g3FishLists + 1] = { "Seeker bike", "g3VsBike", "G3_VS_BIKE", "hold" }
    end
    for _, row in ipairs(g3FishLists) do
      local label, key, which, kind = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          if kind == "quad" then
            local rows = Steps.quadList(text) or {}
            local parts = {}
            for i = 1, #rows do
              local r = rows[i]
              parts[i] = r.frame .. "," .. r.x .. "," .. r.left .. "," .. r.y
            end
            return table.concat(parts, ",")
          end
          local list = Steps.holdList(text) or {}
          if kind == "base" and #list < 4 then return "" end
          if kind == "base" then
            return list[1] .. "," .. list[2] .. "," .. list[3] .. "," .. list[4]
          end
          return table.concat(list, ",")
        end
        local parsed = kind == "quad" and Steps.quadList(v) or Steps.holdList(v)
        if kind == "base" and parsed and #parsed < 4 then parsed = nil end
        if not parsed or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local emeraldRun = Generation.versionId(S) == "emerald"
    local g3PoseLists = {
      { "Stand pictures", "g3Stand", "G3_STAND" },
      { "Step pictures", "g3WalkA", "G3_WALK_A" },
      { "Step pictures 2", "g3WalkB", "G3_WALK_B" },
      { "Run still", "g3RunStill", emeraldRun and "G3_RUN_STILL_E" or "G3_RUN_STILL" },
      { "Run step", "g3RunA", emeraldRun and "G3_RUN_A_E" or "G3_RUN_A" },
      { "Run step 2", "g3RunB", emeraldRun and "G3_RUN_B_E" or "G3_RUN_B" },
    }
    for _, row in ipairs(g3PoseLists) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          local list = Steps.holdList(text) or {}
          if #list < 4 then return "" end
          return list[1] .. "," .. list[2] .. "," .. list[3] .. "," .. list[4]
        end
        local parsed = Steps.holdList(v)
        if parsed and #parsed < 4 then parsed = nil end
        if not parsed or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Bow picture", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Bow", 9)) or 9
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3Bow", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Bow", v, 9) end
    end)
    advRow("Flash light", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Generation.isRse(S) and Steps.G3_FLASH_RSE or Steps.G3_FLASH
      local cur = Steps.get(S, "g3Flash", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g3Flash", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local list = Steps.holdList(text) or {}
        return table.concat(list, ",")
      end
      if flat(v) == "" or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "g3Flash", v, default) end
    end)
    advRow("Run frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Run", 8)) or 8
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_run", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Run", v, 8) end
    end)
    advRow("Turn frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Turn", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3_turn", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Turn", v, 4) end
    end)
    advRow("Bike frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Bike", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_bike", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Bike", v, 4) end
    end)
    advRow("Ledge frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Jump", 32)) or 32
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_jump", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Jump", v, 32) end
    end)
    advRow("Slow run", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Slow", 11)) or 11
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_slow", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Slow", v, 11) end
    end)
    advRow("Downhill frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Fast", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_fast", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Fast", v, 4) end
    end)
    advRow("Run cycle", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3RunCycle", 8)) or 8
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_run_cycle", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3RunCycle", v, 8) end
    end)
    advRow("Run pose", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3RunPose", 5)) or 5
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3_run_pose", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3RunPose", v, 5) end
    end)
    advRow("Approach gap", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "approachGap", 1)) or 1
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3_approach", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "approachGap", v, 1) end
    end)
    advRow("Notice pause", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "emoteFrames", 60)) or 60
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3_notice", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "emoteFrames", v, 60) end
    end)
    if not Generation.isRse(S) then
      advRow("Mark step", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "markStep", 1)) or 1
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_mark_step", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "markStep", v, 1) end
      end)
      advRow("Emote first", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "emoteA", 4)) or 4
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_emote_a", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "emoteA", v, 4) end
      end)
      advRow("Emote second", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "emoteB", 8)) or 8
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_emote_b", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "emoteB", v, 8) end
      end)
      advRow("Mark height", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "markLift", 16)) or 16
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_mark_lift", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "markLift", v, 16) end
      end)
      local markPics = {
        { "Exclaim", "markBang", 0 }, { "Double", "markBang2", 6 },
        { "Cross", "markX", 3 }, { "Smile", "markSmile", 9 },
        { "Question", "markAsk", 12 },
      }
      for _, row in ipairs(markPics) do
        local label, key, default = row[1], row[2], row[3]
        advRow(label, function(fx, fy_, fw, fh_)
          local Steps = require("StepCounters")
          local cur = tonumber(Steps.get(S, key, default)) or default
          local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
          if v ~= cur then Steps.set(S, App, key, v, default) end
        end)
      end
    end
    local reflRows = {
      { "Reflection drop", "reflDrop", 14, -128, 127 },
      { "Reflection reach", "reflCull", 64, 0, 255 },
      { "Reflection pad", "reflPad", 8, 0, 255 },
    }
    for _, row in ipairs(reflRows) do
      local label, key, default, lo, hi = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(lo, math.min(hi, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    if Generation.isRse(S) then
      local bridges = {
        { "Bridge 1", "reflBridge1", 12 },
        { "Bridge 2", "reflBridge2", 28 },
        { "Bridge 3", "reflBridge3", 44 },
      }
      for _, row in ipairs(bridges) do
        local label, key, default = row[1], row[2], row[3]
        advRow(label, function(fx, fy_, fw, fh_)
          local Steps = require("StepCounters")
          local cur = tonumber(Steps.get(S, key, default)) or default
          local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
          if v ~= cur then Steps.set(S, App, key, v, default) end
        end)
      end
      advRow("Water wave", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps.DISTORT
        local cur = Steps.get(S, "distort", default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_distort", fx, fy_, fw, fh_, cur, default)
        local list = Steps.arcList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
        if same or not list or #list < 2 then v = default end
        if v ~= cur then Steps.set(S, App, "distort", v, default) end
      end)
    end
    advRow("Cut frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "cutHold", 6)) or 6
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_cut_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "cutHold", v, 6) end
    end)
    local cutRows = {
      { "Cut across", "cutX", -8 },
      { "Cut down", "cutY", -16 },
    }
    for _, row in ipairs(cutRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Leaf frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "leafStep", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_leaf_step", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "leafStep", v, 4) end
    end)
    advRow("Leaf fall", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "leafFall", 0.12)) or 0.12
      local v = tonumber(RegList.num(App, "pl_leaf_fall", fx, fy_, 100 * s, fh_, cur)) or cur
      if v < 0 then v = 0 end
      if v > 10 then v = 10 end
      if v ~= cur then Steps.set(S, App, "leafFall", v, 0.12) end
    end)
    local grassPuff = {
      { "Grass speed", "grassBase", 1.2 },
      { "Grass spread", "grassSpread", 1 },
      { "Grass lift", "grassLift", 1 },
    }
    for _, row in ipairs(grassPuff) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = tonumber(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur)) or cur
        if v < 0 then v = 0 end
        if v > 10 then v = 10 end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Grass spot", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "grassSpot", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_grass_spot", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "grassSpot", v, 4) end
    end)
    advRow("Smash frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "smashHold", 6)) or 6
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_smash_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "smashHold", v, 6) end
    end)
    advRow("Smash chip", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "smashStep", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_smash_step", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "smashStep", v, 4) end
    end)
    advRow("Smash fall", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "smashFall", 0.15)) or 0.15
      local v = tonumber(RegList.num(App, "pl_smash_fall", fx, fy_, 100 * s, fh_, cur)) or cur
      if v < 0 then v = 0 end
      if v > 10 then v = 10 end
      if v ~= cur then Steps.set(S, App, "smashFall", v, 0.15) end
    end)
    local smashPuff = {
      { "Chip speed", "smashBase", 1.2 },
      { "Chip spread", "smashSpread", 1.6 },
      { "Chip lift", "smashLift", 1.5 },
      { "Chip wobble", "smashJitter", 0.3 },
    }
    for _, row in ipairs(smashPuff) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = tonumber(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur)) or cur
        if v < 0 then v = 0 end
        if v > 10 then v = 10 end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Chip spot", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "smashSpot", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_smash_spot", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "smashSpot", v, 4) end
    end)
    advRow("Grass length", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "grassFrames", 24)) or 24
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_grass_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "grassFrames", v, 24) end
    end)
    advRow("Scent length", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "scentFrames", 50)) or 50
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_scent_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "scentFrames", v, 50) end
    end)
    advRow("Scent size", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "scentRadius", 120)) or 120
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_scent_radius", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "scentRadius", v, 120) end
    end)
    local scentRows = {
      { "Scent gap", "scentGap", 20 },
      { "Scent across", "scentX", 120 },
      { "Scent down", "scentY", 80 },
    }
    for _, row in ipairs(scentRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Splash frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "splashHold", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_splash_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "splashHold", v, 4) end
    end)
    advRow("Dust frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "dustHold", 8)) or 8
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_dust_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "dustHold", v, 8) end
    end)
    local puffPics = {
      { "Splash pictures", "splashPics", "SPLASH_PICS" },
      { "Dust pictures", "dustPics", "DUST_PICS" },
    }
    for _, row in ipairs(puffPics) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.holdList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.holdList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Rustle frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "rustleHold", 10)) or 10
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rustle_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "rustleHold", v, 10) end
    end)
    advRow("Rustle pictures", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.RUSTLE
      local cur = Steps.get(S, "rustlePics", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_rustle_pics", fx, fy_, fw, fh_, cur, default)
      local list = Steps.holdList(v)
      local same = list and table.concat(list, ", ") == table.concat(Steps.holdList(default), ", ")
      if same or not list then v = default end
      if v ~= cur then Steps.set(S, App, "rustlePics", v, default) end
    end)
    advRow("Foot height", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "feetH", 8)) or 8
      local v = math.max(1, math.min(16, math.floor(RegList.num(App, "pl_feet_h", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "feetH", v, 8) end
    end)
    advRow("Grass slack", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "grassSlack", 2)) or 2
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_grass_slack", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "grassSlack", v, 2) end
    end)
    local waterHolds = {
      { "Feet pictures", "feetPics", "FEET_PICS" },
      { "Ripple pictures", "ripplePics", "RIPPLE_PICS" },
      { "Feet holds", "feetHold", "FEET_HOLD" },
      { "Ripple holds", "rippleHold", "RIPPLE_HOLD" },
    }
    for _, row in ipairs(waterHolds) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.holdList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.holdList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Ripple down", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "rippleY", 6)) or 6
      local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_ripple_y", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "rippleY", v, 6) end
    end)
    if Generation.isRse(S) then
      local groundRows = {
        { "Short grass", "shortLift", 8, -128, 127 },
        { "Sand lift", "sandLift", 2, -128, 127 },
        { "Tire blink", "tireBlink", 41, 0, 255 },
        { "Tire end", "tireEnd", 57, 0, 255 },
        { "Effect center", "place", 8, 0, 255 },
        { "Puddle drop", "splashDrop", 12, 0, 255 },
        { "Bubble down", "bubbleY", 0, 0, 255 },
        { "Berry sparkle", "berryY", 4, 0, 255 },
        { "Sand pillar", "pillarY", 0, 0, 255 },
        { "Sparkle wait", "sparkleWait", 34, 0, 255 },
        { "Sand picture", "sandFrame", 2, 0, 255 },
      }
      for _, row in ipairs(groundRows) do
        local label, key, default, lo, hi = row[1], row[2], row[3], row[4], row[5]
        advRow(label, function(fx, fy_, fw, fh_)
          local Steps = require("StepCounters")
          local cur = tonumber(Steps.get(S, key, default)) or default
          local v = math.max(lo, math.min(hi, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
          if v ~= cur then Steps.set(S, App, key, v, default) end
        end)
      end
      advRow("Bubble rise", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "bubbleRise", 0.5)) or 0.5
        local v = tonumber(RegList.num(App, "pl_bubble_rise", fx, fy_, 100 * s, fh_, cur)) or cur
        if v < 0 then v = 0 end
        if v > 10 then v = 10 end
        if v ~= cur then Steps.set(S, App, "bubbleRise", v, 0.5) end
      end)
      advRow("Tire turns", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps.TIRE_TURNS
        local cur = Steps.get(S, "tireTurns", default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_tire_turns", fx, fy_, fw, fh_, cur, default)
        local list = Steps.holdList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.holdList(default), ", ")
        if same or not list or #list < 16 then v = default end
        if v ~= cur then Steps.set(S, App, "tireTurns", v, default) end
      end)
    end
    advRow("Surf frame", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "surfHold", 48)) or 48
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_surf_hold", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "surfHold", v, 48) end
    end)
    local surfSize = {
      { "Blob width", "surfW", 32 },
      { "Blob height", "surfH", 32 },
      { "Blob frames", "surfFrames", 6 },
    }
    for _, row in ipairs(surfSize) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local blobRows = {
      { "Blob across", "blobX", -8 },
      { "Blob down", "blobY", -8 },
      { "Blob bob", "blobBob", -1 },
    }
    for _, row in ipairs(blobRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Track blink", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "trackBlink", 41)) or 41
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_track_blink", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "trackBlink", v, 41) end
    end)
    advRow("Track length", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "trackEnd", 57)) or 57
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_track_end", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "trackEnd", v, 57) end
    end)
    advRow("Shake every", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "shakeEvery", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_shake_every", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "shakeEvery", v, 4) end
    end)
    advRow("Shake size", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "shakeAmp", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_shake_amp", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "shakeAmp", v, 4) end
    end)
    advRow("Shake fade", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "shakeFade", 2)) or 2
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_shake_fade", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "shakeFade", v, 2) end
    end)
    advRow("Rock wait", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "rockWait", 120)) or 120
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rock_wait", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "rockWait", v, 120) end
    end)
    advRow("Rock size", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "rockAmp", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rock_amp", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "rockAmp", v, 4) end
    end)
    advRow("Rock fade", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "rockDecay", 21)) or 21
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rock_decay", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "rockDecay", v, 21) end
    end)
    advRow("Shard across", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fragX", 260)) or 260
      local v = math.max(0, math.min(9999, math.floor(RegList.num(App, "pl_frag_x", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fragX", v, 260) end
    end)
    advRow("Shard down", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "fragY", 200)) or 200
      local v = math.max(0, math.min(9999, math.floor(RegList.num(App, "pl_frag_y", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "fragY", v, 200) end
    end)
    local rockRows = {
      { "Shard step", "shardX", 16, 0 }, { "Shard lift", "shardY", 12, 0 },
      { "Rock hold", "rockHold", 2, 1 }, { "Rock flip", "rockFlip", 1, 1 },
    }
    for _, row in ipairs(rockRows) do
      local label, key, default, minV = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local startRows = {
      { "Start across", "rockFootX", -8, -128, 127 },
      { "Start down", "rockFootY", -20, -128, 127 },
      { "Start above", "rockTop", 4, 0, 255 },
    }
    for _, row in ipairs(startRows) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local flyRows = {
      { "Fly pause", "flySwoop", 16 },
      { "Fly mount", "flyMount", 8 },
      { "Fly away", "flyOff", 10 },
      { "Fly ride", "flyIn", 33 },
      { "Fly pose", "flyPose", 24 },
      { "Fly finish", "flyEnd", 16 },
    }
    for _, row in ipairs(flyRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local warpRows = {
      { "Warp spin", "tpSpin", 8 }, { "Warp turns", "tpTurns", 8 },
      { "Warp rise", "tpRiseTurn", 4 }, { "Rise first", "tpSpeedFirst", 8 },
      { "Rise every", "tpSpeedEvery", 4 }, { "Rise cap", "tpSpeedCap", 8 },
      { "Warp lift", "tpLift", 8 }, { "Warp height", "tpVanish", 168 },
      { "Warp drop", "tpDrop", 8 }, { "Drop turn", "tpDropTurn", 4 },
      { "Drop slow", "tpSlow", 48 }, { "Drop clear", "tpGround", 8 },
      { "Land spin", "tpLand", 8 }, { "Land turns", "tpLandTurns", 4 },
      { "Drop start", "tpStart", 88 },
    }
    for _, row in ipairs(warpRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local birdRows = {
      { "Swoop wide", "birdSwoopX", 140, 0 }, { "Swoop high", "birdSwoopY", 72, 0 },
      { "Swoop step", "birdSwoopStep", 4, 1 }, { "Swoop end", "birdSwoopEnd", 128, 0 },
      { "Ride wide", "birdRideX", 180, 0 }, { "Ride high", "birdRideY", 72, 0 },
      { "Ride step", "birdRideStep", 2, 1 }, { "Ride end", "birdRideEnd", 128, 0 },
    }
    for _, row in ipairs(birdRows) do
      local label, key, default, minV = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(255, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local spawnRows = {
      { "Boy pop", "popBoy", 128, 0, 255 }, { "Girl pop", "popGirl", 118, 0, 255 },
      { "Pop height", "popY", -48, -128, 127 },
      { "Boy return", "backBoy", 112, 0, 255 }, { "Girl return", "backGirl", 100, 0, 255 },
      { "Return height", "backY", -32, -128, 127 },
      { "Dive across", "diveX", 120, 0, 255 }, { "Dive height", "diveY", 0, -128, 127 },
      { "Ride across", "rideX", 120, 0, 255 }, { "Ride down", "rideY", 72, 0, 255 },
      { "Seat", "seat", 8, 0, 255 }, { "Bird nudge", "birdNudge", 8, 0, 255 },
      { "Boy away", "boyAway", 1, 0, 255 }, { "Girl away", "girlAway", 3, 0, 255 },
      { "Boy home", "boyHome", 2, 0, 255 }, { "Girl home", "girlHome", 4, 0, 255 },
      { "Bird rest", "birdRest", 0, 0, 255 },
      { "Bird width", "birdW", 64, 1, 255 },
      { "Bird height", "birdH", 64, 1, 255 },
      { "Bird frames", "birdFrames", 5, 1, 255 },
    }
    for _, row in ipairs(spawnRows) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local ballRows = {
      { "Ball wide", "ballWide", 120, 255 }, { "Ball push", "ballPush", 96, 255 },
      { "Ball cap", "ballCap", 2048, 9999 }, { "Ball end", "ballEnd", 129, 255 },
      { "Ball angle", "ballAngle", 64, 255 }, { "Ball speed", "ballSpeed", 256, 9999 },
    }
    for _, row in ipairs(ballRows) do
      local label, key, default, maxV = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local backRows = {
      { "Back wide", "returnWide", 32, 255 }, { "Back high", "returnHigh", 120, 255 },
      { "Back angle", "returnAngle", 240, 255 }, { "Back speed", "returnSpeed", 2048, 9999 },
      { "Back brake", "returnBrake", 128, 255 }, { "Brake grow", "returnGrow", 24, 255 },
      { "Back floor", "returnFloor", 256, 9999 }, { "Brake cap", "returnBrakeCap", 256, 9999 },
      { "Back end", "returnEnd", 60, 255 },
    }
    local spinRows = {
      { "Pop size", "leaveScale", 8, 0, 9999 }, { "Pop tilt", "leaveTilt", -30, -128, 127 },
      { "Pop frames", "leaveFrames", 30, 0, 255 }, { "Pop grow", "leaveGrow", 28, 0, 255 },
      { "Shrink size", "shrinkScale", 256, 0, 9999 }, { "Shrink tilt", "shrinkTilt", 64, -128, 127 },
      { "Shrink frames", "shrinkFrames", 22, 0, 255 }, { "Shrink step", "shrinkStep", 10, 0, 255 },
      { "Away grow", "awayGrow", 24, 0, 255 }, { "Arrive pop", "arrivePop", 512, 0, 9999 },
      { "Arrive shrink", "arriveShrink", 16, 0, 255 },
    }
    for _, row in ipairs(backRows) do
      local label, key, default, maxV = row[1], row[2], row[3], row[4]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    for _, row in ipairs(spinRows) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Flash length", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "flashFrames", 30)) or 30
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_flash_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "flashFrames", v, 30) end
    end)
    advRow("Veil length", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "veilFrames", 8)) or 8
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_veil_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "veilFrames", v, 8) end
    end)
    local flyHops = {
      { "Onto bird", "mountArc", "MOUNT_ARC" },
      { "Off bird", "dismountArc", "DISMOUNT_ARC" },
    }
    for _, row in ipairs(flyHops) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.arcList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("NPC walk", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3NpcWalk", 16)) or 16
      local v = math.max(1, math.min(65535, math.floor(RegList.num(App, "pl_g3_npc_walk", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3NpcWalk", v, 16) end
    end)
    advRow("NPC run", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3NpcRun", 8)) or 8
      local v = math.max(1, math.min(65535, math.floor(RegList.num(App, "pl_g3_npc_run", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3NpcRun", v, 8) end
    end)
    advRow("NPC slow run", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3NpcSlow", 11)) or 11
      local v = math.max(1, math.min(65535, math.floor(RegList.num(App, "pl_g3_npc_slow", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3NpcSlow", v, 11) end
    end)
    advRow("Float step", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3LevStep", 4)) or 4
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_lev_step", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3LevStep", v, 4) end
    end)
    advRow("Float turn", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3LevTurn", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g3_lev_turn", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3LevTurn", v, 16) end
    end)
    advRow("Float pixels", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3LevPixel", 1)) or 1
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g3_lev_px", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3LevPixel", v, 1) end
    end)
    local figRows = {
      { "Figure 8 across", "fig8X", "FIG8_X" },
      { "Figure 8 down", "fig8Y", "FIG8_Y" },
      { "Copy from", "copyFor", "COPY_FOR" },
      { "Copy to", "copyTo", "COPY_TO" },
    }
    for _, row in ipairs(figRows) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.arcList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local playerArcs = {
      { "Ledge arc", "playerHopHigh", "-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0" },
      { "Player hop", "playerHop", "-2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0" },
      { "Player low hop", "playerHopLow", "0, -2, -3, -4, -5, -6, -6, -6, -5, -5, -4, -3, -2, 0, 0, 0" },
      { "Surf hop arc", "surfHop", "-2, -4, -6, -8, -9, -10, -10, -9, -8, -6, -4, -2, 0, 0, 0, 0" },
    }
    for _, row in ipairs(playerArcs) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.arcList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local pauseRows = {
      { "Medium 1", "g3Med1", 32 }, { "Medium 2", "g3Med2", 64 },
      { "Medium 3", "g3Med3", 96 }, { "Medium 4", "g3Med4", 128 },
      { "Long 1", "g3Long1", 32 }, { "Long 2", "g3Long2", 64 },
      { "Long 3", "g3Long3", 128 }, { "Long 4", "g3Long4", 192 },
      { "Short 1", "g3Short1", 32 }, { "Short 2", "g3Short2", 48 },
      { "Short 3", "g3Short3", 64 }, { "Short 4", "g3Short4", 80 },
    }
    for _, row in ipairs(pauseRows) do
      local label, key, default = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Rotate pause", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "g3Rotate", 48)) or 48
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g3_rotate", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "g3Rotate", v, 48) end
    end)
    if Generation.isRse(S) then
      advRow("Mach coast", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseCoast", 16)) or 16
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_coast", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseCoast", v, 16) end
      end)
      advRow("Mach speed", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseSpeed", 8)) or 8
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_speed", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseSpeed", v, 8) end
      end)
      advRow("Mach top", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseTop", 4)) or 4
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_top", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseTop", v, 4) end
      end)
      advRow("Acro roll", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseAcro", 6)) or 6
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_acro", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseAcro", v, 6) end
      end)
      advRow("Acro hop", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseHop", 16)) or 16
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_hop", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseHop", v, 16) end
      end)
      advRow("Acro ledge", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseLedge", 32)) or 32
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_rse_ledge", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseLedge", v, 32) end
      end)
      advRow("Hop window", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseWindow", 4)) or 4
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rse_window", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseWindow", v, 4) end
      end)
      advRow("Wall bump", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseBump", 16)) or 16
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rse_bump", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseBump", v, 16) end
      end)
      advRow("Turn bump", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseTurnBump", 8)) or 8
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rse_turnbump", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseTurnBump", v, 8) end
      end)
      advRow("Wheelie frames", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "rseWheelie", 8)) or 8
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_rse_wheelie", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "rseWheelie", v, 8) end
      end)
      advRow("NPC hop", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "g3NpcHop", 16)) or 16
        local v = math.max(1, math.min(65535, math.floor(RegList.num(App, "pl_g3_npc_hop", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "g3NpcHop", v, 16) end
      end)
      advRow("NPC far hop", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "g3NpcFar", 32)) or 32
        local v = math.max(1, math.min(65535, math.floor(RegList.num(App, "pl_g3_npc_far", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "g3NpcFar", v, 32) end
      end)
      local arcRows = {
        { "Hop arc", "hopArc", "-2, -4, -6, -8, -9, -10, -10, -10, -9, -8, -6, -5, -3, -2, 0, 0" },
        { "High hop arc", "hopArcHigh", "-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0" },
        { "Low hop arc", "hopArcLow", "0, -2, -3, -4, -5, -6, -6, -6, -5, -5, -4, -3, -2, 0, 0, 0" },
      }
      for _, row in ipairs(arcRows) do
        local label, key, default = row[1], row[2], row[3]
        advRow(label, function(fx, fy_, fw, fh_)
          local Steps = require("StepCounters")
          local cur = Steps.get(S, key, default)
          if type(cur) ~= "string" then cur = default end
          local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
          local list = Steps.arcList(v)
          local same = list and table.concat(list, ", ") == table.concat(Steps.arcList(default), ", ")
          if same or not list then v = default end
          if v ~= cur then Steps.set(S, App, key, v, default) end
        end)
      end
      advRow("Berry blink", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "berryBlink", 2)) or 2
        local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_berry_blink", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "berryBlink", v, 2) end
      end)
      advRow("Berry sparkle", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "berrySparkle", 64)) or 64
        local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_berry_sparkle", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "berrySparkle", v, 64) end
      end)
      advRow("Emote hop", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "emoteHop", -5)) or -5
        local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_emote_hop", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "emoteHop", v, -5) end
      end)
      advRow("Emote gravity", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "emoteGravity", 1)) or 1
        local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_emote_grav", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "emoteGravity", v, 1) end
      end)
      advRow("Mark gap", function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, "markGap", 8)) or 8
        local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_mark_gap", fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, "markGap", v, 8) end
      end)
    end
  else
    advRow("Walk frames", function(fx, fy_, fw, fh_)
      local cur = tonumber(Player.worldField(S, "stepFrames", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_walk", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Player.setWorld(S, "stepFrames", v, 16, App) end
    end)
    advRow("Bike frames", function(fx, fy_, fw, fh_)
      local cur = tonumber(Player.worldField(S, "bikeStepFrames", 8)) or 8
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_bike", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Player.setWorld(S, "bikeStepFrames", v, 8, App) end
    end)
    advRow("Turn frames", function(fx, fy_, fw, fh_)
      local cur = tonumber(Player.worldField(S, "turnFrames", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_turn", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Player.setWorld(S, "turnFrames", v, 4, App) end
    end)
    advRow("Touch turn", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "touchTurn", 8)) or 8
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_touch", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "touchTurn", v, 8) end
    end)
    advRow("Walk loop", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "loopFrames", 2)) or 2
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_loop", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "loopFrames", v, 2) end
    end)
    advRow("Spin cadence", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spinIter", 6)) or 6
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_spin", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spinIter", v, 6) end
    end)
    advRow("Ledge lift", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "hopPeak", 10)) or 10
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_hop", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "hopPeak", v, 10) end
    end)
    advRow("Surf bob cycle", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bobPeriod", 32)) or 32
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_bob", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bobPeriod", v, 32) end
    end)
    advRow("Surf bob pose", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bobHalf", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_bob_half", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bobHalf", v, 16) end
    end)
    advRow("Surf bob drop", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "bobPixels", 1)) or 1
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_bob_px", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "bobPixels", v, 1) end
    end)
    advRow("Hole drop", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "holeSink", 8)) or 8
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_hole", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "holeSink", v, 8) end
    end)
    advRow("Walk cycle", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "walkCycle", 16)) or 16
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_cycle", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "walkCycle", v, 16) end
    end)
    advRow("Leg up from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "legFrom", 4)) or 4
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_leg_from", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "legFrom", v, 4) end
    end)
    advRow("Leg up to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "legTo", 12)) or 12
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_leg_to", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "legTo", v, 12) end
    end)
    advRow("Spin lift", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spinRise", 16)) or 16
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_rise", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spinRise", v, 16) end
    end)
    advRow("Warp lift", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "warpLift", 24)) or 24
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_warp", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "warpLift", v, 24) end
    end)
    advRow("Warp frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "warpFrames", 64)) or 64
      local v = math.max(1, math.min(255, math.floor(RegList.num(App, "pl_g1_warp_frames", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "warpFrames", v, 64) end
    end)
    local g1Travel = {
      { "Fly fade", "g1FlyFade", 4, 0, 255 },
      { "Fly flap", "g1FlyFlap", 8, 0, 255 },
      { "Fly beat", "g1FlyBeat", 40, 0, 255 },
      { "Fly step", "g1FlyStep", 3, 1, 255 },
      { "Teleport out", "g1TeleportOut", 135, 0, 65535 },
      { "Pad out", "g1PadOut", 15, 0, 255 },
      { "Teleport in", "g1TeleportIn", 43, 0, 255 },
      { "Pad in", "g1PadIn", 18, 0, 255 },
      { "Drop steps", "g1DropSteps", 6, 0, 255 },
      { "Hole spin", "g1HoleIn", 15, 0, 255 },
      { "Rise at", "g1InPlace", 16, 0, 255 },
      { "Ship keep", "g1ShipKeep", 16, 0, 255 },
      { "Ship sail", "g1Sail", 128, 0, 255 },
      { "Ship step", "g1SailStep", 8, 0, 255 },
      { "Smoke every", "g1SmokeEvery", 16, 0, 255 },
      { "Smoke x", "g1SmokeX", 64, 0, 255 },
      { "Smoke y", "g1SmokeY", 20, 0, 255 },
      { "Smoke drift", "g1SmokeDrift", 2, -128, 127 },
      { "Ship x", "g1ShipX", 5, 0, 255 },
      { "Ship y", "g1ShipY", 1, 0, 255 },
      { "Ship wide", "g1ShipW", 4, 0, 255 },
      { "Ship tall", "g1ShipH", 2, 0, 255 },
      { "Ghost pad", "g1GhostPad", 16, 0, 255 },
      { "Heal screen", "g1HealMonX", 44, 0, 255 },
      { "Heal height", "g1HealMonY", 20, 0, 255 },
      { "Heal anchor", "g1HealAnchor", 64, 0, 255 },
      { "Heal flip", "g1HealFlip", 8, 0, 255 },
      { "Heal ball", "g1HealBall", 30, 0, 255 },
      { "Heal flash", "g1HealFlash", 10, 0, 255 },
      { "Heal flashes", "g1HealFlashes", 8, 0, 255 },
      { "Delay", "g1Delay", 3, 0, 255 },
      { "Fade from black", "g1FadeBlack", 32, 0, 255 },
      { "Fade to white", "g1OutWhite", 24, 0, 255 },
      { "Fade from white", "g1InWhite", 24, 0, 255 },
      { "Warp out", "g1WarpOut", 32, 0, 255 },
      { "Warp in", "g1WarpIn", 0, 0, 255 },
      { "Battle return", "g1BattleReturn", 10, 0, 255 },
      { "Hole wait", "g1HoleWait", 50, 0, 255 },
      { "Text scroll", "g1Scroll", 10, 0, 255 },
      { "Text wait", "g1TextWait", 3, 0, 255 },
      { "Page clear", "g1PageClear", 20, 0, 255 },
      { "Yes or no", "g1YesNo", 15, 0, 255 },
      { "Slide in", "g1Slide", 72, 0, 255 },
      { "Slide step", "g1SlidePx", 2, 0, 255 },
      { "Trainer gap", "g1TrainerGap", 20, 0, 255 },
      { "Send out", "g1SendOut", 40, 0, 255 },
      { "Move start", "g1MovePre", 3, 0, 255 },
      { "Move end", "g1MoveOff", 30, 0, 255 },
      { "Miss wait", "g1Miss", 30, 0, 255 },
      { "Substitute", "g1Substitute", 50, 0, 255 },
      { "Shake up", "g1ShakeV", 48, 0, 255 },
      { "Shake hard", "g1ShakeHeavy", 72, 0, 255 },
      { "Shake slow", "g1ShakeSlow", 48, 0, 255 },
      { "Shake light", "g1ShakeLight", 18, 0, 255 },
      { "Shake late", "g1ShakeSlow2", 24, 0, 255 },
      { "Blink", "g1Blink", 60, 0, 255 },
      { "Faint", "g1Faint", 14, 0, 255 },
      { "Faint step", "g1FaintStep", 4, 0, 255 },
      { "Switch wait", "g1Switch", 50, 0, 255 },
      { "Crit text", "g1CritText", 20, 0, 255 },
      { "HP bar", "g1HpBar", 48, 1, 255 },
      { "HP pixel", "g1HpPixel", 2, 0, 255 },
      { "HP step", "g1HpStep", 1, 0, 255 },
      { "Fade step", "g1FadeStep", 8, 1, 255 },
      { "White flash", "g1Flash", 7, 0, 255 },
    }
    for _, row in ipairs(g1Travel) do
      local label, key, default, minV, maxV = row[1], row[2], row[3], row[4], row[5]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local cur = tonumber(Steps.get(S, key, default)) or default
        local v = math.max(minV, math.min(maxV, math.floor(RegList.num(App, "pl_" .. key, fx, fy_, 100 * s, fh_, cur))))
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g1Holds = {
      { "Teleport holds", "g1OutHolds", "G1_OUT_HOLDS" },
      { "Pad holds", "g1PadHolds", "G1_PAD_HOLDS" },
      { "Arrive holds", "g1InHolds", "G1_IN_HOLDS" },
      { "Pad in holds", "g1PadInHolds", "G1_PAD_IN_HOLDS" },
      { "Hole holds", "g1HoleHolds", "G1_HOLE_HOLDS" },
      { "Ship water", "g1ShipWater", "G1_SHIP_WATER" },
    }
    for _, row in ipairs(g1Holds) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local list = Steps.holdList(v)
        local same = list and table.concat(list, ", ") == table.concat(Steps.holdList(default), ", ")
        if same or not list then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Rod", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.G1_ROD
      local cur = Steps.get(S, "g1Rod", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g1Rod", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local rows = Steps.rodList(text) or {}
        local parts = {}
        for i = 1, #rows do
          local row = rows[i]
          parts[#parts + 1] = row.dx .. "," .. row.dy .. "," .. row.tile .. "," .. (row.flip and 1 or 0)
        end
        return table.concat(parts, ",")
      end
      if not Steps.rodList(v) or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "g1Rod", v, default) end
    end)
    advRow("Heal balls", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local default = Steps.G1_HEAL_BALLS
      local cur = Steps.get(S, "g1HealBalls", default)
      if type(cur) ~= "string" then cur = default end
      local v = RegList.field(App, "pl_g1HealBalls", fx, fy_, fw, fh_, cur, default)
      local function flat(text)
        local rows = Steps.tripleList(text) or {}
        local parts = {}
        for i = 1, #rows do
          parts[i] = rows[i][1] .. "," .. rows[i][2] .. "," .. (rows[i][3] and 1 or 0)
        end
        return table.concat(parts, ",")
      end
      if not Steps.tripleList(v) or flat(v) == flat(default) then v = default end
      if v ~= cur then Steps.set(S, App, "g1HealBalls", v, default) end
    end)
    local g1Shades = {
      { "DMG flash", "g1HealDmg", "G1_HEAL_DMG" },
      { "Color flash", "g1HealGbc", "G1_HEAL_GBC" },
      { "Lit shades", "g1HealLit", "G1_HEAL_LIT" },
      { "Dim shades", "g1HealDim", "G1_HEAL_DIM" },
    }
    for _, row in ipairs(g1Shades) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          local list = Steps.holdList(text) or {}
          if #list < 4 then return "" end
          local parts = {}
          for i = 1, 4 do
            local n = list[i]
            if n > 3 then n = 3 end
            parts[i] = tostring(n)
          end
          return table.concat(parts, ",")
        end
        if flat(v) == "" or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    local g1Fly = {
      { "Fly out", "g1FlyOut", "G1_FLY_OUT" },
      { "Fly away", "g1FlyAway", "G1_FLY_AWAY" },
      { "Fly in", "g1FlyIn", "G1_FLY_IN" },
      { "Fly anchor", "g1FlyAnchor", "G1_FLY_ANCHOR" },
      { "Fly land", "g1FlyLand", "G1_FLY_LAND" },
    }
    for _, row in ipairs(g1Fly) do
      local label, key, which = row[1], row[2], row[3]
      advRow(label, function(fx, fy_, fw, fh_)
        local Steps = require("StepCounters")
        local default = Steps[which]
        local cur = Steps.get(S, key, default)
        if type(cur) ~= "string" then cur = default end
        local v = RegList.field(App, "pl_" .. key, fx, fy_, fw, fh_, cur, default)
        local function flat(text)
          local pairs = Steps.pairList(text) or {}
          local parts = {}
          for i = 1, #pairs do parts[#parts + 1] = pairs[i][1] .. "," .. pairs[i][2] end
          return table.concat(parts, ",")
        end
        if not Steps.pairList(v) or flat(v) == flat(default) then v = default end
        if v ~= cur then Steps.set(S, App, key, v, default) end
      end)
    end
    advRow("Sight origin X", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightX", 64)) or 64
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_sight_x", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightX", v, 64) end
    end)
    advRow("Sight origin Y", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightY", 60)) or 60
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_sight_y", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightY", v, 60) end
    end)
    advRow("Sight left", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightLeft", -4)) or -4
      local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_sight_left", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightLeft", v, -4) end
    end)
    advRow("Sight right", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightRight", 5)) or 5
      local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_sight_right", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightRight", v, 5) end
    end)
    advRow("Sight up", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightUp", -4)) or -4
      local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_sight_up", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightUp", v, -4) end
    end)
    advRow("Sight down", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "sightDown", 4)) or 4
      local v = math.max(-128, math.min(127, math.floor(RegList.num(App, "pl_sight_down", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "sightDown", v, 4) end
    end)
    advRow("Notice pause", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "emoteFrames", 60)) or 60
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_emote", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "emoteFrames", v, 60) end
    end)
    advRow("Approach gap", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "approachGap", 1)) or 1
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_g1_approach", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "approachGap", v, 1) end
    end)
    advRow("NPC step frames", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "npcStep", 32)) or 32
      local v = math.max(0, math.min(255, math.floor(RegList.num(App, "pl_npc_step_g1", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "npcStep", v, 32) end
    end)
    advRow("Wander from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "wanderLo", 30)) or 30
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_wander_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "wanderLo", v, 30) end
    end)
    advRow("Wander to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "wanderHi", 180)) or 180
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_wander_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "wanderHi", v, 180) end
    end)
    advRow("Turn chance", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "turnOdds", 50)) or 50
      local v = math.max(0, math.min(100, math.floor(RegList.num(App, "pl_g1_turn_odds", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "turnOdds", v, 50) end
    end)
    advRow("First pause from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spawnLo", 30)) or 30
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_spawn_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spawnLo", v, 30) end
    end)
    advRow("First pause to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "spawnHi", 120)) or 120
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_spawn_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "spawnHi", v, 120) end
    end)
    advRow("Stay pause from", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "stayLo", 1)) or 1
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_stay_lo", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "stayLo", v, 1) end
    end)
    advRow("Stay pause to", function(fx, fy_, fw, fh_)
      local Steps = require("StepCounters")
      local cur = tonumber(Steps.get(S, "stayHi", 128)) or 128
      local v = math.max(0, math.min(65535, math.floor(RegList.num(App, "pl_g1_stay_hi", fx, fy_, 100 * s, fh_, cur))))
      if v ~= cur then Steps.set(S, App, "stayHi", v, 128) end
    end)
  end
  advRow("HM moves", function(fx, fy_, fw, fh_)
    local cur = joinCsvIds(Player.constField(S, "hmMoves"))
    local v = RegList.field(App, "pl_const_hm", fx, fy_, fw, fh_, cur, "CUT, FLY, SURF")
    if v ~= cur then Player.setConst(S, "hmMoves", parseCsvIds(v), App) end
  end)

  Kit.text("small", "Badges", viewX, fy + 6 * s, PAL.caption)
  fy = fy + 28 * s
  local badges = Player.badgeRows(S)
  if #badges == 0 then
    Kit.text("micro", "(no badges — add one below)", viewX, fy, PAL.faint)
    fy = fy + 20 * s
  end
  for i = 1, math.max(#badges, 0) do
    local badge = badges[i] or { id = "", name = "" }
    local idCur = tostring(badge.id or "")
    local nameCur = tostring(badge.name or "")
    Kit.text("micro", "#" .. i, viewX, fy + 8 * s, PAL.muted)
    local idV = RegList.field(App, "pl_bdg_id_" .. i, viewX + 28 * s, fy, 140 * s, fh,
      idCur, "BOULDERBADGE")
    local nameV = RegList.field(App, "pl_bdg_nm_" .. i, viewX + 176 * s, fy,
      viewW - 176 * s - 44 * s, fh, nameCur, "Boulder")
    if idV ~= idCur or nameV ~= nameCur then
      local rows = Player.ensureBadges(S, App)
      rows[i] = rows[i] or {}
      rows[i].id = idV
      rows[i].name = nameV
    end
    if Kit.button(viewX + viewW - 36 * s, fy, 32 * s, fh, "X", { kind = "danger" }) then
      local rows = Player.ensureBadges(S, App)
      table.remove(rows, i)
      App.markDirty()
      break
    end
    fy = fy + fh + 6 * s
  end
  if Kit.button(viewX, fy, 100 * s, fh, "+ Badge", { kind = "good" }) then
    local rows = Player.ensureBadges(S, App)
    rows[#rows + 1] = { id = "NEW_BADGE", name = "Badge" }
    App.markDirty()
  end
  fy = fy + fh + secGap

  Kit.caption(viewX, fy, "TRADES / SHOPS")
  fy = fy + 24 * s
  Kit.text("micro",
    "Open the dedicated editors for in-game trades and shop inventories.",
    viewX, fy, PAL.muted)
  fy = fy + 22 * s
  if Kit.button(viewX, fy, 100 * s, fh, "Trades", { kind = "accent" }) then
    S.tab = "trades"
  end
  if Kit.button(viewX + 110 * s, fy, 100 * s, fh, "Shops", { kind = "accent" }) then
    S.tab = "shops"
  end
  fy = fy + fh + secGap

  if not Generation.isGen2(S) then
    Kit.caption(viewX, fy, "FLY ORDER")
    fy = fy + 24 * s
    Kit.text("micro",
      "Controls the order and availability of destinations shown by the Fly menu.",
      viewX, fy, PAL.muted)
    fy = fy + 22 * s

    local function ensureFlyOrder()
      if type(S.project.flyOrder) == "table" then return S.project.flyOrder end
      local base = (S.data and S.data.field and S.data.field.flyOrder) or {}
      local copy = {}
      for i, mid in ipairs(base) do copy[i] = mid end
      S.project.flyOrder = copy
      if next(S.project.flyWarps or {}) == nil then
        local fw = (S.data and S.data.field and S.data.field.flyWarps) or {}
        S.project.flyWarps = {}
        for mid, spot in pairs(fw) do
          if type(spot) == "table" then
            S.project.flyWarps[mid] = { x = spot.x or 0, y = spot.y or 0 }
          end
        end
      end
      App.markDirty()
      return copy
    end

    if type(S.project.flyOrder) ~= "table" then
      if Kit.button(viewX, fy, 160 * s, fh, "Edit fly order…", { kind = "accent" }) then
        ensureFlyOrder()
      end
      fy = fy + fh + 8 * s
    else
      local order = S.project.flyOrder
      S.project.flyWarps = S.project.flyWarps or {}
      for i, mid in ipairs(order) do
        local midV = RegList.field(App, "pl_fly_" .. i, viewX, fy,
          160 * s, fh, tostring(mid or ""), "PALLET_TOWN"):upper():gsub("%s+", "_")
        if midV ~= mid then
          order[i] = midV
          if S.project.flyWarps[mid] and not S.project.flyWarps[midV] then
            S.project.flyWarps[midV] = S.project.flyWarps[mid]
            S.project.flyWarps[mid] = nil
          end
          App.markDirty()
          mid = midV
        end
        local spot = S.project.flyWarps[mid]
        if not spot then
          local base = S.data and S.data.field and S.data.field.flyWarps
            and S.data.field.flyWarps[mid]
          spot = { x = (base and base.x) or 0, y = (base and base.y) or 0 }
          S.project.flyWarps[mid] = spot
        end
        local xV = tonumber(RegList.num(App, "pl_flyx_" .. i,
          viewX + 170 * s, fy, 50 * s, fh, tonumber(spot.x) or 0)) or 0
        local yV = tonumber(RegList.num(App, "pl_flyy_" .. i,
          viewX + 228 * s, fy, 50 * s, fh, tonumber(spot.y) or 0)) or 0
        if xV ~= (spot.x or 0) or yV ~= (spot.y or 0) then
          spot.x, spot.y = xV, yV
          App.markDirty()
        end
        Kit.text("micro", "land x,y", viewX + 286 * s, fy + 8 * s, PAL.faint)
        if Kit.button(viewX + viewW - 36 * s, fy, 32 * s, fh, "X",
            { kind = "danger" }) then
          S.project.flyWarps[mid] = nil
          table.remove(order, i)
          App.markDirty()
          break
        end
        fy = fy + fh + 6 * s
      end
      if Kit.button(viewX, fy, 120 * s, fh, "+ Fly spot", { kind = "good" }) then
        order[#order + 1] = "NEW_TOWN"
        S.project.flyWarps["NEW_TOWN"] = { x = 0, y = 0 }
        App.markDirty()
      end
      fy = fy + fh + 8 * s
    end
  else
    Kit.caption(viewX, fy, "FLY POINTS")
    fy = fy + 24 * s
    Kit.text("micro",
      "Maps each Fly landmark to the spawn and landing position used on arrival.",
      viewX, fy, PAL.muted)
    fy = fy + 22 * s

    local function ensureFlyPoints()
      if type(S.project.flyPoints) == "table" and #S.project.flyPoints > 0 then
        return S.project.flyPoints
      end
      local ok, FieldMoves = pcall(require, "src.world.gen2.FieldMoves")
      local base = (ok and FieldMoves and FieldMoves.FLYPOINTS) or {}
      local spawns = S.data and S.data.gen2Landmarks and S.data.gen2Landmarks.spawns
      local copy = {}
      for i, row in ipairs(base) do
        local spot = spawns and spawns[row.spawn]
        copy[i] = {
          landmark = row.landmark, spawn = row.spawn, flag = row.flag,
          map = spot and spot.map, x = spot and spot.x, y = spot and spot.y,
        }
      end
      S.project.flyPoints = copy
      App.markDirty()
      return copy
    end

    if type(S.project.flyPoints) ~= "table" or #S.project.flyPoints == 0 then
      if Kit.button(viewX, fy, 160 * s, fh, "Edit fly points…", { kind = "accent" }) then
        ensureFlyPoints()
      end
      fy = fy + fh + 8 * s
    else
      local rows = S.project.flyPoints
      for i, row in ipairs(rows) do
        local landmarkV = RegList.field(App, "pl_flylm_" .. i, viewX, fy,
          150 * s, fh, tostring(row.landmark or ""), "LANDMARK_...")
          :upper():gsub("%s+", "_")
        if landmarkV ~= row.landmark then row.landmark = landmarkV end
        local spawnV = RegList.field(App, "pl_flysp_" .. i, viewX + 158 * s, fy,
          130 * s, fh, tostring(row.spawn or ""), "SPAWN_...")
          :upper():gsub("%s+", "_")
        if spawnV ~= row.spawn then row.spawn = spawnV end
        local flagV = tonumber(RegList.num(App, "pl_flyfl_" .. i,
          viewX + 294 * s, fy, 44 * s, fh, tonumber(row.flag) or 0)) or 0
        if flagV ~= (row.flag or 0) then row.flag = flagV end
        local mapV = RegList.field(App, "pl_flymap_" .. i, viewX + 344 * s, fy,
          130 * s, fh, tostring(row.map or ""), "map")
          :upper():gsub("%s+", "_")
        if mapV ~= (row.map or "") then row.map = (mapV ~= "" and mapV) or nil end
        local xV = tonumber(RegList.num(App, "pl_flyx_" .. i,
          viewX + 480 * s, fy, 44 * s, fh, tonumber(row.x) or 0)) or 0
        local yV = tonumber(RegList.num(App, "pl_flyy_" .. i,
          viewX + 528 * s, fy, 44 * s, fh, tonumber(row.y) or 0)) or 0
        if xV ~= (row.x or 0) then row.x = xV end
        if yV ~= (row.y or 0) then row.y = yV end
        Kit.text("micro", "land map/x,y", viewX + 576 * s, fy + 8 * s, PAL.faint)
        if Kit.button(viewX + viewW - 36 * s, fy, 32 * s, fh, "X",
            { kind = "danger" }) then
          table.remove(rows, i)
          App.markDirty()
          break
        end
        fy = fy + fh + 6 * s
      end
      if Kit.button(viewX, fy, 120 * s, fh, "+ Fly point", { kind = "good" }) then
        rows[#rows + 1] = { landmark = "LANDMARK_NEW", spawn = "SPAWN_NEW", flag = 0 }
        App.markDirty()
      end
      fy = fy + fh + 8 * s
    end
  end

  S._playerAdvancedH = math.max(120 * s, fy - innerY + scrollPad)
  row = innerY + S._playerAdvancedH + pad
  FormPane.finish(S, "playerAdvScroll", pageTop, row, pageView)
end

function Player.draw(S, x, y, w, h, App)
  local s = Kit.scale
  if not S.project then
    Kit.emptyBox(x, y, w, h, "Open a mod on the Project tab first")
    return
  end
  State.ensureProjectFields(S.project)

  if Generation.isGen3(S) then require("Gen3Workbench").prepare(S) end
  local modeY = RegList.modeChips(S, "playerMode", modesFor(S), x, y, s)
  local mode = S.playerMode or "start"
  local bodyH = h - (modeY - y)
  if Generation.isGen3(S) and mode=="starters" then
    require("Gen3StartersPanel").draw(S,x,modeY,w,bodyH,App)
  elseif Generation.isGen3(S) and (mode=="pics" or mode=="overworld") then
    require("Gen3Assets").draw(S,x,modeY,w,bodyH,App,function(path)
      return mode=="pics" and path:find("/trainers/",1,true) or mode=="overworld" and path:find("/ow/",1,true)
    end)
  elseif mode == "pics" then
    drawPics(S, x, modeY, w, bodyH, App)
  elseif mode == "overworld" then
    drawOverworld(S, x, modeY, w, bodyH, App)
  elseif mode == "advanced" then
    Player.drawAdvanced(S, x, modeY, w, bodyH, App)
  else
    drawStart(S, x, modeY, w, bodyH, App)
  end
end

return Player
