-- Rare Candy, the summary, and the Day Care stop at the level cap. The cart uses 100.

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

local ItemEffects = require("src.inventory.ItemEffects")
local status = ItemEffects.use({
  constants = { levelCap = 40 },
  items = { RARE_CANDY = { name = "RARE CANDY" } },
}, { player = { name = "Red" } }, "RARE_CANDY", { level = 40, hp = 5 })
assertEq(status, "failed", "gen1 candy")

local Mon = require("src.battle.gen2.Mon")
Mon.MAX_LEVEL = 3
assertEq(Mon.levelForExperience({ numerator = 1, denominator = 1 }, 100000), 3, "gen2 level")
Mon.MAX_LEVEL = 100

local Experience = require("src.core.game3.battle.experience")
local RomText = require("src.core.game3.rom_text")
RomText.box = function() return "no effect" end
local ItemUse = require("src.core.game3.item_use")
local SummaryData = require("src.core.game3.summary_data")
local Daycare = require("src.core.game3.daycare")
Experience.MAX_LEVEL = 40
local ok = ItemUse.useRareCandy(nil, { level = 40, hp = 5 })
assertEq(ok, false, "gen3 candy")
local progress = SummaryData.expProgress({ level = 40, exp = 0 }, 0)
assertEq(progress.expNeeded, 0, "gen3 summary")
assertEq(Daycare.applyExperience({ level = 40, species = 1 }, 100), 0, "gen3 daycare")
Experience.MAX_LEVEL = 100

local Writer = require("ModWriter")
local red = Writer.emitMain({ version = "red", generation = 1, constants = { levelCap = 40 } })
assert(red:find("levelCap", 1, true), "red cap")
assert(not red:find("MAX_LEVEL", 1, true), "red skips gen2")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({
    version = version, generation = 2, constants = { levelCap = 40 },
  })
  assert(main:find("MAX_LEVEL = 40", 1, true), version)
end

local Gen3BattleRules = require("Gen3BattleRules")
local Gen3Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen", "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, gen3BattleRules = { maxLevel = 40 } }
  assert(Gen3Native.used(p), version .. " native")
  local out = {}
  Gen3BattleRules.emit(p, function() return "{ maxLevel = 40 }" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("Experience.MAX_LEVEL = battleRules.maxLevel", 1, true), version)
end

print("PASS level cap")
