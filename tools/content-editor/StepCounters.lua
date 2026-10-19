-- How many steps a Gen 2 bike ride takes before the shop calls,
-- and how a FireRed or LeafGreen Vs. Seeker charges and rolls a rematch.
-- 0 steps means the bike call is ready on the first ride, and the Seeker is already full.
-- The rematch roll is 0 up to one less than the dice. A roll under the refuse line says no.

local M = {}

function M.get(S, key, default)
  local g = S.project and S.project.stepCounters
  if g and g[key] ~= nil then return g[key] end
  return default
end

function M.set(S, App, key, value, default)
  require("State").ensureProjectFields(S.project)
  S.project.stepCounters = S.project.stepCounters or {}
  S.project.stepCounters[key] = (value == default) and nil or value
  if not next(S.project.stepCounters) then S.project.stepCounters = nil end
  App.markDirty()
end

M.COPY_FOR = "2, 1, 4, 3, 1, 2, 3, 4, 3, 4, 2, 1, 4, 3, 1, 2"
M.COPY_TO = "2, 1, 4, 3, 1, 2, 3, 4, 4, 3, 1, 2, 3, 4, 2, 1"
M.MOUNT_ARC = "-4, -6, -8, -10, -11, -12, -12, -12, -11, -10, -9, -8, -6, -4, 0, 0"
M.DISMOUNT_ARC = "-2, -4, -5, -6, -7, -8, -8, -8, -7, -7, -6, -5, -3, -2, 0, 2, 4, 8"
M.SPLASH_PICS = "0, 1"
M.DUST_PICS = "0, 1, 2"
M.RUSTLE = "1, 2, 3, 4, 0"
M.DISTORT = "1, 4, 0, 8, -1, 4, 0, 8, -1, 4, 0, 8, 1, 4, 0, 8"
M.TIRE_TURNS = "1, 2, 7, 8, 1, 2, 6, 5, 5, 8, 3, 4, 6, 7, 3, 4"
M.FADE_WHITE = "3, 2, 1, 0, 2, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0"
M.G1_OUT_HOLDS = "15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0, 3, 3, 3, 3, 3, 0"
M.G1_PAD_HOLDS = "3, 3, 3, 3, 3, 0"
M.G1_IN_HOLDS = "3, 3, 3, 3, 3, 0, 1, 2, 3, 4, 5, 6, 7, 0"
M.G1_PAD_IN_HOLDS = "3, 3, 3, 3, 3, 3, 0"
M.G1_HOLE_HOLDS = "3, 3, 3, 3, 3, 0"
M.G1_SHIP_WATER = "1, 13"
M.G1_ROD = "4, 15, 0, 0, 4, -8, 0, 0, -8, 4, 1, 0, 16, 4, 1, 1"
M.G2_ROD = "0, 16, 0, 0, 0, -8, 0, 0, -8, 5, 1, 1, 16, 5, 1, 0"
M.G2_FISH_ROW = "0, 1, 2, 2"
M.G2_TOWER = "1, 2, 3, 4, 5, 4, 3, 2"
M.G2_SCROLL = "0, 1, 2, 3, 2, 1, 0, -1"
M.G2_WATER = "1, 1, 2, 2, 3, 3, 4, 4"
M.G2_WHIRL_ROWS = "1, 2, 3, 4, 1, 2, 3, 4"
M.G2_LAVA = "3, 3, 4, 4, 1, 1, 2, 2"
M.G2_LAVA2 = "1, 1, 2, 2, 3, 3, 4, 4"
M.G1_HEAL_BALLS = "40, 27, 0, 48, 27, 1, 40, 32, 0, 48, 32, 1, 40, 37, 0, 48, 37, 1"
M.G1_HEAL_DMG = "0, 2, 1, 3"
M.G1_HEAL_GBC = "0, 0, 1, 2"
M.G1_HEAL_LIT = "0, 0, 2, 3"
M.G1_HEAL_DIM = "0, 2, 0, 3"
M.BALL_VEL = "0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, -4, -4, -4, -3, -3, -3, -3, -2, -2, -2, -2, -1, -1, -1, -1, 0, -1, 0, -1, 0, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 4, 4, 4, 4, -4, -3, -3, -2, -2, -1, -1, -1, 0, -1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 2, 2, 3, 3, 4, -4, -3, -2, -1, -1, -1, 0, 0, 0, 0, 1, 0, 1, 1, 2, 3"
M.HEAL_PC_MACHINE = "26, 16, 30, 16"
M.HEAL_PC_BALLS = "24, 22, 0, 32, 22, 1, 24, 27, 0, 32, 27, 1, 24, 32, 0, 32, 32, 1"
M.HEAL_HOF = "73, 44, 0, 78, 44, 0, 69, 43, 0, 82, 43, 0, 65, 41, 0, 85, 41, 0"
M.G3_HEAL_OFFS = "0, 0, 6, 0, 0, 4, 6, 4, 0, 8, 6, 8"
M.G3_HEAL_SEQ = "1, 2, 3, 2, 1, 0"
M.G3_HEAL_DURS = "5, 5, 7, 5, 5, 5"
M.G3_GLOW_K = "16, 12, 8, 0"
M.G3_GLOW_SLOTS = "8, 6, 2, 5, 3"
M.G3_GLOW_LEAD = "3, 2, 1, 0, 0"
M.G3_FISH_BASE = "8, 4, 0, 0"
M.G3_FISH_OUT = "0, 4, 1, 4, 2, 4, 3, 4"
M.G3_FISH_SN = "3, 4, 2, 6, 1, 6, 0, 6"
M.G3_FISH_WE = "3, 4, 2, 4, 1, 4, 0, 4"
M.G3_FISH_HOOK = "2, 6, 3, 6, 2, 6, 3, 6, 3, 30"
M.G3_FISH_OFF = "1, 8, -8, 0, 2, 8, -8, 0, 3, 8, -8, 0, 5, 0, 0, -8, 10, 0, 0, 8, 11, 0, 0, 8"
M.G3_FIELD_MOVE = "0, 4, 1, 4, 2, 4, 3, 4, 4, 8"
M.G3_VS_SEQ = "0, 4, 1, 4, 5, 4, 6, 4, 7, 4, 8, 4, 7, 4, 8, 4, 7, 4, 8, 4, 7, 4, 8, 4, 7, 4, 8, 4, 7, 4, 8, 4, 7, 4, 8, 4, 6, 4, 1, 4, 0, 4"
M.G3_VS_BIKE = "0, 4, 1, 4, 2, 4, 3, 4, 4, 4, 5, 4, 4, 4, 5, 4, 4, 4, 5, 4, 4, 4, 5, 4, 4, 4, 5, 4, 4, 4, 5, 4, 4, 4, 5, 4, 3, 4, 2, 4, 1, 4, 0, 4"
M.G3_STAND = "0, 1, 2, 2"
M.G3_WALK_A = "3, 5, 7, 7"
M.G3_WALK_B = "4, 6, 8, 8"
M.G3_RUN_STILL = "9, 12, 15, 15"
M.G3_RUN_A = "10, 13, 16, 16"
M.G3_RUN_B = "11, 14, 17, 17"
M.G3_RUN_STILL_E = "9, 10, 11, 11"
M.G3_RUN_A_E = "12, 14, 16, 16"
M.G3_RUN_B_E = "13, 15, 17, 17"
M.G3_FLASH = "200, 72, 56, 40, 24"
M.G3_FLASH_RSE = "200, 72, 64, 56, 48, 40, 32, 24, 0"
M.G1_FLY_OUT = "60, 72, 60, 80, 59, 88, 58, 96, 57, 104, 55, 112, 55, 120, 51, 128, 48, 136, 45, 144, 42, 152, 39, 160"
M.G1_FLY_AWAY = "26, 144, 25, 128, 23, 112, 21, 96, 18, 80, 15, 64, 12, 48, 9, 32, 5, 16, 0, 0, -16, 0"
M.G1_FLY_IN = "5, 152, 15, 144, 24, 136, 32, 128, 39, 120, 45, 112, 50, 104, 54, 96, 57, 88, 59, 80, 60, 72, 60, 64"
M.G1_FLY_ANCHOR = "60, 72"
M.G1_FLY_LAND = "60, 64"
M.FADE_BLACK = "3, 2, 1, 0, 3, 3, 2, 1, 3, 3, 3, 2, 3, 3, 3, 3"
M.FEET_PICS = "0, 1, 0, 1, 0, 1, 0, 1"
M.RIPPLE_PICS = "0, 1, 2, 3, 0, 1, 2, 4"
M.FEET_HOLD = "4, 4, 6, 6, 8, 8, 6, 6"
M.RIPPLE_HOLD = "12, 9, 9, 9, 9, 9, 11, 11"
M.FIG8_X = "1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 2, 2, 1, 2, 2, 1, 2, 2, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 0, 1, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0"
M.FIG8_Y = "0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, -1, -1, 0, -1, -1, 0, -1, -1, -1, -1, -1, -1, -1, -2"
local ARC_KIND = { hopArc = "normal", hopArcHigh = "high", hopArcLow = "low" }

function M.copyRows(text)
  local list = M.arcList(text)
  if not list then return nil end
  local rows = {}
  for i, n in ipairs(list) do
    local row = math.floor((i - 1) / 4) + 1
    rows[row] = rows[row] or {}
    rows[row][(i - 1) % 4 + 1] = n
  end
  return rows
end

function M.shadeRows(text)
  local list = M.holdList(text)
  if not list or #list < 4 then return nil end
  local n = #list - (#list % 4)
  local rows = {}
  for i = 1, n, 4 do
    local row = {}
    for c = 0, 3 do
      local v = list[i + c]
      if v > 3 then v = 3 end
      row[#row + 1] = v
    end
    rows[#rows + 1] = row
  end
  return rows
end

function M.holdList(text)
  if type(text) ~= "string" then return nil end
  local out = {}
  for token in text:gmatch("%d+") do
    local n = math.floor(tonumber(token) or 0)
    if n > 255 then n = 255 end
    out[#out + 1] = n
  end
  if #out == 0 then return nil end
  return out
end

function M.pairList(text)
  if type(text) ~= "string" then return nil end
  local nums = {}
  for token in text:gmatch("-?%d+") do
    local n = math.floor(tonumber(token) or 0)
    if n < -512 then n = -512 end
    if n > 512 then n = 512 end
    nums[#nums + 1] = n
  end
  if #nums < 2 then return nil end
  local out = {}
  for i = 1, #nums - 1, 2 do
    out[#out + 1] = { nums[i], nums[i + 1] }
  end
  if #out == 0 then return nil end
  return out
end

function M.pairText(rows)
  local parts = {}
  for i = 1, #rows do parts[i] = "{ " .. rows[i][1] .. ", " .. rows[i][2] .. " }" end
  return table.concat(parts, ", ")
end

function M.numText(rows)
  local parts = {}
  for i = 1, #rows do parts[i] = tostring(rows[i]) end
  return table.concat(parts, ", ")
end

function M.quadList(text)
  if type(text) ~= "string" then return nil end
  local nums = {}
  for token in text:gmatch("-?%d+") do
    nums[#nums + 1] = math.floor(tonumber(token) or 0)
  end
  if #nums < 4 then return nil end
  local out = {}
  for i = 1, #nums - 3, 4 do
    local frame = nums[i]
    local x, left, y = nums[i + 1], nums[i + 2], nums[i + 3]
    if frame < 0 then frame = 0 end
    if frame > 255 then frame = 255 end
    if x < -128 then x = -128 end
    if x > 127 then x = 127 end
    if left < -128 then left = -128 end
    if left > 127 then left = 127 end
    if y < -128 then y = -128 end
    if y > 127 then y = 127 end
    out[#out + 1] = { frame = frame, x = x, left = left, y = y }
  end
  if #out == 0 then return nil end
  return out
end

function M.quadText(rows)
  local parts = {}
  for i = 1, #rows do
    local row = rows[i]
    parts[i] = "{ " .. row.frame .. ", " .. row.x .. ", " .. row.left .. ", " .. row.y .. " }"
  end
  return table.concat(parts, ", ")
end

function M.tripleList(text)
  if type(text) ~= "string" then return nil end
  local nums = {}
  for token in text:gmatch("-?%d+") do
    nums[#nums + 1] = math.floor(tonumber(token) or 0)
  end
  if #nums < 3 then return nil end
  local out = {}
  for i = 1, #nums - 2, 3 do
    local x, y = nums[i], nums[i + 1]
    if x < -512 then x = -512 end
    if x > 512 then x = 512 end
    if y < -512 then y = -512 end
    if y > 512 then y = 512 end
    out[#out + 1] = { x, y, nums[i + 2] ~= 0 }
  end
  if #out == 0 then return nil end
  return out
end

function M.rodText(rows)
  local parts = {}
  for i = 1, #rows do
    local row = rows[i]
    local flip = row.flip and ", flip = true" or ""
    parts[i] = row.face .. " = { dx = " .. row.dx .. ", dy = " .. row.dy
      .. ", tile = " .. row.tile .. flip .. " }"
  end
  return table.concat(parts, ", ")
end

function M.rodList(text)
  if type(text) ~= "string" then return nil end
  local nums = {}
  for token in text:gmatch("-?%d+") do
    nums[#nums + 1] = math.floor(tonumber(token) or 0)
  end
  if #nums < 16 then return nil end
  local faces = { "down", "up", "left", "right" }
  local out = {}
  for i = 1, 4 do
    local b = (i - 1) * 4
    local dx, dy = nums[b + 1], nums[b + 2]
    local tile = nums[b + 3]
    if dx < -128 then dx = -128 end
    if dx > 127 then dx = 127 end
    if dy < -128 then dy = -128 end
    if dy > 127 then dy = 127 end
    if tile < 0 then tile = 0 end
    if tile > 15 then tile = 15 end
    out[i] = { face = faces[i], dx = dx, dy = dy, tile = tile, flip = nums[b + 4] ~= 0 }
  end
  return out
end

function M.arcList(text)
  if type(text) ~= "string" then return nil end
  local out = {}
  for token in text:gmatch("-?%d+") do
    local n = math.floor(tonumber(token) or 0)
    if n < -128 then n = -128 end
    if n > 127 then n = 127 end
    out[#out + 1] = n
  end
  if #out == 0 then return nil end
  return out
end

local function take(g, key, minV, maxV)
  local n = tonumber(g[key])
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

function M.emit(p, encode, out)
  local g = p.stepCounters
  if type(g) ~= "table" then return end
  local ver = p.game or p.version
  local gen = ver and require("Generation").num({version=ver}) or p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  local frlg = ver == "firered" or ver == "leafgreen"
  local rse = ver == "ruby" or ver == "sapphire" or ver == "emerald"
  local lines = {}
  local function gen3Move()
    local walk = take(g, "g3Walk", 1, 255)
    local run = take(g, "g3Run", 1, 255)
    local turn = take(g, "g3Turn", 0, 255)
    local bike = take(g, "g3Bike", 1, 255)
    local jump = take(g, "g3Jump", 1, 255)
    local slow = take(g, "g3Slow", 1, 255)
    local faster = take(g, "g3Fast", 1, 255)
    local approach = take(g, "approachGap", 0, 255)
    local emote = take(g, "emoteFrames", 0, 255)
    local markStep = take(g, "markStep", 0, 255)
    local emoteA = take(g, "emoteA", 0, 255)
    local emoteB = take(g, "emoteB", 0, 255)
    local emoteHop = take(g, "emoteHop", -128, 127)
    local emoteGravity = take(g, "emoteGravity", -128, 127)
    local markLift = take(g, "markLift", 0, 255)
    local markGap = take(g, "markGap", 0, 255)
    local markBang = take(g, "markBang", 0, 255)
    local markBang2 = take(g, "markBang2", 0, 255)
    local markX = take(g, "markX", 0, 255)
    local markSmile = take(g, "markSmile", 0, 255)
    local markAsk = take(g, "markAsk", 0, 255)
    local reflDrop = take(g, "reflDrop", -128, 127)
    local reflCull = take(g, "reflCull", 0, 255)
    local reflPad = take(g, "reflPad", 0, 255)
    local reflB1 = take(g, "reflBridge1", 0, 255)
    local reflB2 = take(g, "reflBridge2", 0, 255)
    local reflB3 = take(g, "reflBridge3", 0, 255)
    local cutHold = take(g, "cutHold", 1, 255)
    local cutX = take(g, "cutX", -128, 127)
    local cutY = take(g, "cutY", -128, 127)
    local leafStep = take(g, "leafStep", 1, 255)
    local leafFall = g and tonumber(g.leafFall)
    local function puff(key)
      local n = tonumber(g[key])
      if n == nil then return nil end
      if n < 0 then n = 0 end
      if n > 10 then n = 10 end
      return n
    end
    local grassBase = puff("grassBase")
    local grassSpread = puff("grassSpread")
    local grassLift = puff("grassLift")
    local grassSpot = take(g, "grassSpot", 0, 255)
    local smashHold = take(g, "smashHold", 1, 255)
    local smashStep = take(g, "smashStep", 1, 255)
    local smashFall = g and tonumber(g.smashFall)
    local smashBase = puff("smashBase")
    local smashSpread = puff("smashSpread")
    local smashLift = puff("smashLift")
    local smashJitter = puff("smashJitter")
    local smashSpot = take(g, "smashSpot", 0, 255)
    local grassFrames = take(g, "grassFrames", 0, 255)
    local scentFrames = take(g, "scentFrames", 1, 255)
    local scentRadius = take(g, "scentRadius", 0, 255)
    local scentGap = take(g, "scentGap", 0, 255)
    local scentX = take(g, "scentX", 0, 255)
    local scentY = take(g, "scentY", 0, 255)
    local splashHold = take(g, "splashHold", 0, 255)
    local splashPics = M.holdList(g.splashPics)
    local dustPics = M.holdList(g.dustPics)
    local dustHold = take(g, "dustHold", 0, 255)
    local rustleHold = take(g, "rustleHold", 0, 255)
    local rustle = M.holdList(g.rustlePics)
    local feetPics = M.holdList(g.feetPics)
    local feetH = take(g, "feetH", 1, 16)
    local grassSlack = take(g, "grassSlack", 0, 255)
    local rippleY = take(g, "rippleY", -128, 127)
    local shortLift = take(g, "shortLift", -128, 127)
    local sandLift = take(g, "sandLift", -128, 127)
    local tireBlink = take(g, "tireBlink", 0, 255)
    local tireEnd = take(g, "tireEnd", 0, 255)
    local ripplePics = M.holdList(g.ripplePics)
    local feet = M.holdList(g.feetHold)
    local ripple = M.holdList(g.rippleHold)
    local surfHold = take(g, "surfHold", 1, 255)
    local surfW = take(g, "surfW", 1, 255)
    local surfH = take(g, "surfH", 1, 255)
    local surfFrames = take(g, "surfFrames", 1, 255)
    local birdW = take(g, "birdW", 1, 255)
    local birdH = take(g, "birdH", 1, 255)
    local birdFrames = take(g, "birdFrames", 1, 255)
    local place = take(g, "place", 0, 255)
    local splashDrop = take(g, "splashDrop", 0, 255)
    local bubbleY = take(g, "bubbleY", 0, 255)
    local bubbleRise = puff("bubbleRise")
    local berryY = take(g, "berryY", 0, 255)
    local pillarY = take(g, "pillarY", 0, 255)
    local sparkleWait = take(g, "sparkleWait", 0, 255)
    local sandFrame = take(g, "sandFrame", 0, 255)
    local distort = M.arcList(g.distort)
    local tireTurns = M.holdList(g.tireTurns)
    local blobX = take(g, "blobX", -128, 127)
    local blobY = take(g, "blobY", -128, 127)
    local blobBob = take(g, "blobBob", -128, 127)
    local trackBlink = take(g, "trackBlink", 0, 255)
    local trackEnd = take(g, "trackEnd", 0, 255)
    local shakeEvery = take(g, "shakeEvery", 1, 255)
    local shakeAmp = take(g, "shakeAmp", 0, 255)
    local shakeFade = take(g, "shakeFade", 1, 255)
    local rockWait = take(g, "rockWait", 0, 255)
    local rockAmp = take(g, "rockAmp", 0, 255)
    local rockDecay = take(g, "rockDecay", 1, 255)
    local fragX = take(g, "fragX", 0, 9999)
    local fragY = take(g, "fragY", 0, 9999)
    local shardX = take(g, "shardX", 0, 255)
    local shardY = take(g, "shardY", 0, 255)
    local rockHold = take(g, "rockHold", 1, 255)
    local rockFlip = take(g, "rockFlip", 1, 255)
    local rockFootX = take(g, "rockFootX", -128, 127)
    local rockFootY = take(g, "rockFootY", -128, 127)
    local rockTop = take(g, "rockTop", 0, 255)
    local flySwoop = take(g, "flySwoop", 0, 255)
    local flyMount = take(g, "flyMount", 0, 255)
    local flyOff = take(g, "flyOff", 0, 255)
    local flyIn = take(g, "flyIn", 0, 255)
    local flyPose = take(g, "flyPose", 0, 255)
    local flyEnd = take(g, "flyEnd", 0, 255)
    local tpKeys = {
      { "tpSpin", "TP_SPIN" }, { "tpTurns", "TP_TURNS" }, { "tpRiseTurn", "TP_RISE_TURN" },
      { "tpSpeedFirst", "TP_SPEED_FIRST" }, { "tpSpeedEvery", "TP_SPEED_EVERY" },
      { "tpSpeedCap", "TP_SPEED_CAP" }, { "tpLift", "TP_LIFT" }, { "tpVanish", "TP_VANISH" },
      { "tpDrop", "TP_DROP" }, { "tpDropTurn", "TP_DROP_TURN" }, { "tpSlow", "TP_SLOW" },
      { "tpGround", "TP_GROUND" }, { "tpLand", "TP_LAND" }, { "tpLandTurns", "TP_LAND_TURNS" },
    }
    local tpTaken = {}
    local tpSet = false
    for i = 1, #tpKeys do
      local n = take(g, tpKeys[i][1], 0, 255)
      tpTaken[i] = n
      if n ~= nil then tpSet = true end
    end
    local birdKeys = {
      { "birdSwoopX", "BIRD_SWOOP_X", 0 }, { "birdSwoopY", "BIRD_SWOOP_Y", 0 },
      { "birdSwoopStep", "BIRD_SWOOP_STEP", 1 }, { "birdSwoopEnd", "BIRD_SWOOP_END", 0 },
      { "birdRideX", "BIRD_RIDE_X", 0 }, { "birdRideY", "BIRD_RIDE_Y", 0 },
      { "birdRideStep", "BIRD_RIDE_STEP", 1 }, { "birdRideEnd", "BIRD_RIDE_END", 0 },
    }
    local birdTaken = {}
    local birdSet = false
    for i = 1, #birdKeys do
      local n = take(g, birdKeys[i][1], birdKeys[i][3], 255)
      birdTaken[i] = n
      if n ~= nil then birdSet = true end
    end
    local spawnKeys = {
      { "popBoy", "POP_BOY", 0, 255 }, { "popGirl", "POP_GIRL", 0, 255 },
      { "popY", "POP_Y", -128, 127 },
      { "backBoy", "BACK_BOY", 0, 255 }, { "backGirl", "BACK_GIRL", 0, 255 },
      { "backY", "BACK_Y", -128, 127 },
      { "diveX", "DIVE_X", 0, 255 }, { "diveY", "DIVE_Y", -128, 127 },
    }
    local spawnTaken = {}
    local spawnSet = false
    for i = 1, #spawnKeys do
      local n = take(g, spawnKeys[i][1], spawnKeys[i][3], spawnKeys[i][4])
      spawnTaken[i] = n
      if n ~= nil then spawnSet = true end
    end
    local rideKeys = {
      { "rideX", "RIDE_X" }, { "rideY", "RIDE_Y" }, { "seat", "SEAT" },
      { "birdNudge", "BIRD_NUDGE" }, { "tpStart", "TP_START" },
      { "boyAway", "BOY_AWAY" }, { "girlAway", "GIRL_AWAY" },
      { "boyHome", "BOY_HOME" }, { "girlHome", "GIRL_HOME" },
      { "birdRest", "BIRD_REST" },
    }
    local rideTaken = {}
    local rideSet = false
    for i = 1, #rideKeys do
      local n = take(g, rideKeys[i][1], 0, 255)
      rideTaken[i] = n
      if n ~= nil then rideSet = true end
    end
    local ballKeys = {
      { "ballWide", "BALL_WIDE", 255 }, { "ballPush", "BALL_PUSH", 255 },
      { "ballCap", "BALL_CAP", 9999 }, { "ballEnd", "BALL_END", 255 },
      { "ballAngle", "BALL_ANGLE", 255 }, { "ballSpeed", "BALL_SPEED", 9999 },
    }
    local ballTaken = {}
    local ballSet = false
    for i = 1, #ballKeys do
      local n = take(g, ballKeys[i][1], 0, ballKeys[i][3])
      ballTaken[i] = n
      if n ~= nil then ballSet = true end
    end
    local backKeys = {
      { "returnWide", "RETURN_WIDE", 255 }, { "returnHigh", "RETURN_HIGH", 255 },
      { "returnAngle", "RETURN_ANGLE", 255 }, { "returnSpeed", "RETURN_SPEED", 9999 },
      { "returnBrake", "RETURN_BRAKE", 255 }, { "returnGrow", "RETURN_GROW", 255 },
      { "returnFloor", "RETURN_FLOOR", 9999 }, { "returnBrakeCap", "RETURN_BRAKE_CAP", 9999 },
      { "returnEnd", "RETURN_END", 255 },
    }
    local backTaken = {}
    local backSet = false
    for i = 1, #backKeys do
      local n = take(g, backKeys[i][1], 0, backKeys[i][3])
      backTaken[i] = n
      if n ~= nil then backSet = true end
    end
    local spinKeys = {
      { "leaveScale", "LEAVE_SCALE", 0, 9999 }, { "leaveTilt", "LEAVE_TILT", -128, 127 },
      { "leaveFrames", "LEAVE_FRAMES", 0, 255 }, { "leaveGrow", "LEAVE_GROW", 0, 255 },
      { "shrinkScale", "SHRINK_SCALE", 0, 9999 }, { "shrinkTilt", "SHRINK_TILT", -128, 127 },
      { "shrinkFrames", "SHRINK_FRAMES", 0, 255 }, { "shrinkStep", "SHRINK_STEP", 0, 255 },
      { "awayGrow", "AWAY_GROW", 0, 255 }, { "arrivePop", "ARRIVE_POP", 0, 9999 },
      { "arriveShrink", "ARRIVE_SHRINK", 0, 255 },
    }
    local spinTaken = {}
    local spinSet = false
    for i = 1, #spinKeys do
      local n = take(g, spinKeys[i][1], spinKeys[i][3], spinKeys[i][4])
      spinTaken[i] = n
      if n ~= nil then spinSet = true end
    end
    local flashFrames = take(g, "flashFrames", 1, 255)
    local veilFrames = take(g, "veilFrames", 1, 255)
    local mountArc = M.arcList(g.mountArc)
    local dismountArc = M.arcList(g.dismountArc)
    local runCycle = take(g, "g3RunCycle", 1, 255)
    local runPose = take(g, "g3RunPose", 0, 255)
    local npcWalk = take(g, "g3NpcWalk", 1, 65535)
    local npcRun = take(g, "g3NpcRun", 1, 65535)
    local npcSlow = take(g, "g3NpcSlow", 1, 65535)
    local levStep = take(g, "g3LevStep", 1, 255)
    local levTurn = take(g, "g3LevTurn", 1, 255)
    local levPixel = take(g, "g3LevPixel", 0, 255)
    local figX = M.arcList(g.fig8X)
    local figY = M.arcList(g.fig8Y)
    local copyFor = M.copyRows(g.copyFor)
    local copyTo = M.copyRows(g.copyTo)
    local fishWait = take(g, "fishWait", 0, 255)
    local fishDot = take(g, "fishDot", 0, 255)
    local fishDots = take(g, "fishDots", 0, 255)
    local fishFirst = take(g, "fishFirst", 0, 255)
    local waterfall = take(g, "waterfall", 1, 255)
    local tradeFade = take(g, "tradeFade", 1, 255)
    local tradeHold = take(g, "tradeHold", 0, 255)
    local tradeBye = take(g, "tradeBye", 0, 255)
    local tradeDepart = take(g, "tradeDepart", 0, 255)
    local tradeReturn = take(g, "tradeReturn", 1, 255)
    local tradeClose = take(g, "tradeClose", 0, 255)
    local tradeFlash = take(g, "tradeFlash", 0, 255)
    local tradeArrived = take(g, "tradeArrived", 0, 255)
    local tradeMon = take(g, "tradeMon", 0, 255)
    local tradeFanfare = take(g, "tradeFanfare", 0, 255)
    local tradeFanfareRs = take(g, "tradeFanfareRs", 0, 255)
    local tradeCare = take(g, "tradeCare", 0, 255)
    local tradeCareRs = take(g, "tradeCareRs", 0, 255)
    local tradeAfter = take(g, "tradeAfter", 0, 255)
    local tradeSave = take(g, "tradeSave", 0, 255)
    local tradeJitter = take(g, "tradeJitter", 0, 255)
    local tradeLink = take(g, "tradeLink", 0, 255)
    local tradeOpen = take(g, "tradeOpen", 0, 255)
    local animPause = take(g, "animPause", 0, 255)
    local anneHorn = take(g, "anneHorn", 0, 255)
    local anneSmoke = take(g, "anneSmoke", 0, 255)
    local anneSlide = take(g, "anneSlide", 1, 255)
    local anneLeave = take(g, "anneLeave", 0, 255)
    local anneFx = {
      wakeStep = take(g, "wakeStep", 1, 255),
      wakeCap = take(g, "wakeCap", 0, 255),
      wakeFlip = take(g, "wakeFlip", 1, 255),
      wakeX = take(g, "wakeX", 0, 255),
      wakeCull = take(g, "wakeCull", -512, 512),
      wakeY = take(g, "wakeY", 0, 255),
      wakeLift = take(g, "wakeLift", 0, 255),
      smokeStep = take(g, "smokeStep", 1, 255),
      smokeA = take(g, "smokeA", 0, 255),
      smokeB = take(g, "smokeB", 0, 255),
      smokeC = take(g, "smokeC", 0, 255),
      smokeEnd = take(g, "smokeEnd", 0, 255),
      smokeSpawn = take(g, "smokeSpawn", 0, 255),
      smokeCull = take(g, "smokeCull", -512, 512),
      smokeY = take(g, "smokeY", 0, 255),
      smokeLift = take(g, "smokeLift", 0, 255),
      boatGone = take(g, "boatGone", -512, 512),
    }
    local anneFxSet = false
    for _, v in pairs(anneFx) do
      if v ~= nil then anneFxSet = true break end
    end
    local ferryCross = take(g, "ferryCross", 0, 255)
    local ferryMusic = take(g, "ferryMusic", 0, 255)
    local dudeScroll = take(g, "dudeScroll", 0, 255)
    local oakDim = take(g, "oakDim", 0, 255)
    local oakWait = take(g, "oakWait", 0, 255)
    local arenaPause = take(g, "arenaPause", 0, 255)
    local motion = {
      slideStart = take(g, "slideStart", 0, 1024),
      slideStep = take(g, "slideStep", 1, 255),
      ballSound = take(g, "ballSound", 0, 255),
      ballFly = take(g, "ballFly", 0, 255),
      ballBounce = take(g, "ballBounce", 0, 255),
      ballRest = take(g, "ballRest", 0, 255),
      ballEnd = take(g, "ballEnd", 0, 255),
      zoomMax = take(g, "zoomMax", 0, 4096),
      zoomMin = take(g, "zoomMin", 0, 4096),
      zoomStep = take(g, "zoomStep", 1, 255),
      zoomFar = take(g, "zoomFar", 0, 4096),
      flashAnim = take(g, "flashAnim", 0, 255),
      gbaTop = take(g, "gbaTop", 0, 1024),
      panEnd = take(g, "panEnd", 0, 1024),
      cableEnd = take(g, "cableEnd", 0, 1024),
      travelEnd = take(g, "travelEnd", 0, 1024),
      linkY = take(g, "linkY", -512, 512),
      linkOff = take(g, "linkOff", -512, 512),
      crossStep = take(g, "crossStep", 1, 255),
      crossEnter = take(g, "crossEnter", -512, 512),
      crossExit = take(g, "crossExit", -512, 512),
      crossMon = take(g, "crossMon", -512, 512),
      crossAy = take(g, "crossAy", -512, 512),
      crossBy = take(g, "crossBy", -512, 512),
      arriveY = take(g, "arriveY", -512, 512),
      arriveAt = take(g, "arriveAt", -512, 512),
      gbaCenter = take(g, "gbaCenter", 0, 1024),
      ballDrop = take(g, "ballDrop", -512, 512),
      ballLand = take(g, "ballLand", -512, 512),
      ballFall = take(g, "ballFall", 1, 255),
      ballIdx = take(g, "ballIdx", 0, 255),
      ballStop = take(g, "ballStop", 0, 255),
      screenH = take(g, "screenH", 1, 255),
      bounce2 = take(g, "bounce2", 0, 255),
      bounce3 = take(g, "bounce3", 0, 255),
      bounce4 = take(g, "bounce4", 0, 255),
      ballX = take(g, "g3HealX", 0, 255),
      ballY = take(g, "g3HealY", 0, 255),
      monX = take(g, "g3HealMonX", 0, 255),
      monY = take(g, "g3HealMonY", 0, 255),
      nudgeX = take(g, "g3HealNudgeX", -512, 512),
      nudgeY = take(g, "g3HealNudgeY", -512, 512),
      monNudgeX = take(g, "g3HealMonNudgeX", -512, 512),
      monNudgeY = take(g, "g3HealMonNudgeY", -512, 512),
      gap = take(g, "g3HealGap", 0, 255),
      ending = take(g, "g3HealEnd", 0, 255),
      glow = take(g, "g3HealGlow", 0, 255),
      laps = take(g, "g3HealLaps", 0, 255),
      rest = take(g, "g3HealRest", 0, 255),
      monLaps = take(g, "g3HealMonLaps", 0, 255),
    }
    local motionSet = false
    for _, v in pairs(motion) do
      if v ~= nil then motionSet = true break end
    end
    local ballVel = M.arcList(g.ballVel)
    motion.offs = M.pairList(g.g3HealOffs)
    motion.seq = M.holdList(g.g3HealSeq)
    motion.durs = M.holdList(g.g3HealDurs)
    motion.glowK = M.holdList(g.g3GlowK)
    motion.glowSlots = M.holdList(g.g3GlowSlots)
    motion.glowLead = M.holdList(g.g3GlowLead)
    motion.fishBase = M.holdList(g.g3FishBase)
    if motion.fishBase and #motion.fishBase < 4 then motion.fishBase = nil end
    motion.fishOut = M.holdList(g.g3FishOut)
    motion.fishSn = M.holdList(g.g3FishSn)
    motion.fishWe = M.holdList(g.g3FishWe)
    motion.fishHook = M.holdList(g.g3FishHook)
    motion.fishOff = M.quadList(g.g3FishOff)
    motion.fieldMove = M.holdList(g.g3FieldMove)
    motion.vsSeq = M.holdList(g.g3VsSeq)
    motion.vsBike = M.holdList(g.g3VsBike)
    motion.bow = take(g, "g3Bow", 0, 255)
    motion.stand = M.holdList(g.g3Stand)
    if motion.stand and #motion.stand < 4 then motion.stand = nil end
    motion.walkA = M.holdList(g.g3WalkA)
    if motion.walkA and #motion.walkA < 4 then motion.walkA = nil end
    motion.walkB = M.holdList(g.g3WalkB)
    if motion.walkB and #motion.walkB < 4 then motion.walkB = nil end
    motion.runStill = M.holdList(g.g3RunStill)
    if motion.runStill and #motion.runStill < 4 then motion.runStill = nil end
    motion.runA = M.holdList(g.g3RunA)
    if motion.runA and #motion.runA < 4 then motion.runA = nil end
    motion.runB = M.holdList(g.g3RunB)
    if motion.runB and #motion.runB < 4 then motion.runB = nil end
    motion.flash = M.holdList(g.g3Flash)
    if walk == nil and run == nil and turn == nil and bike == nil and jump == nil and slow == nil and faster == nil and runCycle == nil and runPose == nil and approach == nil and emote == nil and markStep == nil and emoteA == nil and emoteB == nil and emoteHop == nil and emoteGravity == nil and markLift == nil and markGap == nil and markBang == nil and markBang2 == nil and markX == nil and markSmile == nil and markAsk == nil and reflDrop == nil and reflCull == nil and reflPad == nil and reflB1 == nil and reflB2 == nil and reflB3 == nil and cutHold == nil and cutX == nil and cutY == nil and leafStep == nil and leafFall == nil and grassBase == nil and grassSpread == nil and grassLift == nil and grassSpot == nil and smashHold == nil and smashStep == nil and smashFall == nil and smashBase == nil and smashSpread == nil and smashLift == nil and smashJitter == nil and smashSpot == nil and grassFrames == nil and scentFrames == nil and scentRadius == nil and scentGap == nil and scentX == nil and scentY == nil and splashHold == nil and not splashPics and dustHold == nil and not dustPics and rustleHold == nil and not rustle and not feetPics and feetH == nil and grassSlack == nil and rippleY == nil and shortLift == nil and sandLift == nil and tireBlink == nil and tireEnd == nil and not ripplePics and not feet and not ripple and surfHold == nil and surfW == nil and surfH == nil and surfFrames == nil and birdW == nil and birdH == nil and birdFrames == nil and place == nil and splashDrop == nil and bubbleY == nil and bubbleRise == nil and berryY == nil and pillarY == nil and sparkleWait == nil and sandFrame == nil and not distort and not tireTurns and blobX == nil and blobY == nil and blobBob == nil and trackBlink == nil and trackEnd == nil and shakeEvery == nil and shakeAmp == nil and shakeFade == nil and rockWait == nil and rockAmp == nil and rockDecay == nil and fragX == nil and fragY == nil and shardX == nil and shardY == nil and rockHold == nil and rockFlip == nil and rockFootX == nil and rockFootY == nil and rockTop == nil and flySwoop == nil and flyMount == nil and flyOff == nil and flyIn == nil and flyPose == nil and flyEnd == nil and not tpSet and not birdSet and not spawnSet and not rideSet and not ballSet and not backSet and not spinSet and flashFrames == nil and veilFrames == nil and not mountArc and not dismountArc and npcWalk == nil and npcRun == nil and npcSlow == nil and levStep == nil and levTurn == nil and levPixel == nil and not figX and not figY and not copyFor and not copyTo and fishWait == nil and fishDot == nil and fishDots == nil and fishFirst == nil and waterfall == nil and tradeFade == nil and tradeHold == nil and tradeBye == nil and tradeDepart == nil and tradeReturn == nil and tradeClose == nil and tradeFlash == nil and tradeArrived == nil and tradeMon == nil and tradeFanfare == nil and tradeFanfareRs == nil and tradeCare == nil and tradeCareRs == nil and tradeAfter == nil and tradeSave == nil and tradeJitter == nil and tradeLink == nil and tradeOpen == nil and animPause == nil and anneHorn == nil and anneSmoke == nil and anneSlide == nil and anneLeave == nil and not anneFxSet and ferryCross == nil and ferryMusic == nil and dudeScroll == nil and oakDim == nil and oakWait == nil and arenaPause == nil and not motionSet and not ballVel and not motion.offs and not motion.seq and not motion.durs and not motion.glowK and not motion.glowSlots and not motion.glowLead and not motion.fishBase and not motion.fishOut and not motion.fishSn and not motion.fishWe and not motion.fishHook and not motion.fishOff and not motion.fieldMove and not motion.vsSeq and not motion.vsBike and motion.bow == nil and not motion.stand and not motion.walkA and not motion.walkB and not motion.runStill and not motion.runA and not motion.runB and not motion.flash then return false end
    lines[#lines + 1] = "    local Avatar = require(\"src.core.game3.player\")"
    if walk ~= nil then lines[#lines + 1] = "    Avatar.WALK_FRAMES = " .. walk end
    if run ~= nil then lines[#lines + 1] = "    Avatar.RUN_FRAMES = " .. run end
    if turn ~= nil then lines[#lines + 1] = "    Avatar.TURN_FRAMES = " .. turn end
    if bike ~= nil then lines[#lines + 1] = "    Avatar.BIKE_FRAMES = " .. bike end
    if jump ~= nil then lines[#lines + 1] = "    Avatar.JUMP_FRAMES = " .. jump end
    if slow ~= nil then lines[#lines + 1] = "    Avatar.RUN_SLOW_FRAMES = " .. slow end
    if faster ~= nil then lines[#lines + 1] = "    Avatar.FASTER_FRAMES = " .. faster end
    if approach ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.trainer_sight\").APPROACH_GAP = " .. approach end
    if emote ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").EMOTE_FRAMES = " .. emote end
    if markStep ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_STEP = " .. markStep end
    if emoteA ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").EMOTE_A = " .. emoteA end
    if emoteB ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").EMOTE_B = " .. emoteB end
    if emoteHop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").EMOTE_HOP = " .. emoteHop end
    if emoteGravity ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").EMOTE_GRAVITY = " .. emoteGravity end
    if markLift ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_LIFT = " .. markLift end
    if markGap ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_GAP = " .. markGap end
    if markBang ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_BANG = " .. markBang end
    if markBang2 ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_BANG2 = " .. markBang2 end
    if markX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_X = " .. markX end
    if markSmile ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_SMILE = " .. markSmile end
    if markAsk ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").MARK_ASK = " .. markAsk end
    if reflDrop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").REFL_DROP = " .. reflDrop end
    if reflCull ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").REFL_CULL = " .. reflCull end
    if reflPad ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").REFL_PAD = " .. reflPad end
    if reflB1 ~= nil or reflB2 ~= nil or reflB3 ~= nil then
      local a, b, c = reflB1 or 12, reflB2 or 28, reflB3 or 44
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").REFL_BRIDGE = { " .. a .. ", " .. b .. ", " .. c .. " }"
    end
    if cutHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").CUT_HOLD = " .. cutHold end
    if cutX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").CUT_X = " .. cutX end
    if cutY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").CUT_Y = " .. cutY end
    if leafStep ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").LEAF_STEP = " .. leafStep end
    if leafFall ~= nil then
      if leafFall < 0 then leafFall = 0 end
      if leafFall > 10 then leafFall = 10 end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").LEAF_GRAVITY = " .. leafFall
    end
    if grassBase ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_BASE = " .. grassBase end
    if grassSpread ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_SPREAD = " .. grassSpread end
    if grassLift ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_LIFT = " .. grassLift end
    if grassSpot ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_SPOT = " .. grassSpot end
    if smashHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_HOLD = " .. smashHold end
    if smashStep ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_STEP = " .. smashStep end
    if smashFall ~= nil then
      if smashFall < 0 then smashFall = 0 end
      if smashFall > 10 then smashFall = 10 end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_GRAVITY = " .. smashFall
    end
    if smashBase ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_BASE = " .. smashBase end
    if smashSpread ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_SPREAD = " .. smashSpread end
    if smashLift ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_LIFT = " .. smashLift end
    if smashJitter ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_JITTER = " .. smashJitter end
    if smashSpot ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SMASH_SPOT = " .. smashSpot end
    if grassFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_FRAMES = " .. grassFrames end
    if scentFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SCENT_FRAMES = " .. scentFrames end
    if scentRadius ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SCENT_RADIUS = " .. scentRadius end
    if scentGap ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SCENT_GAP = " .. scentGap end
    if scentX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SCENT_X = " .. scentX end
    if scentY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SCENT_Y = " .. scentY end
    if splashHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SPLASH_HOLD = " .. splashHold end
    if dustHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").DUST_HOLD = " .. dustHold end
    if rustleHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").RUSTLE_HOLD = " .. rustleHold end
    local function emitHolds(name, list)
      local parts = {}
      for i = 1, #list do parts[i] = tostring(list[i]) end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. name .. " = { " .. table.concat(parts, ", ") .. " }"
    end
    if splashPics then emitHolds("SPLASH_PICS", splashPics) end
    if dustPics then emitHolds("DUST_PICS", dustPics) end
    if rustle then emitHolds("RUSTLE", rustle) end
    if feetPics then emitHolds("FEET_PICS", feetPics) end
    if feetH ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FEET_H = " .. feetH end
    if grassSlack ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").GRASS_SLACK = " .. grassSlack end
    if rippleY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").RIPPLE_Y = " .. rippleY end
    if shortLift ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").SHORT_LIFT = " .. shortLift end
    if sandLift ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").SAND_LIFT = " .. sandLift end
    if tireBlink ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").TIRE_BLINK = " .. tireBlink end
    if tireEnd ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").TIRE_END = " .. tireEnd end
    if ripplePics then emitHolds("RIPPLE_PICS", ripplePics) end
    if feet then emitHolds("FEET_HOLD", feet) end
    if ripple then emitHolds("RIPPLE_HOLD", ripple) end
    if surfHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SURF_HOLD = " .. surfHold end
    if surfW ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SURF_W = " .. surfW end
    if surfH ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SURF_H = " .. surfH end
    if surfFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SURF_FRAMES = " .. surfFrames end
    if birdW ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BIRD_W = " .. birdW end
    if birdH ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BIRD_H = " .. birdH end
    if birdFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BIRD_FRAMES = " .. birdFrames end
    if place ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").PLACE = " .. place end
    if splashDrop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").SPLASH_DROP = " .. splashDrop end
    if bubbleY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").BUBBLE_Y = " .. bubbleY end
    if bubbleRise ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").BUBBLE_RISE = " .. bubbleRise end
    if berryY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").BERRY_Y = " .. berryY end
    if pillarY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").PILLAR_Y = " .. pillarY end
    if sparkleWait ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").SPARKLE_WAIT = " .. sparkleWait end
    if sandFrame ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").SAND_FRAME = " .. sandFrame end
    if distort and #distort >= 2 then
      local pairs = {}
      for i = 1, #distort - 1, 2 do
        pairs[#pairs + 1] = "{ " .. distort[i] .. ", " .. distort[i + 1] .. " }"
      end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").DISTORT = { " .. table.concat(pairs, ", ") .. " }"
    end
    if tireTurns then
      local cart = { 1, 2, 7, 8, 1, 2, 6, 5, 5, 8, 3, 4, 6, 7, 3, 4 }
      local rows = {}
      for r = 0, 3 do
        local cells = {}
        for c = 1, 4 do cells[c] = tostring(tireTurns[r * 4 + c] or cart[r * 4 + c]) end
        rows[r + 1] = "{ " .. table.concat(cells, ", ") .. " }"
      end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects_rse\").TIRE_TRANSITIONS = { " .. table.concat(rows, ", ") .. " }"
    end
    if blobX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BLOB_X = " .. blobX end
    if blobY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BLOB_Y = " .. blobY end
    if blobBob ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").BLOB_BOB = " .. blobBob end
    if trackBlink ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").TRACK_BLINK = " .. trackBlink end
    if trackEnd ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").TRACK_END = " .. trackEnd end
    if shakeEvery ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SHAKE_EVERY = " .. shakeEvery end
    if shakeAmp ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SHAKE_AMP = " .. shakeAmp end
    if shakeFade ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SHAKE_FADE = " .. shakeFade end
    if rockWait ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_WAIT = " .. rockWait end
    if rockAmp ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_AMP = " .. rockAmp end
    if rockDecay ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_DECAY = " .. rockDecay end
    if fragX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FRAG_X = " .. fragX end
    if fragY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FRAG_Y = " .. fragY end
    if shardX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SHARD_X = " .. shardX end
    if shardY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").SHARD_Y = " .. shardY end
    if rockHold ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_HOLD = " .. rockHold end
    if rockFlip ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_FLIP = " .. rockFlip end
    if rockFootX ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_FOOT_X = " .. rockFootX end
    if rockFootY ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_FOOT_Y = " .. rockFootY end
    if rockTop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").ROCK_TOP = " .. rockTop end
    if flySwoop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_SWOOP = " .. flySwoop end
    if flyMount ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_MOUNT = " .. flyMount end
    if flyOff ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_OFF = " .. flyOff end
    if flyIn ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_IN = " .. flyIn end
    if flyPose ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_POSE = " .. flyPose end
    if flyEnd ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLY_END = " .. flyEnd end
    for i = 1, #tpKeys do
      if tpTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. tpKeys[i][2] .. " = " .. tpTaken[i]
      end
    end
    for i = 1, #birdKeys do
      if birdTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. birdKeys[i][2] .. " = " .. birdTaken[i]
      end
    end
    for i = 1, #spawnKeys do
      if spawnTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. spawnKeys[i][2] .. " = " .. spawnTaken[i]
      end
    end
    for i = 1, #rideKeys do
      if rideTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. rideKeys[i][2] .. " = " .. rideTaken[i]
      end
    end
    for i = 1, #ballKeys do
      if ballTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. ballKeys[i][2] .. " = " .. ballTaken[i]
      end
    end
    for i = 1, #backKeys do
      if backTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. backKeys[i][2] .. " = " .. backTaken[i]
      end
    end
    for i = 1, #spinKeys do
      if spinTaken[i] ~= nil then
        lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. spinKeys[i][2] .. " = " .. spinTaken[i]
      end
    end
    if flashFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").FLASH_FRAMES = " .. flashFrames end
    if veilFrames ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.field_effects\").VEIL_FRAMES = " .. veilFrames end
    local function emitArc(name, list)
      local parts = {}
      for i = 1, #list do parts[i] = tostring(list[i]) end
      lines[#lines + 1] = "    require(\"src.core.game3.field_effects\")." .. name .. " = { " .. table.concat(parts, ", ") .. " }"
    end
    if mountArc then emitArc("MOUNT_ARC", mountArc) end
    if dismountArc then emitArc("DISMOUNT_ARC", dismountArc) end
    if runCycle ~= nil then lines[#lines + 1] = "    Avatar.RUN_CYCLE = " .. runCycle end
    if runPose ~= nil then lines[#lines + 1] = "    Avatar.RUN_POSE = " .. runPose end
    if npcWalk ~= nil or npcRun ~= nil or npcSlow ~= nil or levStep ~= nil or levTurn ~= nil or levPixel ~= nil or figX or figY or copyFor or copyTo then
      lines[#lines + 1] = "    local Objects = require(\"src.core.game3.objects\")"
    end
    if npcWalk ~= nil then lines[#lines + 1] = "    Objects.WALK_FRAMES = " .. npcWalk end
    if npcRun ~= nil then lines[#lines + 1] = "    Objects.RUN_FRAMES = " .. npcRun end
    if npcSlow ~= nil then lines[#lines + 1] = "    Objects.RUN_SLOW_FRAMES = " .. npcSlow end
    if levStep ~= nil then lines[#lines + 1] = "    Objects.LEV_STEP = " .. levStep end
    if levTurn ~= nil then lines[#lines + 1] = "    Objects.LEV_TURN = " .. levTurn end
    if levPixel ~= nil then lines[#lines + 1] = "    Objects.LEV_PIXEL = " .. levPixel end
    local function figLine(field, list)
      if not list then return end
      local parts = {}
      for i, n in ipairs(list) do parts[i] = tostring(n) end
      lines[#lines + 1] = "    Objects." .. field .. " = { " .. table.concat(parts, ", ") .. " }"
    end
    figLine("FIG8_X", figX)
    figLine("FIG8_Y", figY)
    if fishWait ~= nil or fishDot ~= nil or fishDots ~= nil or fishFirst ~= nil or waterfall ~= nil then
      lines[#lines + 1] = "    local Field = require(\"src.core.game3.field\")"
    end
    if fishWait ~= nil then lines[#lines + 1] = "    Field.FISHING_WAIT_FRAMES = " .. fishWait end
    if fishDot ~= nil then lines[#lines + 1] = "    Field.FISHING_DOT_FRAMES = " .. fishDot end
    if fishDots ~= nil then lines[#lines + 1] = "    Field.FISHING_DOT_MAX = " .. fishDots end
    if fishFirst ~= nil then lines[#lines + 1] = "    Field.FISHING_FIRST_ROUND_DOTS = " .. fishFirst end
    if waterfall ~= nil then lines[#lines + 1] = "    Field.WALK_SLOWER_FRAMES = " .. waterfall end
    local tradeSet = tradeFade or tradeHold or tradeBye or tradeDepart or tradeReturn or tradeClose or tradeFlash or tradeArrived or tradeMon or tradeFanfare or tradeFanfareRs or tradeCare or tradeCareRs or tradeAfter or tradeSave or tradeJitter or tradeLink or motionSet or ballVel
    if tradeSet then
      lines[#lines + 1] = "    local Trade = require(\"src.core.game3.trade_scene\")"
    end
    if tradeFade ~= nil then lines[#lines + 1] = "    Trade.FADE_FRAMES = " .. tradeFade end
    if tradeHold ~= nil then lines[#lines + 1] = "    Trade.HOLD_FRAMES = " .. tradeHold end
    if tradeBye ~= nil then lines[#lines + 1] = "    Trade.BYE_BYE_DELAY = " .. tradeBye end
    if tradeDepart ~= nil then lines[#lines + 1] = "    Trade.BALL_DEPART_DELAY = " .. tradeDepart end
    if tradeReturn ~= nil then lines[#lines + 1] = "    Trade.MON_RETURN_FRAMES = " .. tradeReturn end
    if tradeClose ~= nil then lines[#lines + 1] = "    Trade.BALL_CLOSE_FRAMES = " .. tradeClose end
    if tradeFlash ~= nil then lines[#lines + 1] = "    Trade.GBA_FLASH_DELAY = " .. tradeFlash end
    if tradeArrived ~= nil then lines[#lines + 1] = "    Trade.ARRIVED_DELAY = " .. tradeArrived end
    if tradeMon ~= nil then lines[#lines + 1] = "    Trade.MON_ANIM_DELAY = " .. tradeMon end
    if tradeFanfare ~= nil then lines[#lines + 1] = "    Trade.FANFARE_AT = " .. tradeFanfare end
    if tradeFanfareRs ~= nil then lines[#lines + 1] = "    Trade.FANFARE_RS = " .. tradeFanfareRs end
    if tradeCare ~= nil then lines[#lines + 1] = "    Trade.TAKE_CARE_AT = " .. tradeCare end
    if tradeCareRs ~= nil then lines[#lines + 1] = "    Trade.TAKE_CARE_RS = " .. tradeCareRs end
    if tradeAfter ~= nil then lines[#lines + 1] = "    Trade.AFTER_MON_DELAY = " .. tradeAfter end
    if tradeSave ~= nil then lines[#lines + 1] = "    Trade.LINK_SAVE_HOLD = " .. tradeSave end
    if tradeJitter ~= nil then lines[#lines + 1] = "    Trade.LINK_HOST_JITTER = " .. tradeJitter end
    if tradeLink ~= nil then lines[#lines + 1] = "    Trade.LINK_CLOSE_HOLD = " .. tradeLink end
    local motionFields = {
      slideStart = "MON_SLIDE_HOFS", slideStep = "MON_SLIDE_STEP", ballSound = "BALL_TRADE_SE_AT",
      ballFly = "BALL_DEPART_FRAMES", ballBounce = "BALL_DEPART_BOUNCE_AT", ballRest = "BALL_DEPART_END_HOLD",
      ballEnd = "BALL_DEPART_END_FRAMES", zoomMax = "ZOOM_MAX", zoomMin = "ZOOM_MIN", zoomStep = "ZOOM_STEP",
      zoomFar = "ZOOM_FAR", flashAnim = "FLASH_ANIM_FRAMES", gbaTop = "BG1_GBA_TOP", panEnd = "BG1_PAN_END",
      cableEnd = "CABLE_END_VOFS", travelEnd = "LINK_MON_TRAVEL_END", linkY = "LINK_MON_Y",
      linkOff = "LINK_MON_OFFSCREEN", crossStep = "CROSS_STEP", crossEnter = "CROSS_ENTER_LIMIT",
      crossExit = "CROSS_EXIT_LIMIT", crossMon = "CROSS_MON_LIMIT", crossAy = "CROSS_MON_A_Y",
      crossBy = "CROSS_MON_B_Y", arriveY = "LINK_MON_ARRIVE_Y", arriveAt = "LINK_MON_ARRIVE_TARGET",
      gbaCenter = "BG1_CENTER", ballDrop = "BALL_ARRIVE_Y", ballLand = "BALL_ARRIVE_TARGET",
      ballFall = "BALL_ARRIVE_STEP", ballIdx = "BALL_ARRIVE_IDX",       ballStop = "BALL_ARRIVE_END",
      screenH = "DISPLAY_HEIGHT",
      bounce2 = "BALL_BOUNCE_2", bounce3 = "BALL_BOUNCE_3", bounce4 = "BALL_BOUNCE_4",
    }
    for key, field in pairs(motionFields) do
      if motion[key] ~= nil then lines[#lines + 1] = "    Trade." .. field .. " = " .. motion[key] end
    end
    if ballVel then
      local parts = {}
      for i = 1, #ballVel do parts[i] = tostring(ballVel[i]) end
      lines[#lines + 1] = "    Trade.BALL_VELOCITY = { [0] = " .. table.concat(parts, ", ") .. " }"
    end
    if motion.ballX ~= nil or motion.ballY ~= nil or motion.monX ~= nil or motion.monY ~= nil
      or motion.nudgeX ~= nil or motion.nudgeY ~= nil or motion.monNudgeX ~= nil
      or motion.monNudgeY ~= nil or motion.gap ~= nil or motion.ending ~= nil
      or motion.glow ~= nil or motion.laps ~= nil or motion.rest ~= nil
      or motion.monLaps ~= nil or motion.offs or motion.seq or motion.durs
      or motion.glowK or motion.glowSlots or motion.glowLead then
      lines[#lines + 1] = "    local Heal = require(\"src.core.game3.pokecenter_heal\")"
      if motion.ballX ~= nil then lines[#lines + 1] = "    Heal.BALL_CENTER_X = " .. motion.ballX end
      if motion.ballY ~= nil then lines[#lines + 1] = "    Heal.BALL_CENTER_Y = " .. motion.ballY end
      if motion.monX ~= nil then lines[#lines + 1] = "    Heal.MONITOR_CENTER_X = " .. motion.monX end
      if motion.monY ~= nil then lines[#lines + 1] = "    Heal.MONITOR_CENTER_Y = " .. motion.monY end
      if motion.nudgeX ~= nil then lines[#lines + 1] = "    Heal.BALL_CORNER_X = " .. motion.nudgeX end
      if motion.nudgeY ~= nil then lines[#lines + 1] = "    Heal.BALL_CORNER_Y = " .. motion.nudgeY end
      if motion.monNudgeX ~= nil then lines[#lines + 1] = "    Heal.MONITOR_CORNER_X = " .. motion.monNudgeX end
      if motion.monNudgeY ~= nil then lines[#lines + 1] = "    Heal.MONITOR_CORNER_Y = " .. motion.monNudgeY end
      if motion.gap ~= nil then lines[#lines + 1] = "    Heal.PLACE_FRAMES = " .. motion.gap end
      if motion.ending ~= nil then lines[#lines + 1] = "    Heal.PLACE_END = " .. motion.ending end
      if motion.glow ~= nil then lines[#lines + 1] = "    Heal.FLASH_STEP = " .. motion.glow end
      if motion.laps ~= nil then lines[#lines + 1] = "    Heal.FLASH_LOOPS = " .. motion.laps end
      if motion.rest ~= nil then lines[#lines + 1] = "    Heal.FLASH_AFTER = " .. motion.rest end
      if motion.monLaps ~= nil then lines[#lines + 1] = "    Heal.MONITOR_LOOPS = " .. motion.monLaps end
      if motion.offs then
        lines[#lines + 1] = "    Heal.BALL_OFFSETS = { " .. M.pairText(motion.offs) .. " }"
      end
      if motion.seq then
        lines[#lines + 1] = "    Heal.MONITOR_SEQ = { " .. M.numText(motion.seq) .. " }"
      end
      if motion.durs then
        lines[#lines + 1] = "    Heal.MONITOR_DURS = { " .. M.numText(motion.durs) .. " }"
      end
      if motion.glowK then
        lines[#lines + 1] = "    Heal.GLOW_K = { " .. M.numText(motion.glowK) .. " }"
      end
      if motion.glowSlots then
        lines[#lines + 1] = "    Heal.GLOW_INDICES = { " .. M.numText(motion.glowSlots) .. " }"
      end
      if motion.glowLead then
        lines[#lines + 1] = "    Heal.GLOW_LEAD = { " .. M.numText(motion.glowLead) .. " }"
      end
    end
    if motion.fishBase then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_BASE = { down = "
        .. motion.fishBase[1] .. ", up = " .. motion.fishBase[2] .. ", left = "
        .. motion.fishBase[3] .. ", right = " .. motion.fishBase[4] .. " }"
    end
    if motion.fishOut then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_TAKE_OUT = { " .. M.numText(motion.fishOut) .. " }"
    end
    if motion.fishSn then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_PUT_AWAY_SN = { " .. M.numText(motion.fishSn) .. " }"
    end
    if motion.fishWe then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_PUT_AWAY_WE = { " .. M.numText(motion.fishWe) .. " }"
    end
    if motion.fishHook then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_HOOKED = { " .. M.numText(motion.fishHook) .. " }"
    end
    if motion.fishOff then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FISH_OFFS = { " .. M.quadText(motion.fishOff) .. " }"
    end
    if motion.fieldMove then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").FIELD_MOVE_SEQ = { " .. M.numText(motion.fieldMove) .. " }"
    end
    if motion.vsSeq then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").VS_SEEKER_SEQ = { " .. M.numText(motion.vsSeq) .. " }"
    end
    if motion.vsBike then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").VS_SEEKER_BIKE_SEQ = { " .. M.numText(motion.vsBike) .. " }"
    end
    if motion.bow ~= nil then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").BOW_FRAME = " .. motion.bow
    end
    if motion.stand then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").STAND = { down = "
        .. motion.stand[1] .. ", up = " .. motion.stand[2] .. ", left = "
        .. motion.stand[3] .. ", right = " .. motion.stand[4] .. " }"
    end
    if motion.walkA then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").WALK_A = { down = "
        .. motion.walkA[1] .. ", up = " .. motion.walkA[2] .. ", left = "
        .. motion.walkA[3] .. ", right = " .. motion.walkA[4] .. " }"
    end
    if motion.walkB then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").WALK_B = { down = "
        .. motion.walkB[1] .. ", up = " .. motion.walkB[2] .. ", left = "
        .. motion.walkB[3] .. ", right = " .. motion.walkB[4] .. " }"
    end
    if motion.runStill then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").RUN_BASE = { down = "
        .. motion.runStill[1] .. ", up = " .. motion.runStill[2] .. ", left = "
        .. motion.runStill[3] .. ", right = " .. motion.runStill[4] .. " }"
    end
    if motion.runA then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").RUN_A = { down = "
        .. motion.runA[1] .. ", up = " .. motion.runA[2] .. ", left = "
        .. motion.runA[3] .. ", right = " .. motion.runA[4] .. " }"
    end
    if motion.runB then
      lines[#lines + 1] = "    require(\"src.core.game3.ow_sprites\").RUN_B = { down = "
        .. motion.runB[1] .. ", up = " .. motion.runB[2] .. ", left = "
        .. motion.runB[3] .. ", right = " .. motion.runB[4] .. " }"
    end
    if motion.flash then
      lines[#lines + 1] = "    require(\"src.core.game3.field_view\").FLASH_LEVEL_RADIUS = { [0] = "
        .. M.numText(motion.flash) .. " }"
    end
    if tradeOpen ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.scripting.natives_trade\").FADE_FRAMES = " .. tradeOpen end
    if animPause ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.battle.anim_seq\").PAUSE_SHORT = " .. animPause end
    local anneSet = anneHorn ~= nil or anneSmoke ~= nil or anneSlide ~= nil or anneLeave ~= nil or anneFxSet
    if anneSet then
      lines[#lines + 1] = "    local Anne = require(\"src.core.game3.ss_anne_cutscene\")"
    end
    if anneHorn ~= nil then lines[#lines + 1] = "    Anne.INIT_FRAMES = " .. anneHorn end
    if anneSmoke ~= nil then lines[#lines + 1] = "    Anne.SMOKE_INTERVAL = " .. anneSmoke end
    if anneSlide ~= nil then lines[#lines + 1] = "    Anne.SLIDE_SPEED_DIV = " .. anneSlide end
    if anneLeave ~= nil then lines[#lines + 1] = "    Anne.FINISH_FRAMES = " .. anneLeave end
    local anneFields = {
      wakeStep = "WAKE_STEP", wakeCap = "WAKE_CAP", wakeFlip = "WAKE_FLIP", wakeX = "WAKE_X",
      wakeCull = "WAKE_CULL", wakeY = "WAKE_Y", wakeLift = "WAKE_LIFT", smokeStep = "SMOKE_STEP",
      smokeA = "SMOKE_A", smokeB = "SMOKE_B", smokeC = "SMOKE_C", smokeEnd = "SMOKE_END",
      smokeSpawn = "SMOKE_SPAWN", smokeCull = "SMOKE_CULL", smokeY = "SMOKE_Y",
      smokeLift = "SMOKE_LIFT", boatGone = "BOAT_GONE",
    }
    for key, field in pairs(anneFields) do
      if anneFx[key] ~= nil then lines[#lines + 1] = "    Anne." .. field .. " = " .. anneFx[key] end
    end
    local ferrySet = ferryCross or ferryMusic
    if ferrySet ~= nil then
      lines[#lines + 1] = "    local Ferry = require(\"src.core.game3.scripting.natives_seagallop\")"
    end
    if ferryCross ~= nil then lines[#lines + 1] = "    Ferry.CROSSING_FRAMES = " .. ferryCross end
    if ferryMusic ~= nil then lines[#lines + 1] = "    Ferry.MUSIC_FADE_FRAMES = " .. ferryMusic end
    local oakSet = dudeScroll or oakDim or oakWait
    if oakSet ~= nil then
      lines[#lines + 1] = "    local BattleUi = require(\"src.core.game3.battle.ui\")"
    end
    if dudeScroll ~= nil then lines[#lines + 1] = "    BattleUi.POKEDUDE_AUTO_SCROLL = " .. dudeScroll end
    if oakDim ~= nil then lines[#lines + 1] = "    BattleUi.OAK_DIM_TARGET = " .. oakDim end
    if oakWait ~= nil then lines[#lines + 1] = "    BattleUi.OAK_DIM_DELAY = " .. oakWait end
    if arenaPause ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.battle.facility_arena\").B_WAIT_TIME_LONG = " .. arenaPause end
    local function copyLine(field, rows)
      if not rows then return end
      local body = {}
      for _, row in ipairs(rows) do
        local parts = {}
        for i, n in ipairs(row) do parts[i] = tostring(n) end
        body[#body + 1] = "{ " .. table.concat(parts, ", ") .. " }"
      end
      lines[#lines + 1] = "    Objects." .. field .. " = { " .. table.concat(body, ", ") .. " }"
    end
    copyLine("COPY_FOR", copyFor)
    copyLine("COPY_TO", copyTo)
    return true
  end
  local function rseBike()
    local coast = take(g, "rseCoast", 1, 255)
    local speed = take(g, "rseSpeed", 1, 255)
    local top = take(g, "rseTop", 1, 255)
    local acro = take(g, "rseAcro", 1, 255)
    local hop = take(g, "rseHop", 1, 255)
    local ledge = take(g, "rseLedge", 1, 255)
    local window = take(g, "rseWindow", 0, 255)
    local bump = take(g, "rseBump", 0, 255)
    local turnBump = take(g, "rseTurnBump", 0, 255)
    local wheelie = take(g, "rseWheelie", 0, 255)
    local npcHop = take(g, "g3NpcHop", 1, 65535)
    local npcFar = take(g, "g3NpcFar", 1, 65535)
    local blink = take(g, "berryBlink", 1, 255)
    local sparkle = take(g, "berrySparkle", 0, 65535)
    local arcs = {}
    for key, kind in pairs(ARC_KIND) do
      local list = M.arcList(g[key])
      if list then arcs[#arcs + 1] = { kind = kind, list = list } end
    end
    table.sort(arcs, function(a, b) return a.kind < b.kind end)
    local bike = coast ~= nil or speed ~= nil or top ~= nil or acro ~= nil or hop ~= nil or ledge ~= nil or window ~= nil or bump ~= nil or turnBump ~= nil or wheelie ~= nil
    if not bike and npcHop == nil and npcFar == nil and #arcs == 0 and blink == nil and sparkle == nil then return false end
    if bike then
    lines[#lines + 1] = "    local Bike = require(\"src.core.game3.bike.rse\")"
    if coast ~= nil or speed ~= nil or top ~= nil or acro ~= nil then
      lines[#lines + 1] = "    Bike.FRAMES = Bike.FRAMES or {}"
    end
    if coast ~= nil then lines[#lines + 1] = "    Bike.FRAMES.NORMAL = " .. coast end
    if speed ~= nil then lines[#lines + 1] = "    Bike.FRAMES.FAST_1 = " .. speed end
    if top ~= nil then lines[#lines + 1] = "    Bike.FRAMES.FASTER = " .. top end
    if acro ~= nil then lines[#lines + 1] = "    Bike.FRAMES.FAST_2 = " .. acro end
    if hop ~= nil or ledge ~= nil then
      lines[#lines + 1] = "    Bike.JUMP = Bike.JUMP or {}"
    end
    if hop ~= nil then lines[#lines + 1] = "    Bike.JUMP.NORMAL = " .. hop end
    if ledge ~= nil then lines[#lines + 1] = "    Bike.JUMP.FAR = " .. ledge end
    if window ~= nil then lines[#lines + 1] = "    Bike.JUMP_TIMER = " .. window end
    if bump ~= nil or turnBump ~= nil then
      lines[#lines + 1] = "    Bike.IN_PLACE = Bike.IN_PLACE or {}"
    end
    if bump ~= nil then lines[#lines + 1] = "    Bike.IN_PLACE.NORMAL = " .. bump end
    if turnBump ~= nil then lines[#lines + 1] = "    Bike.IN_PLACE.FAST = " .. turnBump end
    if wheelie ~= nil then lines[#lines + 1] = "    Bike.WHEELIE_FRAMES = " .. wheelie end
    end
    if npcHop ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.objects\").JUMP_FRAMES = " .. npcHop end
    if npcFar ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.objects\").JUMP_FAR_FRAMES = " .. npcFar end
    if blink ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.objects\").BERRY_BLINK = " .. blink end
    if sparkle ~= nil then lines[#lines + 1] = "    require(\"src.core.game3.objects\").BERRY_SPARKLE = " .. sparkle end
    if #arcs > 0 then
      lines[#lines + 1] = "    local Jump = require(\"src.core.game3.objects\")"
      lines[#lines + 1] = "    Jump.JUMP_Y = Jump.JUMP_Y or {}"
      for _, arc in ipairs(arcs) do
        local parts = {}
        for i, n in ipairs(arc.list) do parts[i] = tostring(n) end
        lines[#lines + 1] = "    Jump.JUMP_Y." .. arc.kind .. " = { " .. table.concat(parts, ", ") .. " }"
      end
    end
    return true
  end
  local function gen3Delays()
    local bands = {
      { key = "g3Med", name = "MEDIUM" },
      { key = "g3Long", name = "LONG" },
      { key = "g3Short", name = "SHORT" },
    }
    local picked = {}
    local any = false
    for _, band in ipairs(bands) do
      picked[band.name] = {}
      for i = 1, 4 do
        local n = take(g, band.key .. i, 0, 65535)
        picked[band.name][i] = n
        if n ~= nil then any = true end
      end
    end
    local rotate = take(g, "g3Rotate", 0, 65535)
    if rotate ~= nil then any = true end
    if not any then return false end
    local wrote = false
    for _, band in ipairs(bands) do
      for i = 1, 4 do
        local n = picked[band.name][i]
        if n ~= nil then
          if not wrote then
            lines[#lines + 1] = "    local Gfx = require(\"src.core.game3.scripting.gfx_ids\")"
            wrote = true
          end
          lines[#lines + 1] = "    Gfx.DELAYS." .. band.name .. "[" .. i .. "] = " .. n
        end
      end
    end
    if rotate ~= nil then
      lines[#lines + 1] = "    require(\"src.core.game3.objects\").ROTATE_FRAMES = " .. rotate
    end
    return true
  end
  local PLAYER_ARC = {
    { key = "playerHop", field = "JUMP_Y.normal" },
    { key = "playerHopHigh", field = "JUMP_Y.high" },
    { key = "playerHopLow", field = "JUMP_Y.low" },
    { key = "surfHop", field = "SURF_HOP_Y" },
  }
  local function gen3PlayerArc()
    local rows = {}
    for _, row in ipairs(PLAYER_ARC) do
      local list = M.arcList(g[row.key])
      if list then rows[#rows + 1] = { field = row.field, list = list } end
    end
    if #rows == 0 then return false end
    lines[#lines + 1] = "    local Avatar = require(\"src.core.game3.player\")"
    lines[#lines + 1] = "    Avatar.JUMP_Y = Avatar.JUMP_Y or {}"
    for _, row in ipairs(rows) do
      local parts = {}
      for i, n in ipairs(row.list) do parts[i] = tostring(n) end
      lines[#lines + 1] = "    Avatar." .. row.field .. " = { " .. table.concat(parts, ", ") .. " }"
    end
    return true
  end
  if gen2 then
    local n = take(g, "bikeCall", 0, 65535)
    local cap = take(g, "bikeCap", 0, 65535)
    local beats = take(g, "skyfallBeats", 0, 255)
    local shake = take(g, "pitfallShake", 0, 255)
    local teleport = take(g, "teleportBeats", 0, 255)
    local lift = take(g, "teleportLift", 0, 255)
    local rise = take(g, "teleportRise", 0, 255)
    local fall = take(g, "teleportFall", 0, 255)
    local ledge = M.arcList(g.g2Ledge)
    local tree = take(g, "treeShake", 0, 255)
    local digStep = take(g, "digStep", 0, 255)
    local digSpin = take(g, "digSpin", 0, 255)
    local sleepUnit = take(g, "sleepUnit", 0, 255)
    local npcStep = take(g, "npcStep", 0, 255)
    local spin = take(g, "spinFrames", 1, 255)
    local playerStep = take(g, "playerStep", 1, 255)
    local turn = take(g, "turnFrames", 0, 255)
    local bounce = take(g, "bouncePeriod", 1, 255)
    local bounceHalf = take(g, "bounceHalf", 0, 255)
    local spinTurn = take(g, "spinTurn", 0, 255)
    local wanderLo = take(g, "wanderLo", 0, 65535)
    local wanderHi = take(g, "wanderHi", 0, 65535)
    local spawnLo = take(g, "spawnLo", 0, 65535)
    local spawnHi = take(g, "spawnHi", 0, 65535)
    local turnOdds = take(g, "turnOdds", 0, 100)
    local slowLo = take(g, "slowSpinLo", 0, 65535)
    local slowHi = take(g, "slowSpinHi", 0, 65535)
    local fastLo = take(g, "fastSpinLo", 0, 65535)
    local fastHi = take(g, "fastSpinHi", 0, 65535)
    local approach = take(g, "approachGap", 0, 255)
    local notice = take(g, "noticeFrames", 0, 255)
    local fadeSteps = take(g, "fadeSteps", 1, 255)
    local fadeFrames = take(g, "fadeFrames", 0, 255)
    local mapWhite = take(g, "mapWhite", 0, 255)
    local warpWhite = take(g, "warpWhite", 0, 255)
    local menuWhite = take(g, "menuWhite", 0, 255)
    local flyWhite = take(g, "flyWhite", 0, 255)
    local flyBuild = take(g, "flyBuild", 0, 255)
    local flyBlank = take(g, "flyBlank", 0, 255)
    local flyIcon = take(g, "flyIcon", 0, 255)
    local partyWhite = take(g, "partyWhite", 0, 255)
    local partyIcon = take(g, "partyIcon", 0, 255)
    local partyExtra = take(g, "partyExtra", 0, 255)
    local packWhite = take(g, "packWhite", 0, 255)
    local gearWhite = take(g, "gearWhite", 0, 255)
    local gearExit = take(g, "gearExit", 0, 255)
    local cardWhite = take(g, "cardWhite", 0, 255)
    local dexWhite = take(g, "dexWhite", 0, 255)
    local optionWhite = take(g, "optionWhite", 0, 255)
    local fadeIn = take(g, "fadeIn", 0, 255)
    local palettePoll = take(g, "palettePoll", 0, 255)
    local strengthPause = take(g, "strengthPause", 0, 255)
    local neighborHops = take(g, "neighborHops", 0, 255)
    local fadeWhite = M.shadeRows(g.fadeWhite)
    local fadeBlack = M.shadeRows(g.fadeBlack)
    local battleWaits = {
      { "g2TextPause", "src.ui.gen2.BattleState", "TEXT_PAUSE_FRAMES", 0, 255 },
      { "g2MoveDelay", "src.ui.gen2.BattleState", "MOVE_DELAY_FRAMES", 0, 255 },
      { "g2HpStep", "src.ui.gen2.BattleState", "HP_BAR_FRAMES_PER_STEP", 0, 255 },
      { "g2FaintRow", "src.ui.gen2.BattleState", "FAINT_SLIDE_FRAMES_PER_ROW", 1, 255 },
      { "g2SlideSteps", "src.ui.gen2.BattleState", "TRAINER_SLIDE_STEPS", 0, 255 },
      { "g2SlideStep", "src.ui.gen2.BattleState", "TRAINER_SLIDE_FRAMES_PER_STEP", 1, 255 },
      { "g2BackSteps", "src.ui.gen2.BattleState", "BACKPIC_SLIDE_STEPS", 0, 255 },
      { "g2WinSteps", "src.ui.gen2.BattleState", "WIN_SLIDE_STEPS", 0, 255 },
      { "g2WinStep", "src.ui.gen2.BattleState", "WIN_SLIDE_FRAMES_PER_STEP", 1, 255 },
      { "g2WinRest", "src.ui.gen2.BattleState", "WIN_SLIDE_REST_TILES", 0, 255 },
      { "g2WinDelay", "src.ui.gen2.BattleState", "WIN_SLIDE_DELAY_FRAMES", 0, 255 },
      { "g2ExitFade", "src.ui.gen2.BattleState", "EXIT_FADE_FRAMES", 0, 255 },
      { "g2ExitMusic", "src.ui.gen2.BattleState", "EXIT_MUSIC_FADE", 0, 255 },
      { "g2WhiteFade", "src.ui.gen2.BattleState", "WHITEOUT_FADE_FRAMES", 0, 255 },
      { "g2WhiteHold", "src.ui.gen2.BattleState", "WHITEOUT_HOLD_FRAMES", 0, 255 },
      { "g2IntroSlide", "src.ui.gen2.BattleAnimView", "SLIDE_FRAMES", 0, 255 },
      { "g2ExpSound", "src.ui.gen2.BattleState", "EXP_SOUND_FRAMES", 0, 255 },
      { "g2ExpWait", "src.ui.gen2.BattleState", "EXP_WAIT_SFX_CAP", 0, 255 },
      { "g2ExpGap", "src.ui.gen2.BattleState", "EXP_PIXEL_GAP", 0, 255 },
      { "g2ExpBurst", "src.ui.gen2.BattleState", "EXP_BURST_FRAMES", 0, 255 },
      { "g2ExpSparks", "src.ui.gen2.BattleState", "EXP_BURST_SPRITES", 0, 255 },
      { "g2ExpX", "src.ui.gen2.BattleState", "EXP_BURST_X", 0, 255 },
      { "g2ExpY", "src.ui.gen2.BattleState", "EXP_BURST_Y", 0, 255 },
      { "g2TextX", "src.ui.gen2.BattleState", "TEXT_INNER_X", 0, 255 },
      { "g2TextY", "src.ui.gen2.BattleState", "TEXT_INNER_Y", 0, 255 },
      { "g2TextW", "src.ui.gen2.BattleState", "TEXT_WIDTH", 1, 255 },
      { "g2TextRows", "src.ui.gen2.BattleState", "TEXT_ROWS", 1, 255 },
      { "g2TextStep", "src.ui.gen2.BattleState", "TEXT_ROW_STEP", 0, 255 },
      { "g2ArrowX", "src.ui.gen2.BattleState", "ARROW_X", 0, 255 },
      { "g2ArrowY", "src.ui.gen2.BattleState", "ARROW_Y", 0, 255 },
      { "g2MenuX", "src.ui.gen2.BattleState", "MENU_BOX_X", 0, 255 },
      { "g2MenuGap", "src.ui.gen2.BattleState", "MENU_COL_SPACING", 0, 255 },
      { "g2ParkX", "src.ui.gen2.BattleState", "CONTEST_MENU_BOX_X", 0, 255 },
      { "g2ParkGap", "src.ui.gen2.BattleState", "CONTEST_MENU_COL_SPACING", 0, 255 },
    }
    local g2Waits = {}
    for _, row in ipairs(battleWaits) do
      local n = take(g, row[1], row[4], row[5])
      if n ~= nil then g2Waits[#g2Waits + 1] = { row[2], row[3], n } end
    end
    local cues = {
      headbutt = take(g, "g2HeadbuttSfx", 0, 255),
      cut = take(g, "g2CutSfx", 0, 255),
      flash = take(g, "g2FlashSfx", 0, 255),
      falls = take(g, "g2FallSfx", 0, 255),
      boulder = take(g, "g2BoulderSfx", 0, 255),
      shock = take(g, "g2Shock", 0, 255),
      whirl = take(g, "g2Whirl", 0, 255),
    }
    local cuesSet = false
    for _, v in pairs(cues) do
      if v ~= nil then cuesSet = true break end
    end
    local heal = {
      ball = take(g, "g2HealBall", 0, 255),
      flash = take(g, "g2HealFlash", 0, 255),
      flashes = take(g, "g2HealFlashes", 0, 255),
      anchor = take(g, "g2HealAnchor", 0, 255),
      shiftX = take(g, "g2HealShiftX", -512, 512),
      shiftY = take(g, "g2HealShiftY", -512, 512),
      flip = take(g, "g2HealFlip", 0, 255),
    }
    local healSet = false
    for _, v in pairs(heal) do
      if v ~= nil then healSet = true break end
    end
    local healPc = M.pairList(g.g2HealPc)
    local healBalls = M.tripleList(g.g2HealBalls)
    local healHof = M.tripleList(g.g2HealHof)
    heal.rod = M.rodList(g.g2Rod)
    heal.fish = M.holdList(g.g2FishRow)
    heal.tower = M.holdList(g.g2Tower)
    if heal.tower and #heal.tower < 8 then heal.tower = nil end
    heal.scroll = M.arcList(g.g2Scroll)
    if heal.scroll and #heal.scroll < 8 then heal.scroll = nil end
    heal.water = M.holdList(g.g2Water)
    if heal.water and #heal.water < 8 then heal.water = nil end
    heal.whirlRows = M.holdList(g.g2WhirlRows)
    if heal.whirlRows and #heal.whirlRows < 8 then heal.whirlRows = nil end
    heal.lava = M.holdList(g.g2Lava)
    if heal.lava and #heal.lava < 8 then heal.lava = nil end
    heal.lava2 = M.holdList(g.g2Lava2)
    if heal.lava2 and #heal.lava2 < 8 then heal.lava2 = nil end
    local walkCycle = take(g, "walkCycle", 1, 255)
    local legFrom = take(g, "legFrom", 0, 255)
    local legTo = take(g, "legTo", 0, 255)
    if n == nil and cap == nil and beats == nil and shake == nil and teleport == nil and lift == nil and rise == nil and fall == nil and not ledge and tree == nil and digStep == nil and digSpin == nil and sleepUnit == nil and npcStep == nil and spin == nil and playerStep == nil and turn == nil and bounce == nil and bounceHalf == nil and spinTurn == nil and wanderLo == nil and wanderHi == nil and spawnLo == nil and spawnHi == nil and turnOdds == nil and slowLo == nil and slowHi == nil and fastLo == nil and fastHi == nil and walkCycle == nil and legFrom == nil and legTo == nil and approach == nil and notice == nil and fadeSteps == nil and fadeFrames == nil and mapWhite == nil and warpWhite == nil and menuWhite == nil and flyWhite == nil and flyBuild == nil and flyBlank == nil and flyIcon == nil and partyWhite == nil and partyIcon == nil and partyExtra == nil and packWhite == nil and gearWhite == nil and gearExit == nil and cardWhite == nil and dexWhite == nil and optionWhite == nil and fadeIn == nil and palettePoll == nil and strengthPause == nil and neighborHops == nil and not fadeWhite and not fadeBlack and #g2Waits == 0 and not cuesSet and not healSet and not healPc and not healBalls and not healHof and not heal.rod and not heal.fish and not heal.tower and not heal.scroll and not heal.water and not heal.whirlRows and not heal.lava and not heal.lava2 then return end
    if n ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.StepEvents\").BIKE_CALL_STEPS = " .. n
    end
    if cap ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.StepEvents\").BIKE_STEP_MAX = " .. cap
    end
    if beats ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").SKYFALL_BEAT_FRAMES = " .. beats
    end
    if shake ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").PITFALL_SHAKE = " .. shake
    end
    if teleport ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").TELEPORT_BEAT_FRAMES = " .. teleport
    end
    if lift ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").TELEPORT_LIFT = " .. lift
    end
    if rise ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").TELEPORT_RISE_HEIGHT = " .. rise
    end
    if fall ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").TELEPORT_FALL_HEIGHT = " .. fall
    end
    if ledge then
      local parts = {}
      for i, n in ipairs(ledge) do parts[i] = tostring(n) end
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").JUMP_Y = { " .. table.concat(parts, ", ") .. " }"
    end
    if tree ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").TREE_SHAKE_FRAMES = " .. tree
    end
    if digStep ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").STEP_DIG_FRAMES = " .. digStep
    end
    if digSpin ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").DIG_SPIN_FRAMES = " .. digSpin
    end
    if sleepUnit ~= nil then
      lines[#lines + 1] = "    require(\"src.script.gen2.Movement\").SLEEP_UNIT = " .. sleepUnit
    end
    if npcStep ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").STEP_FRAMES = " .. npcStep
    end
    if spin ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SPIN_FRAMES = " .. spin
    end
    if playerStep ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").STEP_FRAMES = " .. playerStep
    end
    if turn ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").TURN_FRAMES = " .. turn
    end
    if bounce ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").BOUNCE_PERIOD = " .. bounce
    end
    if bounceHalf ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").BOUNCE_HALF = " .. bounceHalf
    end
    if spinTurn ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SPIN_TURN_FRAMES = " .. spinTurn
    end
    if wanderLo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").WANDER_LO = " .. wanderLo
    end
    if wanderHi ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").WANDER_HI = " .. wanderHi
    end
    if spawnLo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SPAWN_LO = " .. spawnLo
    end
    if spawnHi ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SPAWN_HI = " .. spawnHi
    end
    if turnOdds ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").TURN_ODDS = " .. turnOdds
    end
    if slowLo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SLOW_SPIN_LO = " .. slowLo
    end
    if slowHi ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").SLOW_SPIN_HI = " .. slowHi
    end
    if fastLo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").FAST_SPIN_LO = " .. fastLo
    end
    if fastHi ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Npc\").FAST_SPIN_HI = " .. fastHi
    end
    if walkCycle ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").WALK_ANIM_FRAMES = " .. walkCycle
    end
    if legFrom ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").LEG_FROM = " .. legFrom
    end
    if legTo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").LEG_TO = " .. legTo
    end
    if approach ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.Trainers\").APPROACH_GAP = " .. approach
    end
    if notice ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").NOTICE_FRAMES = " .. notice
    end
    if fadeSteps ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FADE_STEPS = " .. fadeSteps
    end
    if fadeFrames ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FADE_STEP_FRAMES = " .. fadeFrames
    end
    if mapWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").MAP_LOAD_WHITE_FRAMES = " .. mapWhite
    end
    if warpWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").WARP_LOAD_WHITE_FRAMES = " .. warpWhite
    end
    if menuWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").MENU_EXIT_WHITE_FRAMES = " .. menuWhite
    end
    if flyWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FLY_EXIT_WHITE_FRAMES = " .. flyWhite
    end
    if flyBuild ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FLY_MAP_BUILD_FRAMES = " .. flyBuild
    end
    if flyBlank ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FLY_CANCEL_BLANK_FRAMES = " .. flyBlank
    end
    if flyIcon ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FLY_CANCEL_ICON_FRAMES = " .. flyIcon
    end
    if partyWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").PARTY_WHITE = " .. partyWhite
    end
    if partyIcon ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").PARTY_ICON_FRAMES = " .. partyIcon
    end
    if partyExtra ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").PARTY_EXTRA = " .. partyExtra
    end
    if packWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").PACK_WHITE = " .. packWhite
    end
    if gearWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").GEAR_WHITE = " .. gearWhite
    end
    if gearExit ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").GEAR_EXIT_WHITE = " .. gearExit
    end
    if cardWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").CARD_WHITE = " .. cardWhite
    end
    if dexWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").DEX_WHITE = " .. dexWhite
    end
    if optionWhite ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").OPTION_WHITE = " .. optionWhite
    end
    if fadeIn ~= nil then
      lines[#lines + 1] = "    require(\"src.ui.gen2.MenuFade\").IN_STEPS = " .. fadeIn
    end
    if palettePoll ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").PALETTE_POLL_STEPS = " .. palettePoll
    end
    if strengthPause ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").STRENGTH_PAUSE_FRAMES = " .. strengthPause
    end
    if neighborHops ~= nil then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").NEIGHBOR_HOPS = " .. neighborHops
    end
    local function rampLiteral(rows)
      local parts = {}
      for _, row in ipairs(rows) do
        parts[#parts + 1] = "{ " .. table.concat(row, ", ") .. " }"
      end
      return "{ " .. table.concat(parts, ", ") .. " }"
    end
    if fadeWhite then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FADE_RAMP.white = " .. rampLiteral(fadeWhite)
    end
    if fadeBlack then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").FADE_RAMP.black = " .. rampLiteral(fadeBlack)
    end
    local cueFields = {
      headbutt = "SFX_SANDSTORM", cut = "SFX_CUT", flash = "SFX_FLASH",
      falls = "SFX_BUBBLEBEAM", boulder = "SFX_STRENGTH", shock = "EMOTE_SHOCK",
      whirl = "WHIRLPOOL_CAP",
    }
    for key, field in pairs(cueFields) do
      if cues[key] ~= nil then
        lines[#lines + 1] = "    require(\"src.world.gen2.World\")." .. field .. " = " .. cues[key]
      end
    end
    local healFields = {
      ball = "HEAL_BALL_FRAMES", flash = "HEAL_FLASH_FRAMES", flashes = "HEAL_FLASHES",
      anchor = "HEAL_ANCHOR", shiftX = "HEAL_SHIFT_X", shiftY = "HEAL_SHIFT_Y",
      flip = "HEAL_FLIP",
    }
    for key, field in pairs(healFields) do
      if heal[key] ~= nil then
        lines[#lines + 1] = "    require(\"src.world.gen2.World\")." .. field .. " = " .. heal[key]
      end
    end
    if heal.rod then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").ROD_OAM = { " .. M.rodText(heal.rod) .. " }"
    end
    if heal.fish and #heal.fish >= 4 then
      lines[#lines + 1] = "    require(\"src.world.gen2.Player\").FISH_ROW = { down = "
        .. heal.fish[1] .. ", up = " .. heal.fish[2] .. ", left = " .. heal.fish[3]
        .. ", right = " .. heal.fish[4] .. " }"
    end
    local function rowText(rows)
      local parts = {}
      for i = 1, 8 do parts[i] = tostring(rows[i]) end
      return "{ [0] = " .. table.concat(parts, ", ") .. " }"
    end
    if heal.tower then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").TOWER_ROWS = " .. rowText(heal.tower)
    end
    if heal.scroll then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").SCROLL_H = " .. rowText(heal.scroll)
    end
    if heal.water then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").WATER_ROWS = " .. rowText(heal.water)
    end
    if heal.whirlRows then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").WHIRL_ROWS = " .. rowText(heal.whirlRows)
    end
    if heal.lava then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").LAVA1_ROWS = " .. rowText(heal.lava)
    end
    if heal.lava2 then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").LAVA2_ROWS = " .. rowText(heal.lava2)
    end
    local function healBallText(rows)
      local parts = {}
      for i = 1, #rows do
        local flip = rows[i][3] and ", true" or ""
        parts[i] = "{ " .. rows[i][1] .. ", " .. rows[i][2] .. flip .. " }"
      end
      return table.concat(parts, ", ")
    end
    if healPc or healBalls then
      local machine = healPc or M.pairList(M.HEAL_PC_MACHINE)
      local balls = healBalls or M.tripleList(M.HEAL_PC_BALLS)
      local lights = {}
      for i = 1, #machine do lights[i] = "{ " .. machine[i][1] .. ", " .. machine[i][2] .. " }" end
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").HEAL_PC = { machine = { "
        .. table.concat(lights, ", ") .. " }, balls = { " .. healBallText(balls) .. " } }"
    end
    if healHof then
      lines[#lines + 1] = "    require(\"src.world.gen2.World\").HEAL_HOF = { balls = { "
        .. healBallText(healHof) .. " } }"
    end
    for _, wait in ipairs(g2Waits) do
      lines[#lines + 1] = "    require(\"" .. wait[1] .. "\")." .. wait[2] .. " = " .. wait[3]
    end
  elseif frlg then
    local charge = take(g, "seekerCharge", 0, 65535)
    local refuse = take(g, "seekerRefuse", 0, 255)
    local dice = take(g, "seekerDice", 1, 65535)
    local moved = gen3Move()
    local delays = gen3Delays()
    local arcs = gen3PlayerArc()
    if charge == nil and refuse == nil and dice == nil and not moved and not delays and not arcs then return end
    if charge ~= nil or refuse ~= nil or dice ~= nil then
    lines[#lines + 1] = "    local Seeker = require(\"src.core.game3.vs_seeker\")"
    if charge ~= nil then lines[#lines + 1] = "    Seeker.MAX_CHARGE = " .. charge end
    if refuse ~= nil then lines[#lines + 1] = "    Seeker.NO_REMATCH = " .. refuse end
    if dice ~= nil then lines[#lines + 1] = "    Seeker.REMATCH_DICE = " .. dice end
    end
  elseif rse then
    local moved = gen3Move()
    local delays = gen3Delays()
    local arcs = gen3PlayerArc()
    if not rseBike() and not moved and not delays and not arcs then return end
  elseif gen == 1 or ver == "red" or ver == "blue" or ver == "yellow" then
    local npcStep = take(g, "npcStep", 0, 255)
    local touch = take(g, "touchTurn", 0, 255)
    local loop = take(g, "loopFrames", 1, 255)
    local spinIter = take(g, "spinIter", 1, 255)
    local hopPeak = take(g, "hopPeak", 0, 255)
    local bobPeriod = take(g, "bobPeriod", 1, 255)
    local bobHalf = take(g, "bobHalf", 0, 255)
    local bobPixels = take(g, "bobPixels", 0, 255)
    local holeSink = take(g, "holeSink", 0, 255)
    local walkCycle = take(g, "walkCycle", 1, 255)
    local legFrom = take(g, "legFrom", 0, 255)
    local legTo = take(g, "legTo", 0, 255)
    local spinRise = take(g, "spinRise", 0, 255)
    local warpLift = take(g, "warpLift", 0, 255)
    local warpFrames = take(g, "warpFrames", 1, 255)
    local sightX = take(g, "sightX", 0, 255)
    local sightY = take(g, "sightY", 0, 255)
    local sightLeft = take(g, "sightLeft", -128, 127)
    local sightRight = take(g, "sightRight", -128, 127)
    local sightUp = take(g, "sightUp", -128, 127)
    local sightDown = take(g, "sightDown", -128, 127)
    local emote = take(g, "emoteFrames", 0, 255)
    local approach = take(g, "approachGap", 0, 255)
    local wanderLo = take(g, "wanderLo", 0, 65535)
    local wanderHi = take(g, "wanderHi", 0, 65535)
    local spawnLo = take(g, "spawnLo", 0, 65535)
    local spawnHi = take(g, "spawnHi", 0, 65535)
    local turnOdds = take(g, "turnOdds", 0, 100)
    local stayLo = take(g, "stayLo", 0, 65535)
    local stayHi = take(g, "stayHi", 0, 65535)
    local flyFade = take(g, "g1FlyFade", 0, 255)
    local flyFlap = take(g, "g1FlyFlap", 0, 255)
    local flyBeat = take(g, "g1FlyBeat", 0, 255)
    local flyStep = take(g, "g1FlyStep", 1, 255)
    local teleportOut = take(g, "g1TeleportOut", 0, 65535)
    local padOut = take(g, "g1PadOut", 0, 255)
    local teleportIn = take(g, "g1TeleportIn", 0, 255)
    local padIn = take(g, "g1PadIn", 0, 255)
    local dropSteps = take(g, "g1DropSteps", 0, 255)
    local holeIn = take(g, "g1HoleIn", 0, 255)
    local waitRows = {
      { "g1Delay", "src.core.Timing", "DELAY3", 0, 255 },
      { "g1FadeBlack", "src.core.Timing", "FADE_IN_FROM_BLACK", 0, 255 },
      { "g1OutWhite", "src.core.Timing", "FADE_OUT_TO_WHITE", 0, 255 },
      { "g1InWhite", "src.core.Timing", "FADE_IN_FROM_WHITE", 0, 255 },
      { "g1WarpOut", "src.core.Timing", "WARP_FADE_OUT", 0, 255 },
      { "g1WarpIn", "src.core.Timing", "WARP_FADE_IN", 0, 255 },
      { "g1BattleReturn", "src.core.Timing", "POST_BATTLE_RETURN", 0, 255 },
      { "g1HoleWait", "src.core.Timing", "DUNGEON_WARP_ARRIVAL", 0, 255 },
      { "g1Scroll", "src.core.Timing", "TEXT_SCROLL_PAIR", 0, 255 },
      { "g1TextWait", "src.core.Timing", "TEXT_PRE_ADVANCE", 0, 255 },
      { "g1PageClear", "src.core.Timing", "TEXT_PAGE_CLEAR", 0, 255 },
      { "g1YesNo", "src.core.Timing", "YES_NO_ANSWER", 0, 255 },
      { "g1Slide", "src.core.Timing", "BATTLE_SLIDE_IN_FRAMES", 0, 255 },
      { "g1SlidePx", "src.core.Timing", "BATTLE_SLIDE_PX_PER_FRAME", 0, 255 },
      { "g1TrainerGap", "src.core.Timing", "TRAINER_INTRO_SFX_GAP", 0, 255 },
      { "g1SendOut", "src.core.Timing", "BATTLE_START_SENDOUT", 0, 255 },
      { "g1MovePre", "src.core.Timing", "MOVE_ANIM_PRE", 0, 255 },
      { "g1MoveOff", "src.core.Timing", "MOVE_ANIM_OFF", 0, 255 },
      { "g1Miss", "src.core.Timing", "MOVE_STATUS_OR_MISS", 0, 255 },
      { "g1Substitute", "src.core.Timing", "SUBSTITUTE_ENTRY", 0, 255 },
      { "g1ShakeV", "src.core.Timing", "SHAKE_VERTICAL", 0, 255 },
      { "g1ShakeHeavy", "src.core.Timing", "SHAKE_HORIZ_HEAVY", 0, 255 },
      { "g1ShakeSlow", "src.core.Timing", "SHAKE_HORIZ_SLOW", 0, 255 },
      { "g1ShakeLight", "src.core.Timing", "SHAKE_HORIZ_LIGHT", 0, 255 },
      { "g1ShakeSlow2", "src.core.Timing", "SHAKE_HORIZ_SLOW2", 0, 255 },
      { "g1Blink", "src.core.Timing", "BLINK_MON", 0, 255 },
      { "g1Faint", "src.core.Timing", "FAINT_SLIDE", 0, 255 },
      { "g1FaintStep", "src.core.Timing", "FAINT_SLIDE_STEP", 0, 255 },
      { "g1Switch", "src.core.Timing", "SWITCH_PLAYER_MON", 0, 255 },
      { "g1CritText", "src.core.Timing", "CRIT_OHKO_TEXT", 0, 255 },
      { "g1HpBar", "src.core.Timing", "HP_BAR_PIXELS", 1, 255 },
      { "g1HpPixel", "src.core.Timing", "HP_BAR_PIXEL_STEP", 0, 255 },
      { "g1HpStep", "src.core.Timing", "HP_BAR_HP_STEP", 0, 255 },
      { "g1FadeStep", "src.render.Transition", "FADE_STEP_FRAMES", 1, 255 },
      { "g1Flash", "src.render.Transition", "FLASH_FRAMES", 0, 255 },
    }
    local waits = {}
    for _, row in ipairs(waitRows) do
      local n = take(g, row[1], row[4], row[5])
      if n ~= nil then waits[#waits + 1] = { row[2], row[3], n } end
    end
    local spinLines = {}
    local spinSet = (function()
      local wrote = false
      local function listLine(key, field)
        local list = M.holdList(g[key])
        if not list then return end
        wrote = true
        local parts = {}
        for i = 1, #list do parts[i] = tostring(list[i]) end
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field
          .. " = { " .. table.concat(parts, ", ") .. " }"
      end
      listLine("g1OutHolds", "TELEPORT_OUT_HOLDS")
      listLine("g1PadHolds", "WARP_PAD_OUT_HOLDS")
      listLine("g1InHolds", "TELEPORT_IN_HOLDS")
      listLine("g1PadInHolds", "TELEPORT_IN_PAD_HOLDS")
      listLine("g1HoleHolds", "HOLE_IN_HOLDS")
      listLine("g1ShipWater", "SS_ANNE_WATER")
      local rods = M.rodList(g.g1Rod)
      if rods then
        wrote = true
        local parts = {}
        for i = 1, #rods do
          local row = rods[i]
          local flip = row.flip and ", flip = true" or ""
          parts[i] = row.face .. " = { dx = " .. row.dx .. ", dy = " .. row.dy
            .. ", tile = " .. row.tile .. flip .. " }"
        end
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\").ROD_OAM = { "
          .. table.concat(parts, ", ") .. " }"
      end
      local inplace = take(g, "g1InPlace", 0, 255)
      local keep = take(g, "g1ShipKeep", 0, 255)
      local ghost = take(g, "g1GhostPad", 0, 255)
      local sail = take(g, "g1Sail", 0, 255)
      local sailStep = take(g, "g1SailStep", 0, 255)
      local smokeEvery = take(g, "g1SmokeEvery", 0, 255)
      local smokeX = take(g, "g1SmokeX", 0, 255)
      local smokeY = take(g, "g1SmokeY", 0, 255)
      local smokeDrift = take(g, "g1SmokeDrift", -128, 127)
      local shipX = take(g, "g1ShipX", 0, 255)
      local shipY = take(g, "g1ShipY", 0, 255)
      local shipW = take(g, "g1ShipW", 0, 255)
      local shipH = take(g, "g1ShipH", 0, 255)
      local function shipLine(value, field)
        if value == nil then return end
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field .. " = " .. value
      end
      shipLine(sail, "SS_ANNE_SAIL_PX")
      shipLine(sailStep, "SS_ANNE_PX_FRAMES")
      shipLine(smokeEvery, "SS_ANNE_SMOKE_EVERY")
      shipLine(smokeX, "SS_ANNE_SMOKE_DX")
      shipLine(smokeY, "SS_ANNE_SMOKE_DY")
      shipLine(smokeDrift, "SS_ANNE_SMOKE_DRIFT")
      shipLine(shipX, "SS_ANNE_BLOCK_X")
      shipLine(shipY, "SS_ANNE_BLOCK_Y")
      shipLine(shipW, "SS_ANNE_BLOCK_W")
      shipLine(shipH, "SS_ANNE_BLOCK_H")
      if inplace ~= nil then
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\").TELEPORT_OUT_INPLACE = " .. inplace
      end
      if keep ~= nil then
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\").SS_ANNE_KEEP_PX = " .. keep
      end
      if ghost ~= nil then
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\").GHOST_CULL_PAD = " .. ghost
      end
      local function pathLine(key, field)
        local pairs = M.pairList(g[key])
        if not pairs then return end
        wrote = true
        local parts = {}
        for i = 1, #pairs do parts[i] = "{ " .. pairs[i][1] .. ", " .. pairs[i][2] .. " }" end
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field
          .. " = { " .. table.concat(parts, ", ") .. " }"
      end
      pathLine("g1FlyOut", "FLY_PATH1")
      pathLine("g1FlyAway", "FLY_PATH2")
      pathLine("g1FlyIn", "FLY_PATH_IN")
      local function pointLine(key, field)
        local pairs = M.pairList(g[key])
        if not pairs then return end
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field
          .. " = { " .. pairs[1][1] .. ", " .. pairs[1][2] .. " }"
      end
      pointLine("g1FlyAnchor", "FLY_ANCHOR")
      pointLine("g1FlyLand", "FLY_ARRIVE_ANCHOR")
      local healBalls = M.tripleList(g.g1HealBalls)
      if healBalls then
        wrote = true
        local parts = {}
        for i = 1, #healBalls do
          local flip = healBalls[i][3] and ", true" or ""
          parts[i] = "{ " .. healBalls[i][1] .. ", " .. healBalls[i][2] .. flip .. " }"
        end
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\").HEAL_BALL_XY = { "
          .. table.concat(parts, ", ") .. " }"
      end
      local function healLine(key, field, minV, maxV)
        local n = take(g, key, minV, maxV)
        if n == nil then return end
        wrote = true
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field .. " = " .. n
      end
      healLine("g1HealMonX", "HEAL_MONITOR_X", 0, 255)
      healLine("g1HealMonY", "HEAL_MONITOR_Y", 0, 255)
      healLine("g1HealAnchor", "HEAL_ANCHOR", 0, 255)
      healLine("g1HealFlip", "HEAL_FLIP", 0, 255)
      healLine("g1HealBall", "HEAL_BALL_FRAMES", 0, 255)
      healLine("g1HealFlash", "HEAL_FLASH_FRAMES", 0, 255)
      healLine("g1HealFlashes", "HEAL_FLASHES", 0, 255)
      local function shadeLine(key, field)
        local list = M.holdList(g[key])
        if not list or #list < 4 then return end
        wrote = true
        local parts = {}
        for i = 1, 4 do
          local n = list[i]
          if n > 3 then n = 3 end
          parts[i] = tostring(n)
        end
        spinLines[#spinLines + 1] = "    require(\"src.world.OverworldController\")." .. field
          .. " = { [0] = " .. table.concat(parts, ", ") .. " }"
      end
      shadeLine("g1HealDmg", "HEAL_FLASH_MAP")
      shadeLine("g1HealGbc", "HEAL_FLASH_MAP_GBC")
      shadeLine("g1HealLit", "HEAL_OBP1_MAP")
      shadeLine("g1HealDim", "HEAL_OBP1_FLASH_MAP")
      return wrote
    end)()
    if npcStep == nil and touch == nil and loop == nil and spinIter == nil and hopPeak == nil and bobPeriod == nil and bobHalf == nil and bobPixels == nil and holeSink == nil and walkCycle == nil and legFrom == nil and legTo == nil and spinRise == nil and warpLift == nil and warpFrames == nil and sightX == nil and sightY == nil and sightLeft == nil and sightRight == nil and sightUp == nil and sightDown == nil and emote == nil and approach == nil and wanderLo == nil and wanderHi == nil and spawnLo == nil and spawnHi == nil and turnOdds == nil and stayLo == nil and stayHi == nil and flyFade == nil and flyFlap == nil and flyBeat == nil and flyStep == nil and teleportOut == nil and padOut == nil and teleportIn == nil and padIn == nil and dropSteps == nil and holeIn == nil and #waits == 0 and not spinSet then return end
    for i = 1, #spinLines do lines[#lines + 1] = spinLines[i] end
    if npcStep ~= nil then
      lines[#lines + 1] = "    require(\"src.world.NPC\").STEP_FRAMES = " .. npcStep
    end
    if touch ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").TOUCH_TURN_FRAMES = " .. touch
    end
    if loop ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").LOOP_FRAMES = " .. loop
    end
    if spinIter ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").SPIN_ITER_FRAMES = " .. spinIter
    end
    if hopPeak ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").HOP_PEAK = " .. hopPeak
    end
    if bobPeriod ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").BOB_PERIOD = " .. bobPeriod
    end
    if bobHalf ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").BOB_HALF = " .. bobHalf
    end
    if bobPixels ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").BOB_PIXELS = " .. bobPixels
    end
    if holeSink ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").HOLE_SINK = " .. holeSink
    end
    if walkCycle ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").WALK_CYCLE = " .. walkCycle
    end
    if legFrom ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").LEG_FROM = " .. legFrom
    end
    if legTo ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").LEG_TO = " .. legTo
    end
    if spinRise ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").SPIN_RISE = " .. spinRise
    end
    if warpLift ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").WARP_LIFT = " .. warpLift
    end
    if warpFrames ~= nil then
      lines[#lines + 1] = "    require(\"src.world.Player\").WARP_FRAMES = " .. warpFrames
    end
    if sightX ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_X = " .. sightX
    end
    if sightY ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_Y = " .. sightY
    end
    if sightLeft ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_LEFT = " .. sightLeft
    end
    if sightRight ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_RIGHT = " .. sightRight
    end
    if sightUp ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_UP = " .. sightUp
    end
    if sightDown ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").SIGHT_DOWN = " .. sightDown
    end
    if emote ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").EMOTE_FRAMES = " .. emote
    end
    if approach ~= nil then
      lines[#lines + 1] = "    require(\"src.world.OverworldController\").APPROACH_GAP = " .. approach
    end
    if wanderLo ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").WANDER_LO = " .. wanderLo end
    if wanderHi ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").WANDER_HI = " .. wanderHi end
    if spawnLo ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").SPAWN_LO = " .. spawnLo end
    if spawnHi ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").SPAWN_HI = " .. spawnHi end
    if turnOdds ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").TURN_ODDS = " .. turnOdds end
    if stayLo ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").STAY_LO = " .. stayLo end
    if stayHi ~= nil then lines[#lines + 1] = "    require(\"src.world.NPC\").STAY_HI = " .. stayHi end
    if flyFade ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").FLY_FADE_CONTROL = " .. flyFade end
    if flyFlap ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").FLY_FLAP = " .. flyFlap end
    if flyBeat ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").FLY_BEAT = " .. flyBeat end
    if flyStep ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").FLY_STEP = " .. flyStep end
    if teleportOut ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").TELEPORT_OUT_FRAMES = " .. teleportOut end
    if padOut ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").WARP_PAD_OUT_FRAMES = " .. padOut end
    if teleportIn ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").TELEPORT_IN_FRAMES = " .. teleportIn end
    if padIn ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").TELEPORT_IN_PAD_FRAMES = " .. padIn end
    if dropSteps ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").SPIN_DOWN_STEPS = " .. dropSteps end
    if holeIn ~= nil then lines[#lines + 1] = "    require(\"src.world.OverworldController\").HOLE_IN_FRAMES = " .. holeIn end
    for _, wait in ipairs(waits) do
      lines[#lines + 1] = "    require(\"" .. wait[1] .. "\")." .. wait[2] .. " = " .. wait[3]
    end
  else
    return
  end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
