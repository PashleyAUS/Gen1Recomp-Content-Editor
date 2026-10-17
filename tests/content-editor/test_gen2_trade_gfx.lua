-- Gold, Silver, and Crystal trade-animation sheets save into data.gen2Trade.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local data = { trade = {
  image = "assets/generated/trade/scene.png",
  tiles = 49,
  ball = { image = "assets/generated/trade/ball.png", tiles = 4 },
} }
require("Generation").bindGoldData(data)
assert(data.gen2Trade == data.trade, "trade.lua is the Gen 2 trade animation")

local State = require("State")
local Writer = require("ModWriter")
for _, game in ipairs({ "gold", "silver", "crystal" }) do
  local project = State.blankProject("trade_gfx")
  project.game = game
  project.tradeGfx = {
    image = "mods/trade_gfx/scene.png",
    ball = { image = "mods/trade_gfx/ball.png" },
  }
  local main = Writer.emitMain(project, {})
  assert(type(main) == "string" and main:find("data.gen2Trade", 1, true), game)
  local literal = assert(main:match("local _trade = (%b{})"), game .. " trade table")
  local gfx = assert(loadstring("return " .. literal))()
  assert(gfx.image:find("scene.png", 1, true), game)
  assert(gfx.ball.image:find("ball.png", 1, true), game)
  assert(main:find("data.gen2Trade = gfx", 1, true), game .. " installs the sheets")
end

local project = State.blankProject("trade_gfx")
project.game = "silver"
project.tradeGfx = {
  image = "mods/trade_gfx/scene.png",
  ball = { image = "mods/trade_gfx/ball.png" },
}
local main = Writer.emitMain(project, {})
local literal = assert(main:match("local _trade = (%b{})"))
local gfx = assert(loadstring("return " .. literal))()
local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" and type(dst[k]) == "table" then merge(dst[k], v) else dst[k] = v end
  end
end
local live = {
  image = "assets/generated/trade/scene.png",
  tiles = 49,
  ball = { image = "assets/generated/trade/ball.png", tiles = 4 },
}
merge(live, gfx)
assert(live.image:find("scene.png", 1, true) and not live.image:find("assets/generated", 1, true))
assert(live.tiles == 49, "the scene tile count stays with the vanilla table")
assert(live.ball.tiles == 4 and live.ball.image:find("ball.png", 1, true))

local red = State.blankProject("trade_gfx")
red.game = "red"
red.tradeGfx = { image = "mods/trade_gfx/scene.png" }
local redMain = Writer.emitMain(red, {})
assert(not redMain:find("data.gen2Trade", 1, true), "Red does not use the Gen 2 trade sheets")

print("PASS gen2 trade animation sheets")
