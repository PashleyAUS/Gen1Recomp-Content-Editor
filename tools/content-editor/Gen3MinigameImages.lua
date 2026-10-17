-- Mini-game images already decoded in the imported cache. Entries with `key`
-- take file and size from that folder's manifest. Each game's list keeps
-- the order the animation preview draws from.
local M={}
M.emerald={
 slots={dir="rse_slot_machine",
  {name="Reel symbols",file="reel_symbols.png"},
  {name="Reel Time Pikachu",file="reel_time_pikachu.png"},
  {name="Reel Time machine",file="reel_time_machine_0.png"},
  {name="Reel Time explosion",file="reel_time_explosion.png"},
  {name="Reel background",file="reel_background_0.png"},
  {name="Numbers",file="numbers.png"},
 },
 crush={dir="berry_crush",
  {name="Berry Crush background",key="bg"},
  {name="Crusher graphics",key="crusher_base"},
  {name="Impact animation frames",key="impact"},
  {name="Powder sparkles",key="sparkle"},
  {name="Timer numbers",key="timer_digits"},
 },
 jump={dir="pokemon_jump",
  {name="Pokemon Jump background",key="bg"},
  {name="Venusaur graphics",key="venusaur"},
  {name="Bonus graphics",key="bonuses"},
  {name="Vine animation 1",key="vine1"},
  {name="Vine animation 2",key="vine2"},
  {name="Vine animation 3",key="vine3"},
  {name="Vine animation 4",key="vine4"},
  {name="Star animation",key="star"},
 },
 dodrio={dir="dodrio_berry_picking",
  {name="Berry Picking background",key="bg"},
  {name="Dodrio animation frames",key="dodrio"},
  {name="Berries",key="berries"},
  {name="Cloud",key="cloud"},
  {name="Status icons",key="status"},
  {name="Tree border tiles",key="tree_border_left"},
 },
}
-- FireRed and LeafGreen share Emerald's wireless mini-game folders; only
-- the Game Corner slot machine differs.
M.kanto={
 slots={dir="slot_machine",
  {name="Slot machine background",key="bg"},
  {name="Winning combinations",key="combos_window"},
  {name="Reel symbols",key="reel_icons"},
  {name="Clefairy animation frames",key="clefairy"},
  {name="Pressed button",key="button_pressed"},
 },
 crush=M.emerald.crush,jump=M.emerald.jump,dodrio=M.emerald.dodrio,
}
local function lists(S)
  if require("Generation").isRse(S) then return M.emerald end
  return M.kanto
end
function M.list(S,game) return lists(S)[game] end

-- Cache path the game reads for this picture, plus the manifest row when
-- the sheet is raw RGBA.
function M.cachePath(S, game, index)
  local spec = lists(S)[game]
  local rec = spec and spec[index]
  if not rec then return nil, "Unknown mini-game image" end
  local dir = "data/generated/gba/" .. spec.dir .. "/"
  if rec.file then return dir .. rec.file, rec end
  local manifest = require("Gen3Resources").readTable(S.data, dir .. "manifest.lua")
  local entry = manifest[rec.key]
  if type(entry) ~= "table" then return nil, "Missing Gen 3 cache: " .. dir .. "manifest.lua" end
  return dir .. (entry.file or rec.key .. ".rgba"), rec, entry
end

local function cacheImage(S, game, index)
  local path, err, entry = M.cachePath(S, game, index)
  if not path then return nil, err end
  local override = (S.project and S.project.gen3Assets or {})[path]
  local bytes
  if override and override.file and S.path then
    bytes = require("ModIO").readText(S.path .. "/" .. override.file)
  else
    bytes = S.data._gen3Read(path)
  end
  if not bytes then return nil, "Missing Gen 3 cache: " .. path end
  if path:match("%.rgba$") then
    local width = (entry and entry.width) or (override and override.width)
    local height = (entry and entry.height) or (override and override.height)
    if not width or not height or #bytes < width * height * 4 then
      return nil, "Missing Gen 3 cache: " .. path
    end
    return love.image.newImageData(width, height, "rgba8", bytes:sub(1, width * height * 4))
  end
  return love.image.newImageData(love.filesystem.newFileData(bytes, path:match("[^/]+$")))
end
function M.image(S,game,index)
 local path = M.cachePath(S, game, index)
 local override = path and (S.project and S.project.gen3Assets or {})[path]
 local cache=S.data._miniGameImages or {};S.data._miniGameImages=cache
 local key=game.."/"..index.."/"..(override and override.file or "")
 if cache[key] then return cache[key] end
 local img,err=cacheImage(S,game,index);if not img then return nil,err end
 cache[key]=img;return img
end
return M
