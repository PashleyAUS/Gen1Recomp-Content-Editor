-- Gold, Silver, and Crystal share the Magnet Train tilemaps.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local function bytes(n, value)
  local list = {}
  for i = 1, n do list[i] = value end
  return list
end

local Train = require("Gen2MagnetTrain")
local bg = bytes(Train.BG_COUNT, 1)
local train = bytes(Train.TRAIN_COUNT, 2)
bg[1], bg[2] = 7, 8
train[1] = 9
local S = {
  version = "gold",
  data = { field = { magnetTrain = { bgTiles = bg, tilemap = train, source = "ROM" } } },
  project = { game = "gold", tilesets = {} },
}
require("Generation").bindGoldData(S.data)
assert(S.data.gen2Field == S.data.field, "field.lua is the Gen 2 field table")
assert(Train.record(S).bgTiles[1] == 7)
assert(Train.paint(S, "scenery", 1, 7) == false, "painting the vanilla tile does not copy it")
assert(not Train.owned(S))
assert(Train.paint(S, "scenery", 3, 40))
assert(S.data.field.magnetTrain.bgTiles[3] == 1, "vanilla stays unchanged")
assert(S.project.magnetTrain.bgTiles[1] == 7)
assert(S.project.magnetTrain.bgTiles[3] == 40)
assert(S.project.magnetTrain.tilemap[1] == 9)
Train.validate(S.project.magnetTrain)

local rows = require("src.core.gen2.MagnetTrain").new({
  bgTiles = S.project.magnetTrain.bgTiles,
  fgTilemap = S.project.magnetTrain.tilemap,
}):tilemap()
assert(rows[1][1] == 7 and rows[1][2] == 8, "scenery pairs repeat across the row")
assert(rows[7][1] == 9, "the train covers the middle rows")

local Writer = require("ModWriter")
local function install(game)
  local project = {
    game = game,
    magnetTrain = S.project.magnetTrain,
  }
  local out = {}
  Train.emit(project, Writer.encodeLua, out)
  return out
end

for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local out = install(game)
  assert(#out > 0, game .. " emits the ride")
  local events = {}
  local mod = { events = { on = function(_, name, fn) events[name] = fn end } }
  assert(loadstring("return function(mod)\n" .. table.concat(out, "\n") .. "\nend"))()(mod)
  local data = { gen2Field = { magnetTrain = { bgTiles = bytes(36, 1), tilemap = bytes(80, 2), source = "ROM" } } }
  events["mods.loaded"]({ data = data })
  assert(data.gen2Field.magnetTrain.bgTiles[3] == 40, game)
  assert(data.gen2Field.magnetTrain.tilemap[1] == 9, game)
  assert(data.gen2Field.magnetTrain.source == "ROM", game .. " keeps the other ride fields")
  assert(data.gen2Field.magnetTrain.width == 20 and data.gen2Field.magnetTrain.rows == 4, game)
end

local red = {}
Train.emit({ game = "red", magnetTrain = S.project.magnetTrain }, Writer.encodeLua, red)
assert(#red == 0, "Red has no Magnet Train")

local bad = { bgTiles = bytes(36, 1), tilemap = bytes(79, 2) }
assert(not pcall(Train.validate, bad), "a short train map is rejected")

local main = Writer.emitMain({
  id = "train_test", game = "silver",
  magnetTrain = S.project.magnetTrain,
}, {})
assert(type(main) == "string" and main:find("data.gen2Field.magnetTrain", 1, true),
  "Save writes the ride into main.lua")

Train.revert(S)
assert(not Train.owned(S))
assert(Train.record(S).bgTiles[3] == 1)

print("PASS magnet train tilemaps")
