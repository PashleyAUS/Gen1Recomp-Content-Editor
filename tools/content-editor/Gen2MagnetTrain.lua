-- Magnet Train ride tilemaps (engine/events/magnet_train.asm).
-- Gold, Silver, and Crystal share the ride. The scenery is a 2x18 strip
-- repeated across the background; the train is a 20x4 map laid over rows 6-9.
-- Tile pictures come from TILESET_TRAIN_STATION, already in VRAM.

local M = {}
local Kit = require("Kit")
local Theme = require("Theme")
local PAL = Theme.PAL

M.BG_COUNT = 36
M.TRAIN_COUNT = 80
M.TRAIN_WIDTH = 20
M.TRAIN_ROWS = 4

local function vanilla(S)
  local field = S.data and (S.data.gen2Field or S.data.field)
  local gfx = field and field.magnetTrain
  if type(gfx) ~= "table" then return nil end
  return gfx
end

function M.owned(S)
  return S.project and type(S.project.magnetTrain) == "table"
end

function M.record(S)
  if M.owned(S) then return S.project.magnetTrain end
  return vanilla(S)
end

local function copyList(src, n)
  local out = {}
  for i = 1, n do
    local v = src and src[i]
    out[i] = type(v) == "number" and math.floor(v) % 256 or 0
  end
  return out
end

function M.begin(S)
  local src = vanilla(S) or {}
  S.project.magnetTrain = {
    bgTiles = copyList(src.bgTiles, M.BG_COUNT),
    tilemap = copyList(src.tilemap, M.TRAIN_COUNT),
  }
end

function M.revert(S)
  if S.project then S.project.magnetTrain = nil end
end

function M.paint(S, layer, index, tile)
  tile = math.floor(tonumber(tile) or 0)
  assert(tile >= 0 and tile <= 255, "Tile ids are bytes")
  local key = layer == "train" and "tilemap" or "bgTiles"
  local n = key == "tilemap" and M.TRAIN_COUNT or M.BG_COUNT
  assert(type(index) == "number" and index >= 1 and index <= n and index % 1 == 0,
    "That cell is outside the Magnet Train map")
  local rec = M.record(S)
  local list = rec and rec[key]
  if list and list[index] == tile then return false end
  if not M.owned(S) then M.begin(S) end
  S.project.magnetTrain[key][index] = tile
  return true
end

local function byteList(name, list, n)
  assert(type(list) == "table" and #list == n, name .. " needs " .. n .. " tile ids")
  for i = 1, n do
    local v = list[i]
    assert(type(v) == "number" and v >= 0 and v <= 255 and v % 1 == 0,
      name .. " tile ids are bytes")
  end
end

function M.validate(mt)
  assert(type(mt) == "table", "Magnet Train tilemaps are missing")
  byteList("Scenery", mt.bgTiles, M.BG_COUNT)
  byteList("Train", mt.tilemap, M.TRAIN_COUNT)
end

function M.emit(project, encode, out)
  if not require("Generation").isGen2({ version = project.game or project.version }) then return end
  local mt = project.magnetTrain
  if type(mt) ~= "table" then return end
  M.validate(mt)
  out[#out + 1] = "  -- Magnet Train scenery and train tilemaps (data.gen2Field.magnetTrain)"
  out[#out + 1] = "  do"
  out[#out + 1] = "    local _mt = " .. encode(mt)
  out[#out + 1] = "    mod.events:on(\"mods.loaded\", function(ev)"
  out[#out + 1] = "      local data = ev and ev.data"
  out[#out + 1] = "      if type(data) ~= \"table\" then return end"
  out[#out + 1] = "      if type(data.gen2Field) ~= \"table\" then data.gen2Field = {} end"
  out[#out + 1] = "      local src = data.gen2Field.magnetTrain"
  out[#out + 1] = "      local ride = {}"
  out[#out + 1] = "      if type(src) == \"table\" then"
  out[#out + 1] = "        for k, v in pairs(src) do ride[k] = v end"
  out[#out + 1] = "      end"
  out[#out + 1] = "      ride.bgTiles = _mt.bgTiles"
  out[#out + 1] = "      ride.tilemap = _mt.tilemap"
  out[#out + 1] = "      ride.width = 20"
  out[#out + 1] = "      ride.rows = 4"
  out[#out + 1] = "      data.gen2Field.magnetTrain = ride"
  out[#out + 1] = "    end)"
  out[#out + 1] = "  end"
  out[#out + 1] = ""
end

local function station(S)
  local id = "TILESET_TRAIN_STATION"
  local proj = S.project and S.project.tilesets and S.project.tilesets[id]
  if type(proj) == "table" and proj.image then return proj end
  local tilesets = require("Generation").dataTilesets(S)
  return tilesets and tilesets[id]
end

local quads = setmetatable({}, { __mode = "k" })
local function quadFor(img, tile, perRow)
  local bag = quads[img]
  if not bag then bag = {}; quads[img] = bag end
  local q = bag[tile]
  if not q then
    local col, row = tile % perRow, math.floor(tile / perRow)
    q = love.graphics.newQuad(col * 8, row * 8, 8, 8, img:getDimensions())
    bag[tile] = q
  end
  return q
end

local function drawTile(img, perRow, nTiles, tile, x, y, size)
  local G = love.graphics
  if img and tile >= 0 and tile < nTiles then
    G.setColor(1, 1, 1, 1)
    G.draw(img, quadFor(img, tile, perRow), x, y, 0, size / 8, size / 8)
  else
    G.setColor(0.12, 0.14, 0.2, 1)
    G.rectangle("fill", x, y, size, size)
  end
  G.setColor(1, 1, 1, 0.35)
  G.rectangle("line", x, y, size, size)
end

local function screenRows(rec)
  if not rec then return nil end
  local ok, MT = pcall(require, "src.core.gen2.MagnetTrain")
  if not ok or not MT then return nil end
  return MT.new({ bgTiles = rec.bgTiles, fgTilemap = rec.tilemap }):tilemap()
end

function M.draw(S, x, y, w, h, App)
  local s = Kit.scale
  local fy, view, viewX, viewW = require("RegList").beginForm(S, x, y, w, h,
    "uiTrainScroll", "magnet", 12 * s)
  local contentTop = fy
  local rec = M.record(S)
  local owned = M.owned(S)
  Kit.caption(viewX, fy, "MAGNET TRAIN")
  fy = fy + 22 * s
  Kit.text("micro", owned
      and "Saved with this mod. Playtest uses these tilemaps on the ride."
      or "Vanilla tilemaps from the imported game. Painting a cell saves a copy in the mod.",
    viewX, fy, PAL.muted)
  fy = fy + 18 * s
  Kit.text("micro", "Pictures are the train station tileset. Change those on the GFX tab.",
    viewX, fy, PAL.muted)
  fy = fy + 22 * s
  if owned and Kit.button(viewX, fy, 160 * s, 28 * s, "Revert to vanilla", { kind = "danger" }) then
    M.revert(S)
    App.markDirty()
    rec, owned = M.record(S), false
  end
  if owned then fy = fy + 36 * s end
  if not rec then
    Kit.text("small", "This import has no Magnet Train tilemaps.", viewX, fy, PAL.caption)
    fy = fy + 28 * s
    if Kit.button(viewX, fy, 220 * s, 28 * s, "Set up Magnet Train", { kind = "good" }) then
      M.begin(S)
      App.markDirty()
    end
    require("FormPane").finish(S, "uiTrainScroll", contentTop, fy + 36 * s, view)
    return
  end

  local sheet = station(S)
  local img = sheet and sheet.image and require("Preview").image(S, sheet.image) or nil
  local perRow = (sheet and sheet.tilesPerRow) or 16
  local nTiles = 0
  if img then nTiles = math.floor(img:getWidth() / 8) * math.floor(img:getHeight() / 8) end

  local rows = screenRows(rec)
  local cell = 8 * s
  if rows then
    Kit.text("micro", "What the ride draws", viewX, fy, PAL.caption)
    fy = fy + 16 * s
    for row = 1, 18 do
      local line = rows[row]
      for col = 1, 20 do
        drawTile(img, perRow, nTiles, line and line[col] or 0,
          viewX + (col - 1) * cell, fy + (row - 1) * cell, cell)
      end
    end
    fy = fy + 18 * cell + 12 * s
  end

  local function grid(title, key, cols, count)
    Kit.text("small", title, viewX, fy, PAL.caption)
    fy = fy + 20 * s
    local size = 16 * s
    local rowsN = math.ceil(count / cols)
    for i = 1, count do
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local cx = viewX + col * size
      local cy = fy + row * size
      local tile = rec[key][i] or 0
      drawTile(img, perRow, nTiles, tile, cx, cy, size)
      if Kit.press(cx, cy, size, size) then
        if M.paint(S, key == "tilemap" and "train" or "scenery", i, S._magnetBrush or 0) then
          App.markDirty()
        end
      end
      if Kit.hit(cx, cy, size, size) then
        Kit.offerTooltip(cx, cy, size, size, "Tile " .. tostring(tile))
      end
    end
    fy = fy + rowsN * size + 12 * s
  end
  grid("Scenery strip (repeats across the screen)", "bgTiles", 2, M.BG_COUNT)
  grid("Train (covers the middle of the screen)", "tilemap", M.TRAIN_WIDTH, M.TRAIN_COUNT)

  Kit.text("small", "Brush", viewX, fy + 6 * s, PAL.caption)
  local raw = Kit.textfield("magnet_brush", viewX + 70 * s, fy, 80 * s, 28 * s, tostring(S._magnetBrush or 0), "0")
  local brush = tonumber(raw)
  if brush then S._magnetBrush = math.max(0, math.min(255, math.floor(brush))) end
  fy = fy + 36 * s
  if img and nTiles > 0 then
    local shown = math.min(nTiles, 16 * 6)
    local size = 16 * s
    for i = 0, shown - 1 do
      local col = i % 16
      local row = math.floor(i / 16)
      local cx = viewX + col * size
      local cy = fy + row * size
      drawTile(img, perRow, nTiles, i, cx, cy, size)
      if i == (S._magnetBrush or 0) then
        love.graphics.setColor(0.3, 1, 0.45, 1)
        love.graphics.rectangle("line", cx, cy, size, size)
      end
      if Kit.press(cx, cy, size, size) then S._magnetBrush = i end
    end
    fy = fy + math.ceil(shown / 16) * size
  end
  require("FormPane").finish(S, "uiTrainScroll", contentTop, fy + 8 * s, view)
end

return M
