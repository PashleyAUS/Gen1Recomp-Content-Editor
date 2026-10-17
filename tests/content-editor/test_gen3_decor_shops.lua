-- Ruby, Sapphire, and Emerald decoration shops are editable shelves.
-- FireRed and LeafGreen do not open those shops.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;" .. package.path
love = require("tests.love_stub")

local pack = { marts = {
  ["g3:item"] = { key = "g3:item", ptr = 1, items = { 1 } },
  ["g3:decor"] = { key = "g3:decor", ptr = 2, items = { 1 }, kind = "decorations", martType = "DECOR" },
} }
local scripts = { clerk = {
  { op = "pokemart", items = "g3:item" },
  { op = "pokemartdecoration", items = "g3:decor" },
} }

package.loaded["Gen3ContentAdapter"] = { prepare = function() end }
package.loaded["src.core.game3.battle.types"] = {
  ID = {}, isPhysical = function() return false end, effectiveness = function() return 1 end,
}
package.loaded["Gen3Resources"] = { readTable = function() return pack end }
package.loaded["Gen3"] = { catalog = function() return scripts end }
package.loaded["Gen3Labels"] = {
  scriptMaps = function() return { clerk = { SLATEPORT = true } } end,
  map = function(id) return id end,
}
package.loaded["RegList"] = {
  sortedKeys = function(t)
    local keys = {}
    for id in pairs(t or {}) do keys[#keys + 1] = id end
    table.sort(keys)
    return keys
  end,
}

local Work = require("Gen3Workbench")
local function session(game)
  return {
    version = game,
    data = { items = { POKE_BALL = { index = 1 } }, _g3TypeChart = { types = {}, matchups = {} }, type_chart = {} },
    project = { game = game, marts = {} },
  }
end

local rubyKeys, rubyShops = Work.shops(session("ruby"))
local function has(keys, id)
  for _, key in ipairs(keys) do if key == id then return true end end
  return false
end
assert(has(rubyKeys, "g3:item") and has(rubyKeys, "g3:decor"), "Ruby lists item and decoration shops")
assert(rubyShops["g3:item"].mart[1] == "POKE_BALL")
assert(rubyShops["g3:decor"].kind == "decorations")
assert(rubyShops["g3:decor"].mart[1] == "DECOR_SMALL_DESK", "decoration 1 is not an item")
assert(rubyShops["g3:decor"].label:find("SLATEPORT", 1, true))

for _, game in ipairs({ "sapphire", "emerald" }) do
  local keys = Work.shops(session(game))
  assert(has(keys, "g3:decor"), game .. " lists the decoration shop")
end
local frKeys = Work.shops(session("firered"))
assert(has(frKeys, "g3:item") and not has(frKeys, "g3:decor"), "FireRed hides decoration shops")

local Decor = require("Gen3DecorMart")
local function decorId(id) return ({ DECOR_SMALL_DESK = 1, DECOR_PRETTY_DESK = 6 })[id] end
local sold, rec = Decor.apply({ "DECOR_SMALL_DESK" }, { martType = "DECOR", key = "g3:decor" },
  function() return nil end, decorId)
assert(sold[1] == 1 and rec.martType == "DECOR")
local wrapped, made = Decor.apply({
  items = { "DECOR_PRETTY_DESK" }, martType = "DECOR2", kind = "decorations",
}, nil, function() return nil end, decorId)
assert(wrapped[1] == 6 and made.martType == "DECOR2")
local items = Decor.apply({ "POTION" }, { key = "g3:item" },
  function(id) return id == "POTION" and 13 or nil end, decorId)
assert(items[1] == 13, "item shops still sell items")

local help = require("Gen3ActionLanguage").help
assert(help({ op = "pokemartdecoration" }, { version = "ruby" }):find("decorations it sells", 1, true))
assert(help({ op = "pokemartdecoration" }, { version = "leafgreen" }):find("will not open", 1, true))

print("PASS decoration shops")
