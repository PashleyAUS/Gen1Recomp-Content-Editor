-- Game Corner prizes keep their cart prices until a cell is set.
-- 0 coins is free. Crystal's Blue Card prizes are separate.

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

local Prize = require("src.ui.gen2.PrizeMenu")
local tm = Prize.COUNTERS.CELADON_TM.prizes[1]
local mon = Prize.COUNTERS.CELADON_MON.prizes[3]
assertEq(tm.cost, 1500, "tm32")
assertEq(mon.level, 20, "porygon level")
Prize.PRIZE_COSTS.CELADON_TM = { [1] = 0 }
Prize.PRIZE_LEVELS.CELADON_MON = { [3] = 1 }
Prize.applyPrizeOverrides()
assertEq(tm.cost, 0, "free tm")
assertEq(Prize.COUNTERS.CELADON_TM.prizes[2].cost, 3500, "untouched tm")
assertEq(mon.level, 1, "level 1")
local save = { player = { coins = 0 }, inventory = {} }
assertEq(Prize.check(save, Prize.COUNTERS.CELADON_TM, tm, {
  items = { TM_DOUBLE_TEAM = { pocket = "TM_HM" } },
}), "ok", "free check")
Prize.PRIZE_COSTS.CELADON_TM = nil
Prize.PRIZE_LEVELS.CELADON_MON = nil
Prize.applyPrizeOverrides()
assertEq(tm.cost, 1500, "restored")
assertEq(mon.level, 20, "level restored")

require("src.script.gen2.Specials")
local Extras = require("src.core.gen2.BuenaPrizes")
assertEq(Extras.cost(1, 2), 2, "ultra ball")
assertEq(Extras.pointCap(), 30, "cap")
Extras.COSTS[1] = 0
Extras.POINT_CAP = 0
assertEq(Extras.cost(1, 2), 0, "free prize")
assertEq(Extras.cost(2, 2), 2, "full restore")
assertEq(Extras.pointCap(), 0, "no points")

local Writer = require("ModWriter")
local crystal = Writer.emitMain({
  version = "crystal", generation = 2,
  prizeShop = { CELADON_TM = { costs = { [1] = 0 } }, CELADON_MON = { levels = { [3] = 1 } } },
  buenaPrizes = { cap = 0, costs = { [1] = 0 } },
})
assert(crystal:find("PRIZE_COSTS.CELADON_TM[1] = 0", 1, true), "crystal cost")
assert(crystal:find("PRIZE_LEVELS.CELADON_MON[3] = 1", 1, true), "crystal level")
assert(crystal:find("POINT_CAP = 0", 1, true), "crystal cap")
assert(crystal:find("COSTS[1] = 0", 1, true), "crystal buena")
assert(crystal:find("src.core.gen2.BuenaPrizes", 1, true), "crystal module")
local gold = Writer.emitMain({
  version = "gold", generation = 2,
  prizeShop = { GOLDENROD_MON = { costs = { [1] = 0 } } },
  buenaPrizes = { cap = 0 },
})
assert(gold:find("PRIZE_COSTS.GOLDENROD_MON[1] = 0", 1, true), "gold cost")
assert(not gold:find("BuenaPrizes", 1, true), "gold skips buena")
local red = Writer.emitMain({
  version = "red", generation = 1,
  prizeShop = { CELADON_TM = { costs = { [1] = 0 } } },
  buenaPrizes = { cap = 0 },
})
assert(not red:find("PRIZE_COSTS", 1, true), "red")
assert(not red:find("BuenaPrizes", 1, true), "red buena")

print("PASS prize shop")
