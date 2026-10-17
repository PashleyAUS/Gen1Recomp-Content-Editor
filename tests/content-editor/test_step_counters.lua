-- A Gen 2 bike ride calls the shop after 1024 steps.
-- A FireRed Vs. Seeker fills in 100 steps and refuses a rematch below 30.
-- 0 steps means the call is ready immediately and the Seeker is already full.

package.path = table.concat({
  "tools/content-editor/?.lua",
  "tools/content-editor/panels/?.lua",
  "tools/save-editor/?.lua",
  "runtime/gen1recomp/?.lua",
  "runtime/gen1recomp/?/init.lua",
  package.path,
}, ";")

love = dofile("tests/love_stub.lua")

local function assertEq(actual, expected, label)
  if actual ~= expected then
    error(label .. ": got " .. tostring(actual) .. " expected " .. tostring(expected))
  end
end

local Steps = require("src.world.gen2.StepEvents")
assertEq(Steps.bikeCallSteps(), 1024, "bike call")
Steps.BIKE_CALL_STEPS = 0
assertEq(Steps.bikeCallSteps(), 0, "bike call zero")
local save = { bikeShopCall = true, bikeStep = 0, engineFlags = {} }
local called = Steps.bikeStep(save, { playerState = "bike" })
assertEq(called, true, "zero waits no steps")
Steps.BIKE_CALL_STEPS = 1024
assertEq(Steps.bikeStepMax(), 65535, "bike cap")
Steps.BIKE_STEP_MAX = 2
local capped = { bikeShopCall = true, bikeStep = 0, engineFlags = {} }
for _ = 1, 5 do Steps.bikeStep(capped, { playerState = "bike" }) end
assertEq(capped.bikeStep, 2, "the counter stops at the cap")
Steps.BIKE_STEP_MAX = 0
local stuck = { bikeShopCall = true, bikeStep = 0, engineFlags = {} }
assertEq(Steps.bikeStep(stuck, { playerState = "bike" }), false, "a cap of 0 never calls")
assertEq(stuck.bikeStep, 0, "a cap of 0 never counts")
Steps.BIKE_STEP_MAX = 0xffff
local Movement = require("src.script.gen2.Movement")
local World = require("src.world.gen2.World")
assertEq(Movement.skyfallBeats(), 16, "pitfall beat")
assertEq(Movement.decodeByte(Movement.SKYFALL).frames, 32, "a full drop is two beats")
assertEq(Movement.decodeByte(Movement.SKYFALL_TOP).frames, 16, "the top drop is one beat")
Movement.SKYFALL_BEAT_FRAMES = 0
assertEq(Movement.decodeByte(Movement.SKYFALL).frames, 0, "a beat of 0 has no drop")
local falling = setmetatable({ playSfxNamed = function() end }, { __index = World })
World.startSkyfall(falling)
assertEq(falling.skyfall.timer, 0, "the drop starts with no wait")
World.PITFALL_SHAKE = 0
World.updateSkyfall(falling)
assertEq(falling.skyfall, nil, "a beat of 0 lands on the first step")
assertEq(falling.shake.left, 0, "a shake of 0 does not linger")
Movement.SKYFALL_BEAT_FRAMES = 16
World.PITFALL_SHAKE = 0x10
World.earthquake(falling, World.pitfallShake())
assertEq(falling.shake.left, 16, "the cart landing shake lasts 16 frames")
assertEq(falling.shake.amplitude, 1, "the cart landing shake is one pixel")
assertEq(Movement.decodeByte(Movement.TELEPORT_FROM).frames, 32, "teleport away is two beats")
assertEq(Movement.decodeByte(Movement.TELEPORT_TO).frames, 48, "teleport in is three beats")
assertEq(Movement.decodeByte(Movement.TREE_SHAKE).frames, 24, "a tree shakes for 24 frames")
local Npc = require("src.world.gen2.Npc")
local actor = setmetatable({}, { __index = Npc })
Npc.scriptTeleport(actor, "from")
assertEq(actor.teleport.frames, 32, "the sprite lifts for two beats")
Movement.TELEPORT_BEAT_FRAMES = 0
assertEq(Movement.decodeByte(Movement.TELEPORT_FROM).frames, 0, "a teleport beat of 0 has no wait")
Npc.scriptTeleport(actor, "to")
assertEq(actor.teleport.frames, 0, "arriving also uses that beat")
Movement.TELEPORT_BEAT_FRAMES = 16
assertEq(Movement.teleportYOffset(32), -96, "a teleport lifts 96 pixels")
Movement.TELEPORT_LIFT = 0
assertEq(Movement.teleportYOffset(32), 0, "a lift of 0 stays on the tile")
Movement.TELEPORT_LIFT = 96
local savedJump = Movement.JUMP_Y
Movement.JUMP_Y = { 0, -8 }
assertEq(Movement.jumpYOffset(1, 2), 0, "a ledge hop reads the first height")
Movement.JUMP_Y = savedJump
local G1 = require("src.world.Player")
local hopper = setmetatable({ px = 0, py = 100, hopFrames = 16, hopTotal = 32 }, G1)
local _, _, hopY = hopper:pose()
assertEq(hopY, 90, "a ledge hop peaks ten pixels up")
G1.HOP_PEAK = 0
_, _, hopY = hopper:pose()
assertEq(hopY, 100, "a lift of 0 stays on the tile")
G1.HOP_PEAK = 10
hopper.hopFrames = 0
hopper.spinning = true
hopper.spinTimer = 6
local _, _, _, face = hopper:pose()
assertEq(face, "left", "the cart spin waits six frames")
G1.SPIN_ITER_FRAMES = 1
_, _, _, face = hopper:pose()
assertEq(face, "up", "a one-frame spin has already turned")
G1.SPIN_ITER_FRAMES = 6
hopper.spinning = false
local surfer = setmetatable({ px = 0, py = 100, surfing = true, bobTimer = 16 }, G1)
local _, _, bobY = surfer:pose()
assertEq(bobY, 101, "the surf bob drops one pixel")
G1.BOB_PIXELS = 0
surfer.bobTimer = 16
_, _, bobY = surfer:pose()
assertEq(bobY, 100, "a bob of 0 stays level")
G1.BOB_PIXELS = 1
local sink = setmetatable({ px = 0, py = 100, holeSink = true }, G1)
local _, _, sinkY = sink:pose()
assertEq(sinkY, 108, "a hole drops the sprite eight pixels")
G1.HOLE_SINK = 0
_, _, sinkY = sink:pose()
assertEq(sinkY, 100, "a hole drop of 0 stays on the tile")
G1.HOLE_SINK = 8
hopper.moving = true
hopper.animClock = 8
local _, _, _, _, phase, flip = hopper:pose()
assertEq(phase, 1, "the middle of a walk lifts a leg")
assertEq(flip, false, "the first cycle does not mirror")
G1.LEG_FROM = 9
_, _, _, _, phase = hopper:pose()
assertEq(phase, 0, "a later leg window is still standing")
G1.LEG_FROM = 4
hopper.animClock = 16
_, _, _, _, _, flip = hopper:pose()
assertEq(flip, true, "the next cycle mirrors")
hopper.moving = false
hopper.spinning = true
hopper.spinHolds = true
hopper.spinStep = 2
hopper.spinRiseFrom = 0
hopper.py = 100
local _, _, riseY = hopper:pose()
assertEq(riseY, 68, "two spin steps lift 32 pixels")
G1.SPIN_RISE = 0
_, _, riseY = hopper:pose()
assertEq(riseY, 100, "a spin lift of 0 stays on the tile")
G1.SPIN_RISE = 16
hopper.spinHolds = nil
hopper.spinDrop = true
hopper.spinFrames = 32
hopper.spinTotal = nil
hopper.py = 100
_, _, riseY = hopper:pose()
assertEq(riseY, 88, "a warp spin is 12 pixels up at the halfway point")
G1.WARP_LIFT = 0
_, _, riseY = hopper:pose()
assertEq(riseY, 100, "a warp lift of 0 stays on the tile")
G1.WARP_LIFT = 24
hopper.spinning = false
hopper.spinDrop = nil
local G2 = require("src.world.gen2.Player")
local walker = setmetatable({ moving = true, animClock = 8, turnTimer = 0, stepFlip = false }, G2)
assertEq(walker:walkPhase(), 1, "the middle of a Gen 2 walk lifts a leg")
G2.LEG_FROM = 9
assertEq(walker:walkPhase(), 0, "a later Gen 2 leg window is still standing")
G2.LEG_FROM = 4
walker.moving = false
walker.bumpFrames = 1
walker.animClock = 16
assertEq(walker:walkPhase(), 1, "a wall bump flips the leg every cycle")
G2.WALK_ANIM_FRAMES = 32
assertEq(walker:walkPhase(), 0, "a longer cycle has not flipped yet")
G2.WALK_ANIM_FRAMES = 16
assertEq(G2.rodOam().down.dy, 16, "the downward rod sits 16 pixels below the player")
assertEq(G2.rodOam().left.flip, true, "the left-facing rod is flipped")
assertEq(G2.fishRow("up"), 1, "facing up uses the second fishing pose")
local savedG2Rod = G2.ROD_OAM
G2.ROD_OAM = { down = { dx = 1, dy = 2, tile = 0 }, up = { dx = 0, dy = 0, tile = 0 }, left = { dx = 0, dy = 0, tile = 0 }, right = { dx = 0, dy = 0, tile = 0, flip = true } }
assertEq(G2.rodOam().down.dx, 1, "a saved rod offset is the one drawn")
assertEq(G2.rodOam().right.flip, true, "a saved rod can flip to the right")
G2.ROD_OAM = savedG2Rod
local OW = require("src.world.OverworldController")
local north = { cellX = 0, cellY = -4 }
local spot = { cellX = 0, cellY = 0 }
assertEq(OW.sightPixelDist(north, spot, false), 192, "four tiles north wraps past a range of four")
OW.SIGHT_Y = 64
assertEq(OW.sightPixelDist(north, spot, false), 64, "a centered origin counts those four tiles")
OW.SIGHT_Y = 0x3c
assertEq(OW.spriteOnScreen({ cellX = 5, cellY = 0 }, { cellX = 0, cellY = 0 }), true, "five tiles east is still on screen")
assertEq(OW.spriteOnScreen({ cellX = 6, cellY = 0 }, { cellX = 0, cellY = 0 }), false, "six tiles east is off screen")
OW.SIGHT_RIGHT = 6
assertEq(OW.spriteOnScreen({ cellX = 6, cellY = 0 }, { cellX = 0, cellY = 0 }), true, "a wider screen includes that tile")
OW.SIGHT_RIGHT = 5
local walked
local ow = setmetatable({
  pushableAtCell = function() return false end,
  scriptMove = function(_, _, _, n) walked = n end,
}, { __index = OW })
local trainer = { cellX = 0, cellY = 0, facing = "down", def = {} }
ow:startTrainerApproach(trainer, 4)
assertEq(ow.emote.frames, 60, "the notice bubble lasts 60 frames")
OW.EMOTE_FRAMES = 0
ow:startTrainerApproach(trainer, 4)
assertEq(ow.emote.frames, 0, "a notice of 0 does not wait")
OW.EMOTE_FRAMES = 60
ow.emote.onDone()
assertEq(walked, 3, "the trainer stops one tile short")
OW.APPROACH_GAP = 0
ow:startTrainerApproach(trainer, 4)
ow.emote.onDone()
assertEq(walked, 4, "a gap of 0 walks the whole way")
OW.APPROACH_GAP = 1
local G2Trainers = require("src.world.gen2.Trainers")
assertEq(#G2Trainers.approach(4, "down"), 3, "a Gen 2 trainer stops one tile short")
G2Trainers.APPROACH_GAP = 0
assertEq(#G2Trainers.approach(4, "down"), 4, "a Gen 2 gap of 0 walks the whole way")
G2Trainers.APPROACH_GAP = 1
local G2World = require("src.world.gen2.World")
local seen = { { op = "showemote", frames = 30 } }
G2World.NOTICE_FRAMES = 0
G2World.applyNotice(seen)
assertEq(seen[1].frames, 0, "a Gen 2 notice of 0 does not wait")
G2World.NOTICE_FRAMES = 30
G2World.applyNotice(seen)
assertEq(seen[1].frames, 30, "the cart notice lasts 30 frames")
assertEq(seen[1].emote, 0, "a trainer notice uses the shock bubble")
G2World.EMOTE_SHOCK = 3
G2World.applyNotice(seen)
assertEq(seen[1].emote, 3, "a saved shock bubble is the one shown")
G2World.EMOTE_SHOCK = 0
assertEq(G2World.headbuttSfx(), 109, "Headbutt plays sound 109")
assertEq(G2World.cutSfx(), 30, "Cut plays sound 30")
assertEq(G2World.flashSfx(), 169, "Flash plays sound 169")
assertEq(G2World.waterfallSfx(), 81, "Waterfall plays sound 81")
assertEq(G2World.boulderSfx(), 27, "a boulder plays sound 27")
assertEq(G2World.whirlpoolCap(), 180, "a whirlpool waits at most 180 frames")
assertEq(G2World.waterFrameFor(0), 1, "water starts on frame 1")
assertEq(G2World.waterFrameFor(2), 2, "water advances on the third tick")
assertEq(G2World.towerRow(0), 1, "the tower starts on row 1")
assertEq(G2World.towerRow(4), 5, "the tower reaches row 5")
assertEq(G2World.scrollShift(7), -1, "the scroll ends one pixel back")
assertEq(G2World.whirlRow(3), 4, "the whirlpool reaches frame 4")
assertEq(G2World.lavaRow(0, true), 3, "the ahead lava starts on frame 3")
assertEq(G2World.lavaRow(0, false), 1, "the other lava starts on frame 1")
G2World.TOWER_ROWS = { [0] = 6, 6, 6, 6, 6, 6, 6, 6 }
assertEq(G2World.towerRow(4), 6, "a saved tower row is the one drawn")
G2World.TOWER_ROWS = nil
G2World.WHIRLPOOL_CAP = 0
assertEq(G2World.whirlpoolCap(), 0, "a whirlpool wait of 0 does not hold")
G2World.WHIRLPOOL_CAP = 180
assertEq(G2World.healBallFrames(), 30, "each heal ball waits 30 frames")
assertEq(G2World.healFlashFrames(), 10, "each heal flash waits 10 frames")
assertEq(G2World.healFlashes(), 8, "the heal machine flashes 8 times")
G2World.HEAL_FLASHES = 0
assertEq(G2World.healFlashes(), 0, "a flash count of 0 ends the machine")
G2World.HEAL_FLASHES = 8
assertEq(G2World.healLayout(0).machine[1][1], 26, "the center lights start at x 26")
assertEq(G2World.healLayout(1).machine[1][1], 42, "the lab lights sit 16 pixels to the right")
assertEq(G2World.healLayout(2).balls[1][1], 73, "the Hall of Fame balls start at x 73")
local savedPc = G2World.HEAL_PC
G2World.HEAL_PC = { machine = { { 1, 2 } }, balls = { { 3, 4, true } } }
assertEq(G2World.healLayout(0).balls[1][1], 3, "a saved center ball is the one drawn")
assertEq(G2World.healLayout(1).balls[1][1], 19, "the lab follows the saved center")
G2World.HEAL_PC = savedPc
assertEq(G2World.fadeSteps(), 4, "a map fade has 4 steps")
assertEq(G2World.fadeStepFrames(), 2, "each fade step waits 2 frames")
assertEq(G2World.mapWhiteFrames(), 13, "a door stays white for 13 frames")
assertEq(G2World.warpWhiteFrames(), 15, "a warp stays white for 15 frames")
G2World.FADE_STEPS = 1
assertEq(G2World.fadeSteps(), 1, "a fade of 1 is the shortest ramp")
G2World.FADE_STEPS = 0
assertEq(G2World.fadeSteps(), 1, "the ramp stays at least one step")
G2World.FADE_STEPS = 4
G2World.FADE_STEP_FRAMES = 0
assertEq(G2World.fadeStepFrames(), 0, "a fade frame of 0 does not wait")
G2World.FADE_STEP_FRAMES = 2
G2World.MAP_LOAD_WHITE_FRAMES = 0
assertEq(G2World.mapWhiteFrames(), 0, "a door white of 0 does not hold")
G2World.MAP_LOAD_WHITE_FRAMES = 13
G2World.WARP_LOAD_WHITE_FRAMES = 0
assertEq(G2World.warpWhiteFrames(), 0, "a warp white of 0 does not hold")
G2World.WARP_LOAD_WHITE_FRAMES = 15
assertEq(G2World.menuWhite(), 23, "closing a menu stays white for 23 frames")
G2World.MENU_EXIT_WHITE_FRAMES = 0
assertEq(G2World.menuWhite(), 0, "a menu white of 0 does not hold")
G2World.MENU_EXIT_WHITE_FRAMES = 23
assertEq(G2World.flyWhite(), 31, "leaving to fly stays white for 31 frames")
G2World.FLY_EXIT_WHITE_FRAMES = 0
assertEq(G2World.flyWhite(), 0, "a fly white of 0 does not hold")
G2World.FLY_EXIT_WHITE_FRAMES = 31
assertEq(G2World.flyBuild(), 28, "the fly map stays blank for 28 frames")
G2World.FLY_MAP_BUILD_FRAMES = 0
assertEq(G2World.flyBuild(), 0, "a fly build of 0 does not wait")
G2World.FLY_MAP_BUILD_FRAMES = 28
assertEq(G2World.flyCancelBlank(), 21, "cancelling Fly stays blank for 21 frames")
assertEq(G2World.flyCancelIcon(), 3, "each party icon adds 3 frames")
G2World.FLY_CANCEL_BLANK_FRAMES = 0
assertEq(G2World.flyCancelBlank(), 0, "a fly blank of 0 does not wait")
G2World.FLY_CANCEL_BLANK_FRAMES = 21
G2World.FLY_CANCEL_ICON_FRAMES = 0
assertEq(G2World.flyCancelIcon(), 0, "an icon of 0 adds no wait")
G2World.FLY_CANCEL_ICON_FRAMES = 3
local Menu = require("src.ui.gen2.MenuFade")
assertEq(Menu.openWhite("pack"), 16, "the bag stays white for 16 frames")
Menu.PACK_WHITE = 0
assertEq(Menu.openWhite("pack"), 0, "a bag white of 0 does not hold")
Menu.PACK_WHITE = 16
assertEq(Menu.openWhite("pokedex"), 27, "the dex stays white for 27 frames")
Menu.DEX_WHITE = 0
assertEq(Menu.openWhite("pokedex"), 0, "a dex white of 0 does not hold")
Menu.DEX_WHITE = 27
assertEq(Menu.closeWhite("pokegear"), Menu.exitWhite() + 4, "the gear adds 4 frames on the way out")
Menu.GEAR_EXIT_WHITE = 0
assertEq(Menu.closeWhite("pokegear"), Menu.exitWhite(), "a gear exit of 0 adds nothing")
Menu.GEAR_EXIT_WHITE = 4
assertEq(Menu.partyExtra(), 3, "Gold and Silver add 3 party frames")
Menu.PARTY_EXTRA = 0
assertEq(Menu.partyExtra(), 0, "a party extra of 0 adds nothing")
Menu.PARTY_EXTRA = 3
assertEq(Menu.inRampFrames(), 6, "the menu returns over 3 steps of 2 frames")
Menu.IN_STEPS = 0
assertEq(Menu.inRampFrames(), 0, "a return of 0 does not ramp")
Menu.IN_STEPS = 3
assertEq(G2World.palettePoll(), 60, "the clock is checked every 60 frames")
G2World.PALETTE_POLL_STEPS = 0
assertEq(G2World.palettePoll(), 0, "a poll of 0 checks every frame")
G2World.PALETTE_POLL_STEPS = 60
assertEq(G2World.strengthPause(), 3, "Strength waits 3 frames")
G2World.STRENGTH_PAUSE_FRAMES = 0
assertEq(G2World.strengthPause(), 0, "a Strength pause of 0 does not wait")
G2World.STRENGTH_PAUSE_FRAMES = 3
assertEq(G2World.neighborHops(), 2, "two connections past the map stay loaded")
G2World.NEIGHBOR_HOPS = 0
assertEq(G2World.neighborHops(), 0, "a reach of 0 keeps the current view")
G2World.NEIGHBOR_HOPS = 2
local savedWhite = G2World.FADE_RAMP.white
G2World.FADE_RAMP.white = { { 0, 0, 0, 0 } }
assertEq(G2World.fadeRampRow("white", 1)[1], 0, "a saved white ramp is the one drawn")
G2World.FADE_RAMP.white = savedWhite
assertEq(OW.flyFadeFrames(), 28, "Fly waits 4 volume steps of 7 frames")
OW.FLY_FADE_CONTROL = 0
assertEq(OW.flyFadeFrames(), 0, "a fly fade of 0 does not hold")
OW.FLY_FADE_CONTROL = 4
assertEq(OW.flyFlap(), 8, "the bird flaps for 8 beats")
OW.FLY_FLAP = 0
assertEq(OW.flyFlap(), 0, "a flap of 0 does not wait")
OW.FLY_FLAP = 8
assertEq(OW.flyBeat(), 40, "the bird waits 40 frames off screen")
OW.FLY_BEAT = 0
assertEq(OW.flyBeat(), 0, "a beat of 0 does not wait")
OW.FLY_BEAT = 40
assertEq(OW.flyStep(), 3, "each fly picture waits 3 frames")
OW.FLY_STEP = 0
assertEq(OW.flyStep(), 1, "a fly step stays at least one frame")
OW.FLY_STEP = 3
assertEq(OW.teleportOutFrames(), 135, "Teleport spins out for 135 frames")
OW.TELEPORT_OUT_FRAMES = 0
assertEq(OW.teleportOutFrames(), 0, "a teleport out of 0 does not spin")
OW.TELEPORT_OUT_FRAMES = 135
assertEq(OW.holeInFrames(), 15, "a hole spins in for 15 frames")
OW.HOLE_IN_FRAMES = 0
assertEq(OW.holeInFrames(), 0, "a hole spin of 0 does not wait")
OW.HOLE_IN_FRAMES = 15
assertEq(#OW.teleportOutHolds(), 22, "Teleport out has 22 holds")
assertEq(OW.teleportOutHolds()[1], 15, "Teleport out starts on a 15 frame hold")
assertEq(OW.teleportInPlace(), 16, "Teleport rises after 16 steps")
OW.TELEPORT_OUT_INPLACE = 0
assertEq(OW.teleportInPlace(), 0, "a rise at 0 lifts from the first step")
OW.TELEPORT_OUT_INPLACE = 16
assertEq(OW.shipKeep(), 16, "the ship keeps its top 16 pixels")
assertEq(OW.ghostPad(), 16, "an offscreen neighbor is padded by 16 pixels")
local savedHolds = OW.HOLE_IN_HOLDS
OW.HOLE_IN_HOLDS = { 0 }
assertEq(OW.holeHolds()[1], 0, "a hole hold of 0 does not wait")
OW.HOLE_IN_HOLDS = savedHolds
assertEq(#OW.flyPath1(), 12, "Fly leaves on 12 points")
assertEq(OW.flyPath1()[1][1], 60, "Fly leaves from y 60")
assertEq(OW.flyPath1()[12][2], 160, "Fly leaves toward x 160")
assertEq(OW.flyPath2()[11][1], -16, "Fly parks 16 pixels above the anchor")
assertEq(OW.flyAnchor()[2], 72, "Fly is anchored at x 72")
assertEq(OW.flyLand()[2], 64, "Fly lands at x 64")
local savedPath = OW.FLY_PATH1
OW.FLY_PATH1 = { { 0, 0 } }
assertEq(#OW.flyPath1(), 1, "a saved fly path replaces the cart path")
OW.FLY_PATH1 = savedPath
assertEq(OW.shipSail(), 128, "the ship sails 128 pixels")
OW.SS_ANNE_SAIL_PX = 0
assertEq(OW.shipSail(), 0, "a sail of 0 leaves immediately")
OW.SS_ANNE_SAIL_PX = 128
assertEq(OW.shipStep(), 8, "the ship waits 8 frames per pixel")
assertEq(OW.shipSmokeEvery(), 16, "smoke puffs every 16 pixels")
assertEq(OW.shipBlock().w, 4, "the ship is 4 blocks wide")
assertEq(OW.shipWater()[2], 13, "the lower ship row becomes water 13")
assertEq(OW.rodOam().down.dy, 15, "the downward rod sits 15 pixels below the player")
assertEq(OW.rodOam().right.flip, true, "the right-facing rod is flipped")
local savedRod = OW.ROD_OAM
OW.ROD_OAM = { down = { dx = 0, dy = 0, tile = 0 }, up = { dx = 0, dy = 0, tile = 0 }, left = { dx = 0, dy = 0, tile = 0 }, right = { dx = 1, dy = 2, tile = 3, flip = false } }
assertEq(OW.rodOam().right.tile, 3, "a saved rod tile is kept")
assertEq(OW.rodOam().right.flip, false, "a saved rod can stay unflipped")
OW.ROD_OAM = savedRod
assertEq(OW.healBallFrames(), 30, "each Center ball waits 30 frames")
assertEq(OW.healFlashFrames(), 10, "each Center flash waits 10 frames")
assertEq(OW.healFlashes(), 8, "the Center machine flashes 8 times")
OW.HEAL_FLASHES = 0
assertEq(OW.healFlashes(), 0, "a flash count of 0 ends on the first beat")
OW.HEAL_FLASHES = 8
assertEq(OW.healBalls()[2][1], 48, "the second Center ball sits at x 48")
assertEq(OW.healBalls()[2][3], true, "the second Center ball is mirrored")
assertEq(OW.healMonitorX(), 44, "the Center screen sits at x 44")
local savedHeal = OW.HEAL_BALL_XY
OW.HEAL_BALL_XY = { { 1, 2, true } }
assertEq(OW.healBalls()[1][1], 1, "a saved Center ball is the one drawn")
OW.HEAL_BALL_XY = savedHeal
assertEq(OW.healDmgMap()[1], 2, "the DMG flash swaps the middle shades")
assertEq(OW.healGbcMap()[2], 1, "the color flash lifts shade 2")
local savedDmg = OW.HEAL_FLASH_MAP
OW.HEAL_FLASH_MAP = { [0] = 1, 1, 1, 1 }
assertEq(OW.healDmgMap()[0], 1, "a saved flash map is the one drawn")
OW.HEAL_FLASH_MAP = savedDmg
local Timing = require("src.core.Timing")
local Transition = require("src.render.Transition")
local warp = Transition.new(nil, function() end, function() end, true)
assertEq(warp.frames, 32, "a warp fades out for 32 frames")
assertEq(warp.framesIn, 0, "a warp does not fade back in")
Timing.WARP_FADE_OUT = 0
local fast = Transition.new(nil, function() end, function() end, true)
assertEq(fast.frames, 0, "a warp out of 0 does not hold")
Timing.WARP_FADE_OUT = 32
assertEq(Transition.fadeStep(), 8, "each fade shade holds for 8 frames")
Transition.FADE_STEP_FRAMES = 0
assertEq(Transition.fadeStep(), 1, "a fade step stays at least one frame")
Transition.FADE_STEP_FRAMES = 8
assertEq(Transition.flashFrames(nil), 7, "a white flash holds for 7 frames")
Transition.FLASH_FRAMES = 0
assertEq(Transition.flashFrames(nil), 0, "a white flash of 0 does not hold")
Transition.FLASH_FRAMES = 7
assertEq(Timing.BLINK_MON, 60, "a hit blinks for 60 frames")
Timing.BLINK_MON = 0
assertEq(Timing.BLINK_MON, 0, "a blink of 0 does not wait")
Timing.BLINK_MON = 60
local G2Battle = require("src.ui.gen2.BattleState")
assertEq(G2Battle.textPause(), 30, "a battle pause waits 30 frames")
G2Battle.TEXT_PAUSE_FRAMES = 0
assertEq(G2Battle.textPause(), 0, "a battle pause of 0 does not wait")
G2Battle.TEXT_PAUSE_FRAMES = 30
assertEq(G2Battle.exitFadeFrames(), 8, "the battle exit holds each shade for 8 frames")
G2Battle.EXIT_FADE_FRAMES = 0
assertEq(G2Battle.exitFadeFrames(), 0, "an exit fade of 0 does not hold")
G2Battle.EXIT_FADE_FRAMES = 8
assertEq(G2Battle.faintRow(), 2, "a faint sinks one row every 2 frames")
G2Battle.FAINT_SLIDE_FRAMES_PER_ROW = 0
assertEq(G2Battle.faintRow(), 1, "a faint row stays at least one frame")
G2Battle.FAINT_SLIDE_FRAMES_PER_ROW = 2
assertEq(G2Battle.expSound(), 10, "the exp bar waits 10 frames before it moves")
G2Battle.EXP_SOUND_FRAMES = 0
assertEq(G2Battle.expSound(), 0, "an exp sound of 0 does not wait")
G2Battle.EXP_SOUND_FRAMES = 10
assertEq(G2Battle.expWait(), 180, "a busy sound holds the exp bar for 180 frames")
assertEq(G2Battle.expBurst(), 8, "the level burst lasts 8 frames")
assertEq(G2Battle.expX(), 76, "the level burst starts at x 76")
assertEq(G2Battle.expY(), 88, "the level burst starts at y 88")
assertEq(G2Battle.textWidth(), 18, "a battle line is 18 tiles wide")
G2Battle.TEXT_WIDTH = 0
assertEq(G2Battle.textWidth(), 1, "a battle line stays at least one tile")
G2Battle.TEXT_WIDTH = 18
assertEq(G2Battle.textRows(), 2, "a battle box shows 2 rows")
assertEq(G2Battle.menuX(), 8, "the battle menu starts at tile 8")
assertEq(G2Battle.parkX(), 2, "the Park Ball menu starts at tile 2")
local G2Anim = require("src.ui.gen2.BattleAnimView")
assertEq(G2Anim.SLIDE_FRAMES, 72, "the battle intro slides for 72 frames")
G2Anim.SLIDE_FRAMES = 0
assertEq(G2Anim.SLIDE_FRAMES, 0, "an intro slide of 0 does not wait")
G2Anim.SLIDE_FRAMES = 72
local Fx = require("src.core.game3.field_effects")
assertEq(Fx.emoteDuration(nil), 60, "a Gen 3 notice lasts 60 frames")
Fx.EMOTE_FRAMES = 0
assertEq(Fx.emoteDuration(nil), 0, "a Gen 3 notice of 0 does not wait")
assertEq(Fx.emoteDuration(12), 12, "a supplied notice length is kept")
Fx.EMOTE_FRAMES = 60
assertEq(Fx.emoteRise(nil), -5, "the mark hops up by 5")
Fx.EMOTE_HOP = 0
assertEq(Fx.emoteRise(nil), 0, "a hop of 0 stays put")
assertEq(Fx.emoteRise(-2), -2, "a supplied hop is kept")
Fx.EMOTE_HOP = -5
local savedAnims = Fx._anims
Fx._anims = { { kind = "emote", timer = 3, baseFrame = 0, frame = 0, maxDur = 60 } }
Fx.step()
assertEq(Fx._anims[1].frame, 1, "the second pose starts on frame 4")
Fx.EMOTE_A = 0
Fx.EMOTE_B = 0
Fx._anims[1].timer = 0
Fx.step()
assertEq(Fx._anims[1].frame, 2, "poses of 0 skip to the last frame")
Fx.EMOTE_A = 4
Fx.EMOTE_B = 8
Fx.MARK_STEP = 0
Fx._anims = { { kind = "emote", timer = 10, baseFrame = 4, maxDur = 60 } }
Fx.step()
assertEq(Fx._anims[1].frame, 4, "a mark step of 0 stays on the first picture")
Fx.MARK_STEP = 2
Fx._anims = { { kind = "emote", timer = 3, baseFrame = 4, maxDur = 60 } }
Fx.step()
assertEq(Fx._anims[1].frame, 6, "the second pose jumps by the saved step")
Fx.MARK_STEP = 1
Fx._anims = { { kind = "emote", rse = true, timer = 0, yOffset = 0, yVelocity = -5, maxDur = 60 } }
Fx.step()
assertEq(Fx._anims[1].yOffset, -5, "the mark rises five pixels")
assertEq(Fx._anims[1].yVelocity, -4, "gravity slows the rise")
Fx.EMOTE_GRAVITY = 0
Fx._anims[1].yOffset = 0
Fx._anims[1].yVelocity = -5
Fx.step()
assertEq(Fx._anims[1].yVelocity, -5, "gravity of 0 keeps the speed")
Fx.EMOTE_GRAVITY = 1
Fx.MARK_LIFT = 0
assertEq(Fx.markHeight(40, false, 32, 0), 40, "a mark height of 0 sits on the feet")
Fx.MARK_GAP = 0
assertEq(Fx.markHeight(40, true, 32, 0), 24, "a mark gap of 0 sits at half the sprite")
Fx.MARK_LIFT = 16
Fx.MARK_GAP = 8
assertEq(Fx.markHeight(40, true, 32, 0), 16, "the cart gap sits 8 pixels above half the sprite")
Fx.MARK_BANG = 4
assertEq(Fx.markBase("exclamation"), 4, "an exclamation uses the saved picture")
assertEq(Fx.markBase(0), 4, "picture 0 of the mark list is the exclamation")
assertEq(Fx.markBase(0x62), 4, "the notice exclamation uses the same picture")
Fx.MARK_ASK = 0
assertEq(Fx.markBase("question"), 0, "a question can start on picture 0")
Fx.MARK_X = 1
assertEq(Fx.markBase(2), 1, "the cross uses the saved picture")
Fx.MARK_BANG = 0
Fx.MARK_BANG2 = 6
Fx.MARK_X = 3
Fx.MARK_SMILE = 9
Fx.MARK_ASK = 12
Fx._anims = savedAnims
local stump = { customFrame = -1 }
local leaf = { x = 0, y = 0, vx = 0, vy = 0, frame = 0 }
Fx._anims = { { kind = "cut_tree", timer = 5, targetObj = stump, particles = { leaf } } }
Fx.step()
assertEq(stump.customFrame, 1, "the second cut picture starts on tick 6")
assertEq(leaf.vy, 0.12, "a leaf falls faster by 0.12")
Fx.CUT_HOLD = 1
Fx.LEAF_GRAVITY = 0
leaf.vy = 1
Fx._anims[1].timer = 0
Fx.step()
assertEq(stump.customFrame, 1, "a one-tick cut picture advances immediately")
assertEq(leaf.vy, 1, "a fall of 0 does not speed up")
Fx.CUT_HOLD = 6
Fx.LEAF_GRAVITY = 0.12
Fx.CUT_X = 0
Fx.CUT_Y = 0
local cutX, cutY = Fx.cutPlace(2, 3)
assertEq(cutX, 32, "a cut across of 0 sits on the tile")
assertEq(cutY, 48, "a cut down of 0 sits on the tile")
assertEq(Fx.cutFrame(6), 1, "the drawn cut picture follows the frame length")
Fx.CUT_X = -8
Fx.CUT_Y = -16
Fx.GRASS_BASE = 0
Fx.GRASS_SPREAD = 0
Fx.GRASS_LIFT = 0
assertEq(Fx.grassBurst(1), 0, "grass with no speed stays put")
assertEq(Fx.grassKick(0, 0), 0, "a grass lift of 0 does not kick")
Fx.GRASS_LIFT = 2
assertEq(Fx.grassKick(0, 0), -2, "the grass lift is upward")
Fx.SMASH_JITTER = 0
assertEq(Fx.smashAngle(1, 1), 0, "a wobble of 0 keeps the first chip straight")
Fx.SMASH_BASE = 0
Fx.SMASH_SPREAD = 0
Fx.SMASH_LIFT = 0
assertEq(Fx.smashBurst(1), 0, "chips with no speed stay put")
assertEq(Fx.smashKick(0, 0), 0, "a chip lift of 0 does not kick")
Fx.GRASS_BASE = 1.2
Fx.GRASS_SPREAD = 1
Fx.GRASS_LIFT = 1
Fx.SMASH_BASE = 1.2
Fx.SMASH_SPREAD = 1.6
Fx.SMASH_LIFT = 1.5
Fx.SMASH_JITTER = 0.3
local rock = { customFrame = -1 }
local chip = { x = 0, y = 0, vx = 0, vy = 0, frame = 0 }
Fx._anims = { { kind = "rock_smash", timer = 5, targetObj = rock, particles = { chip } } }
Fx.step()
assertEq(rock.customFrame, 1, "the second smash picture starts on tick 6")
assertEq(chip.vy, 0.15, "a chip falls faster by 0.15")
Fx.SMASH_HOLD = 1
Fx.SMASH_GRAVITY = 0
chip.vy = 1
Fx._anims[1].timer = 0
Fx.step()
assertEq(rock.customFrame, 1, "a one-tick smash picture advances immediately")
assertEq(chip.vy, 1, "a smash fall of 0 does not speed up")
Fx.SMASH_HOLD = 6
Fx.SMASH_GRAVITY = 0.15
Fx._anims = { { kind = "cut_grass_scatter", timer = 22, particles = {} } }
Fx.step()
assertEq(#Fx._anims, 1, "cut grass is still going on tick 23")
Fx.GRASS_FRAMES = 0
Fx.step()
assertEq(#Fx._anims, 0, "a grass length of 0 ends on the next tick")
Fx.GRASS_FRAMES = 24
local scent = { kind = "sweet_scent", timer = 0, radius = 0 }
Fx._anims = { scent }
Fx.step()
assertEq(scent.radius, (1 / 50) * 120, "the scent ring grows toward 120")
Fx.SCENT_RADIUS = 0
Fx.step()
assertEq(scent.radius, 0, "a scent size of 0 stays a point")
Fx.SCENT_FRAMES = 1
Fx.step()
assertEq(#Fx._anims, 0, "a one-tick scent ends once that tick has passed")
Fx.SCENT_FRAMES = 50
Fx.SCENT_RADIUS = 120
Fx.SCENT_GAP = 0
assertEq(Fx.scentInner(40), 40, "a scent gap of 0 draws both rings together")
Fx.SCENT_GAP = 50
assertEq(Fx.scentInner(40), 0, "a gap bigger than the ring stays at the center")
assertEq(Fx.scentX(), 120, "the scent starts in the middle")
assertEq(Fx.scentY(), 80, "the scent starts in the middle")
Fx.SCENT_X = 0
Fx.SCENT_Y = 0
assertEq(Fx.scentX(), 0, "a scent across of 0 sits at the left edge")
assertEq(Fx.scentY(), 0, "a scent down of 0 sits at the top")
Fx.SCENT_GAP = 20
Fx.SCENT_X = 120
Fx.SCENT_Y = 80
local splash = { kind = "splash", timer = 4, frame = -1 }
Fx._anims = { splash }
Fx.step()
assertEq(splash.frame, 1, "the second splash picture starts after 4 ticks")
Fx.SPLASH_HOLD = 0
Fx._anims = { { kind = "splash", timer = 0, frame = 0 } }
Fx.step()
assertEq(#Fx._anims, 0, "a splash hold of 0 ends immediately")
Fx.SPLASH_HOLD = 4
local dust = { kind = "dust", timer = 8, frame = -1 }
Fx._anims = { dust }
Fx.step()
assertEq(dust.frame, 1, "the second dust picture starts after 8 ticks")
Fx.DUST_HOLD = 0
Fx._anims = { { kind = "dust", timer = 0, frame = 0 } }
Fx.step()
assertEq(#Fx._anims, 0, "a dust hold of 0 ends immediately")
Fx.DUST_HOLD = 8
Fx.SPLASH_PICS = { 7 }
Fx.SPLASH_HOLD = 4
splash = { kind = "splash", timer = 0, frame = -1 }
Fx._anims = { splash }
Fx.step()
assertEq(splash.frame, 7, "the splash uses the saved picture")
Fx.DUST_PICS = { 5 }
Fx.DUST_HOLD = 8
dust = { kind = "dust", timer = 0, frame = -1 }
Fx._anims = { dust }
Fx.step()
assertEq(dust.frame, 5, "the dust uses the saved picture")
Fx.SPLASH_PICS = { 0, 1 }
Fx.SPLASH_HOLD = 4
Fx.DUST_PICS = { 0, 1, 2 }
Fx.DUST_HOLD = 8
local savedFx = Fx._fx
Fx._fx = { timer = 9, step = 1 }
Fx.step()
assertEq(Fx._fx.timer, 0, "tall grass advances after 10 ticks")
Fx.RUSTLE_HOLD = 0
Fx._fx = { timer = 0, step = 1 }
Fx.step()
assertEq(Fx._fx.step, 2, "a rustle hold of 0 advances every tick")
Fx.RUSTLE_HOLD = 10
Fx._fx = savedFx
Fx.RUSTLE = { 7 }
assertEq(Fx.grassPicture({ step = 0 }), 7, "tall grass uses the saved picture")
Fx.RUSTLE = { 0 }
Fx.RUSTLE_HOLD = 1
Fx._fx = { timer = 0, step = 0, leaving = false }
Fx.step()
assertEq(Fx._fx.step, 0, "one grass picture stays on that picture")
Fx.RUSTLE = { 1, 2, 3, 4, 0 }
Fx.RUSTLE_HOLD = 10
Fx._fx = savedFx
local savedGround = Fx._ground
Fx._ground = { inShallowFlowingWater = true }
local feet = { kind = "feet_water", timer = 4, frame = -1, cx = 0, cy = 0 }
Fx._anims = { feet }
Fx.step()
assertEq(feet.frame, 1, "the second feet picture starts after 4 ticks")
Fx.FEET_HOLD = { 0, 4, 6, 6, 8, 8, 6, 6 }
feet = { kind = "feet_water", timer = 0, frame = -1, cx = 0, cy = 0 }
Fx._anims = { feet }
Fx.step()
assertEq(feet.frame, 1, "a feet hold of 0 skips that picture")
Fx.FEET_HOLD = { 4, 4, 6, 6, 8, 8, 6, 6 }
Fx._ground = savedGround
local ripple = { kind = "ripple", timer = 12, frame = -1 }
Fx._anims = { ripple }
Fx.step()
assertEq(ripple.frame, 1, "the second ripple picture starts after 12 ticks")
Fx.RIPPLE_HOLD = { 0, 9, 9, 9, 9, 9, 11, 11 }
ripple = { kind = "ripple", timer = 0, frame = -1 }
Fx._anims = { ripple }
Fx.step()
assertEq(ripple.frame, 1, "a ripple hold of 0 skips that picture")
Fx.RIPPLE_HOLD = { 12, 9, 9, 9, 9, 9, 11, 11 }
Fx._ground = { inShallowFlowingWater = true }
Fx.FEET_PICS = { 7 }
Fx.FEET_HOLD = { 4 }
feet = { kind = "feet_water", timer = 0, frame = -1, cx = 0, cy = 0 }
Fx._anims = { feet }
Fx.step()
assertEq(feet.frame, 7, "the footprints use the saved picture")
assertEq(Fx.feetH(), 8, "the grass cover is 8 pixels tall")
assertEq(Fx.feetCover(32), 40, "the cover sits on the bottom of the tile")
Fx.FEET_H = 4
assertEq(Fx.feetCover(32), 44, "a shorter cover sits lower in the tile")
Fx.FEET_H = 0
assertEq(Fx.feetH(), 1, "the cover stays at least one pixel")
Fx.FEET_H = 8
assertEq(Fx.grassSlack(), 2, "the grass cover stays for 2 pixels past the tile")
Fx.GRASS_SLACK = 0
assertEq(Fx.grassSlack(), 0, "a slack of 0 ends at the tile edge")
Fx.GRASS_SLACK = 2
assertEq(Fx.ripplePlace(16), 22, "the ripple sits 6 pixels below the tile")
Fx.RIPPLE_Y = 0
assertEq(Fx.ripplePlace(16), 16, "a ripple drop of 0 sits on the tile")
Fx.RIPPLE_Y = 6
local Rse = require("src.core.game3.field_effects_rse")
assertEq(Rse.shortGrassY(32), 8, "short grass sits 8 pixels above the middle")
Rse.SHORT_LIFT = 0
assertEq(Rse.shortGrassY(32), 16, "a short-grass lift of 0 sits at the middle")
Rse.SHORT_LIFT = 8
assertEq(Rse.sandY(32), 14, "the sand pile sits 2 pixels above the middle")
Rse.SAND_LIFT = 0
assertEq(Rse.sandY(32), 16, "a sand lift of 0 sits at the middle")
Rse.SAND_LIFT = 2
local tire = { timer = 42, hidden = false }
assertEq(Rse.tireStep(tire), false, "the track is still down at tick 42")
assertEq(tire.hidden, true, "the track starts blinking after 41 ticks")
tire.timer = 58
assertEq(Rse.tireStep(tire), true, "the track ends after 57 ticks")
Rse.TIRE_BLINK = 0
Rse.TIRE_END = 0
tire = { timer = 1, hidden = false }
assertEq(Rse.tireStep(tire), true, "a tire end of 0 clears on the next tick")
assertEq(tire.hidden, true, "a blink of 0 flickers on the next tick")
Rse.TIRE_BLINK = 41
Rse.TIRE_END = 57
assertEq(Fx.birdW(), 64, "the bird is 64 pixels wide")
assertEq(Fx.birdH(), 64, "the bird is 64 pixels tall")
assertEq(Fx.birdFrames(), 5, "the bird has 5 pictures")
Fx.BIRD_W = 1
assertEq(Fx.birdW(), 1, "a one-pixel bird is kept")
Fx.BIRD_W = 0
assertEq(Fx.birdW(), 1, "the bird stays at least one pixel wide")
Fx.BIRD_W = 64
Fx.BIRD_FRAMES = 1
assertEq(Fx.birdFrames(), 1, "a one-picture bird is kept")
Fx.BIRD_FRAMES = 5
assertEq(Fx.surfW(), 32, "the surf blob is 32 pixels wide")
assertEq(Fx.surfH(), 32, "the surf blob is 32 pixels tall")
assertEq(Fx.surfFrames(), 6, "the surf blob has 6 pictures")
Fx.SURF_W = 16
assertEq(Fx.surfW(), 16, "a narrower blob is kept")
Fx.SURF_W = 0
assertEq(Fx.surfW(), 1, "the blob stays at least one pixel wide")
Fx.SURF_W = 32
local x, y = Rse.effectAt(1, 2)
assertEq(x, 24, "effects sit 8 pixels into the tile")
assertEq(y, 40, "effects sit 8 pixels down the tile")
Rse.PLACE = 0
x, y = Rse.effectAt(1, 2)
assertEq(x, 16, "a center of 0 stays on the tile corner")
Rse.PLACE = 8
assertEq(Rse.splashDrop(), 12, "the puddle splash sits 12 pixels down")
assertEq(Rse.bubbleY(), 0, "bubbles start at the top of the tile")
assertEq(Rse.bubbleRise(), 0.5, "bubbles rise half a pixel a tick")
Rse.BUBBLE_RISE = 0
assertEq(Rse.bubbleRise(), 0, "a rise of 0 stays put")
Rse.BUBBLE_RISE = 0.5
assertEq(Rse.berryY(), 4, "the berry sparkle sits 4 pixels down")
assertEq(Rse.pillarY(), 0, "the sand pillar starts at the top of the tile")
assertEq(Rse.sparkleWait(), 34, "the sparkle holds for 34 ticks")
Rse.SPARKLE_WAIT = 0
assertEq(Rse.sparkleWait(), 0, "a wait of 0 ends with the picture")
Rse.SPARKLE_WAIT = 34
assertEq(Rse.sandFrame(), 2, "the sand pile starts on picture 2")
Rse.SAND_FRAME = 0
assertEq(Rse.sandFrame(), 0, "picture 0 is the first sand picture")
Rse.SAND_FRAME = 2
assertEq(Rse.distortWave()[1], math.floor(65536 / 255), "the water wave starts one step wider")
Rse.DISTORT = { { 0, 1 } }
assertEq(Rse.distortWave()[1], 256, "a flat wave stays at the normal size")
assertEq(#Rse.distortWave(), 1, "one hold keeps a single sample")
Rse.DISTORT = {}
assertEq(Rse.distortWave()[1], 256, "an empty wave stays at the normal size")
Rse.DISTORT = {
  { 1, 4 }, { 0, 8 }, { -1, 4 }, { 0, 8 },
  { -1, 4 }, { 0, 8 }, { 1, 4 }, { 0, 8 },
}
assertEq(Rse.tireTrackAnim("down", "down"), 1, "straight down keeps track 1")
assertEq(Rse.tireTrackAnim("down", "left"), 7, "turning left from down uses track 7")
assertEq(Rse.tireTrackAnim(nil, nil), 1, "a missing direction uses the down row")
Rse.TIRE_TRANSITIONS = { { 0, 2, 7, 8 }, { 1, 2, 6, 5 }, { 5, 8, 3, 4 }, { 6, 7, 3, 4 } }
assertEq(Rse.tireTrackAnim("down", "down"), 0, "a saved 0 is a real track")
Rse.TIRE_TRANSITIONS = {}
assertEq(Rse.tireTrackAnim("down", "down"), 1, "a missing row uses track 1")
Rse.TIRE_TRANSITIONS = {
  { 1, 2, 7, 8 }, { 1, 2, 6, 5 }, { 5, 8, 3, 4 }, { 6, 7, 3, 4 },
}
assertEq(Fx.reflDrop(), 14, "the reflection starts 14 pixels down")
assertEq(Fx.reflTop(20), 34, "the mirror line follows the saved drop")
Fx.REFL_DROP = 0
assertEq(Fx.reflTop(20), 20, "a drop of 0 starts on the sprite")
Fx.REFL_DROP = 14
assertEq(Fx.reflCull(), 64, "reflections reach 64 pixels past the camera")
Fx.REFL_CULL = 0
assertEq(Fx.reflCull(), 0, "a reach of 0 stays on the camera")
Fx.REFL_CULL = 64
assertEq(Fx.reflSpan(16, 16), 1, "a one-tile sprite searches one column")
Fx.REFL_PAD = 16
assertEq(Fx.reflSpan(16, 16), 2, "a wider pad searches the next column")
Fx.REFL_PAD = 0
assertEq(Fx.reflSpan(16, 16), 1, "a pad of 0 uses the sprite size")
Fx.REFL_PAD = 8
assertEq(Fx.reflBridge(1), 12, "the first bridge lifts the reflection by 12")
assertEq(Fx.reflBridge(2), 28, "the second bridge lifts it by 28")
assertEq(Fx.reflBridge(3), 44, "the third bridge lifts it by 44")
assertEq(Fx.reflBridge(0), 0, "ground uses no bridge lift")
Fx.REFL_BRIDGE = { 0, 28, 44 }
assertEq(Fx.reflBridge(1), 0, "a bridge lift of 0 stays with the other reflections")
Fx.REFL_BRIDGE = { 12, 28, 44 }
assertEq(Fx.reflTop(20, 12, 4), 42, "the bridge lift and the hop both move the mirror")
Fx.FEET_PICS = { 0, 1, 0, 1, 0, 1, 0, 1 }
Fx.FEET_HOLD = { 4, 4, 6, 6, 8, 8, 6, 6 }
Fx.RIPPLE_PICS = { 5 }
Fx.RIPPLE_HOLD = { 9 }
ripple = { kind = "ripple", timer = 0, frame = -1 }
Fx._anims = { ripple }
Fx.step()
assertEq(ripple.frame, 5, "the ripple uses the saved picture")
Fx.RIPPLE_PICS = { 0, 1, 2, 3, 0, 1, 2, 4 }
Fx.RIPPLE_HOLD = { 12, 9, 9, 9, 9, 9, 11, 11 }
Fx._ground = savedGround
local savedClock = Fx._surfClock
Fx._surfClock = 47
Fx.step()
assertEq(math.floor(Fx._surfClock / Fx.surfHold()) % 2, 1, "the surf blob flips after 48 ticks")
Fx.SURF_HOLD = 1
Fx._surfClock = 0
Fx.step()
assertEq(math.floor(Fx._surfClock / Fx.surfHold()) % 2, 1, "a one-tick surf hold flips on the next tick")
Fx.SURF_HOLD = 48
Fx._surfClock = savedClock
Fx.BLOB_X = 0
Fx.BLOB_Y = 0
Fx.BLOB_BOB = 0
assertEq(Fx.blobX(), 0, "a blob across of 0 sits on the player")
assertEq(Fx.blobY(), 0, "a blob down of 0 sits on the player")
assertEq(Fx.surfBob(1, false, false), 0, "a bob of 0 stays flat")
Fx.BLOB_BOB = -3
assertEq(Fx.surfBob(1, false, false), -3, "the second picture uses the saved bob")
assertEq(Fx.surfBob(0, false, false), 0, "the first picture stays flat")
assertEq(Fx.surfBob(1, true, false), 0, "moving does not bob")
Fx.BLOB_X = -8
Fx.BLOB_Y = -8
Fx.BLOB_BOB = -1
local tracks = { kind = "tracks", timer = 41, visible = true }
Fx._anims = { tracks }
Fx.step()
assertEq(tracks.visible, false, "footprints start blinking after 41 ticks")
Fx.TRACK_BLINK = 255
tracks.visible = true
tracks.timer = 41
Fx.step()
assertEq(tracks.visible, true, "a late blink does not flicker yet")
Fx.TRACK_END = 0
tracks.timer = 0
Fx.step()
assertEq(#Fx._anims, 0, "a track length of 0 ends on the next tick")
Fx.TRACK_BLINK = 41
Fx.TRACK_END = 57
local viewKey = "src.core.game3.field_view"
local savedView = package.loaded[viewKey]
package.loaded[viewKey] = { setCameraPanning = function() end }
local shake = { kind = "camera_shake", amp = 4, ticks = 3, timer = 0 }
Fx._anims = { shake }
Fx.step()
assertEq(shake.amp, -2, "the landing shake halves every 4 ticks")
Fx.SHAKE_EVERY = 1
shake.amp = 4
shake.ticks = 0
Fx._anims = { shake }
Fx.step()
assertEq(shake.amp, -2, "a shake of every tick halves on the next tick")
Fx.SHAKE_FADE = 1
shake.amp = 4
shake.ticks = 0
Fx._anims = { shake }
Fx.step()
assertEq(shake.amp, -4, "a fade of 1 keeps the shake size")
Fx.SHAKE_FADE = 4
shake.amp = 4
shake.ticks = 0
Fx._anims = { shake }
Fx.step()
assertEq(shake.amp, -1, "a fade of 4 drops the shake by four")
Fx.SHAKE_FADE = 2
Fx.SHAKE_AMP = 0
local started = Fx.startLandingShake()
assertEq(started.amp, 0, "a shake size of 0 starts still")
Fx.SHAKE_EVERY = 4
Fx.SHAKE_AMP = 4
package.loaded[viewKey] = savedView
local frag = { x = 0, y = 0, ox = 0, oy = 0, dx = 1, dy = 0 }
local rock = { kind = "deoxys_rock_destroy", state = "shatter", timer = 20, amp = 1, frags = { frag } }
Fx._anims = { rock }
Fx.step()
assertEq(frag.off, nil, "a shard is still on screen after one pixel")
assertEq(rock.amp, 0, "the rock shake fades one step every 21 ticks")
Fx.FRAG_X = 0
frag = { x = 0, y = 0, ox = 0, oy = 0, dx = 1, dy = 0 }
rock = { kind = "deoxys_rock_destroy", state = "shatter", timer = 0, amp = 4, frags = { frag } }
Fx._anims = { rock }
Fx.step()
assertEq(frag.off, true, "a shard distance of 0 drops the shard once it moves")
Fx.ROCK_WAIT = 0
rock = { kind = "deoxys_rock_destroy", state = "shake", timer = 0, frags = {} }
Fx._anims = { rock }
Fx.step()
assertEq(rock.state, "shatter", "a rock wait of 0 breaks the rock on the next tick")
Fx.FRAG_X = 260
Fx.ROCK_WAIT = 120
local objKey = "src.core.game3.objects"
local savedObj = package.loaded[objKey]
package.loaded[objKey] = { find = function() return { px = 0, py = 0 } end }
Fx.SHARD_X = 0
Fx.SHARD_Y = 3
Fx.ROCK_FOOT_X = 0
Fx.ROCK_FOOT_Y = 0
local made = Fx.startDestroyDeoxysRock(1)
assertEq(made.frags[1].dx, 0, "a shard step of 0 stays put")
assertEq(made.frags[1].dy, -3, "the first shard uses the saved lift")
assertEq(made.frags[4].dy, 3, "the lower shard lifts the other way")
assertEq(made.frags[1].x, 0, "a start across of 0 begins at the rock")
assertEq(made.frags[1].y, 0, "a start down of 0 begins at the rock")
Fx.ROCK_TOP = 0
local ox, oy = Fx.rockOrigin(10, 40, { width = 16, height = 32 })
assertEq(ox, 10, "a matching sprite stays on the rock's across spot")
assertEq(oy, 24, "a start above of 0 sits on the sprite top")
Fx.ROCK_FOOT_X = -8
Fx.ROCK_FOOT_Y = -20
Fx.ROCK_TOP = 4
Fx._anims = {}
package.loaded[objKey] = savedObj
Fx.SHARD_X = 16
Fx.SHARD_Y = 12
Fx.ROCK_HOLD = 1
assertEq(Fx.rockHoldSign(1), -1, "a rock hold of 1 flips on the next tick")
Fx.ROCK_HOLD = 2
assertEq(Fx.rockHoldSign(1), 1, "a rock hold of 2 keeps the first direction")
Fx.ROCK_FLIP = 2
assertEq(Fx.rockFlipSign(1), 1, "a rock flip of 2 holds the shatter direction")
Fx.ROCK_FLIP = 1
assertEq(Fx.rockFlipSign(1), -1, "a rock flip of 1 changes on the next tick")
local playerKey = "src.core.game3.player"
local savedPlayer = package.loaded[playerKey]
local posed = nil
package.loaded[playerKey] = {
  facing = "left",
  setVisible = function() end,
  startFieldMove = function(n) posed = n end,
}
Fx.FLY_SWOOP = 0
local fly = { kind = "fly_out", state = "wait_leave", timer = 0, tTimer = 99, bird = { done = true } }
Fx._anims = { fly }
Fx.step()
assertEq(fly.tTimer, 0, "a fly pause of 0 is stored on the dive")
Fx.step()
assertEq(fly.state, "jump_on", "a fly pause of 0 dives on the next tick")
Fx.FLY_MOUNT = 1
fly = { kind = "fly_out", state = "jump_on", timer = 0, tTimer = 0, bird = {} }
Fx._anims = { fly }
Fx.step()
assertEq(fly.state, "fly_off", "a one-tick mount climbs on immediately")
Fx.FLY_OFF = 1
fly = { kind = "fly_out", state = "fly_off", timer = 0, tTimer = 0, gender = 0, bird = { x = 0, y = 0, x2 = 0, y2 = 0, d2 = 0 } }
Fx._anims = { fly }
Fx.step()
assertEq(fly.state, "wait_off", "a one-tick fly-away leaves immediately")
Fx.FLY_IN = 0
fly = { kind = "fly_in", state = "swoop", timer = 0, tTimer = 99, gender = 0 }
Fx._anims = { fly }
Fx.step()
assertEq(fly.tTimer, 0, "a fly ride of 0 starts the landing")
Fx.FLY_POSE = 0
fly = { kind = "fly_in", state = "pose", timer = 0, bird = { done = true } }
Fx._anims = { fly }
Fx.step()
assertEq(posed, 0, "a fly pose of 0 is the pose length")
Fx.FLY_END = 0
fly = { kind = "fly_in", state = "wait_return", timer = 0, bird = { done = true } }
Fx._anims = { fly }
Fx.step()
assertEq(fly.state, "end", "a fly finish of 0 is the last wait")
Fx.step()
assertEq(#Fx._anims, 0, "a fly finish of 0 ends on the next tick")
Fx.FLY_SWOOP = 16
Fx.FLY_MOUNT = 8
Fx.FLY_OFF = 10
Fx.FLY_IN = 33
Fx.FLY_POSE = 24
Fx.FLY_END = 16
local P = package.loaded[playerKey]
Fx.TP_TURNS = 8
P.facing = "down"
local warp = { kind = "teleport_out", state = 2, timer = 0, orig = "left", d1 = 0, d2 = 0, d3 = 0, d4 = 0 }
Fx._anims = { warp }
Fx.step()
assertEq(warp.state, 2, "eight turns have not finished")
assertEq(P.facing, "left", "the first spin faces left")
Fx.TP_TURNS = 1
P.facing = "down"
warp = { kind = "teleport_out", state = 2, timer = 0, orig = "left", d1 = 0, d2 = 0, d3 = 0, d4 = 0 }
Fx._anims = { warp }
Fx.step()
assertEq(warp.state, 3, "one turn starts the rise")
assertEq(warp.d2, 8, "the rise waits 8 before it speeds up")
Fx.TP_VANISH = 1
warp = { kind = "teleport_out", state = 3, timer = 0, d1 = 5, d2 = 5, d3 = 1, d4 = 0 }
Fx._anims = { warp }
Fx.step()
assertEq(#Fx._anims, 0, "a warp height of 1 leaves on the next rise")
Fx.TP_VANISH = 255
Fx.TP_SPEED_EVERY = 1
Fx.TP_SPEED_CAP = 2
warp = { kind = "teleport_out", state = 3, timer = 0, d1 = 5, d2 = 1, d3 = 1, d4 = 0 }
Fx._anims = { warp }
Fx.step()
assertEq(warp.d3, 2, "the rise doubles until the cap")
warp.d2 = 1
Fx.step()
assertEq(warp.d3, 2, "the rise stops doubling at the cap")
Fx.TP_DROP = 0
local arrived = Fx.startTeleportIn()
assertEq(arrived.d1, 0, "a warp drop of 0 does not fall")
Fx.TP_SLOW = 20
warp = { kind = "teleport_in", state = 2, timer = 0, y2 = -10, d1 = 2, d2 = 5 }
Fx._anims = { warp }
Fx.step()
assertEq(warp.d1, 1, "the drop slows inside the slow band")
Fx.TP_LAND_TURNS = 0
P.facing = "right"
warp = { kind = "teleport_in", state = 3, timer = 0, d1 = 1, d2 = 0 }
Fx._anims = { warp }
Fx.step()
assertEq(#Fx._anims, 0, "a land count of 0 finishes once you face down")
Fx.TP_TURNS = 8
Fx.TP_VANISH = 168
Fx.TP_SPEED_EVERY = 4
Fx.TP_SPEED_CAP = 8
Fx.TP_DROP = 8
Fx.TP_SLOW = 48
Fx.TP_LAND_TURNS = 4
Fx.BIRD_SWOOP_X = 0
Fx.BIRD_SWOOP_END = 0
local bird = { cb = "swoop", d2 = 0, x = 0, y = 0, x2 = 9, y2 = 9, attached = false }
local glide = { kind = "fly_out", state = "swoop", timer = 0, tTimer = 5, bird = bird }
Fx._anims = { glide }
Fx.step()
assertEq(bird.x2, 0, "a swoop width of 0 stays centered")
assertEq(bird.done, true, "a swoop end of 0 finishes on the next step")
Fx.BIRD_RIDE_X = 0
Fx.BIRD_RIDE_STEP = 1
bird = { cb = "with_player", d2 = 0, x = 0, y = 0, x2 = 9, y2 = 0, attached = false }
glide = { kind = "fly_out", state = "wait_off", timer = 0, bird = bird }
Fx._anims = { glide }
Fx.step()
assertEq(bird.x2, 0, "a ride width of 0 stays centered")
assertEq(bird.d2, 1, "a ride step of 1 advances one")
assertEq(bird.done, nil, "the ride is still going before 128")
Fx.BIRD_SWOOP_X = 140
Fx.BIRD_SWOOP_END = 128
Fx.BIRD_RIDE_X = 180
Fx.BIRD_RIDE_STEP = 2
Fx.BALL_WIDE = 0
Fx.BALL_END = 0
local ball = { cb = "leave", done = false, init = false }
local pop = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 0, bird = ball }
Fx._anims = { pop }
Fx.step()
assertEq(ball.x2, 0, "a ball width of 0 stays centered")
assertEq(ball.done, true, "a ball end of 0 finishes once the arc has started")
Fx.BALL_END = 255
Fx.BALL_PUSH = 0
Fx.BALL_ANGLE = 0
ball = { cb = "leave", done = false, init = false }
pop = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 0, bird = ball }
Fx._anims = { pop }
Fx.step()
assertEq(ball.d1, 1, "a ball angle of 0 starts the arc at the next step")
assertEq(ball.d2, 256, "a push of 0 does not speed up")
Fx.BALL_WIDE = 120
Fx.BALL_PUSH = 96
Fx.BALL_END = 129
Fx.BALL_ANGLE = 64
Fx.RETURN_WIDE = 0
Fx.RETURN_HIGH = 0
Fx.RETURN_END = 0
local back = { cb = "return", done = false, init = false, d3 = 0 }
local home = { kind = "fly_in", state = "return", timer = 0, poseWait = 5, gender = 0, bird = back }
Fx._anims = { home }
Fx.step()
assertEq(back.x2, 0, "a return width of 0 stays centered")
assertEq(back.y2, 0, "a return height of 0 stays level")
assertEq(back.done, true, "a return end of 0 finishes once the arc has started")
Fx.RETURN_END = 255
Fx.RETURN_GROW = 0
back = { cb = "return", done = false, init = false, d3 = 0 }
home = { kind = "fly_in", state = "return", timer = 0, poseWait = 5, gender = 0, bird = back }
Fx._anims = { home }
Fx.step()
assertEq(back.d4, 128, "a brake grow of 0 does not tighten")
Fx.RETURN_WIDE = 32
Fx.RETURN_HIGH = 120
Fx.RETURN_END = 60
Fx.RETURN_GROW = 24
Fx.LEAVE_SCALE = 0
Fx.LEAVE_TILT = 0
Fx.LEAVE_GROW = 0
local spin = { done = false, aff = { kind = "leave", k = 0, scale = 9, rot = 9 } }
local pose = { kind = "fly_out", state = "wait_leave", timer = 0, bird = spin }
Fx._anims = { pose }
Fx.step()
assertEq(spin.aff.scale, 0, "a pop size of 0 starts at nothing")
assertEq(spin.aff.rot, 0, "a pop tilt of 0 stays upright")
Fx.step()
assertEq(spin.aff.scale, 0, "a pop grow of 0 does not enlarge")
Fx.AWAY_GROW = 0
spin.aff = { kind = "out", k = 0, scale = 10 }
Fx._anims = { pose }
Fx.step()
assertEq(spin.aff.scale, 10, "an away grow of 0 does not enlarge")
Fx.ARRIVE_POP = 0
spin.aff = { kind = "in", k = 0, scale = 10 }
Fx.step()
assertEq(spin.aff.scale, 10, "an arrive pop of 0 does not jump")
Fx.SHRINK_SCALE = 0
Fx.SHRINK_TILT = 0
spin.aff = { kind = "return", k = 0, scale = 9, rot = 9 }
Fx.step()
assertEq(spin.aff.scale, 0, "a shrink size of 0 starts at nothing")
assertEq(spin.aff.rot, 0, "a shrink tilt of 0 stays upright")
Fx.LEAVE_SCALE = 8
Fx.LEAVE_TILT = -30
Fx.LEAVE_GROW = 28
Fx.AWAY_GROW = 24
Fx.ARRIVE_POP = 512
Fx.SHRINK_SCALE = 256
Fx.SHRINK_TILT = 64
Fx.FLASH_FRAMES = 1
local flash = Fx.startFlash()
assertEq(flash.maxDur, 1, "a flash length of 1 is one tick")
Fx._anims = { flash }
Fx.step()
assertEq(#Fx._anims, 0, "a one-tick flash ends on the next tick")
Fx.VEIL_FRAMES = 1
local veil = Fx.startBgFlash()
assertEq(veil.maxDur, 1, "a veil length of 1 is one tick")
assertEq(Fx.startBgFlash(4).maxDur, 4, "a caller can still pass a veil length")
Fx.FLASH_FRAMES = 30
Fx.VEIL_FRAMES = 8
local rider = package.loaded[playerKey]
Fx.MOUNT_ARC = { -3 }
rider.spriteYOffset = 9
local hop = { kind = "fly_out", state = "wait_off", timer = 0, jump = 0, bird = { done = false } }
Fx._anims = { hop }
Fx.step()
assertEq(rider.spriteYOffset, -3, "the hop onto the bird uses the first pixel")
assertEq(hop.jump, nil, "a one-pixel hop onto the bird ends")
Fx.DISMOUNT_ARC = { 5 }
hop = { kind = "fly_in", state = "jump_off", timer = 0, tTimer = 0, baseY = 10 }
Fx._anims = { hop }
Fx.step()
assertEq(rider.spriteYOffset, 15, "the hop off the bird adds the first pixel")
assertEq(hop.state, "pose", "a one-pixel hop off the bird finishes")
Fx.MOUNT_ARC = { -4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0 }
Fx.DISMOUNT_ARC = { -2, -4, -5, -6, -7, -8, -8, -8, -7, -7, -6, -5, -3, -2, 0, 2, 4, 8 }
Fx.POP_BOY = 10
Fx.POP_GIRL = 20
Fx.POP_Y = 0
local function freshBird(cb)
  return { cb = cb, init = false, done = false, x = 1, y = 1, x2 = 0, y2 = 0, d1 = 0, d2 = 0, d3 = 0 }
end
local pop = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 0, bird = freshBird("leave") }
Fx._anims = { pop }
Fx.step()
assertEq(pop.bird.x, 10, "a boy pops out at the boy spot")
assertEq(pop.bird.y, 0, "a pop height of 0 stays on the line")
pop = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 1, bird = freshBird("leave") }
Fx._anims = { pop }
Fx.step()
assertEq(pop.bird.x, 20, "a girl pops out at the girl spot")
Fx.BACK_BOY = 7
Fx.BACK_Y = -1
pop = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 0, bird = freshBird("return") }
Fx._anims = { pop }
Fx.step()
assertEq(pop.bird.x, 7, "a boy returns at the boy spot")
assertEq(pop.bird.y, -1, "the return height is the saved pixel")
Fx.DIVE_X = 3
Fx.DIVE_Y = -2
pop = { kind = "fly_out", state = "swoop", timer = 0, tTimer = 0, gender = 0, bird = freshBird("swoop") }
Fx._anims = { pop }
Fx.step()
assertEq(pop.bird.x, 3, "the dive starts at the saved across spot")
assertEq(pop.bird.y, -2, "the dive starts at the saved height")
Fx.POP_BOY = 128
Fx.POP_GIRL = 118
Fx.POP_Y = -48
Fx.BACK_BOY = 112
Fx.BACK_GIRL = 100
Fx.BACK_Y = -32
Fx.DIVE_X = 120
Fx.DIVE_Y = 0
local rider = package.loaded[playerKey]
Fx.RIDE_X = 0
Fx.RIDE_Y = 0
Fx.SEAT = 0
Fx.BIRD_SWOOP_X = 0
Fx.BIRD_SWOOP_Y = 0
local seat = { kind = "fly_out", state = "wait_leave", timer = 0, gender = 0, bird = {
  cb = "swoop", attached = true, x = 10, y = 6, x2 = 0, y2 = 0, d2 = 0, done = false,
} }
Fx._anims = { seat }
Fx.step()
assertEq(rider.spriteXOffset, 10, "a ride across of 0 keeps the bird's across spot")
assertEq(rider.spriteYOffset, 6, "a seat of 0 sits on the bird point")
Fx.TP_START = 0
local drop = Fx.startTeleportIn()
assertEq(drop.y2, 0, "a drop start of 0 begins on the ground")
assertEq(rider.spriteYOffset, 0, "the player starts at the drop height")
Fx.RIDE_X = 120
Fx.RIDE_Y = 72
Fx.SEAT = 8
Fx.BIRD_SWOOP_X = 140
Fx.BIRD_SWOOP_Y = 72
Fx.BOY_AWAY = 0
Fx.FLY_OFF = 1
Fx.BIRD_RIDE_X = 0
Fx.BIRD_RIDE_Y = 0
local away = { kind = "fly_out", state = "fly_off", timer = 0, tTimer = 0, gender = 0, bird = {
  anim = 9, x = 0, y = 0, x2 = 0, y2 = 0, d2 = 0, done = false,
} }
Fx._anims = { away }
Fx.step()
assertEq(away.bird.anim, 0, "a boy leaving uses the saved picture")
Fx.GIRL_HOME = 0
assertEq(Fx.birdPicture(1, "home"), 0, "a girl arriving can use picture 0")
Fx.BIRD_REST = 4
assertEq(Fx.birdPicture(0, "rest"), 4, "the resting bird uses the saved picture")
Fx.BOY_AWAY = 1
Fx.GIRL_AWAY = 3
Fx.BOY_HOME = 2
Fx.GIRL_HOME = 4
Fx.BIRD_REST = 0
Fx.FLY_OFF = 10
Fx.BIRD_RIDE_X = 180
Fx.BIRD_RIDE_Y = 72
Fx.TP_START = 88
package.loaded[playerKey] = savedPlayer
Fx._anims = savedAnims
local Sight = require("src.core.game3.trainer_sight")
assertEq(Sight.approachSteps(4), 3, "a Gen 3 trainer stops one tile short")
Sight.APPROACH_GAP = 0
assertEq(Sight.approachSteps(4), 4, "a Gen 3 gap of 0 walks the whole way")
Sight.APPROACH_GAP = 1
Movement.TREE_SHAKE_FRAMES = 0
Npc.scriptTreeShake(actor)
assertEq(actor.treeShake.frames, 0, "a tree shake of 0 does not wait")
Movement.TREE_SHAKE_FRAMES = 24
assertEq(Movement.forcedMovementBytes("down")[2], 16, "a forced step waits 16")
assertEq(Movement.digOutBytes()[2], 32, "digging out spins for 32")
assertEq(Movement.digReturnBytes()[3], 32, "digging back spins for 32")
Movement.STEP_DIG_FRAMES = 0
Movement.DIG_SPIN_FRAMES = 0
assertEq(Movement.forcedMovementBytes("up")[2], 0, "a dig step of 0 does not wait")
assertEq(Movement.forcedMovementBytes("up")[5], 0, "the second forced step matches")
assertEq(Movement.digOutBytes()[2], 0, "digging out can skip the spin")
assertEq(Movement.digReturnBytes()[3], 0, "digging back can skip the spin")
Movement.STEP_DIG_FRAMES = 16
Movement.DIG_SPIN_FRAMES = 32
assertEq(Movement.decodeByte(0x3e).frames, 16, "the shortest sleep is 16")
assertEq(Movement.decodeByte(0x46).frames, 144, "the longest sleep is 144")
Movement.SLEEP_UNIT = 0
assertEq(Movement.decodeByte(0x3e).frames, 0, "a unit of 0 skips the shortest sleep")
assertEq(Movement.decodeByte(0x46).frames, 0, "a unit of 0 skips the longest sleep")
Movement.SLEEP_UNIT = 1
assertEq(Movement.decodeByte(0x3e).frames, 1, "a unit of 1 is one frame")
Movement.SLEEP_UNIT = 16
assertEq(Npc.stepFrameCount(), 16, "an NPC step is 16 frames")
assertEq(Npc.spinFrameCount(), 4, "a teleport turns every four frames")
local spinner = setmetatable({}, { __index = Npc })
Npc.scriptTeleport(spinner, "from")
for _ = 1, 3 do Npc.updateTeleport(spinner) end
assertEq(spinner.facing, "down", "the first three frames still face down")
Npc.updateTeleport(spinner)
assertEq(spinner.facing, "left", "the fourth frame turns left")
Npc.SPIN_FRAMES = 1
spinner.teleport = nil
Npc.scriptTeleport(spinner, "from")
Npc.updateTeleport(spinner)
assertEq(spinner.facing, "left", "one frame turns on the first tick")
Npc.SPIN_FRAMES = 0
assertEq(Npc.spinFrameCount(), 1, "zero frames still turns once a frame")
Npc.updateTeleport(spinner)
assertEq(spinner.facing, "up", "the next frame keeps turning")
Npc.SPIN_FRAMES = 4
assertEq(Npc.bouncePeriod(), 32, "a bounce cycle is 32 frames")
assertEq(Npc.bounceHalf(), 16, "the second bounce pose starts at 16")
local bouncer = setmetatable({ bouncing = true, bounceStep = 0, frozen = false, kind = "stand" }, { __index = Npc })
Npc.update(bouncer)
assertEq(bouncer.bounceStep, 1, "the bounce clock advances")
assertEq(Npc.bounceFrame(bouncer), 0, "the first half keeps the first pose")
bouncer.bounceStep = 16
assertEq(Npc.bounceFrame(bouncer), 1, "frame 16 switches the pose")
Npc.BOUNCE_PERIOD = 1
bouncer.bounceStep = 0
Npc.update(bouncer)
assertEq(bouncer.bounceStep, 0, "a one-frame cycle wraps immediately")
Npc.BOUNCE_PERIOD = 0
assertEq(Npc.bouncePeriod(), 1, "zero bounce frames stays one frame")
Npc.BOUNCE_HALF = 0
bouncer.bounceStep = 0
assertEq(Npc.bounceFrame(bouncer), 1, "a pose line of zero uses the second pose")
Npc.BOUNCE_PERIOD = 32
Npc.BOUNCE_HALF = 16
assertEq(Npc.spinTurnFrames(), 16, "a fixed spinner waits 16 frames")
local turner = setmetatable({
  kind = "turn", timer = 1, facing = "down", frozen = false,
  roamDirs = { down = "left" },
}, { __index = Npc })
Npc.SPIN_TURN_FRAMES = 0
Npc.update(turner)
assertEq(turner.facing, "left", "the spinner takes the next facing")
assertEq(turner.timer, 0, "a turn of zero does not wait")
Npc.SPIN_TURN_FRAMES = 16
local wLo, wHi = Npc.wanderWait()
assertEq(wLo, 30, "a wander waits at least 30 frames")
assertEq(wHi, 180, "a wander waits at most 180 frames")
Npc.WANDER_LO = 40
Npc.WANDER_HI = 5
wLo, wHi = Npc.wanderWait()
assertEq(wHi, 40, "the high end cannot sit below the low end")
Npc.WANDER_LO = 5
Npc.WANDER_HI = 5
Npc.TURN_ODDS = 100
local wanderer = setmetatable({
  kind = "walk", timer = 1, facing = "up", frozen = false,
  roamDirs = { "left" }, cellX = 0, cellY = 0,
}, { __index = Npc })
Npc.update(wanderer)
assertEq(wanderer.timer, 5, "the next pause uses the wander range")
assertEq(wanderer.facing, "left", "the wanderer picks a facing")
assertEq(wanderer.moving, nil, "a full turn chance does not step")
Npc.WANDER_LO = 30
Npc.WANDER_HI = 180
Npc.TURN_ODDS = 50
local sLo, sHi = Npc.slowSpinWait()
assertEq(sLo, 60, "a slow spin waits at least 60 frames")
assertEq(sHi, 180, "a slow spin waits at most 180 frames")
local fLo, fHi = Npc.fastSpinWait()
assertEq(fLo, 20, "a fast spin waits at least 20 frames")
assertEq(fHi, 60, "a fast spin waits at most 60 frames")
Npc.SLOW_SPIN_LO = 0
Npc.SLOW_SPIN_HI = 0
local slowSpin = setmetatable({
  kind = "spin", timer = 1, facing = "down", frozen = false,
  roamDirs = { "up" },
}, { __index = Npc })
Npc.update(slowSpin)
assertEq(slowSpin.timer, 0, "a missing range uses the slow spin, even at zero")
Npc.FAST_SPIN_LO = 3
Npc.FAST_SPIN_HI = 3
local fastSpin = setmetatable({
  kind = "spin", timer = 1, facing = "down", frozen = false,
  spinLo = 3, spinHi = 3, roamDirs = { "left" },
}, { __index = Npc })
Npc.update(fastSpin)
assertEq(fastSpin.timer, 3, "a spawned fast spin keeps its own range")
Npc.SLOW_SPIN_LO = 60
Npc.SLOW_SPIN_HI = 180
Npc.FAST_SPIN_LO = 20
Npc.FAST_SPIN_HI = 60
local Player = require("src.world.gen2.Player")
assertEq(Player.stepFrameCount(), 16, "a walk is 16 frames")
assertEq(Player.turnFrameCount(), 4, "a turn waits four frames")
local walker = setmetatable({
  moving = false, cellX = 0, cellY = 0, facing = "down", fixedFacing = true,
}, { __index = Player })
Player.STEP_FRAMES = 1
Player.scriptStep(walker, "right")
assertEq(walker.stepFrames, 1, "a scripted step uses the walk length")
assertEq(walker.targetX, 1, "the step aims at the next tile")
walker.moving = false
Player.scriptJump(walker, "right")
assertEq(walker.stepFrames, 2, "a jump lasts twice the walk")
Player.STEP_FRAMES = 0
assertEq(Player.stepFrameCount(), 1, "zero walk frames stays one frame")
local turner = setmetatable({
  facing = "down", moving = false, turnArmed = true, cellX = 0, cellY = 0,
}, { __index = Player })
Player.TURN_FRAMES = 0
assertEq(Player.tryMove(turner, "up"), "turned", "a new facing still counts as a turn")
assertEq(turner.turnTimer, 0, "zero turn frames does not pause")
Player.STEP_FRAMES = 16
Player.TURN_FRAMES = 4
local Gen1Player = require("src.world.Player")
assertEq(Gen1Player.touchTurnFrames(), 8, "a touch turn waits eight frames")
local tap = setmetatable({ facing = "down", turnFrames = 0 }, { __index = Gen1Player })
assertEq(Gen1Player.turnWindow(tap), 0, "zero turn frames does not wait")
Gen1Player.TOUCH_TURN_FRAMES = 0
assertEq(Gen1Player.touchTurnFrames(), 0, "zero touch frames does not extend the turn")
Gen1Player.TOUCH_TURN_FRAMES = 8
local G3 = require("src.core.game3.player")
assertEq(G3.walkFrameCount(), 16, "a gen 3 walk is 16 frames")
assertEq(G3.runFrameCount(), 8, "a gen 3 run is 8 frames")
assertEq(G3.turnFrameCount(), 4, "a gen 3 turn waits four frames")
G3.moving = false
G3.cellX, G3.cellY = 0, 0
G3.WALK_FRAMES = 1
G3.scriptStep("right", false)
assertEq(G3.stepFrames, 1, "a scripted walk uses the walk length")
assertEq(G3.targetX, 1, "the walk aims at the next tile")
G3.moving = false
G3.RUN_FRAMES = 2
G3.scriptStep("right", true)
assertEq(G3.stepFrames, 2, "a scripted run uses the run length")
G3.WALK_FRAMES = 0
assertEq(G3.walkFrameCount(), 1, "zero walk frames stays one frame")
G3.moving = false
G3.facing = "down"
G3.turnArmed = true
G3.TURN_FRAMES = 0
assertEq(G3.tryMove("up"), "turned", "a new facing still counts as a turn")
assertEq(G3.turnTimer, 0, "zero turn frames does not pause")
G3.moving = false
G3.WALK_FRAMES = 16
G3.RUN_FRAMES = 8
G3.TURN_FRAMES = 4
G3.moving = false
G3.biking = true
G3.surfHopping = false
G3.dismounting = false
G3.cellX, G3.cellY = 0, 0
G3.BIKE_FRAMES = 3
G3.forceStep("right")
assertEq(G3.stepFrames, 3, "a bike step uses the bike length")
G3.moving = false
G3.biking = false
G3.JUMP_FRAMES = 5
G3.scriptJump("right", 1)
assertEq(G3.stepFrames, 5, "a ledge hop uses the ledge length")
G3.moving = false
G3.RUN_SLOW_FRAMES = 7
G3.scriptStep("right", true, true)
assertEq(G3.stepFrames, 7, "a slow run uses the slow length")
G3.FASTER_FRAMES = 0
assertEq(G3.fasterFrameCount(), 1, "zero downhill frames stays one frame")
G3.moving = false
G3.BIKE_FRAMES = 4
G3.JUMP_FRAMES = 32
G3.RUN_SLOW_FRAMES = 11
G3.FASTER_FRAMES = 4
local Gfx = require("src.core.game3.scripting.gfx_ids")
assertEq(Gfx.DELAYS.MEDIUM[1], 32, "the first medium pause is 32 frames")
assertEq(Gfx.DELAYS.MEDIUM[4], 128, "the last medium pause is 128 frames")
assertEq(Gfx.DELAYS.LONG[4], 192, "the last long pause is 192 frames")
assertEq(Gfx.DELAYS.SHORT[2], 48, "the second short pause is 48 frames")
local Objects = require("src.core.game3.objects")
assertEq(Objects.rotateFrames(), 48, "a rotating npc waits 48 frames")
Objects.ROTATE_FRAMES = 0
assertEq(Objects.rotateFrames(), 0, "a rotate pause can be instant")
Objects.ROTATE_FRAMES = 48
Gfx.DELAYS.MEDIUM[1] = 0
assertEq(Gfx.DELAYS.MEDIUM[1], 0, "a medium pause can be zero")
Gfx.DELAYS.MEDIUM[1] = 32
assertEq(Objects.walkFrameCount(), 16, "an npc walk is 16 frames")
assertEq(Objects.runFrameCount(), 8, "an npc run is 8 frames")
assertEq(Objects.slowRunFrameCount(), 11, "an npc slow run is 11 frames")
Objects.WALK_FRAMES = 1
local npc = { moving = false, cellX = 0, cellY = 0 }
Objects.scriptStep(npc, "right")
assertEq(npc.stepFrames, 1, "a scripted npc walk uses the walk length")
assertEq(npc.targetX, 1, "the npc steps onto the next tile")
Objects.WALK_FRAMES = 0
assertEq(Objects.walkFrameCount(), 1, "zero npc walk frames stays one frame")
npc.moving = false
Objects.RUN_FRAMES = 2
Objects.scriptStep(npc, "right", true)
assertEq(npc.stepFrames, 2, "a scripted npc run uses the run length")
npc.moving = false
Objects.RUN_SLOW_FRAMES = 3
Objects.scriptStep(npc, "right", true, true)
assertEq(npc.stepFrames, 3, "a slow npc run uses the slow length")
Objects.WALK_FRAMES = 16
Objects.RUN_FRAMES = 8
Objects.RUN_SLOW_FRAMES = 11
local floater = { raiseY = 0, levitate = { t = 0, d = -1 } }
Objects.tickRse(floater)
assertEq(floater.raiseY, -1, "a floater rises one pixel")
assertEq(floater.levitate.d, 1, "the first frame turns the float around")
Objects.LEV_PIXEL = 0
Objects.setLevitate(floater, true)
assertEq(floater.levitate.d, 0, "a float of 0 stays level")
Objects.LEV_PIXEL = 1
Objects.LEV_STEP = 4
Objects.LEV_TURN = 16
local savedX, savedY = Objects.FIG8_X, Objects.FIG8_Y
Objects.FIG8_X = { 3 }
Objects.FIG8_Y = { -2 }
local eight = { fig8 = { i = 0, part = 0, x2 = 0, y2 = 0 } }
Objects.tickRse(eight)
assertEq(eight.raiseX, 3, "a figure eight reads the across step")
assertEq(eight.raiseY, -2, "a figure eight reads the down step")
Objects.FIG8_X = {}
Objects.tickRse(eight)
assertEq(eight.fig8, nil, "an empty path ends the figure eight")
Objects.FIG8_X, Objects.FIG8_Y = savedX, savedY
assertEq(Objects.copyDirection("down", "down", "up"), "up", "a matching copy follows up")
local savedCopy = Objects.COPY_TO[1][1]
Objects.COPY_TO[1][1] = 4
assertEq(Objects.copyDirection("down", "down", "up"), "right", "the copy table picks the new facing")
Objects.COPY_TO[1][1] = savedCopy
local treesKey = "src.core.game3.rse.berry_trees"
local fxKey = "src.core.game3.field_effects_rse"
local oldTrees, oldFx = package.loaded[treesKey], package.loaded[fxKey]
package.loaded[treesKey] = { peek = function() return { stage = 1, berry = 1 } end }
package.loaded[fxKey] = { startBerryTreeSparkle = function() end }
local tree = { rseKind = "berry_tree", cellX = 0, cellY = 0, berryTree = { init = true, func = "sparkle", timer = 1, animNum = 0 } }
Objects.tickRse(tree)
assertEq(tree.berryTree.visible, false, "the cart blink is dark on frame 2")
Objects.BERRY_BLINK = 1
tree.berryTree.timer = 1
Objects.tickRse(tree)
assertEq(tree.berryTree.visible, true, "a one-frame blink stays lit")
Objects.BERRY_BLINK = 2
Objects.BERRY_SPARKLE = 64
tree.berryTree.func = "sparkle_end"
tree.berryTree.timer = 0
Objects.tickRse(tree)
assertEq(tree.berryTree.func, "sparkle_end", "the cart sparkle is still running")
Objects.BERRY_SPARKLE = 0
tree.berryTree.func = "sparkle_end"
tree.berryTree.timer = 0
Objects.tickRse(tree)
assertEq(tree.berryTree.func, "normal", "a sparkle of 0 ends on the first frame")
Objects.BERRY_SPARKLE = 64
package.loaded[treesKey], package.loaded[fxKey] = oldTrees, oldFx
assertEq(Objects.jumpFrameCount(false), 16, "an npc hop is 16 frames")
assertEq(Objects.jumpFrameCount(true), 32, "a far npc hop is 32 frames")
Objects.JUMP_FRAMES = 5
Objects.JUMP_FAR_FRAMES = 9
local hopper = { cellX = 0, cellY = 0 }
Objects.startJumpArc(hopper, 1)
assertEq(hopper.stepFrames, 5, "a one-tile hop uses the hop length")
Objects.startJumpArc(hopper, 2)
assertEq(hopper.stepFrames, 9, "a two-tile hop uses the far length")
Objects.JUMP_FRAMES = 0
assertEq(Objects.jumpFrameCount(false), 1, "zero hop frames stays one frame")
Objects.JUMP_FRAMES = 16
Objects.JUMP_FAR_FRAMES = 32
local savedArc = Objects.JUMP_Y.normal
Objects.JUMP_Y.normal = { -9, 0 }
local arcHop = {}
Objects.startJumpArc(arcHop, 1)
assertEq(arcHop.jumpArc.table[1], -9, "a hop reads the normal arc")
Objects.JUMP_Y.normal = savedArc
G3.jumping = true
G3.progress = 1
G3.jumpType = nil
G3.surfHopping = false
G3.dismounting = false
assertEq(G3.jumpSpriteY(), -4, "a ledge hop starts four pixels up")
G3.JUMP_Y.high[1] = -7
assertEq(G3.jumpSpriteY(), -7, "the ledge hop reads the new height")
G3.JUMP_Y.high[1] = -4
G3.jumpType = "normal"
G3.stepFrames = 16
assertEq(G3.jumpSpriteY(), -2, "a typed hop uses the normal arc")
G3.jumpType = nil
G3.surfHopping = true
assertEq(G3.jumpSpriteY(), -2, "a surf hop starts two pixels up")
G3.SURF_HOP_Y[1] = 0
assertEq(G3.jumpSpriteY(), 0, "a surf hop can stay on the ground")
G3.SURF_HOP_Y[1] = -2
G3.surfHopping = false
G3.jumping = false
G3.moving = true
G3.running = true
G3.biking = false
G3.surfing = false
G3.animDisabled = false
G3.animClock = 6
assertEq(G3.runPose(), 1, "the run pose changes on frame 6")
G3.animClock = 1
assertEq(G3.runPose(), 0, "the run starts on the first pose")
G3.RUN_POSE = 0
assertEq(G3.runPose(), 1, "a pose of 0 is always the second frame")
G3.RUN_POSE = 5
G3.RUN_CYCLE = 1
G3.animClock = 6
assertEq(G3.runPose(), 0, "a one-frame cycle stays on the first pose")
G3.RUN_CYCLE = 8
G3.moving = false
G3.running = false
local Rse = require("src.core.game3.bike.rse")
assertEq(Rse.frameCount("NORMAL"), 16, "mach coast is 16 frames")
assertEq(Rse.machStepFrames(0), 16, "the first gear coasts")
assertEq(Rse.machStepFrames(1), 8, "the second gear is the middle speed")
assertEq(Rse.machStepFrames(2), 4, "the third gear is the top speed")
assertEq(Rse.frameCount("FAST_2"), 6, "an acro roll is 6 frames")
assertEq(Rse.jumpFrames("NORMAL"), 16, "an acro hop is 16 frames")
assertEq(Rse.jumpFrames("FAR"), 32, "an acro ledge is 32 frames")
Rse.FRAMES.FASTER = 1
assertEq(Rse.machStepFrames(2), 1, "the top gear reads the new length")
Rse.FRAMES.NORMAL = 0
assertEq(Rse.frameCount("NORMAL"), 1, "zero coast frames stays one frame")
Rse.JUMP.FAR = 9
assertEq(Rse.jumpFrames("FAR"), 9, "the acro ledge reads the new length")
Rse.FRAMES.NORMAL = 16
Rse.FRAMES.FASTER = 4
Rse.JUMP.FAR = 32
assertEq(Rse.jumpWindow(), 4, "a hop accepts four frames of input")
assertEq(Rse.inPlaceFrames("NORMAL"), 16, "a wall bump lasts 16 frames")
assertEq(Rse.inPlaceFrames("FAST"), 8, "a turn bump lasts 8 frames")
assertEq(Rse.wheelieFrames(), 8, "a wheelie pose lasts 8 frames")
Rse.state.abHistory = 2
Rse.state.dirHistory = 1
Rse.state.dirTimers[1] = 4
Rse.state.abTimers[1] = 0
assertEq(Rse.jumpDirection(), "down", "four frames still counts as a hop")
Rse.state.dirTimers[1] = 5
assertEq(Rse.jumpDirection(), nil, "five frames is too late")
Rse.JUMP_TIMER = 0
Rse.state.dirTimers[1] = 0
assertEq(Rse.jumpDirection(), "down", "a window of zero still hops on that frame")
Rse.state.dirTimers[1] = 1
assertEq(Rse.jumpDirection(), nil, "the next frame misses a zero window")
Rse.JUMP_TIMER = 4
Rse.IN_PLACE.NORMAL = 0
assertEq(Rse.inPlaceFrames("NORMAL"), 0, "a wall bump can be instant")
Rse.IN_PLACE.NORMAL = 16
local walker = setmetatable({
  moving = true, progress = 0, cellX = 0, cellY = 0,
  targetX = 1, targetY = 0, stepFlip = false,
}, { __index = Npc })
Npc.STEP_FRAMES = 1
Npc.update(walker)
assertEq(walker.moving, false, "one frame finishes the step")
assertEq(walker.cellX, 1, "the step lands on the next tile")
Npc.STEP_FRAMES = 0
walker.moving = true
walker.progress = 0
walker.cellX = 0
walker.cellY = 0
walker.targetX = 1
walker.targetY = 0
walker.jumping = true
Npc.update(walker)
assertEq(walker.cellX, 1, "zero frames still lands")
assertEq(walker.moving, false, "zero frames is not still walking")
assertEq(walker.jumping, nil, "a jump of zero frames lands too")
walker.moving = true
walker.progress = 0
assertEq(Npc.walkPhase(walker), 0, "zero frames has no walk pose")
Npc.STEP_FRAMES = 16
local Gen1 = require("src.world.NPC")
assertEq(Gen1.stepFrameCount(), 32, "a gen 1 step is 32 frames")
local redWalker = setmetatable({
  moving = true, progress = 0, cellX = 0, cellY = 0,
  targetX = 1, targetY = 0, facing = "right", stepFlip = false,
}, { __index = Gen1 })
Gen1.STEP_FRAMES = 1
Gen1.update(redWalker)
assertEq(redWalker.cellX, 1, "one frame finishes a gen 1 step")
assertEq(redWalker.moving, false, "the gen 1 step is done")
Gen1.STEP_FRAMES = 0
redWalker.moving = true
redWalker.progress = 0
redWalker.cellX = 0
redWalker.cellY = 0
redWalker.targetX = 1
redWalker.targetY = 0
redWalker.facing = "right"
Gen1.update(redWalker)
assertEq(redWalker.cellX, 1, "zero frames still lands in gen 1")
assertEq(redWalker.moving, false, "zero frames is not still walking")
Gen1.STEP_FRAMES = 32
local gLo, gHi = Gen1.wanderWait()
assertEq(gLo, 30, "a gen 1 wander waits at least 30 frames")
assertEq(gHi, 180, "a gen 1 wander waits at most 180 frames")
local sLo, sHi = Gen1.stayWait()
assertEq(sLo, 1, "a standing npc waits at least 1 frame")
assertEq(sHi, 128, "a standing npc waits at most 128 frames")
Gen1.WANDER_LO = 7
Gen1.WANDER_HI = 7
Gen1.TURN_ODDS = 100
local redWander = setmetatable({
  frozen = false, wanders = true, timer = 1, facing = "up",
  roamDirs = { "left" }, steps = true, cellX = 0, cellY = 0,
}, { __index = Gen1 })
Gen1.update(redWander)
assertEq(redWander.timer, 7, "the gen 1 pause uses the wander range")
assertEq(redWander.facing, "left", "the gen 1 wanderer picks a facing")
assertEq(redWander.moving, nil, "a full turn chance does not step")
Gen1.WANDER_LO = 30
Gen1.WANDER_HI = 180
Gen1.TURN_ODDS = 50

local Seeker = require("src.core.game3.vs_seeker")
assertEq(Seeker.chargeGoal(), 100, "seeker charge")
assertEq(Seeker.refusesRematch(29), true, "below 30 refuses")
assertEq(Seeker.refusesRematch(30), false, "30 accepts")
Seeker.NO_REMATCH = 0
assertEq(Seeker.refusesRematch(0), false, "refuse zero always accepts")
Seeker.NO_REMATCH = 30
assertEq(Seeker.rematchDice(), 100, "dice")
Seeker.REMATCH_DICE = 1
assertEq(Seeker.rematchDice(), 1, "one-sided roll")
assertEq(0 % Seeker.rematchDice(), 0, "roll is zero")
Seeker.REMATCH_DICE = 0
assertEq(Seeker.rematchDice(), 1, "zero dice stays one")
Seeker.REMATCH_DICE = 100
Seeker.MAX_CHARGE = 0
local session = {}
Seeker.setBattery(session, 40)
assertEq(Seeker.getBattery(session), 0, "charge zero is already full")
Seeker.MAX_CHARGE = 100

local Writer = require("ModWriter")
local Counters = require("StepCounters")
assertEq(Counters.arcList("-9, 200, -200")[1], -9, "an arc keeps a negative pixel")
assertEq(Counters.arcList("-9, 200, -200")[2], 127, "an arc pixel clamps at 127")
assertEq(Counters.arcList("-9, 200, -200")[3], -128, "an arc pixel clamps at -128")
assertEq(#Counters.arcList(Counters.FIG8_X), #Objects.FIG8_X, "the across list matches the cart")
assertEq(#Counters.arcList(Counters.FIG8_Y), #Objects.FIG8_Y, "the down list matches the cart")
assertEq(Counters.arcList(Counters.FIG8_Y)[#Objects.FIG8_Y], -2, "the cart path ends two pixels up")
assertEq(Counters.copyRows(Counters.COPY_FOR)[1][2], 1, "the cart copy row maps that step to down")
assertEq(Counters.copyRows(Counters.COPY_TO)[4][4], 1, "the cart copy result ends on down")
for _, version in ipairs({ "gold", "silver", "crystal" }) do
  local main = Writer.emitMain({ version = version, generation = 2, stepCounters = { bikeCall = 0, bikeCap = 0, skyfallBeats = 0, pitfallShake = 0, teleportBeats = 0, treeShake = 0, digStep = 0, digSpin = 0, sleepUnit = 0, npcStep = 0, spinFrames = 1, playerStep = 1, turnFrames = 0, bouncePeriod = 1, bounceHalf = 0, spinTurn = 0, wanderLo = 5, wanderHi = 5, spawnLo = 1, spawnHi = 1, turnOdds = 0, slowSpinLo = 0, slowSpinHi = 0, fastSpinLo = 2, fastSpinHi = 2, teleportLift = 0, teleportRise = 1, teleportFall = 2, g2Ledge = "0, -8", walkCycle = 1, legFrom = 0, legTo = 0, approachGap = 0, noticeFrames = 0, fadeSteps = 1, fadeFrames = 0, mapWhite = 0, warpWhite = 0, menuWhite = 0, flyWhite = 0, flyBuild = 0, flyBlank = 0, flyIcon = 0, partyWhite = 0, partyIcon = 0, partyExtra = 0, packWhite = 0, gearWhite = 0, gearExit = 0, cardWhite = 0, dexWhite = 0, optionWhite = 0, fadeIn = 0, palettePoll = 0, strengthPause = 0, neighborHops = 0, fadeWhite = "0, 0, 0, 0", fadeBlack = "1, 1, 1, 1", g2TextPause = 0, g2MoveDelay = 0, g2HpStep = 0, g2FaintRow = 1, g2SlideSteps = 0, g2SlideStep = 1, g2BackSteps = 0, g2WinSteps = 0, g2WinStep = 1, g2WinRest = 0, g2WinDelay = 0, g2ExitFade = 0, g2ExitMusic = 0, g2WhiteFade = 0, g2WhiteHold = 0, g2IntroSlide = 0, g2ExpSound = 0, g2ExpWait = 0, g2ExpGap = 0, g2ExpBurst = 0, g2ExpSparks = 0, g2ExpX = 0, g2ExpY = 0, g2TextX = 0, g2TextY = 0, g2TextW = 1, g2TextRows = 1, g2TextStep = 0, g2ArrowX = 0, g2ArrowY = 0, g2MenuX = 0, g2MenuGap = 0, g2ParkX = 0, g2ParkGap = 0, g2HeadbuttSfx = 0, g2CutSfx = 0, g2FlashSfx = 0, g2FallSfx = 0, g2BoulderSfx = 0, g2Shock = 0, g2Whirl = 0, g2HealBall = 0, g2HealFlash = 0, g2HealFlashes = 0, g2HealAnchor = 0, g2HealShiftX = 0, g2HealShiftY = 0, g2HealFlip = 0, g2HealPc = "0, 0", g2HealBalls = "1, 2, 1", g2HealHof = "3, 4, 0", g2Rod = "0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0", g2FishRow = "0, 0, 0, 0", g2Tower = "1, 1, 1, 1, 1, 1, 1, 1", g2Scroll = "0, 0, 0, 0, 0, 0, 0, -1", g2Water = "2, 2, 2, 2, 2, 2, 2, 2", g2WhirlRows = "3, 3, 3, 3, 3, 3, 3, 3", g2Lava = "4, 4, 4, 4, 4, 4, 4, 4", g2Lava2 = "5, 5, 5, 5, 5, 5, 5, 5" } })
  assert(main:find("BIKE_CALL_STEPS = 0", 1, true), version)
  assert(main:find("BIKE_STEP_MAX = 0", 1, true), version)
  assert(main:find("SKYFALL_BEAT_FRAMES = 0", 1, true), version)
  assert(main:find("PITFALL_SHAKE = 0", 1, true), version)
  assert(main:find("TELEPORT_BEAT_FRAMES = 0", 1, true), version)
  assert(main:find("TELEPORT_LIFT = 0", 1, true), version)
  assert(main:find("TELEPORT_RISE_HEIGHT = 1", 1, true), version)
  assert(main:find("TELEPORT_FALL_HEIGHT = 2", 1, true), version)
  assert(main:find("Movement\").JUMP_Y = { 0, -8 }", 1, true), version)
  assert(main:find("WALK_ANIM_FRAMES = 1", 1, true), version)
  assert(main:find("gen2.Player\").LEG_FROM = 0", 1, true), version)
  assert(main:find("gen2.Player\").LEG_TO = 0", 1, true), version)
  assert(main:find("Trainers\").APPROACH_GAP = 0", 1, true), version)
  assert(main:find("NOTICE_FRAMES = 0", 1, true), version)
  assert(main:find("FADE_STEPS = 1", 1, true), version)
  assert(main:find("FADE_STEP_FRAMES = 0", 1, true), version)
  assert(main:find("MAP_LOAD_WHITE_FRAMES = 0", 1, true), version)
  assert(main:find("WARP_LOAD_WHITE_FRAMES = 0", 1, true), version)
  assert(main:find("MENU_EXIT_WHITE_FRAMES = 0", 1, true), version)
  assert(main:find("FLY_EXIT_WHITE_FRAMES = 0", 1, true), version)
  assert(main:find("FLY_MAP_BUILD_FRAMES = 0", 1, true), version)
  assert(main:find("FLY_CANCEL_BLANK_FRAMES = 0", 1, true), version)
  assert(main:find("FLY_CANCEL_ICON_FRAMES = 0", 1, true), version)
  assert(main:find("PARTY_WHITE = 0", 1, true), version)
  assert(main:find("PARTY_ICON_FRAMES = 0", 1, true), version)
  assert(main:find("PARTY_EXTRA = 0", 1, true), version)
  assert(main:find("PACK_WHITE = 0", 1, true), version)
  assert(main:find("GEAR_WHITE = 0", 1, true), version)
  assert(main:find("GEAR_EXIT_WHITE = 0", 1, true), version)
  assert(main:find("CARD_WHITE = 0", 1, true), version)
  assert(main:find("DEX_WHITE = 0", 1, true), version)
  assert(main:find("OPTION_WHITE = 0", 1, true), version)
  assert(main:find("IN_STEPS = 0", 1, true), version)
  assert(main:find("PALETTE_POLL_STEPS = 0", 1, true), version)
  assert(main:find("STRENGTH_PAUSE_FRAMES = 0", 1, true), version)
  assert(main:find("NEIGHBOR_HOPS = 0", 1, true), version)
  assert(main:find("FADE_RAMP.white = { { 0, 0, 0, 0 } }", 1, true), version)
  assert(main:find("FADE_RAMP.black = { { 1, 1, 1, 1 } }", 1, true), version)
  assert(main:find("TEXT_PAUSE_FRAMES = 0", 1, true), version)
  assert(main:find("MOVE_DELAY_FRAMES = 0", 1, true), version)
  assert(main:find("HP_BAR_FRAMES_PER_STEP = 0", 1, true), version)
  assert(main:find("FAINT_SLIDE_FRAMES_PER_ROW = 1", 1, true), version)
  assert(main:find("EXIT_FADE_FRAMES = 0", 1, true), version)
  assert(main:find("WHITEOUT_HOLD_FRAMES = 0", 1, true), version)
  assert(main:find("SLIDE_FRAMES = 0", 1, true), version)
  assert(main:find("EXP_SOUND_FRAMES = 0", 1, true), version)
  assert(main:find("EXP_WAIT_SFX_CAP = 0", 1, true), version)
  assert(main:find("EXP_PIXEL_GAP = 0", 1, true), version)
  assert(main:find("EXP_BURST_FRAMES = 0", 1, true), version)
  assert(main:find("EXP_BURST_SPRITES = 0", 1, true), version)
  assert(main:find("EXP_BURST_X = 0", 1, true), version)
  assert(main:find("EXP_BURST_Y = 0", 1, true), version)
  assert(main:find("TEXT_INNER_X = 0", 1, true), version)
  assert(main:find("TEXT_WIDTH = 1", 1, true), version)
  assert(main:find("TEXT_ROWS = 1", 1, true), version)
  assert(main:find("MENU_BOX_X = 0", 1, true), version)
  assert(main:find("CONTEST_MENU_BOX_X = 0", 1, true), version)
  assert(main:find("CONTEST_MENU_COL_SPACING = 0", 1, true), version)
  assert(main:find("SFX_SANDSTORM = 0", 1, true), version)
  assert(main:find("SFX_CUT = 0", 1, true), version)
  assert(main:find("SFX_FLASH = 0", 1, true), version)
  assert(main:find("EMOTE_SHOCK = 0", 1, true), version)
  assert(main:find("WHIRLPOOL_CAP = 0", 1, true), version)
  assert(main:find("HEAL_BALL_FRAMES = 0", 1, true), version)
  assert(main:find("HEAL_FLASHES = 0", 1, true), version)
  assert(main:find("HEAL_ANCHOR = 0", 1, true), version)
  assert(main:find("HEAL_SHIFT_X = 0", 1, true), version)
  assert(main:find("HEAL_PC = { machine = { { 0, 0 } }, balls = { { 1, 2, true } } }", 1, true), version)
  assert(main:find("HEAL_HOF = { balls = { { 3, 4 } } }", 1, true), version)
  assert(main:find("ROD_OAM = { down = { dx = 0, dy = 0, tile = 0 }, up = { dx = 0, dy = 0, tile = 0 }, left = { dx = 0, dy = 0, tile = 0, flip = true }, right = { dx = 0, dy = 0, tile = 0 } }", 1, true), version)
  assert(main:find("FISH_ROW = { down = 0, up = 0, left = 0, right = 0 }", 1, true), version)
  assert(main:find("TOWER_ROWS = { [0] = 1, 1, 1, 1, 1, 1, 1, 1 }", 1, true), version)
  assert(main:find("SCROLL_H = { [0] = 0, 0, 0, 0, 0, 0, 0, -1 }", 1, true), version)
  assert(main:find("WATER_ROWS = { [0] = 2, 2, 2, 2, 2, 2, 2, 2 }", 1, true), version)
  assert(main:find("WHIRL_ROWS = { [0] = 3, 3, 3, 3, 3, 3, 3, 3 }", 1, true), version)
  assert(main:find("LAVA1_ROWS = { [0] = 4, 4, 4, 4, 4, 4, 4, 4 }", 1, true), version)
  assert(main:find("LAVA2_ROWS = { [0] = 5, 5, 5, 5, 5, 5, 5, 5 }", 1, true), version)
  assert(not main:find("EMOTE_FRAMES", 1, true), version)
  assert(not main:find("WALK_CYCLE", 1, true), version)
  assert(main:find("TREE_SHAKE_FRAMES = 0", 1, true), version)
  assert(main:find("STEP_DIG_FRAMES = 0", 1, true), version)
  assert(main:find("DIG_SPIN_FRAMES = 0", 1, true), version)
  assert(main:find("SLEEP_UNIT = 0", 1, true), version)
  assert(main:find("STEP_FRAMES = 0", 1, true), version)
  assert(main:find("SPIN_FRAMES = 1", 1, true), version)
  assert(main:find("gen2.Player\").STEP_FRAMES = 1", 1, true), version)
  assert(main:find("TURN_FRAMES = 0", 1, true), version)
  assert(main:find("BOUNCE_PERIOD = 1", 1, true), version)
  assert(main:find("BOUNCE_HALF = 0", 1, true), version)
  assert(main:find("SPIN_TURN_FRAMES = 0", 1, true), version)
  assert(main:find("gen2.Npc\").WANDER_LO = 5", 1, true), version)
  assert(main:find("WANDER_HI = 5", 1, true), version)
  assert(main:find("SPAWN_LO = 1", 1, true), version)
  assert(main:find("SPAWN_HI = 1", 1, true), version)
  assert(main:find("TURN_ODDS = 0", 1, true), version)
  assert(not main:find("STAY_LO", 1, true), version)
  assert(main:find("SLOW_SPIN_LO = 0", 1, true), version)
  assert(main:find("SLOW_SPIN_HI = 0", 1, true), version)
  assert(main:find("FAST_SPIN_LO = 2", 1, true), version)
  assert(main:find("FAST_SPIN_HI = 2", 1, true), version)
  assert(not main:find("HOP_PEAK", 1, true), version)
  assert(not main:find("LOOP_FRAMES", 1, true), version)
  assert(not main:find("BOB_PERIOD", 1, true), version)
  assert(not main:find("HOLE_SINK", 1, true), version)
  assert(not main:find("WALK_CYCLE", 1, true), version)
  assert(not main:find("WARP_LIFT", 1, true), version)
  assert(not main:find("SIGHT_X", 1, true), version)
  assert(not main:find("game3.player", 1, true), version)
  assert(not main:find("gfx_ids", 1, true), version)
  assert(not main:find("game3.objects", 1, true), version)
  assert(not main:find("MAX_CHARGE", 1, true), version)
end
for _, version in ipairs({ "red", "blue", "yellow" }) do
  local main = Writer.emitMain({
    version = version, generation = 1,
    constants = { world = { stepFrames = 1, bikeStepFrames = 2, turnFrames = 0 } },
    stepCounters = { bikeCall = 0, bikeCap = 0, seekerCharge = 0, npcStep = 0, touchTurn = 0, loopFrames = 1, spinIter = 1, hopPeak = 0, bobPeriod = 1, bobHalf = 0, bobPixels = 0, holeSink = 0, walkCycle = 1, legFrom = 0, legTo = 0, spinRise = 0, warpLift = 0, warpFrames = 1, sightX = 0, sightY = 0, sightLeft = 0, sightRight = 0, sightUp = 0, sightDown = 0, emoteFrames = 0, approachGap = 0, wanderLo = 5, wanderHi = 6, spawnLo = 1, spawnHi = 2, turnOdds = 0, stayLo = 3, stayHi = 4, g1FlyFade = 0, g1FlyFlap = 0, g1FlyBeat = 0, g1FlyStep = 1, g1TeleportOut = 0, g1PadOut = 0, g1TeleportIn = 0, g1PadIn = 0, g1DropSteps = 0, g1HoleIn = 0, g1InPlace = 0, g1ShipKeep = 0, g1GhostPad = 0, g1OutHolds = "0", g1PadHolds = "0", g1InHolds = "0", g1PadInHolds = "0", g1HoleHolds = "0", g1FlyOut = "0, 0", g1FlyAway = "0, 0", g1FlyIn = "0, 0", g1FlyAnchor = "0, 0", g1FlyLand = "0, 0", g1Sail = 0, g1SailStep = 0, g1SmokeEvery = 0, g1SmokeX = 0, g1SmokeY = 0, g1SmokeDrift = 0, g1ShipX = 0, g1ShipY = 0, g1ShipW = 0, g1ShipH = 0, g1ShipWater = "0", g1Rod = "0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1", g1HealBalls = "1, 2, 1", g1HealMonX = 0, g1HealMonY = 0, g1HealAnchor = 0, g1HealFlip = 0, g1HealBall = 0, g1HealFlash = 0, g1HealFlashes = 0, g1HealDmg = "0, 0, 0, 0", g1HealGbc = "1, 1, 1, 1", g1HealLit = "2, 2, 2, 2", g1HealDim = "3, 3, 3, 3", g1Delay = 0, g1FadeBlack = 0, g1OutWhite = 0, g1InWhite = 0, g1WarpOut = 0, g1WarpIn = 0, g1BattleReturn = 0, g1HoleWait = 0, g1Scroll = 0, g1TextWait = 0, g1PageClear = 0, g1YesNo = 0, g1Slide = 0, g1SlidePx = 0, g1TrainerGap = 0, g1SendOut = 0, g1MovePre = 0, g1MoveOff = 0, g1Miss = 0, g1Substitute = 0, g1ShakeV = 0, g1ShakeHeavy = 0, g1ShakeSlow = 0, g1ShakeLight = 0, g1ShakeSlow2 = 0, g1Blink = 0, g1Faint = 0, g1FaintStep = 0, g1Switch = 0, g1CritText = 0, g1HpBar = 1, g1HpPixel = 0, g1HpStep = 0, g1FadeStep = 1, g1Flash = 0 },
  })
  assert(not main:find("BIKE_CALL_STEPS", 1, true), version)
  assert(not main:find("BIKE_STEP_MAX", 1, true), version)
  assert(not main:find("SKYFALL_BEAT_FRAMES", 1, true), version)
  assert(not main:find("TELEPORT_BEAT_FRAMES", 1, true), version)
  assert(not main:find("TELEPORT_LIFT", 1, true), version)
  assert(not main:find("gen2.Movement", 1, true), version)
  assert(not main:find("DIG_SPIN_FRAMES", 1, true), version)
  assert(not main:find("SLEEP_UNIT", 1, true), version)
  assert(not main:find("gen2.Npc", 1, true), version)
  assert(not main:find("Npc\").SPIN_FRAMES", 1, true), version)
  assert(not main:find("gen2.Player", 1, true), version)
  assert(not main:find("WALK_ANIM_FRAMES", 1, true), version)
  assert(main:find("src.world.NPC\").STEP_FRAMES = 0", 1, true), version)
  assert(main:find("stepFrames = 1", 1, true), version)
  assert(main:find("bikeStepFrames = 2", 1, true), version)
  assert(main:find("turnFrames = 0", 1, true), version)
  assert(main:find("TOUCH_TURN_FRAMES = 0", 1, true), version)
  assert(main:find("LOOP_FRAMES = 1", 1, true), version)
  assert(main:find("SPIN_ITER_FRAMES = 1", 1, true), version)
  assert(main:find("HOP_PEAK = 0", 1, true), version)
  assert(main:find("BOB_PERIOD = 1", 1, true), version)
  assert(main:find("BOB_HALF = 0", 1, true), version)
  assert(main:find("BOB_PIXELS = 0", 1, true), version)
  assert(main:find("HOLE_SINK = 0", 1, true), version)
  assert(main:find("WALK_CYCLE = 1", 1, true), version)
  assert(main:find("LEG_FROM = 0", 1, true), version)
  assert(main:find("LEG_TO = 0", 1, true), version)
  assert(main:find("SPIN_RISE = 0", 1, true), version)
  assert(main:find("WARP_LIFT = 0", 1, true), version)
  assert(main:find("WARP_FRAMES = 1", 1, true), version)
  assert(main:find("SIGHT_X = 0", 1, true), version)
  assert(main:find("SIGHT_Y = 0", 1, true), version)
  assert(main:find("SIGHT_LEFT = 0", 1, true), version)
  assert(main:find("SIGHT_RIGHT = 0", 1, true), version)
  assert(main:find("SIGHT_UP = 0", 1, true), version)
  assert(main:find("SIGHT_DOWN = 0", 1, true), version)
  assert(main:find("EMOTE_FRAMES = 0", 1, true), version)
  assert(main:find("OverworldController\").APPROACH_GAP = 0", 1, true), version)
  assert(not main:find("Trainers\").APPROACH_GAP", 1, true), version)
  assert(not main:find("NOTICE_FRAMES", 1, true), version)
  assert(main:find("src.world.NPC\").WANDER_LO = 5", 1, true), version)
  assert(main:find("WANDER_HI = 6", 1, true), version)
  assert(main:find("SPAWN_LO = 1", 1, true), version)
  assert(main:find("TURN_ODDS = 0", 1, true), version)
  assert(main:find("STAY_LO = 3", 1, true), version)
  assert(main:find("STAY_HI = 4", 1, true), version)
  assert(main:find("FLY_FADE_CONTROL = 0", 1, true), version)
  assert(main:find("FLY_FLAP = 0", 1, true), version)
  assert(main:find("FLY_BEAT = 0", 1, true), version)
  assert(main:find("FLY_STEP = 1", 1, true), version)
  assert(main:find("TELEPORT_OUT_FRAMES = 0", 1, true), version)
  assert(main:find("WARP_PAD_OUT_FRAMES = 0", 1, true), version)
  assert(main:find("TELEPORT_IN_FRAMES = 0", 1, true), version)
  assert(main:find("TELEPORT_IN_PAD_FRAMES = 0", 1, true), version)
  assert(main:find("SPIN_DOWN_STEPS = 0", 1, true), version)
  assert(main:find("HOLE_IN_FRAMES = 0", 1, true), version)
  assert(main:find("TELEPORT_OUT_HOLDS = { 0 }", 1, true), version)
  assert(main:find("WARP_PAD_OUT_HOLDS = { 0 }", 1, true), version)
  assert(main:find("TELEPORT_IN_HOLDS = { 0 }", 1, true), version)
  assert(main:find("TELEPORT_IN_PAD_HOLDS = { 0 }", 1, true), version)
  assert(main:find("HOLE_IN_HOLDS = { 0 }", 1, true), version)
  assert(main:find("TELEPORT_OUT_INPLACE = 0", 1, true), version)
  assert(main:find("SS_ANNE_KEEP_PX = 0", 1, true), version)
  assert(main:find("GHOST_CULL_PAD = 0", 1, true), version)
  assert(main:find("FLY_PATH1 = { { 0, 0 } }", 1, true), version)
  assert(main:find("FLY_PATH2 = { { 0, 0 } }", 1, true), version)
  assert(main:find("FLY_PATH_IN = { { 0, 0 } }", 1, true), version)
  assert(main:find("FLY_ANCHOR = { 0, 0 }", 1, true), version)
  assert(main:find("FLY_ARRIVE_ANCHOR = { 0, 0 }", 1, true), version)
  assert(main:find("SS_ANNE_SAIL_PX = 0", 1, true), version)
  assert(main:find("SS_ANNE_PX_FRAMES = 0", 1, true), version)
  assert(main:find("SS_ANNE_SMOKE_EVERY = 0", 1, true), version)
  assert(main:find("SS_ANNE_WATER = { 0 }", 1, true), version)
  assert(main:find("ROD_OAM = { down = { dx = 0, dy = 0, tile = 0 }, up = { dx = 0, dy = 0, tile = 0 }, left = { dx = 0, dy = 0, tile = 0 }, right = { dx = 0, dy = 0, tile = 0, flip = true } }", 1, true), version)
  assert(main:find("HEAL_BALL_XY = { { 1, 2, true } }", 1, true), version)
  assert(main:find("HEAL_MONITOR_X = 0", 1, true), version)
  assert(main:find("HEAL_BALL_FRAMES = 0", 1, true), version)
  assert(main:find("HEAL_FLASHES = 0", 1, true), version)
  assert(main:find("HEAL_FLASH_MAP = { [0] = 0, 0, 0, 0 }", 1, true), version)
  assert(main:find("HEAL_FLASH_MAP_GBC = { [0] = 1, 1, 1, 1 }", 1, true), version)
  assert(main:find("HEAL_OBP1_MAP = { [0] = 2, 2, 2, 2 }", 1, true), version)
  assert(main:find("HEAL_OBP1_FLASH_MAP = { [0] = 3, 3, 3, 3 }", 1, true), version)
  assert(main:find("SS_ANNE_BLOCK_W = 0", 1, true), version)
  assert(main:find("DELAY3 = 0", 1, true), version)
  assert(main:find("WARP_FADE_OUT = 0", 1, true), version)
  assert(main:find("WARP_FADE_IN = 0", 1, true), version)
  assert(main:find("YES_NO_ANSWER = 0", 1, true), version)
  assert(main:find("BLINK_MON = 0", 1, true), version)
  assert(main:find("FAINT_SLIDE = 0", 1, true), version)
  assert(main:find("HP_BAR_PIXELS = 1", 1, true), version)
  assert(main:find("FADE_STEP_FRAMES = 1", 1, true), version)
  assert(main:find("FLASH_FRAMES = 0", 1, true), version)
  assert(not main:find("SLOW_SPIN", 1, true), version)
  assert(not main:find("game3.player", 1, true), version)
  assert(not main:find("gfx_ids", 1, true), version)
  assert(not main:find("game3.objects", 1, true), version)
  assert(not main:find("BOUNCE_PERIOD", 1, true), version)
  assert(not main:find("MAX_CHARGE", 1, true), version)
end
local Native = require("Gen3Native")
for _, version in ipairs({ "firered", "leafgreen" }) do
  local p = { version = version, generation = 3, stepCounters = { seekerCharge = 0, seekerRefuse = 0, seekerDice = 1, g3Walk = 1, g3Run = 2, g3Turn = 0, g3Bike = 3, g3Jump = 5, g3Slow = 7, g3Fast = 1, g3RunCycle = 1, g3RunPose = 0, approachGap = 0, emoteFrames = 0, markStep = 0, markLift = 0, markGap = 0, markBang = 0, markBang2 = 0, markX = 0, markSmile = 0, markAsk = 0, reflDrop = 0, reflCull = 0, reflPad = 0, reflBridge1 = 0, cutHold = 1, cutX = 0, cutY = 0, leafStep = 1, leafFall = 0, grassBase = 0, grassSpread = 0, grassLift = 0, grassSpot = 0, smashHold = 1, smashStep = 1, smashFall = 0, smashBase = 0, smashSpread = 0, smashLift = 0, smashJitter = 0, smashSpot = 0, grassFrames = 0, scentFrames = 1, scentRadius = 0, scentGap = 0, scentX = 0, scentY = 0, splashHold = 0, splashPics = "0", dustHold = 0, dustPics = "0", rustleHold = 0, rustlePics = "0", feetPics = "0", feetH = 1, grassSlack = 0, rippleY = 0, shortLift = 0, sandLift = 0, tireBlink = 0, tireEnd = 0, surfW = 1, surfH = 1, surfFrames = 1, birdW = 1, birdH = 1, birdFrames = 1, place = 0, splashDrop = 0, bubbleY = 0, bubbleRise = 0, berryY = 0, pillarY = 0, sparkleWait = 0, sandFrame = 0, distort = "0, 1", tireTurns = "0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0", ripplePics = "0", feetHold = "0, 4, 6, 6, 8, 8, 6, 6", rippleHold = "0, 9, 9, 9, 9, 9, 11, 11", surfHold = 1, blobX = 0, blobY = 0, blobBob = 0, trackBlink = 0, trackEnd = 0, shakeEvery = 1, shakeAmp = 0, shakeFade = 1, rockWait = 0, rockAmp = 0, rockDecay = 1, fragX = 0, fragY = 0, shardX = 0, shardY = 0, rockHold = 1, rockFlip = 1, rockFootX = 0, rockFootY = 0, rockTop = 0, flySwoop = 0, flyMount = 0, flyOff = 0, flyIn = 0, flyPose = 0, flyEnd = 0, tpSpin = 0, tpTurns = 0, tpRiseTurn = 0, tpSpeedFirst = 0, tpSpeedEvery = 0, tpSpeedCap = 0, tpLift = 0, tpVanish = 0, tpDrop = 0, tpDropTurn = 0, tpSlow = 0, tpGround = 0, tpLand = 0, tpLandTurns = 0, birdSwoopX = 0, birdSwoopY = 0, birdSwoopStep = 1, birdSwoopEnd = 0, birdRideX = 0, birdRideY = 0, birdRideStep = 1, birdRideEnd = 0, ballWide = 0, ballPush = 0, ballCap = 0, ballEnd = 0, ballAngle = 0, ballSpeed = 0, returnWide = 0, returnHigh = 0, returnAngle = 0, returnSpeed = 0, returnBrake = 0, returnGrow = 0, returnFloor = 0, returnBrakeCap = 0, returnEnd = 0, leaveScale = 0, leaveTilt = 0, leaveFrames = 0, leaveGrow = 0, shrinkScale = 0, shrinkTilt = 0, shrinkFrames = 0, shrinkStep = 0, awayGrow = 0, arrivePop = 0, arriveShrink = 0, flashFrames = 1, veilFrames = 1, mountArc = "0", dismountArc = "0", popBoy = 0, popGirl = 0, popY = 0, backBoy = 0, backGirl = 0, backY = 0, diveX = 0, diveY = 0, rideX = 0, rideY = 0, seat = 0, birdNudge = 0, tpStart = 0, boyAway = 0, girlAway = 0, boyHome = 0, girlHome = 0, birdRest = 0, g3Med1 = 0, g3Rotate = 1, g3NpcWalk = 1, g3NpcRun = 2, g3NpcSlow = 3, g3LevStep = 1, g3LevTurn = 1, g3LevPixel = 0, fig8X = "3", fig8Y = "-2", copyFor = "4", emoteA = 0, emoteB = 0, playerHop = "-9, 0", surfHop = "0", fishWait = 0, fishDot = 0, fishDots = 0, fishFirst = 0, waterfall = 1, tradeFade = 1, tradeHold = 0, tradeBye = 0, tradeDepart = 0, tradeReturn = 1, tradeClose = 0, tradeFlash = 0, tradeArrived = 0, tradeMon = 0, tradeFanfare = 0, tradeFanfareRs = 0, tradeCare = 0, tradeCareRs = 0, tradeAfter = 0, tradeSave = 0, tradeJitter = 0, tradeLink = 0, tradeOpen = 0, animPause = 0, anneHorn = 0, anneSmoke = 0, anneSlide = 1, anneLeave = 0, wakeStep = 0, wakeCap = 0, wakeFlip = 0, wakeX = 0, wakeCull = 0, wakeY = 0, wakeLift = 0, smokeStep = 0, smokeA = 0, smokeB = 0, smokeC = 0, smokeEnd = 0, smokeSpawn = 0, smokeCull = 0, smokeY = 0, smokeLift = 0, boatGone = 0, ferryCross = 0, ferryMusic = 0, dudeScroll = 0, oakDim = 0, oakWait = 0, arenaPause = 0, slideStart = 0, slideStep = 1, ballSound = 0, ballFly = 0, ballBounce = 0, ballRest = 0, ballEnd = 0, zoomMax = 0, zoomMin = 0, zoomStep = 1, zoomFar = 0, flashAnim = 0, gbaTop = 0, panEnd = 0, cableEnd = 0, travelEnd = 0, linkY = 0, linkOff = 0, crossStep = 1, crossEnter = 0, crossExit = 0, crossMon = 0, crossAy = 0, crossBy = 0, arriveY = 0, arriveAt = 0, gbaCenter = 0, ballDrop = 0, ballLand = 0, ballFall = 1, ballIdx = 0, ballStop = 0, bounce2 = 0, bounce3 = 0, bounce4 = 0, ballVel = "0", g3HealX = 0, g3HealY = 0, g3HealMonX = 0, g3HealMonY = 0, g3HealNudgeX = 0, g3HealNudgeY = 0, g3HealMonNudgeX = 0, g3HealMonNudgeY = 0, g3HealGap = 0, g3HealEnd = 0, g3HealGlow = 0, g3HealLaps = 0, g3HealRest = 0, g3HealMonLaps = 0, g3HealOffs = "0, 0", g3HealSeq = "0", g3HealDurs = "0", g3GlowK = "0", g3GlowSlots = "0", g3GlowLead = "0", g3FishBase = "1, 1, 1, 1", g3FishOut = "0, 1", g3FishSn = "1, 1", g3FishWe = "2, 1", g3FishHook = "3, 1", g3FishOff = "1, 0, 0, 0", g3FieldMove = "4, 1", g3VsSeq = "5, 1", g3VsBike = "6, 1", g3Bow = 0, g3Stand = "1, 1, 1, 1", g3WalkA = "2, 2, 2, 2", g3WalkB = "3, 3, 3, 3", g3RunStill = "4, 4, 4, 4", g3RunA = "5, 5, 5, 5", g3RunB = "6, 6, 6, 6", g3Flash = "0", screenH = 1 } }
  assert(Native.used(p), version)
  local out = {}
  Counters.emit(p, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(chunk:find("MAX_CHARGE = 0", 1, true), version)
  assert(chunk:find("NO_REMATCH = 0", 1, true), version)
  assert(chunk:find("REMATCH_DICE = 1", 1, true), version)
  assert(chunk:find("WALK_FRAMES = 1", 1, true), version)
  assert(chunk:find("RUN_FRAMES = 2", 1, true), version)
  assert(chunk:find("TURN_FRAMES = 0", 1, true), version)
  assert(chunk:find("BIKE_FRAMES = 3", 1, true), version)
  assert(chunk:find("JUMP_FRAMES = 5", 1, true), version)
  assert(chunk:find("RUN_SLOW_FRAMES = 7", 1, true), version)
  assert(chunk:find("FASTER_FRAMES = 1", 1, true), version)
  assert(chunk:find("RUN_CYCLE = 1", 1, true), version)
  assert(chunk:find("RUN_POSE = 0", 1, true), version)
  assert(chunk:find("FISHING_WAIT_FRAMES = 0", 1, true), version)
  assert(chunk:find("FISHING_DOT_FRAMES = 0", 1, true), version)
  assert(chunk:find("FISHING_DOT_MAX = 0", 1, true), version)
  assert(chunk:find("FISHING_FIRST_ROUND_DOTS = 0", 1, true), version)
  assert(chunk:find("WALK_SLOWER_FRAMES = 1", 1, true), version)
  assert(chunk:find("FADE_FRAMES = 1", 1, true), version)
  assert(chunk:find("HOLD_FRAMES = 0", 1, true), version)
  assert(chunk:find("BYE_BYE_DELAY = 0", 1, true), version)
  assert(chunk:find("TAKE_CARE_AT = 0", 1, true), version)
  assert(chunk:find("TAKE_CARE_RS = 0", 1, true), version)
  assert(chunk:find("LINK_CLOSE_HOLD = 0", 1, true), version)
  assert(chunk:find("natives_trade\").FADE_FRAMES = 0", 1, true), version)
  assert(chunk:find("PAUSE_SHORT = 0", 1, true), version)
  assert(chunk:find("INIT_FRAMES = 0", 1, true), version)
  assert(chunk:find("SMOKE_INTERVAL = 0", 1, true), version)
  assert(chunk:find("SLIDE_SPEED_DIV = 1", 1, true), version)
  assert(chunk:find("FINISH_FRAMES = 0", 1, true), version)
  assert(chunk:find("WAKE_STEP = 1", 1, true), version)
  assert(chunk:find("WAKE_CAP = 0", 1, true), version)
  assert(chunk:find("SMOKE_END = 0", 1, true), version)
  assert(chunk:find("BOAT_GONE = 0", 1, true), version)
  assert(chunk:find("SMOKE_CULL = 0", 1, true), version)
  assert(chunk:find("CROSSING_FRAMES = 0", 1, true), version)
  assert(chunk:find("MUSIC_FADE_FRAMES = 0", 1, true), version)
  assert(chunk:find("POKEDUDE_AUTO_SCROLL = 0", 1, true), version)
  assert(chunk:find("OAK_DIM_TARGET = 0", 1, true), version)
  assert(chunk:find("OAK_DIM_DELAY = 0", 1, true), version)
  assert(chunk:find("B_WAIT_TIME_LONG = 0", 1, true), version)
  assert(chunk:find("MON_SLIDE_HOFS = 0", 1, true), version)
  assert(chunk:find("MON_SLIDE_STEP = 1", 1, true), version)
  assert(chunk:find("ZOOM_MAX = 0", 1, true), version)
  assert(chunk:find("CROSS_ENTER_LIMIT = 0", 1, true), version)
  assert(chunk:find("BALL_ARRIVE_END = 0", 1, true), version)
  assert(chunk:find("DISPLAY_HEIGHT = 1", 1, true), version)
  assert(chunk:find("BALL_BOUNCE_2 = 0", 1, true), version)
  assert(chunk:find("BALL_BOUNCE_4 = 0", 1, true), version)
  assert(chunk:find("BALL_VELOCITY = { [0] = 0 }", 1, true), version)
  assert(chunk:find("BALL_CENTER_X = 0", 1, true), version)
  assert(chunk:find("PLACE_FRAMES = 0", 1, true), version)
  assert(chunk:find("FLASH_LOOPS = 0", 1, true), version)
  assert(chunk:find("BALL_OFFSETS = { { 0, 0 } }", 1, true), version)
  assert(chunk:find("MONITOR_SEQ = { 0 }", 1, true), version)
  assert(chunk:find("MONITOR_DURS = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_K = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_INDICES = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_LEAD = { 0 }", 1, true), version)
  assert(chunk:find("FISH_BASE = { down = 1, up = 1, left = 1, right = 1 }", 1, true), version)
  assert(chunk:find("FISH_TAKE_OUT = { 0, 1 }", 1, true), version)
  assert(chunk:find("FISH_PUT_AWAY_SN = { 1, 1 }", 1, true), version)
  assert(chunk:find("FISH_PUT_AWAY_WE = { 2, 1 }", 1, true), version)
  assert(chunk:find("FISH_HOOKED = { 3, 1 }", 1, true), version)
  assert(chunk:find("FISH_OFFS = { { 1, 0, 0, 0 } }", 1, true), version)
  assert(chunk:find("FIELD_MOVE_SEQ = { 4, 1 }", 1, true), version)
  assert(chunk:find("VS_SEEKER_SEQ = { 5, 1 }", 1, true), version)
  assert(chunk:find("VS_SEEKER_BIKE_SEQ = { 6, 1 }", 1, true), version)
  assert(chunk:find("BOW_FRAME = 0", 1, true), version)
  assert(chunk:find("STAND = { down = 1, up = 1, left = 1, right = 1 }", 1, true), version)
  assert(chunk:find("WALK_A = { down = 2, up = 2, left = 2, right = 2 }", 1, true), version)
  assert(chunk:find("WALK_B = { down = 3, up = 3, left = 3, right = 3 }", 1, true), version)
  assert(chunk:find("RUN_BASE = { down = 4, up = 4, left = 4, right = 4 }", 1, true), version)
  assert(chunk:find("RUN_A = { down = 5, up = 5, left = 5, right = 5 }", 1, true), version)
  assert(chunk:find("RUN_B = { down = 6, up = 6, left = 6, right = 6 }", 1, true), version)
  assert(chunk:find("FLASH_LEVEL_RADIUS = { [0] = 0 }", 1, true), version)
  assert(chunk:find("trainer_sight\").APPROACH_GAP = 0", 1, true), version)
  assert(chunk:find("field_effects\").EMOTE_FRAMES = 0", 1, true), version)
  assert(chunk:find("MARK_STEP = 0", 1, true), version)
  assert(chunk:find("REFL_DROP = 0", 1, true), version)
  assert(chunk:find("REFL_CULL = 0", 1, true), version)
  assert(chunk:find("REFL_PAD = 0", 1, true), version)
  assert(chunk:find("REFL_BRIDGE = { 0, 28, 44 }", 1, true), version)
  assert(chunk:find("CUT_HOLD = 1", 1, true), version)
  assert(chunk:find("CUT_X = 0", 1, true), version)
  assert(chunk:find("CUT_Y = 0", 1, true), version)
  assert(chunk:find("LEAF_STEP = 1", 1, true), version)
  assert(chunk:find("LEAF_GRAVITY = 0", 1, true), version)
  assert(chunk:find("SMASH_HOLD = 1", 1, true), version)
  assert(chunk:find("SMASH_STEP = 1", 1, true), version)
  assert(chunk:find("SMASH_GRAVITY = 0", 1, true), version)
  assert(chunk:find("GRASS_BASE = 0", 1, true), version)
  assert(chunk:find("GRASS_SPREAD = 0", 1, true), version)
  assert(chunk:find("GRASS_LIFT = 0", 1, true), version)
  assert(chunk:find("GRASS_SPOT = 0", 1, true), version)
  assert(chunk:find("SMASH_BASE = 0", 1, true), version)
  assert(chunk:find("SMASH_SPREAD = 0", 1, true), version)
  assert(chunk:find("SMASH_LIFT = 0", 1, true), version)
  assert(chunk:find("SMASH_JITTER = 0", 1, true), version)
  assert(chunk:find("SMASH_SPOT = 0", 1, true), version)
  assert(chunk:find("GRASS_FRAMES = 0", 1, true), version)
  assert(chunk:find("SCENT_FRAMES = 1", 1, true), version)
  assert(chunk:find("SCENT_RADIUS = 0", 1, true), version)
  assert(chunk:find("SCENT_GAP = 0", 1, true), version)
  assert(chunk:find("SCENT_X = 0", 1, true), version)
  assert(chunk:find("SCENT_Y = 0", 1, true), version)
  assert(chunk:find("SPLASH_HOLD = 0", 1, true), version)
  assert(chunk:find("SPLASH_PICS = { 0 }", 1, true), version)
  assert(chunk:find("DUST_PICS = { 0 }", 1, true), version)
  assert(chunk:find("DUST_HOLD = 0", 1, true), version)
  assert(chunk:find("RUSTLE_HOLD = 0", 1, true), version)
  assert(chunk:find("RUSTLE = { 0 }", 1, true), version)
  assert(chunk:find("FEET_HOLD = { 0, 4, 6, 6, 8, 8, 6, 6 }", 1, true), version)
  assert(chunk:find("FEET_PICS = { 0 }", 1, true), version)
  assert(chunk:find("FEET_H = 1", 1, true), version)
  assert(chunk:find("GRASS_SLACK = 0", 1, true), version)
  assert(chunk:find("RIPPLE_Y = 0", 1, true), version)
  assert(chunk:find("SHORT_LIFT = 0", 1, true), version)
  assert(chunk:find("SAND_LIFT = 0", 1, true), version)
  assert(chunk:find("TIRE_BLINK = 0", 1, true), version)
  assert(chunk:find("TIRE_END = 0", 1, true), version)
  assert(chunk:find("SURF_W = 1", 1, true), version)
  assert(chunk:find("SURF_H = 1", 1, true), version)
  assert(chunk:find("SURF_FRAMES = 1", 1, true), version)
  assert(chunk:find("BIRD_W = 1", 1, true), version)
  assert(chunk:find("BIRD_H = 1", 1, true), version)
  assert(chunk:find("BIRD_FRAMES = 1", 1, true), version)
  assert(chunk:find("PLACE = 0", 1, true), version)
  assert(chunk:find("SPLASH_DROP = 0", 1, true), version)
  assert(chunk:find("BUBBLE_Y = 0", 1, true), version)
  assert(chunk:find("BUBBLE_RISE = 0", 1, true), version)
  assert(chunk:find("BERRY_Y = 0", 1, true), version)
  assert(chunk:find("PILLAR_Y = 0", 1, true), version)
  assert(chunk:find("SPARKLE_WAIT = 0", 1, true), version)
  assert(chunk:find("SAND_FRAME = 0", 1, true), version)
  assert(chunk:find("DISTORT = { { 0, 1 } }", 1, true), version)
  assert(chunk:find("TIRE_TRANSITIONS = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }", 1, true), version)
  assert(chunk:find("RIPPLE_PICS = { 0 }", 1, true), version)
  assert(chunk:find("RIPPLE_HOLD = { 0, 9, 9, 9, 9, 9, 11, 11 }", 1, true), version)
  assert(chunk:find("SURF_HOLD = 1", 1, true), version)
  assert(chunk:find("BLOB_X = 0", 1, true), version)
  assert(chunk:find("BLOB_Y = 0", 1, true), version)
  assert(chunk:find("BLOB_BOB = 0", 1, true), version)
  assert(chunk:find("TRACK_BLINK = 0", 1, true), version)
  assert(chunk:find("TRACK_END = 0", 1, true), version)
  assert(chunk:find("SHAKE_EVERY = 1", 1, true), version)
  assert(chunk:find("SHAKE_AMP = 0", 1, true), version)
  assert(chunk:find("SHAKE_FADE = 1", 1, true), version)
  assert(chunk:find("ROCK_WAIT = 0", 1, true), version)
  assert(chunk:find("ROCK_AMP = 0", 1, true), version)
  assert(chunk:find("ROCK_DECAY = 1", 1, true), version)
  assert(chunk:find("FRAG_X = 0", 1, true), version)
  assert(chunk:find("FRAG_Y = 0", 1, true), version)
  assert(chunk:find("SHARD_X = 0", 1, true), version)
  assert(chunk:find("SHARD_Y = 0", 1, true), version)
  assert(chunk:find("ROCK_HOLD = 1", 1, true), version)
  assert(chunk:find("ROCK_FLIP = 1", 1, true), version)
  assert(chunk:find("ROCK_FOOT_X = 0", 1, true), version)
  assert(chunk:find("ROCK_FOOT_Y = 0", 1, true), version)
  assert(chunk:find("ROCK_TOP = 0", 1, true), version)
  assert(chunk:find("FLY_SWOOP = 0", 1, true), version)
  assert(chunk:find("FLY_MOUNT = 0", 1, true), version)
  assert(chunk:find("FLY_OFF = 0", 1, true), version)
  assert(chunk:find("FLY_IN = 0", 1, true), version)
  assert(chunk:find("FLY_POSE = 0", 1, true), version)
  assert(chunk:find("FLY_END = 0", 1, true), version)
  assert(chunk:find("TP_SPIN = 0", 1, true), version)
  assert(chunk:find("TP_TURNS = 0", 1, true), version)
  assert(chunk:find("TP_RISE_TURN = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_FIRST = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_EVERY = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_CAP = 0", 1, true), version)
  assert(chunk:find("TP_LIFT = 0", 1, true), version)
  assert(chunk:find("TP_VANISH = 0", 1, true), version)
  assert(chunk:find("TP_DROP = 0", 1, true), version)
  assert(chunk:find("TP_DROP_TURN = 0", 1, true), version)
  assert(chunk:find("TP_SLOW = 0", 1, true), version)
  assert(chunk:find("TP_GROUND = 0", 1, true), version)
  assert(chunk:find("TP_LAND = 0", 1, true), version)
  assert(chunk:find("TP_LAND_TURNS = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_X = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_Y = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_STEP = 1", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_END = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_X = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_Y = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_STEP = 1", 1, true), version)
  assert(chunk:find("BIRD_RIDE_END = 0", 1, true), version)
  assert(chunk:find("BALL_WIDE = 0", 1, true), version)
  assert(chunk:find("BALL_PUSH = 0", 1, true), version)
  assert(chunk:find("BALL_CAP = 0", 1, true), version)
  assert(chunk:find("BALL_END = 0", 1, true), version)
  assert(chunk:find("BALL_ANGLE = 0", 1, true), version)
  assert(chunk:find("BALL_SPEED = 0", 1, true), version)
  assert(chunk:find("RETURN_WIDE = 0", 1, true), version)
  assert(chunk:find("RETURN_HIGH = 0", 1, true), version)
  assert(chunk:find("RETURN_ANGLE = 0", 1, true), version)
  assert(chunk:find("RETURN_SPEED = 0", 1, true), version)
  assert(chunk:find("RETURN_BRAKE = 0", 1, true), version)
  assert(chunk:find("RETURN_GROW = 0", 1, true), version)
  assert(chunk:find("RETURN_FLOOR = 0", 1, true), version)
  assert(chunk:find("RETURN_BRAKE_CAP = 0", 1, true), version)
  assert(chunk:find("RETURN_END = 0", 1, true), version)
  assert(chunk:find("LEAVE_SCALE = 0", 1, true), version)
  assert(chunk:find("LEAVE_TILT = 0", 1, true), version)
  assert(chunk:find("LEAVE_FRAMES = 0", 1, true), version)
  assert(chunk:find("LEAVE_GROW = 0", 1, true), version)
  assert(chunk:find("SHRINK_SCALE = 0", 1, true), version)
  assert(chunk:find("SHRINK_TILT = 0", 1, true), version)
  assert(chunk:find("SHRINK_FRAMES = 0", 1, true), version)
  assert(chunk:find("SHRINK_STEP = 0", 1, true), version)
  assert(chunk:find("AWAY_GROW = 0", 1, true), version)
  assert(chunk:find("ARRIVE_POP = 0", 1, true), version)
  assert(chunk:find("ARRIVE_SHRINK = 0", 1, true), version)
  assert(chunk:find("FLASH_FRAMES = 1", 1, true), version)
  assert(chunk:find("VEIL_FRAMES = 1", 1, true), version)
  assert(chunk:find("MOUNT_ARC = { 0 }", 1, true), version)
  assert(chunk:find("DISMOUNT_ARC = { 0 }", 1, true), version)
  assert(chunk:find("POP_BOY = 0", 1, true), version)
  assert(chunk:find("POP_GIRL = 0", 1, true), version)
  assert(chunk:find("POP_Y = 0", 1, true), version)
  assert(chunk:find("BACK_BOY = 0", 1, true), version)
  assert(chunk:find("BACK_GIRL = 0", 1, true), version)
  assert(chunk:find("BACK_Y = 0", 1, true), version)
  assert(chunk:find("DIVE_X = 0", 1, true), version)
  assert(chunk:find("DIVE_Y = 0", 1, true), version)
  assert(chunk:find("RIDE_X = 0", 1, true), version)
  assert(chunk:find("RIDE_Y = 0", 1, true), version)
  assert(chunk:find("SEAT = 0", 1, true), version)
  assert(chunk:find("BIRD_NUDGE = 0", 1, true), version)
  assert(chunk:find("TP_START = 0", 1, true), version)
  assert(chunk:find("BOY_AWAY = 0", 1, true), version)
  assert(chunk:find("GIRL_AWAY = 0", 1, true), version)
  assert(chunk:find("BOY_HOME = 0", 1, true), version)
  assert(chunk:find("GIRL_HOME = 0", 1, true), version)
  assert(chunk:find("BIRD_REST = 0", 1, true), version)
  assert(chunk:find("DELAYS.MEDIUM[1] = 0", 1, true), version)
  assert(chunk:find("ROTATE_FRAMES = 1", 1, true), version)
  assert(chunk:find("Objects.WALK_FRAMES = 1", 1, true), version)
  assert(chunk:find("Objects.RUN_FRAMES = 2", 1, true), version)
  assert(chunk:find("Objects.RUN_SLOW_FRAMES = 3", 1, true), version)
  assert(chunk:find("LEV_STEP = 1", 1, true), version)
  assert(chunk:find("LEV_TURN = 1", 1, true), version)
  assert(chunk:find("LEV_PIXEL = 0", 1, true), version)
  assert(chunk:find("FIG8_X = { 3 }", 1, true), version)
  assert(chunk:find("FIG8_Y = { -2 }", 1, true), version)
  assert(chunk:find("COPY_FOR = { { 4 } }", 1, true), version)
  assert(chunk:find("EMOTE_A = 0", 1, true), version)
  assert(chunk:find("EMOTE_B = 0", 1, true), version)
  assert(not chunk:find("EMOTE_HOP", 1, true), version)
  assert(not chunk:find("BERRY_BLINK", 1, true), version)
  assert(not chunk:find("JUMP_FAR_FRAMES", 1, true), version)
  assert(chunk:find("JUMP_Y.normal = { -9, 0 }", 1, true), version)
  assert(chunk:find("SURF_HOP_Y = { 0 }", 1, true), version)
  assert(not chunk:find("bike.rse", 1, true), version)
end
for _, version in ipairs({ "ruby", "sapphire", "emerald" }) do
  local out = {}
  Counters.emit({ version = version, generation = 3, stepCounters = { seekerCharge = 0, bikeCall = 0, bikeCap = 0, npcStep = 0, g3Walk = 1, g3Run = 2, g3Turn = 0, g3Bike = 3, g3Jump = 5, g3Slow = 7, g3Fast = 1, g3RunCycle = 1, g3RunPose = 0, approachGap = 0, emoteFrames = 0, markStep = 0, markLift = 0, markGap = 0, markBang = 0, markBang2 = 0, markX = 0, markSmile = 0, markAsk = 0, reflDrop = 0, reflCull = 0, reflPad = 0, reflBridge1 = 0, cutHold = 1, cutX = 0, cutY = 0, leafStep = 1, leafFall = 0, grassBase = 0, grassSpread = 0, grassLift = 0, grassSpot = 0, smashHold = 1, smashStep = 1, smashFall = 0, smashBase = 0, smashSpread = 0, smashLift = 0, smashJitter = 0, smashSpot = 0, grassFrames = 0, scentFrames = 1, scentRadius = 0, scentGap = 0, scentX = 0, scentY = 0, splashHold = 0, splashPics = "0", dustHold = 0, dustPics = "0", rustleHold = 0, rustlePics = "0", feetPics = "0", feetH = 1, grassSlack = 0, rippleY = 0, shortLift = 0, sandLift = 0, tireBlink = 0, tireEnd = 0, surfW = 1, surfH = 1, surfFrames = 1, birdW = 1, birdH = 1, birdFrames = 1, place = 0, splashDrop = 0, bubbleY = 0, bubbleRise = 0, berryY = 0, pillarY = 0, sparkleWait = 0, sandFrame = 0, distort = "0, 1", tireTurns = "0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0", ripplePics = "0", feetHold = "0, 4, 6, 6, 8, 8, 6, 6", rippleHold = "0, 9, 9, 9, 9, 9, 11, 11", surfHold = 1, blobX = 0, blobY = 0, blobBob = 0, trackBlink = 0, trackEnd = 0, shakeEvery = 1, shakeAmp = 0, shakeFade = 1, rockWait = 0, rockAmp = 0, rockDecay = 1, fragX = 0, fragY = 0, shardX = 0, shardY = 0, rockHold = 1, rockFlip = 1, rockFootX = 0, rockFootY = 0, rockTop = 0, flySwoop = 0, flyMount = 0, flyOff = 0, flyIn = 0, flyPose = 0, flyEnd = 0, tpSpin = 0, tpTurns = 0, tpRiseTurn = 0, tpSpeedFirst = 0, tpSpeedEvery = 0, tpSpeedCap = 0, tpLift = 0, tpVanish = 0, tpDrop = 0, tpDropTurn = 0, tpSlow = 0, tpGround = 0, tpLand = 0, tpLandTurns = 0, birdSwoopX = 0, birdSwoopY = 0, birdSwoopStep = 1, birdSwoopEnd = 0, birdRideX = 0, birdRideY = 0, birdRideStep = 1, birdRideEnd = 0, ballWide = 0, ballPush = 0, ballCap = 0, ballEnd = 0, ballAngle = 0, ballSpeed = 0, returnWide = 0, returnHigh = 0, returnAngle = 0, returnSpeed = 0, returnBrake = 0, returnGrow = 0, returnFloor = 0, returnBrakeCap = 0, returnEnd = 0, leaveScale = 0, leaveTilt = 0, leaveFrames = 0, leaveGrow = 0, shrinkScale = 0, shrinkTilt = 0, shrinkFrames = 0, shrinkStep = 0, awayGrow = 0, arrivePop = 0, arriveShrink = 0, flashFrames = 1, veilFrames = 1, mountArc = "0", dismountArc = "0", popBoy = 0, popGirl = 0, popY = 0, backBoy = 0, backGirl = 0, backY = 0, diveX = 0, diveY = 0, rideX = 0, rideY = 0, seat = 0, birdNudge = 0, tpStart = 0, boyAway = 0, girlAway = 0, boyHome = 0, girlHome = 0, birdRest = 0, g3Med1 = 0, g3Rotate = 1, g3NpcWalk = 1, g3NpcRun = 2, g3NpcSlow = 3, g3LevStep = 1, g3LevTurn = 1, g3LevPixel = 0, fig8X = "3", fig8Y = "-2", copyFor = "4", rseCoast = 1, rseSpeed = 2, rseTop = 3, rseAcro = 4, rseHop = 5, rseLedge = 6, rseWindow = 0, rseBump = 1, rseTurnBump = 2, rseWheelie = 3, g3NpcHop = 5, g3NpcFar = 9, hopArc = "-9, 0", playerHopHigh = "-1", surfHop = "0", berryBlink = 1, berrySparkle = 0, emoteHop = 0, emoteGravity = 0, fishWait = 0, fishDot = 0, fishDots = 0, fishFirst = 0, waterfall = 1, tradeFade = 1, tradeHold = 0, tradeBye = 0, tradeDepart = 0, tradeReturn = 1, tradeClose = 0, tradeFlash = 0, tradeArrived = 0, tradeMon = 0, tradeFanfare = 0, tradeFanfareRs = 0, tradeCare = 0, tradeCareRs = 0, tradeAfter = 0, tradeSave = 0, tradeJitter = 0, tradeLink = 0, tradeOpen = 0, animPause = 0, anneHorn = 0, anneSmoke = 0, anneSlide = 1, anneLeave = 0, wakeStep = 0, wakeCap = 0, wakeFlip = 0, wakeX = 0, wakeCull = 0, wakeY = 0, wakeLift = 0, smokeStep = 0, smokeA = 0, smokeB = 0, smokeC = 0, smokeEnd = 0, smokeSpawn = 0, smokeCull = 0, smokeY = 0, smokeLift = 0, boatGone = 0, ferryCross = 0, ferryMusic = 0, dudeScroll = 0, oakDim = 0, oakWait = 0, arenaPause = 0, slideStart = 0, slideStep = 1, ballSound = 0, ballFly = 0, ballBounce = 0, ballRest = 0, ballEnd = 0, zoomMax = 0, zoomMin = 0, zoomStep = 1, zoomFar = 0, flashAnim = 0, gbaTop = 0, panEnd = 0, cableEnd = 0, travelEnd = 0, linkY = 0, linkOff = 0, crossStep = 1, crossEnter = 0, crossExit = 0, crossMon = 0, crossAy = 0, crossBy = 0, arriveY = 0, arriveAt = 0, gbaCenter = 0, ballDrop = 0, ballLand = 0, ballFall = 1, ballIdx = 0, ballStop = 0, bounce2 = 0, bounce3 = 0, bounce4 = 0, ballVel = "0", g3HealX = 0, g3HealY = 0, g3HealMonX = 0, g3HealMonY = 0, g3HealNudgeX = 0, g3HealNudgeY = 0, g3HealMonNudgeX = 0, g3HealMonNudgeY = 0, g3HealGap = 0, g3HealEnd = 0, g3HealGlow = 0, g3HealLaps = 0, g3HealRest = 0, g3HealMonLaps = 0, g3HealOffs = "0, 0", g3HealSeq = "0", g3HealDurs = "0", g3GlowK = "0", g3GlowSlots = "0", g3GlowLead = "0", g3FishBase = "1, 1, 1, 1", g3FishOut = "0, 1", g3FishSn = "1, 1", g3FishWe = "2, 1", g3FishHook = "3, 1", g3FishOff = "1, 0, 0, 0", g3FieldMove = "4, 1", g3VsSeq = "5, 1", g3VsBike = "6, 1", g3Bow = 0, g3Stand = "1, 1, 1, 1", g3WalkA = "2, 2, 2, 2", g3WalkB = "3, 3, 3, 3", g3RunStill = "4, 4, 4, 4", g3RunA = "5, 5, 5, 5", g3RunB = "6, 6, 6, 6", g3Flash = "0", screenH = 1 } }, function() return "{}" end, out)
  local chunk = table.concat(out, "\n")
  assert(not chunk:find("MAX_CHARGE", 1, true), version)
  assert(not chunk:find("BIKE_CALL_STEPS", 1, true), version)
  assert(not chunk:find("BIKE_STEP_MAX", 1, true), version)
  assert(not chunk:find("STEP_FRAMES", 1, true), version)
  assert(not chunk:find("SPIN_FRAMES", 1, true), version)
  assert(not chunk:find("gen2.Player", 1, true), version)
  assert(not chunk:find("BOUNCE_PERIOD", 1, true), version)
  assert(not chunk:find("WANDER_LO", 1, true), version)
  assert(not chunk:find("SLOW_SPIN", 1, true), version)
  assert(not chunk:find("TOUCH_TURN_FRAMES", 1, true), version)
  assert(chunk:find("WALK_FRAMES = 1", 1, true), version)
  assert(chunk:find("RUN_FRAMES = 2", 1, true), version)
  assert(chunk:find("Avatar.TURN_FRAMES = 0", 1, true), version)
  assert(chunk:find("BIKE_FRAMES = 3", 1, true), version)
  assert(chunk:find("JUMP_FRAMES = 5", 1, true), version)
  assert(chunk:find("RUN_SLOW_FRAMES = 7", 1, true), version)
  assert(chunk:find("FASTER_FRAMES = 1", 1, true), version)
  assert(chunk:find("RUN_CYCLE = 1", 1, true), version)
  assert(chunk:find("RUN_POSE = 0", 1, true), version)
  assert(chunk:find("FISHING_WAIT_FRAMES = 0", 1, true), version)
  assert(chunk:find("FISHING_DOT_FRAMES = 0", 1, true), version)
  assert(chunk:find("FISHING_DOT_MAX = 0", 1, true), version)
  assert(chunk:find("FISHING_FIRST_ROUND_DOTS = 0", 1, true), version)
  assert(chunk:find("WALK_SLOWER_FRAMES = 1", 1, true), version)
  assert(chunk:find("FADE_FRAMES = 1", 1, true), version)
  assert(chunk:find("HOLD_FRAMES = 0", 1, true), version)
  assert(chunk:find("BYE_BYE_DELAY = 0", 1, true), version)
  assert(chunk:find("TAKE_CARE_AT = 0", 1, true), version)
  assert(chunk:find("TAKE_CARE_RS = 0", 1, true), version)
  assert(chunk:find("LINK_CLOSE_HOLD = 0", 1, true), version)
  assert(chunk:find("natives_trade\").FADE_FRAMES = 0", 1, true), version)
  assert(chunk:find("PAUSE_SHORT = 0", 1, true), version)
  assert(chunk:find("INIT_FRAMES = 0", 1, true), version)
  assert(chunk:find("SMOKE_INTERVAL = 0", 1, true), version)
  assert(chunk:find("SLIDE_SPEED_DIV = 1", 1, true), version)
  assert(chunk:find("FINISH_FRAMES = 0", 1, true), version)
  assert(chunk:find("WAKE_STEP = 1", 1, true), version)
  assert(chunk:find("WAKE_CAP = 0", 1, true), version)
  assert(chunk:find("SMOKE_END = 0", 1, true), version)
  assert(chunk:find("BOAT_GONE = 0", 1, true), version)
  assert(chunk:find("SMOKE_CULL = 0", 1, true), version)
  assert(chunk:find("CROSSING_FRAMES = 0", 1, true), version)
  assert(chunk:find("MUSIC_FADE_FRAMES = 0", 1, true), version)
  assert(chunk:find("POKEDUDE_AUTO_SCROLL = 0", 1, true), version)
  assert(chunk:find("OAK_DIM_TARGET = 0", 1, true), version)
  assert(chunk:find("OAK_DIM_DELAY = 0", 1, true), version)
  assert(chunk:find("B_WAIT_TIME_LONG = 0", 1, true), version)
  assert(chunk:find("MON_SLIDE_HOFS = 0", 1, true), version)
  assert(chunk:find("MON_SLIDE_STEP = 1", 1, true), version)
  assert(chunk:find("ZOOM_MAX = 0", 1, true), version)
  assert(chunk:find("CROSS_ENTER_LIMIT = 0", 1, true), version)
  assert(chunk:find("BALL_ARRIVE_END = 0", 1, true), version)
  assert(chunk:find("DISPLAY_HEIGHT = 1", 1, true), version)
  assert(chunk:find("BALL_BOUNCE_2 = 0", 1, true), version)
  assert(chunk:find("BALL_BOUNCE_4 = 0", 1, true), version)
  assert(chunk:find("BALL_VELOCITY = { [0] = 0 }", 1, true), version)
  assert(chunk:find("BALL_CENTER_X = 0", 1, true), version)
  assert(chunk:find("PLACE_FRAMES = 0", 1, true), version)
  assert(chunk:find("FLASH_LOOPS = 0", 1, true), version)
  assert(chunk:find("BALL_OFFSETS = { { 0, 0 } }", 1, true), version)
  assert(chunk:find("MONITOR_SEQ = { 0 }", 1, true), version)
  assert(chunk:find("MONITOR_DURS = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_K = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_INDICES = { 0 }", 1, true), version)
  assert(chunk:find("GLOW_LEAD = { 0 }", 1, true), version)
  assert(chunk:find("FISH_BASE = { down = 1, up = 1, left = 1, right = 1 }", 1, true), version)
  assert(chunk:find("FISH_TAKE_OUT = { 0, 1 }", 1, true), version)
  assert(chunk:find("FISH_PUT_AWAY_SN = { 1, 1 }", 1, true), version)
  assert(chunk:find("FISH_PUT_AWAY_WE = { 2, 1 }", 1, true), version)
  assert(chunk:find("FISH_HOOKED = { 3, 1 }", 1, true), version)
  assert(chunk:find("FISH_OFFS = { { 1, 0, 0, 0 } }", 1, true), version)
  assert(chunk:find("FIELD_MOVE_SEQ = { 4, 1 }", 1, true), version)
  assert(chunk:find("VS_SEEKER_SEQ = { 5, 1 }", 1, true), version)
  assert(chunk:find("VS_SEEKER_BIKE_SEQ = { 6, 1 }", 1, true), version)
  assert(chunk:find("BOW_FRAME = 0", 1, true), version)
  assert(chunk:find("STAND = { down = 1, up = 1, left = 1, right = 1 }", 1, true), version)
  assert(chunk:find("WALK_A = { down = 2, up = 2, left = 2, right = 2 }", 1, true), version)
  assert(chunk:find("WALK_B = { down = 3, up = 3, left = 3, right = 3 }", 1, true), version)
  assert(chunk:find("RUN_BASE = { down = 4, up = 4, left = 4, right = 4 }", 1, true), version)
  assert(chunk:find("RUN_A = { down = 5, up = 5, left = 5, right = 5 }", 1, true), version)
  assert(chunk:find("RUN_B = { down = 6, up = 6, left = 6, right = 6 }", 1, true), version)
  assert(chunk:find("FLASH_LEVEL_RADIUS = { [0] = 0 }", 1, true), version)
  assert(chunk:find("trainer_sight\").APPROACH_GAP = 0", 1, true), version)
  assert(chunk:find("field_effects\").EMOTE_FRAMES = 0", 1, true), version)
  assert(chunk:find("MARK_STEP = 0", 1, true), version)
  assert(chunk:find("REFL_DROP = 0", 1, true), version)
  assert(chunk:find("REFL_CULL = 0", 1, true), version)
  assert(chunk:find("REFL_PAD = 0", 1, true), version)
  assert(chunk:find("REFL_BRIDGE = { 0, 28, 44 }", 1, true), version)
  assert(chunk:find("CUT_HOLD = 1", 1, true), version)
  assert(chunk:find("CUT_X = 0", 1, true), version)
  assert(chunk:find("CUT_Y = 0", 1, true), version)
  assert(chunk:find("LEAF_STEP = 1", 1, true), version)
  assert(chunk:find("LEAF_GRAVITY = 0", 1, true), version)
  assert(chunk:find("SMASH_HOLD = 1", 1, true), version)
  assert(chunk:find("SMASH_STEP = 1", 1, true), version)
  assert(chunk:find("SMASH_GRAVITY = 0", 1, true), version)
  assert(chunk:find("GRASS_BASE = 0", 1, true), version)
  assert(chunk:find("GRASS_SPREAD = 0", 1, true), version)
  assert(chunk:find("GRASS_LIFT = 0", 1, true), version)
  assert(chunk:find("GRASS_SPOT = 0", 1, true), version)
  assert(chunk:find("SMASH_BASE = 0", 1, true), version)
  assert(chunk:find("SMASH_SPREAD = 0", 1, true), version)
  assert(chunk:find("SMASH_LIFT = 0", 1, true), version)
  assert(chunk:find("SMASH_JITTER = 0", 1, true), version)
  assert(chunk:find("SMASH_SPOT = 0", 1, true), version)
  assert(chunk:find("GRASS_FRAMES = 0", 1, true), version)
  assert(chunk:find("SCENT_FRAMES = 1", 1, true), version)
  assert(chunk:find("SCENT_RADIUS = 0", 1, true), version)
  assert(chunk:find("SCENT_GAP = 0", 1, true), version)
  assert(chunk:find("SCENT_X = 0", 1, true), version)
  assert(chunk:find("SCENT_Y = 0", 1, true), version)
  assert(chunk:find("SPLASH_HOLD = 0", 1, true), version)
  assert(chunk:find("SPLASH_PICS = { 0 }", 1, true), version)
  assert(chunk:find("DUST_PICS = { 0 }", 1, true), version)
  assert(chunk:find("DUST_HOLD = 0", 1, true), version)
  assert(chunk:find("RUSTLE_HOLD = 0", 1, true), version)
  assert(chunk:find("RUSTLE = { 0 }", 1, true), version)
  assert(chunk:find("FEET_HOLD = { 0, 4, 6, 6, 8, 8, 6, 6 }", 1, true), version)
  assert(chunk:find("FEET_PICS = { 0 }", 1, true), version)
  assert(chunk:find("FEET_H = 1", 1, true), version)
  assert(chunk:find("GRASS_SLACK = 0", 1, true), version)
  assert(chunk:find("RIPPLE_Y = 0", 1, true), version)
  assert(chunk:find("SHORT_LIFT = 0", 1, true), version)
  assert(chunk:find("SAND_LIFT = 0", 1, true), version)
  assert(chunk:find("TIRE_BLINK = 0", 1, true), version)
  assert(chunk:find("TIRE_END = 0", 1, true), version)
  assert(chunk:find("SURF_W = 1", 1, true), version)
  assert(chunk:find("SURF_H = 1", 1, true), version)
  assert(chunk:find("SURF_FRAMES = 1", 1, true), version)
  assert(chunk:find("BIRD_W = 1", 1, true), version)
  assert(chunk:find("BIRD_H = 1", 1, true), version)
  assert(chunk:find("BIRD_FRAMES = 1", 1, true), version)
  assert(chunk:find("PLACE = 0", 1, true), version)
  assert(chunk:find("SPLASH_DROP = 0", 1, true), version)
  assert(chunk:find("BUBBLE_Y = 0", 1, true), version)
  assert(chunk:find("BUBBLE_RISE = 0", 1, true), version)
  assert(chunk:find("BERRY_Y = 0", 1, true), version)
  assert(chunk:find("PILLAR_Y = 0", 1, true), version)
  assert(chunk:find("SPARKLE_WAIT = 0", 1, true), version)
  assert(chunk:find("SAND_FRAME = 0", 1, true), version)
  assert(chunk:find("DISTORT = { { 0, 1 } }", 1, true), version)
  assert(chunk:find("TIRE_TRANSITIONS = { { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { 0, 0, 0, 0 } }", 1, true), version)
  assert(chunk:find("RIPPLE_PICS = { 0 }", 1, true), version)
  assert(chunk:find("RIPPLE_HOLD = { 0, 9, 9, 9, 9, 9, 11, 11 }", 1, true), version)
  assert(chunk:find("SURF_HOLD = 1", 1, true), version)
  assert(chunk:find("BLOB_X = 0", 1, true), version)
  assert(chunk:find("BLOB_Y = 0", 1, true), version)
  assert(chunk:find("BLOB_BOB = 0", 1, true), version)
  assert(chunk:find("TRACK_BLINK = 0", 1, true), version)
  assert(chunk:find("TRACK_END = 0", 1, true), version)
  assert(chunk:find("SHAKE_EVERY = 1", 1, true), version)
  assert(chunk:find("SHAKE_AMP = 0", 1, true), version)
  assert(chunk:find("SHAKE_FADE = 1", 1, true), version)
  assert(chunk:find("ROCK_WAIT = 0", 1, true), version)
  assert(chunk:find("ROCK_AMP = 0", 1, true), version)
  assert(chunk:find("ROCK_DECAY = 1", 1, true), version)
  assert(chunk:find("FRAG_X = 0", 1, true), version)
  assert(chunk:find("FRAG_Y = 0", 1, true), version)
  assert(chunk:find("SHARD_X = 0", 1, true), version)
  assert(chunk:find("SHARD_Y = 0", 1, true), version)
  assert(chunk:find("ROCK_HOLD = 1", 1, true), version)
  assert(chunk:find("ROCK_FLIP = 1", 1, true), version)
  assert(chunk:find("ROCK_FOOT_X = 0", 1, true), version)
  assert(chunk:find("ROCK_FOOT_Y = 0", 1, true), version)
  assert(chunk:find("ROCK_TOP = 0", 1, true), version)
  assert(chunk:find("FLY_SWOOP = 0", 1, true), version)
  assert(chunk:find("FLY_MOUNT = 0", 1, true), version)
  assert(chunk:find("FLY_OFF = 0", 1, true), version)
  assert(chunk:find("FLY_IN = 0", 1, true), version)
  assert(chunk:find("FLY_POSE = 0", 1, true), version)
  assert(chunk:find("FLY_END = 0", 1, true), version)
  assert(chunk:find("TP_SPIN = 0", 1, true), version)
  assert(chunk:find("TP_TURNS = 0", 1, true), version)
  assert(chunk:find("TP_RISE_TURN = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_FIRST = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_EVERY = 0", 1, true), version)
  assert(chunk:find("TP_SPEED_CAP = 0", 1, true), version)
  assert(chunk:find("TP_LIFT = 0", 1, true), version)
  assert(chunk:find("TP_VANISH = 0", 1, true), version)
  assert(chunk:find("TP_DROP = 0", 1, true), version)
  assert(chunk:find("TP_DROP_TURN = 0", 1, true), version)
  assert(chunk:find("TP_SLOW = 0", 1, true), version)
  assert(chunk:find("TP_GROUND = 0", 1, true), version)
  assert(chunk:find("TP_LAND = 0", 1, true), version)
  assert(chunk:find("TP_LAND_TURNS = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_X = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_Y = 0", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_STEP = 1", 1, true), version)
  assert(chunk:find("BIRD_SWOOP_END = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_X = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_Y = 0", 1, true), version)
  assert(chunk:find("BIRD_RIDE_STEP = 1", 1, true), version)
  assert(chunk:find("BIRD_RIDE_END = 0", 1, true), version)
  assert(chunk:find("BALL_WIDE = 0", 1, true), version)
  assert(chunk:find("BALL_PUSH = 0", 1, true), version)
  assert(chunk:find("BALL_CAP = 0", 1, true), version)
  assert(chunk:find("BALL_END = 0", 1, true), version)
  assert(chunk:find("BALL_ANGLE = 0", 1, true), version)
  assert(chunk:find("BALL_SPEED = 0", 1, true), version)
  assert(chunk:find("RETURN_WIDE = 0", 1, true), version)
  assert(chunk:find("RETURN_HIGH = 0", 1, true), version)
  assert(chunk:find("RETURN_ANGLE = 0", 1, true), version)
  assert(chunk:find("RETURN_SPEED = 0", 1, true), version)
  assert(chunk:find("RETURN_BRAKE = 0", 1, true), version)
  assert(chunk:find("RETURN_GROW = 0", 1, true), version)
  assert(chunk:find("RETURN_FLOOR = 0", 1, true), version)
  assert(chunk:find("RETURN_BRAKE_CAP = 0", 1, true), version)
  assert(chunk:find("RETURN_END = 0", 1, true), version)
  assert(chunk:find("LEAVE_SCALE = 0", 1, true), version)
  assert(chunk:find("LEAVE_TILT = 0", 1, true), version)
  assert(chunk:find("LEAVE_FRAMES = 0", 1, true), version)
  assert(chunk:find("LEAVE_GROW = 0", 1, true), version)
  assert(chunk:find("SHRINK_SCALE = 0", 1, true), version)
  assert(chunk:find("SHRINK_TILT = 0", 1, true), version)
  assert(chunk:find("SHRINK_FRAMES = 0", 1, true), version)
  assert(chunk:find("SHRINK_STEP = 0", 1, true), version)
  assert(chunk:find("AWAY_GROW = 0", 1, true), version)
  assert(chunk:find("ARRIVE_POP = 0", 1, true), version)
  assert(chunk:find("ARRIVE_SHRINK = 0", 1, true), version)
  assert(chunk:find("FLASH_FRAMES = 1", 1, true), version)
  assert(chunk:find("VEIL_FRAMES = 1", 1, true), version)
  assert(chunk:find("MOUNT_ARC = { 0 }", 1, true), version)
  assert(chunk:find("DISMOUNT_ARC = { 0 }", 1, true), version)
  assert(chunk:find("POP_BOY = 0", 1, true), version)
  assert(chunk:find("POP_GIRL = 0", 1, true), version)
  assert(chunk:find("POP_Y = 0", 1, true), version)
  assert(chunk:find("BACK_BOY = 0", 1, true), version)
  assert(chunk:find("BACK_GIRL = 0", 1, true), version)
  assert(chunk:find("BACK_Y = 0", 1, true), version)
  assert(chunk:find("DIVE_X = 0", 1, true), version)
  assert(chunk:find("DIVE_Y = 0", 1, true), version)
  assert(chunk:find("RIDE_X = 0", 1, true), version)
  assert(chunk:find("RIDE_Y = 0", 1, true), version)
  assert(chunk:find("SEAT = 0", 1, true), version)
  assert(chunk:find("BIRD_NUDGE = 0", 1, true), version)
  assert(chunk:find("TP_START = 0", 1, true), version)
  assert(chunk:find("BOY_AWAY = 0", 1, true), version)
  assert(chunk:find("GIRL_AWAY = 0", 1, true), version)
  assert(chunk:find("BOY_HOME = 0", 1, true), version)
  assert(chunk:find("GIRL_HOME = 0", 1, true), version)
  assert(chunk:find("BIRD_REST = 0", 1, true), version)
  assert(chunk:find("DELAYS.MEDIUM[1] = 0", 1, true), version)
  assert(chunk:find("ROTATE_FRAMES = 1", 1, true), version)
  assert(chunk:find("Objects.WALK_FRAMES = 1", 1, true), version)
  assert(chunk:find("Objects.RUN_FRAMES = 2", 1, true), version)
  assert(chunk:find("Objects.RUN_SLOW_FRAMES = 3", 1, true), version)
  assert(chunk:find("LEV_STEP = 1", 1, true), version)
  assert(chunk:find("LEV_TURN = 1", 1, true), version)
  assert(chunk:find("LEV_PIXEL = 0", 1, true), version)
  assert(chunk:find("FIG8_X = { 3 }", 1, true), version)
  assert(chunk:find("FIG8_Y = { -2 }", 1, true), version)
  assert(chunk:find("COPY_FOR = { { 4 } }", 1, true), version)
  assert(chunk:find("EMOTE_HOP = 0", 1, true), version)
  assert(chunk:find("EMOTE_GRAVITY = 0", 1, true), version)
  assert(chunk:find("MARK_LIFT = 0", 1, true), version)
  assert(chunk:find("MARK_GAP = 0", 1, true), version)
  assert(chunk:find("MARK_BANG = 0", 1, true), version)
  assert(chunk:find("MARK_BANG2 = 0", 1, true), version)
  assert(chunk:find("MARK_X = 0", 1, true), version)
  assert(chunk:find("MARK_SMILE = 0", 1, true), version)
  assert(chunk:find("MARK_ASK = 0", 1, true), version)
  assert(not chunk:find("EMOTE_A", 1, true), version)
  assert(chunk:find("BERRY_BLINK = 1", 1, true), version)
  assert(chunk:find("BERRY_SPARKLE = 0", 1, true), version)
  assert(chunk:find("FRAMES.NORMAL = 1", 1, true), version)
  assert(chunk:find("FRAMES.FAST_1 = 2", 1, true), version)
  assert(chunk:find("FRAMES.FASTER = 3", 1, true), version)
  assert(chunk:find("FRAMES.FAST_2 = 4", 1, true), version)
  assert(chunk:find("JUMP.NORMAL = 5", 1, true), version)
  assert(chunk:find("JUMP.FAR = 6", 1, true), version)
  assert(chunk:find("JUMP_TIMER = 0", 1, true), version)
  assert(chunk:find("IN_PLACE.NORMAL = 1", 1, true), version)
  assert(chunk:find("IN_PLACE.FAST = 2", 1, true), version)
  assert(chunk:find("WHEELIE_FRAMES = 3", 1, true), version)
  assert(chunk:find("objects\").JUMP_FRAMES = 5", 1, true), version)
  assert(chunk:find("JUMP_FAR_FRAMES = 9", 1, true), version)
  assert(chunk:find("JUMP_Y.normal = { -9, 0 }", 1, true), version)
  assert(chunk:find("JUMP_Y.high = { -1 }", 1, true), version)
  assert(chunk:find("SURF_HOP_Y = { 0 }", 1, true), version)
  assert(not chunk:find("REMATCH_DICE", 1, true), version)
end

local G3Field = require("src.core.game3.field")
assertEq(G3Field.fishWait(), 60, "a cast waits 60 frames")
G3Field.FISHING_WAIT_FRAMES = 0
assertEq(G3Field.fishWait(), 0, "a cast of 0 does not wait")
G3Field.FISHING_WAIT_FRAMES = 60
assertEq(G3Field.fishMax(), 10, "the line asks for up to 10 dots")
G3Field.FISHING_DOT_MAX = 0
assertEq(G3Field.fishMax(), 0, "a dot cap of 0 asks for none")
G3Field.FISHING_DOT_MAX = 10
assertEq(G3Field.waterfallFrames(), 32, "a waterfall step takes 32 frames")
G3Field.WALK_SLOWER_FRAMES = 0
assertEq(G3Field.waterfallFrames(), 1, "a waterfall step stays at least one frame")
G3Field.WALK_SLOWER_FRAMES = 32
local Trade = require("src.core.game3.trade_scene")
assertEq(Trade.fadeFrames(), 16, "a trade fades for 16 frames")
Trade.FADE_FRAMES = 0
assertEq(Trade.fadeFrames(), 1, "a trade fade stays at least one frame")
Trade.FADE_FRAMES = 16
assertEq(Trade.holdFrames(), 60, "a trade holds for 60 frames")
Trade.HOLD_FRAMES = 0
assertEq(Trade.holdFrames(), 0, "a trade hold of 0 does not wait")
Trade.HOLD_FRAMES = 60
assertEq(Trade.takeCare(), 250, "FireRed and LeafGreen wait 250 frames")
assertEq(Trade.takeCareRs(), 240, "Ruby, Sapphire, and Emerald wait 240 frames")
assertEq(Trade.bounce2(), 66, "the second bounce sound is step 66")
assertEq(Trade.bounce4(), 107, "the fourth bounce sound is step 107")
Trade.BALL_BOUNCE_2 = 0
assertEq(Trade.bounce2(), 0, "a bounce sound of 0 plays on the first step")
Trade.BALL_BOUNCE_2 = 66
local cartCurve = Counters.arcList(Counters.BALL_VEL)
assertEq(#cartCurve, 108, "the cart bounce curve has 108 steps")
assertEq(Trade.ballVelocity(0), cartCurve[1], "the first bounce step matches the cart curve")
assertEq(Trade.ballVelocity(107), cartCurve[108], "the last bounce step matches the cart curve")
local savedCurve = Trade.BALL_VELOCITY
Trade.BALL_VELOCITY = { [0] = 4, -4 }
assertEq(Trade.ballVelocity(0), 4, "a saved curve keeps the first step")
assertEq(Trade.ballVelocity(2), 0, "a short curve leaves later steps still")
Trade.BALL_VELOCITY = savedCurve
local Heal = require("src.core.game3.pokecenter_heal")
local hx, hy = Heal._ballScreenTl(0)
assertEq(hx, 89, "the first Center ball sits at x 89")
assertEq(hy, 32, "the first Center ball sits at y 32")
assertEq(Heal.placeFrames(), 25, "each Center ball waits 25 frames")
assertEq(Heal.flashLoops(), 3, "the Center glow runs 3 laps")
Heal.FLASH_LOOPS = 0
assertEq(Heal.flashLoops(), 0, "a glow of 0 does not lap")
Heal.FLASH_LOOPS = 3
assertEq(Heal.monitorSeq()[1], 1, "the Center screen starts on frame 1")
local savedSeq = Heal.MONITOR_SEQ
Heal.MONITOR_SEQ = { 0 }
assertEq(Heal.monitorSeq()[1], 0, "a saved screen frame is the one shown")
Heal.MONITOR_SEQ = savedSeq
assertEq(Heal.glowK()[1], 16, "the Center glow starts at brightness 16")
assertEq(Heal.glowSlots()[1], 8, "the first glowing color is slot 8")
local savedGlow = Heal.GLOW_K
Heal.GLOW_K = { 0 }
assertEq(Heal.glowK()[1], 0, "a saved glow brightness is the one drawn")
Heal.GLOW_K = savedGlow
Trade.TAKE_CARE_AT = 0
assertEq(Trade.takeCare(), 0, "a take-care of 0 does not wait")
Trade.TAKE_CARE_AT = 250
local Anne = require("src.core.game3.ss_anne_cutscene")
assertEq(Anne.initFrames(), 50, "the ship waits 50 frames before it moves")
Anne.INIT_FRAMES = 0
assertEq(Anne.initFrames(), 0, "a ship horn of 0 does not wait")
Anne.INIT_FRAMES = 50
Anne.SLIDE_SPEED_DIV = 0
assertEq(Anne.slideDiv(), 1, "the ship still moves when the step is 0")
Anne.SLIDE_SPEED_DIV = 5
assertEq(Anne.wakeStep(), 6, "the wake moves every 6 frames")
Anne.WAKE_STEP = 0
assertEq(Anne.wakeStep(), 1, "a wake step of 0 still moves")
Anne.WAKE_STEP = 6
assertEq(Anne.wakeCap(), 22, "the wake grows for 22 steps")
assertEq(Anne.smokeEnd(), 80, "a puff lasts 80 frames")
assertEq(Anne.boatGone(), -120, "the ship is gone at -120")
Anne.BOAT_GONE = 0
assertEq(Anne.boatGone(), 0, "a gone line of 0 is the screen edge")
Anne.BOAT_GONE = -120
local Ferry = require("src.core.game3.scripting.natives_seagallop")
assertEq(Ferry.crossing(), 140, "the ferry crosses for 140 frames")
Ferry.CROSSING_FRAMES = 0
assertEq(Ferry.crossing(), 0, "a ferry cross of 0 does not wait")
Ferry.CROSSING_FRAMES = 140
local Ingame = require("src.core.game3.scripting.natives_trade")
assertEq(Ingame.fadeFrames(), 16, "an in-game trade opens for 16 frames")
Ingame.FADE_FRAMES = 0
assertEq(Ingame.fadeFrames(), 0, "a trade open of 0 does not wait")
Ingame.FADE_FRAMES = 16
assertEq(Trade.slideStart(), 180, "the traded mon slides in from 180")
Trade.MON_SLIDE_STEP = 0
assertEq(Trade.slideStep(), 1, "the slide still moves when the step is 0")
Trade.MON_SLIDE_STEP = 3
assertEq(Trade.zoomMax(), 1024, "the trade screen starts zoomed to 1024")
assertEq(Trade.crossEnter(), -90, "the crossing mons enter at -90")
Trade.CROSS_STEP = 0
assertEq(Trade.crossStep(), 1, "the crossing still moves when the step is 0")
Trade.CROSS_STEP = 3
local Ow = require("src.core.game3.ow_sprites")
assertEq(Ow.fishingAbsFrame("down", 0), 8, "facing down starts on fishing picture 8")
local savedBase = Ow.FISH_BASE
Ow.FISH_BASE = { down = 1, up = 1, left = 1, right = 1 }
assertEq(Ow.fishingAbsFrame("down", 0), 1, "a saved fishing picture is the one drawn")
Ow.FISH_BASE = savedBase
local leftX = Ow.fishingOffset(3, "left")
assertEq(leftX, -8, "facing left shifts the rod 8 pixels left")
local savedOut = Ow.FISH_TAKE_OUT
Ow.FISH_TAKE_OUT = { 7, 2 }
local fishFrame = Ow.fishingFrame("down", "takeout", 0)
assertEq(fishFrame, 7, "a saved rod-out frame is the one shown")
Ow.FISH_TAKE_OUT = savedOut
assertEq(Ow.sheetFrame("STAND", "down"), 0, "standing down is picture 0")
assertEq(Ow.bowFrame(), 9, "the bow is picture 9")
local standSheet = { frameCount = 9 }
local standFrame = Ow.pose(standSheet, "down", 0, false)
assertEq(standFrame, 0, "a standing player draws picture 0")
Ow.STAND = { down = 4, up = 4, left = 4, right = 4 }
standFrame = Ow.pose(standSheet, "down", 0, false)
assertEq(standFrame, 4, "a saved stand picture is the one drawn")
Ow.STAND = nil
Ow.BOW_FRAME = 2
assertEq(Ow.bowFrame(), 2, "a saved bow picture is the one drawn")
Ow.BOW_FRAME = nil
Ow.RUN_A = { down = 3, up = 3, left = 3, right = 3 }
local runFrame = Ow.pose({ frameCount = 18 }, "down", 0, true, { running = 1 })
assertEq(runFrame, 3, "a saved run step is the one drawn")
Ow.RUN_A = nil
local FieldView = require("src.core.game3.field_view")
assertEq(FieldView.radiusForLevel(1), 72, "the second Flash ring is 72 pixels")
FieldView.FLASH_LEVEL_RADIUS = { [0] = 10, 20 }
assertEq(FieldView.radiusForLevel(1), 20, "a saved Flash ring is the one drawn")
assertEq(FieldView.maxFlashLevel(), 1, "a two-number Flash list has two levels")
FieldView.FLASH_LEVEL_RADIUS = nil
print("PASS step counters")
