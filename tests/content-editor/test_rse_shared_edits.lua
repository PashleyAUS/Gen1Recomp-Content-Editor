-- Shared Hoenn and Gen 3 editors must not stay Emerald-only.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local Generation = require("Generation")
local Berries = require("Gen3Berries")
local Contest = require("Gen3ContestEvo")
local Split = require("Gen3Split")
local Clock = require("Gen3SystemClock")

for _, game in ipairs({ "ruby", "sapphire", "emerald" }) do
  assert(Generation.isRse({ version = game }), game .. " is RSE")
  assert(Generation.isRseId(game), game .. " id is RSE")
  local project = { game = game, gen3Berries = { flavors = { [1] = {
    spicy = 10, dry = 0, sweet = 0, bitter = 0, sour = 0, smoothness = 20,
  } } } }
  Berries.validate(project)
  assert(Contest.enabled(project), game .. " contest evolutions")
end

for _, game in ipairs({ "red", "gold", "crystal", "firered", "leafgreen" }) do
  assert(not Generation.isRse({ version = game }), game .. " is not RSE")
  local ok = pcall(Berries.validate, { game = game, gen3Berries = { flavors = { [1] = {
    spicy = 1, dry = 0, sweet = 0, bitter = 0, sour = 0, smoothness = 0,
  } } } })
  assert(not ok, game .. " must not accept berry edits")
  assert(not Contest.enabled({ game = game }), game .. " contest evolutions")
end

local rows = Contest.compile({
  game = "ruby",
  gen3 = { pokemon = { FEEBAS = { evolutions = {
    { method = "EVO_CUTE", species = "MILOTIC", param = 170 },
  } } } },
})
assert(#rows == 1 and rows[1].condition == "cute" and rows[1].from == "FEEBAS", "ruby contest evolution compiles")

for _, game in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  assert(Generation.isGen3Id(game), game)
  local project = { game = game, gen3Split = true, gen3 = { moves = { POUND = { category = "physical" } } } }
  local out = {}
  local old = love.filesystem.read
  love.filesystem.read = function(path)
    local f = io.open(path, "rb")
    if not f then return old(path) end
    local body = f:read("*a")
    f:close()
    return body
  end
  Split.emit(project, function() return "{}" end, out)
  love.filesystem.read = old
  assert(#out == 1 and out[1]:find("split.install", 1, true), game .. " split emit")
end

local refused = pcall(Split.emit, { game = "gold", gen3Split = true, gen3 = { moves = {} } }, function() return "{}" end, {})
assert(not refused, "Gen 1/2 must not emit the split")

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return end
  local body = f:read("*a")
  f:close()
  return body
end
for _, game in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  local old = love.filesystem.read
  love.filesystem.read = readFile
  Clock.emit({ game = game, gen3SystemClock = true }, out)
  love.filesystem.read = old
  assert(#out == 1 and out[1]:find("systemClock.install", 1, true), game .. " system clock")
end
local noClock = pcall(Clock.emit, { game = "firered", gen3SystemClock = true }, {})
assert(not noClock, "FireRed has no bedroom system clock")
local Constants = require("src.core.game3.constants")
assert(Constants.of("ruby"):special("StartWallClock") == 154)
assert(Constants.of("sapphire"):special("StartWallClock") == 154)
assert(Constants.of("emerald"):special("StartWallClock") == 157)
assert(Constants.of("firered"):special("StartWallClock") == nil)

local Patches = require("GamePatches")
local split
for _, patch in ipairs(Patches.PATCHES) do
  if patch.id == "split" then split = patch end
end
assert(split and not split.emerald, "Physical/Special split is available on every Gen 3 game")
local clock
for _, patch in ipairs(Patches.PATCHES) do
  if patch.id == "systemClock" then clock = patch end
end
assert(clock and clock.rse and not clock.emerald, "System clock is available on Ruby, Sapphire, and Emerald")

local Mini = require("Gen3MinigameImages")
assert(Mini.list({ version = "ruby" }, "slots")[1].file == "reel_symbols.png")
assert(Mini.list({ version = "sapphire" }, "crush")[1].key == "bg")
assert(Mini.list({ version = "emerald" }, "dodrio")[1].key == "bg")
assert(Mini.cachePath({ version = "ruby" }, "slots", 1) == "data/generated/gba/rse_slot_machine/reel_symbols.png")
assert(Mini.list({ version = "firered" }, "slots")[1].key == "bg")
assert(Mini.list({ version = "leafgreen" }, "jump")[1].key == "bg")

print("PASS rse shared edits: berries, contest evolutions, physical/special split, system clock, mini-games")
