-- FireRed link (Gen3FrLink / Gen3FrLinkRuntime): FireRed tilesets and map
-- layouts in Emerald mods, read from the player's FireRed / LeafGreen import.
-- Plain LuaJIT, no LOVE. Run from the repository root:
--   luajit tests/content-editor/test_gen3_frlink.lua
package.path = "tools/content-editor/?.lua;" .. package.path
package.loaded["src.core.GameVersion"] = {
  cachePrefix = function(game) return game .. "/" end,
  revisions = function(game)
    return ({ firered = { { sha1 = "41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc" }, { sha1 = "dd5945db9b930750cb39d00c84da8571feebf417" } },
      leafgreen = { { sha1 = "574fa542ffebb14be69902d1d36f1ec0a4afd71e" } } })[game] or {}
  end,
}
local R = require("Gen3FrLinkRuntime")
local L = require("Gen3FrLink")

local pass, fail = 0, 0
local function run(name, fn)
  local ok, err = pcall(fn)
  if ok then pass = pass + 1; print("ok    " .. name)
  else fail = fail + 1; print("FAIL  " .. name .. "\n      " .. tostring(err)) end
end

run("FireRed tileset folders are sent to the import", function()
  assert(R.redirect("data/generated/gba/native/frlg__pallet_outdoor/mids.idx") == "data/generated/gba/native/pallet_outdoor/mids.idx")
  assert(R.redirect("data/generated/gba/native/frlg__building__rom_082d4bcc/palettes.bin")
    == "data/generated/gba/native/building__rom_082d4bcc/palettes.bin")
  assert(R.redirect("data/generated/gba/native/general__petalburg/mids.idx") == nil)
  assert(R.redirect(nil) == nil)
end)

run("only a finished FireRed or LeafGreen import of a known dump counts", function()
  local files = {}
  local function readAt(p) return files[p] end
  assert(R.find(readAt) == nil)
  files["firered/rom-cache.complete"] = "rom-cache-v21-firered:0000"
  assert(R.find(readAt) == nil)
  files["leafgreen/rom-cache.complete"] = "rom-cache-v21-leafgreen:574FA542FFEBB14BE69902D1D36F1EC0A4AFD71E"
  local prefix, game = R.find(readAt)
  assert(prefix == "leafgreen/" and game == "leafgreen")
  files["firered/rom-cache.complete"] = "rom-cache-v21-firered:dd5945db9b930750cb39d00c84da8571feebf417"
  prefix, game = R.find(readAt)
  assert(prefix == "firered/" and game == "firered")
  files = { ["firered/rom-cache.complete"] = "rom-cache-v3-emerald:41cb23d8dccc8ebd7c649cd8fbb58eeace6e2fdc" }
  assert(R.find(readAt) == nil)
end)

run("names and labels", function()
  assert(L.isPair("frlg__pallet_outdoor") and not L.isPair("general__petalburg") and not L.isPair(nil))
  assert(L.isMap("frlg:FR_PALLET_TOWN") and not L.isMap("EM_LITTLEROOT_TOWN"))
  assert(L.label("frlg__pallet_outdoor") == "FireRed: pallet_outdoor")
  assert(L.label("frlg__building__rom_082d4bcc") == "FireRed: building_ / 082d4bcc")
  assert(L.label("general__petalburg") == "general__petalburg")
end)

run("used() finds FireRed layouts, tilesets, borders and painted tiles", function()
  assert(not L.used({}))
  assert(L.used({ gen3MapLayouts = { EM_A = { source = "frlg:FR_ROUTE_1", width = 1, height = 1 } } }))
  assert(L.used({ gen3MapLayouts = { EM_A = { source = "EM_LITTLEROOT_TOWN", pair = "frlg__pallet_outdoor" } } }))
  assert(not L.used({ gen3MapLayouts = { EM_A = { source = "EM_LITTLEROOT_TOWN", width = 1, height = 1 } } }))
  assert(L.used({ gen3Borders = { EM_A = { borderPair = "frlg__pallet_outdoor" } } }))
  assert(L.used({ gen3VoidMaps = { EM_A = { pair = "frlg__pallet_outdoor" } } }))
  assert(L.used({ gen3VoidMaps = { EM_A = { cells = { [1] = { m = 3, p = "frlg__viridian_outdoor" } } } } }))
  assert(L.used({ layeredMaps = { EM_A = { baseTileset = "frlg__pallet_outdoor", layers = {} } } }))
  assert(L.used({ layeredMaps = { EM_A = { baseTileset = "general__petalburg",
    layers = { { cells = { [4] = { source = "@runtime:frlg__pallet_outdoor", tile = 7 } } } } } } }))
  assert(not L.used({ layeredMaps = { EM_A = { baseTileset = "general__petalburg",
    layers = { { cells = { [4] = { source = "@runtime:general__petalburg", tile = 7 } } } } } } }))
end)

run("the GAME PATCHES switch is Emerald's; Import region names", function()
  local p = { game = "emerald" }
  assert(not L.enabled(p) and L.setEnabled(p, true) and L.enabled(p) and not L.setEnabled(p, true))
  assert(L.setEnabled(p, false) and p.gen3FrLink == nil and not L.enabled(p))
  assert(not L.enabled({ game = "firered", gen3FrLink = true }))
  assert(L.regionId("FR_PALLET_TOWN") == "EM_KANTO_PALLET_TOWN")
  assert(L.regionId("SEVII_ONE_ISLAND") == "EM_KANTO_SEVII_ONE_ISLAND")
  assert(L.used({ gen3FrRegion = true }))
  assert(not L.templateMaps({ game = "emerald" })[1])
end)

run("only Emerald mods can carry it", function()
  local p = { game = "firered", gen3MapLayouts = { EM_A = { source = "frlg:FR_ROUTE_1" } } }
  local ok, err = pcall(L.emit, p, tostring, {})
  assert(not ok and tostring(err):find("Emerald", 1, true))
  local out = {}
  L.emit({ game = "emerald" }, tostring, out)
  assert(#out == 0)
end)

print(("%d passed, %d failed"):format(pass, fail))
if fail > 0 then os.exit(1) end
