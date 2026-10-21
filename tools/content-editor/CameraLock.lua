-- Camera lock: the follow camera stops at the edge of the maps chosen in the
-- editor, in every game.
-- project.cameraLockMaps[mapId] = true
--
-- Nothing in the engine is changed; the lock is generated into main.lua.
-- Gen 1 / Gen 2 wrap Camera.follow (shared by both worlds) and clamp the
-- camera to the open map. Gen 3 computes its camera inside FieldView.draw, so
-- the lock adds the pan that brings it back inside the map, the same way the
-- engine's own camera object does.

local M = {}

function M.enabled(project, id)
  return ((project or {}).cameraLockMaps or {})[id] == true
end

function M.set(project, id, on)
  if on then
    project.cameraLockMaps = project.cameraLockMaps or {}
    project.cameraLockMaps[id] = true
  elseif project.cameraLockMaps then
    project.cameraLockMaps[id] = nil
    if not next(project.cameraLockMaps) then project.cameraLockMaps = nil end
  end
end

function M.used(project)
  return next((project or {}).cameraLockMaps or {}) ~= nil
end

local GEN12 = [=[
    local okC, Camera = pcall(require, "src.render.Camera")
    local okR, Runtime = pcall(require, "src.mods.Runtime")
    if okC and okR and type(Camera) == "table" and type(Camera.follow) == "function" then
      if not Camera._editorCameraLock then
        Camera._editorCameraLock = true
        local original = Camera.follow
        Camera.follow = function(...) return Runtime.call("editor.camera_lock.follow", original, ...) end
      end
      -- A map smaller than the view stays centered.
      local function fit(value, size, view)
        if size <= view then return math.floor((size - view) / 2) end
        return math.max(0, math.min(size - view, value))
      end
      mod.hooks:wrap("editor.camera_lock.follow", function(proceed, camera, px, py, viewW, viewH)
        proceed()
        local world = mod.world
        local overworld = world and world:overworld()
        local map = overworld and overworld.map
        if not (map and lockedMaps[map.id]) then return end
        camera.x = fit(camera.x, (map.widthCells or 0) * 16, viewW or 160)
        camera.y = fit(camera.y, (map.heightCells or 0) * 16, viewH or 144)
      end)
    end
]=]

local GEN3 = [=[
    local okV, FieldView = pcall(require, "src.core.game3.field_view")
    local okR, Runtime = pcall(require, "src.mods.Runtime")
    local okM, Map = pcall(require, "src.core.game3.map")
    local okP, Player = pcall(require, "src.core.game3.player")
    if okV and okR and okM and okP and type(FieldView.draw) == "function" then
      if not FieldView._editorCameraLock then
        FieldView._editorCameraLock = true
        local draw = FieldView.draw
        FieldView.draw = function(...) return Runtime.call("editor.camera_lock.draw", draw, ...) end
      end
      -- A map smaller than the view stays centered.
      local function fit(value, size, view)
        if size <= view then return math.floor((size - view) / 2) end
        return math.max(0, math.min(size - view, value))
      end
      local function restore(panX, panY, ok, ...)
        FieldView.cameraPanX, FieldView.cameraPanY = panX, panY
        if not ok then error((...), 0) end
        return ...
      end
      mod.hooks:wrap("editor.camera_lock.draw", function(proceed, game, w, h, opts)
        local def = lockedMaps[Map.current] and Map.currentDef()
        local layout = def and def.midLayout
        local px, py = tonumber(Player.px), tonumber(Player.py)
        if not (layout and px and py) then return proceed() end
        local viewW, viewH = w or 240, h or 160
        -- the camera FieldView.draw would use, then where it should be
        local rawX = math.floor(px + 8 - viewW / 2)
        local rawY = math.floor(py + 8 - viewH / 2)
        local panX = fit(rawX, (layout.trueWidth or layout.width) * 16, viewW) - rawX
        local panY = fit(rawY, (layout.trueHeight or layout.height) * 16, viewH) - rawY
        if panX == 0 and panY == 0 then return proceed() end
        local baseX, baseY = FieldView.cameraPanX or 0, FieldView.cameraPanY or 0
        FieldView.cameraPanX, FieldView.cameraPanY = baseX + panX, baseY + panY
        return restore(baseX, baseY, pcall(proceed))
      end)
    end
]=]

--- Append the lock to the generated main.lua (inside `return function(mod)`).
function M.emit(project, out, gen3)
  if not M.used(project) then return end
  local ids = {}
  for id in pairs(project.cameraLockMaps) do ids[#ids + 1] = id end
  table.sort(ids)
  out[#out + 1] = "  -- Camera lock (MAPS > Camera): the camera stops at the edge of these maps."
  out[#out + 1] = "  do"
  out[#out + 1] = "    local lockedMaps = {"
  for _, id in ipairs(ids) do
    out[#out + 1] = string.format("      [%q] = true,", id)
  end
  out[#out + 1] = "    }"
  out[#out + 1] = gen3 and GEN3 or GEN12
  out[#out + 1] = "  end"
  out[#out + 1] = ""
end

return M
