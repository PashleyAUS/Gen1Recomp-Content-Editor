-- Morning starts at 4, day at 10, and night at 18. Hour 3 is night and
-- hour 4 is morning. Morning starting at 0 makes hour 3 morning. Oak
-- still includes the hour day starts. Gold, Silver, and Crystal emit
-- the hours. Red does not.

package.path = table.concat({
  "tools/content-editor/?.lua",
  "tools/content-editor/panels/?.lua",
  "tools/save-editor/?.lua",
  "runtime/gen1recomp/?.lua",
  "runtime/gen1recomp/?/init.lua",
  package.path,
}, ";")

dofile("tests/love_stub.lua")

local function assertEq(actual, expected, label)
  if actual ~= expected then
    error(label .. ": got " .. tostring(actual) .. " expected " .. tostring(expected))
  end
end

local Palettes = require("src.world.gen2.Palettes")
assertEq(Palettes.clockDaytime(3), "NITE", "3 is night")
assertEq(Palettes.clockDaytime(4), "MORN", "4 is morning")
assertEq(Palettes.clockDaytime(10), "DAY", "10 is day")
assertEq(Palettes.clockDaytime(18), "NITE", "18 is night")
Palettes.MORN_HOUR = 0
assertEq(Palettes.clockDaytime(3), "MORN", "morning from midnight")
Palettes.MORN_HOUR = 4
Palettes.DAY_HOUR = 6
assertEq(Palettes.clockDaytime(5), "MORN", "5 stays morning")
assertEq(Palettes.clockDaytime(6), "DAY", "day starts at 6")
Palettes.DAY_HOUR = 10
Palettes.NITE_HOUR = 12
assertEq(Palettes.clockDaytime(11), "DAY", "11 stays day")
assertEq(Palettes.clockDaytime(12), "NITE", "night starts at 12")
Palettes.NITE_HOUR = 18

local Phone = require("src.core.gen2.Phone")
assertEq(Phone.timeOfDay({ clock = { hour = 3 } }), Phone.NITE, "phone night")
assertEq(Phone.timeOfDay({ clock = { hour = 4 } }), Phone.MORN, "phone morning")

local InitClock = require("src.ui.gen2.InitClock")
assertEq(InitClock.responseKey(10), "overslept", "10 is still overslept")
assertEq(InitClock.responseKey(11), "yikes", "11 is yikes")
Palettes.DAY_HOUR = 6
assertEq(InitClock.responseKey(6), "overslept", "Oak includes the new day hour")
assertEq(InitClock.responseKey(7), "yikes", "the next hour is yikes")
Palettes.DAY_HOUR = 10

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2,
    gen2Clock = { morn = 0, day = 6, nite = 12 },
  })
  assert(main:find("MORN_HOUR = 0", 1, true), version)
  assert(main:find("DAY_HOUR = 6", 1, true), version)
  assert(main:find("NITE_HOUR = 12", 1, true), version)
end
local red = Writer.emitMain({
  version = "red", generation = 1,
  gen2Clock = { morn = 0 },
})
assert(not red:find("MORN_HOUR", 1, true), "red")

print("PASS gen2 clock")
