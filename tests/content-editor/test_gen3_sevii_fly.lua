-- FireRed and LeafGreen Fly setup includes Sevii destinations and the
-- Town Map page each one is drawn on.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;" .. package.path
love = require("tests.love_stub")

local files = {
  ["data/generated/gba/region_map/map_sections.lua"] = [[return { sections = {
    [1] = { id = "MAPSEC_PALLET_TOWN", name = "PALLET TOWN" },
    [2] = { id = "MAPSEC_VIRIDIAN_CITY", name = "VIRIDIAN CITY" },
    [143] = { id = "MAPSEC_ONE_ISLAND", name = "ONE ISLAND" },
    [150] = { id = "MAPSEC_FOUR_ISLAND", name = "FOUR ISLAND" },
    [160] = { id = "MAPSEC_SIX_ISLAND", name = "SIX ISLAND" },
  } }]],
  ["data/generated/gba/region_map/section_geometry.lua"] = [[return { topLeft = {
    [1] = { 4, 11 }, [2] = { 4, 8 }, [143] = { 12, 10 }, [150] = { 6, 6 }, [160] = { 8, 4 },
  } }]],
  ["data/generated/gba/region_map/layouts.lua"] = [[return { seviiMapsecs = {
    [0] = { 143 }, [1] = { 150 }, [2] = { 160 },
  } }]],
  ["data/generated/gba/region_map/fly_destinations.lua"] = [[return { fly_destinations = {
    one = { mapsec = 143, map = "FR_ONE_ISLAND", x = 14, y = 12, healLocation = 20 },
    viridian = { mapsec = 2, map = "FR_VIRIDIAN_CITY", x = 20, y = 26, healLocation = 2 },
    six = { mapsec = 160, map = "FR_SIX_ISLAND", x = 12, y = 14, healLocation = 1 },
    pallet = { mapsec = 1, map = "FR_PALLET_TOWN", x = 6, y = 8, healLocation = 1 },
    four = { mapsec = 150, map = "FR_FOUR_ISLAND", x = 16, y = 10, healLocation = 24 },
  } }]],
}

local S = { data = { _gen3Read = function(path) return files[path] end } }
local Fly = require("Gen3Fly")
local rows = Fly.defaults(S)
assert(#rows == 5, "every Fly destination, including Sevii")
local function at(i, name, region, mapX, mapY)
  local row = rows[i]
  assert(row.name == name and row.region == region and row.mapX == mapX and row.mapY == mapY,
    name .. " page " .. tostring(region))
end
at(1, "PALLET TOWN", 0, 4, 11)
at(2, "VIRIDIAN CITY", 0, 4, 8)
at(3, "ONE ISLAND", 1, 12, 10)
at(4, "FOUR ISLAND", 2, 6, 6)
at(5, "SIX ISLAND", 3, 8, 4)
Fly.validate(rows)
rows[3].region = 4
local ok = pcall(Fly.validate, rows)
assert(not ok, "a Town Map page must be Kanto or one of the three Sevii pages")
rows[3].region = nil
Fly.validate(rows)

print("PASS sevii fly destinations")
