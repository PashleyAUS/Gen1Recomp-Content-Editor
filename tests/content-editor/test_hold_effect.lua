-- Held-item effects come from the item record. The cart table is the fallback.

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

local HeldItems = require("src.core.game3.battle.held_items")
local effect, param = HeldItems.effectOf(44)
assertEq(effect, 1, "berry juice effect")
assertEq(param, 20, "berry juice amount")
effect, param = HeldItems.effectOf(183)
assertEq(effect, 26, "quick claw effect")
assertEq(param, 20, "quick claw chance")

local ItemsData = require("src.core.game3.items_data")
ItemsData.info = function(id)
  id = tonumber(id)
  if id == 44 then return { holdEffect = 1, holdEffectParam = 5 } end
  if id == 183 then return { holdEffect = 0, holdEffectParam = 0 } end
  return nil
end
effect, param = HeldItems.effectOf(44)
assertEq(effect, 1, "edited juice effect")
assertEq(param, 5, "edited juice amount")
effect, param = HeldItems.effectOf(183)
assertEq(effect, 0, "cleared quick claw")
assertEq(param, 0, "cleared quick claw amount")
effect, param = HeldItems.effectOf(139)
assertEq(effect, 1, "oran fallback")
assertEq(param, 10, "oran amount")

print("PASS hold effect")
