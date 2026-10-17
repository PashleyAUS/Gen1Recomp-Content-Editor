-- A blackout takes half the wallet until that cut is edited.
-- FireRed and LeafGreen charge by level and badges instead of halving.

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

local Overworld = require("src.world.OverworldController")
assertEq(Overworld.blackoutDivisor(nil), 2, "gen1 half")
Overworld.BLACKOUT_DIV = 1
assertEq(Overworld.blackoutDivisor(nil), 1, "gen1 keeps the wallet")
Overworld.BLACKOUT_DIV = 4
assertEq(math.floor(100 / Overworld.blackoutDivisor(nil)), 25, "gen1 quarter")
Overworld.BLACKOUT_DIV = nil

local CallAsm = require("src.script.gen2.CallAsm")
local ctx = { game = { save = { player = { money = 100 } } } }
CallAsm.run(ctx, "HalveMoney")
assertEq(ctx.game.save.player.money, 50, "gen2 half")
CallAsm.MONEY_DIV = 1
CallAsm.run(ctx, "HalveMoney")
assertEq(ctx.game.save.player.money, 50, "gen2 divisor 1 keeps it")
CallAsm.MONEY_DIV = 4
ctx.game.save.player.money = 100
CallAsm.run(ctx, "HalveMoney")
assertEq(ctx.game.save.player.money, 25, "gen2 quarter")
CallAsm.MONEY_DIV = 2

local Bridge = require("src.core.game3.battle_bridge")
local Profile = require("src.core.game3.battle.profile")
local prevGet = Profile.get
Profile.get = function() return { rules = { whiteout = "half" } } end
local session = { money = 100 }
local host = { money = 100 }
Bridge.WHITEOUT_DIV = 4
local lost, kept = Bridge.applyWhiteoutMoneyLoss(session, host)
assertEq(lost, 75, "hoenn loss")
assertEq(kept, 25, "hoenn kept")
assertEq(session.money, 25, "hoenn session")
assertEq(host.money, 25, "hoenn save")
Bridge.WHITEOUT_DIV = 1
session.money = 100
host.money = 100
Bridge.applyWhiteoutMoneyLoss(session, host)
assertEq(session.money, 100, "hoenn divisor 1 keeps it")
Bridge.WHITEOUT_DIV = 2
Profile.get = prevGet

local loss = Bridge.calcMoneyLossFrlg({ party = { { level = 10 } } }, {})
assertEq(loss, 80, "frlg 10 * 4 * 2")
Bridge.LOSS_LEVEL_FACTOR = 0
assertEq(Bridge.calcMoneyLossFrlg({ party = { { level = 10 } } }, {}), 0, "frlg factor zero")
Bridge.LOSS_LEVEL_FACTOR = 4
Bridge.BADGE_LOSS_MULT[1] = 0
assertEq(Bridge.calcMoneyLossFrlg({ party = { { level = 10 } } }, {}), 0, "frlg no badges can cost nothing")
Bridge.BADGE_LOSS_MULT[1] = 2

local Writer = require("ModWriter")
local Whiteout = require("Whiteout")
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({ version = version, generation = 1, whiteout = { div = 4 } })
  assert(main:find("BLACKOUT_DIV = 4", 1, true), version)
  assert(not main:find("MONEY_DIV", 1, true), version)
end
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, whiteout = { div = 1 } })
  assert(main:find("MONEY_DIV = 1", 1, true), version)
  assert(not main:find("BLACKOUT_DIV", 1, true), version)
end

local Native = require("Gen3Native")
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local p = { version = version, generation = 3, whiteout = { div = 1 } }
  assert(Native.used(p), version)
  local out = {}
  Whiteout.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("WHITEOUT_DIV = 1", 1, true), version)
  assert(not chunk:find("LOSS_LEVEL_FACTOR", 1, true), version)
end
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, whiteout = { levelFactor = 0, badgeMult = { 0, 4, 6, 9, 12, 16, 20, 25, 30 } } }
  assert(Native.used(p), version)
  local out = {}
  Whiteout.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("LOSS_LEVEL_FACTOR = 0", 1, true), version)
  assert(chunk:find("BADGE_LOSS_MULT = { 0, 4, 6, 9, 12, 16, 20, 25, 30 }", 1, true), version)
  assert(not chunk:find("WHITEOUT_DIV", 1, true), version)
end

print("PASS whiteout")
