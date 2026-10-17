-- An Amulet Coin doubles a quarter of 100 into 200, and four quarters
-- print 800. A ceiling of 50 stops both the doubled quarter and the
-- printed total. Gold, Silver, and Crystal share it. Red does not.

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

local Prize = require("src.battle.gen2.Prize")
local function pay(cap)
  if cap ~= nil then Prize.REWARD_CAP = cap end
  return Prize.award({ player = { money = 0 } }, { baseMoney = 10, level = 10, amuletCoin = true })
end
local open = pay()
assertEq(open.quarter, 200, "the coin doubles 100")
assertEq(open.total, 800, "four quarters print 800")
assertEq(open.wallet, 800, "the wallet receives 800")
local capped = pay(50)
assertEq(capped.quarter, 50, "the doubled quarter stops at 50")
assertEq(capped.total, 50, "the printed total stops at 50")
assertEq(capped.wallet, 200, "four capped quarters are 200")
Prize.REWARD_CAP = 0xffffff

local Writer = require("ModWriter")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, prizeRules = { rewardCap = 50 } })
  assert(main:find("rewardCap = 50", 1, true), version)
  assert(main:find("Prize.REWARD_CAP = prizeRules.rewardCap", 1, true), version)
end
local red = Writer.emitMain({ version = "red", generation = 1, prizeRules = { rewardCap = 50 } })
assert(not red:find("REWARD_CAP", 1, true), "red")

print("PASS reward cap")
