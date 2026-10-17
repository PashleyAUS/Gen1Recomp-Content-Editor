-- The Pyramid light grows until 120, then stays there. A cap of 0
-- never grows. A cap of 2 lets a radius of 1 become 2 and stops the
-- next step. Ruby, Sapphire, and Emerald share it. FireRed does not.

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

local Util = require("src.core.game3.rse.frontier.util")
local Pyramid = require("src.core.game3.rse.frontier.pyramid")
local function grow(radius, cap)
  if cap ~= nil then Pyramid.MAX_LIGHT_RADIUS = cap end
  local vars = {
    [Util.VAR_0x8006] = Pyramid.LIGHT.INCR_RADIUS,
    [Util.VAR_RESULT] = 1,
    [Util.VAR_0x8005] = 1,
  }
  local ctx = {
    getVar = function(_, id) return vars[id] or 0 end,
    setVar = function(_, id, value) vars[id] = value end,
  }
  local sess = { frontier = { _shaped = true, lvlMode = 0, pyramidLightRadius = radius } }
  Pyramid.updateLight(ctx, sess)
  return sess.frontier.pyramidLightRadius
end
assertEq(grow(119), 120, "119 grows to 120")
assertEq(grow(120), 120, "120 stays at 120")
assertEq(grow(0, 0), 0, "a cap of 0 never grows")
assertEq(grow(1, 2), 2, "a cap of 2 accepts the next step")
assertEq(grow(2, 2), 2, "a cap of 2 stops at 2")
Pyramid.MAX_LIGHT_RADIUS = 120

local Rules = require("PyramidRules")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Rules.emit({ version = version, pyramidRules = { light = 0 } }, function() return "{}" end, out)
  assert(table.concat(out, "\n"):find("MAX_LIGHT_RADIUS = 0", 1, true), version)
end
local out = {}
Rules.emit({ version = "firered", pyramidRules = { light = 0 } }, function() return "{}" end, out)
assert(not table.concat(out, "\n"):find("MAX_LIGHT_RADIUS", 1, true), "firered")

print("PASS pyramid light")
