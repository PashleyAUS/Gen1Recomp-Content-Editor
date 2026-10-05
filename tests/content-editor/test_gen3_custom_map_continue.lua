-- Run from the repository root with tools/tooling/luajit/luajit.exe.
package.path = "tools/content-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
local GameVersion = require("src.core.GameVersion")
GameVersion.set("emerald")
local MapIds = require("src.core.game3.map_ids")
assert(not MapIds.isGame3Map("PR_FALL_CITY", "emerald"))

-- Load the real Continue gate with its unrelated UI/audio dependencies stubbed.
local source = assert(io.open("runtime/gen1recomp/src/core/Game3.lua", "rb")):read("*a")
for name in source:match("^(.-)local s9Warned"):gmatch('require%("([^"]+)"%)') do
  if name ~= "src.core.game3.map_ids" and name ~= "src.core.game3.profile" then
    package.loaded[name] = {}
  end
end
local save = {engine="game3", version="emerald", map="PR_FALL_CITY", x=15, y=24}
package.loaded["src.core.SaveData"].load = function() return save end
local Game3 = require("src.core.Game3")
local game = Game3.new()
assert(not game:_hasContinueSave(), "reproduce missing Continue before fix")

local maps = {PR_FALL_CITY={id="PR_FALL_CITY"}}
local mod = {content={maps={get=function(_, id) return maps[id] end}}}
local out = {}
require("Gen3CustomMapRuntime").emit({game="emerald", gen3={maps=maps}},
  require("ModWriter").encodeLua, out)
assert(loadstring("return function(mod)\n" .. table.concat(out, "\n") .. "\nend"))()(mod)
assert(game:_hasContinueSave(), "Fall City save must expose Continue")
assert(save.map == "PR_FALL_CITY" and save.x == 15 and save.y == 24)
assert(MapIds.isGame3Map("PR_FALL_CITY"), "field loading must accept Fall City too")
assert(not MapIds.isGame3Map("PR_UNKNOWN", "emerald"))
assert(not MapIds.isGame3Map("PR_FALL_CITY", "firered"))
assert(MapIds.isGame3Map("EM_ROUTE104", "emerald"), "stock maps still work")
maps.PR_FALL_CITY = nil
assert(not game:_hasContinueSave(), "removed content must not remain recognized")
assert(loadfile("mods/Nihon-Expansion/main.lua"), "patched mod compiles")
print("PASS: custom map Continue and field identity")
