-- Berry Crush silk starts at 50. Powder keeps that score out of 100.
-- Goal depth is difficulty divided by 32. A divisor of 0 yields none.
-- The earlier games do not have Berry Crush.

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

local R = require("src.core.game3.minigames.berry_crush.rules")
local T = { berry_data = { { difficulty = 64, powder = 10 } } }
local st = R.newState(1)
R.setBerries(st, T, { 0 })
assertEq(st.targetDepth, 512, "depth")
assertEq(st.powder, 10, "base powder")
R.DEPTH_DIV = 0
R.setBerries(st, T, { 0 })
assertEq(st.targetDepth, 0, "depth zero")
R.DEPTH_DIV = 32

st.nb, st.nc = 0, 0
local res = R.tabulate(st, 0)
assertEq(res.silk, 50, "silk base")
R.POWDER_DEN = 0
res = R.tabulate(st, 0)
assertEq(res.powder, 0, "powder zero")
R.POWDER_DEN = 100

local Rules = require("BerryCrushRules")
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, berryCrush = { powderDen = 0, depthDiv = 0 } }
  assert(Native.used(p), version)
  local out = {}
  Rules.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("POWDER_DEN = 0", 1, true), version)
  assert(chunk:find("DEPTH_DIV = 0", 1, true), version)
end
local Writer = require("ModWriter")
local main = Writer.emitMain({ version = "red", generation = 1, berryCrush = { powderDen = 0 } })
assert(not main:find("POWDER_DEN", 1, true), "red")

print("PASS berry crush")
