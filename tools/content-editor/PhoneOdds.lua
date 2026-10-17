-- How long Gen 2 waits between Pokégear calls, and whether the coin flip rings.
-- The four waits shrink after each missed call. 0 minutes is ready immediately.
-- A pass line of 0 never rings. 256 always rings.

local M = {}
local DEFAULTS = { 20, 10, 5, 3 }

local function bag(S)
  return S.project and S.project.phoneOdds
end

function M.draw(S, x, y, w, App)
  local Kit = require("Kit")
  local s = Kit.scale
  local Generation = require("Generation")
  if not Generation.isGen2(S) or not S.project then return y end
  local function write(key, value, default)
    require("State").ensureProjectFields(S.project)
    S.project.phoneOdds = S.project.phoneOdds or {}
    local same = value == default
    if type(value) == "table" then
      same = #value == #default
      if same then
        for i = 1, #value do
          if value[i] ~= default[i] then same = false break end
        end
      end
    end
    S.project.phoneOdds[key] = same and nil or value
    if not next(S.project.phoneOdds) then S.project.phoneOdds = nil end
    App.markDirty()
  end
  local g = bag(S)
  Kit.caption(x, y, "Call waits, minutes")
  local shown = type(g and g.delays) == "table" and g.delays or DEFAULTS
  local nextDelays = {}
  for i = 1, 4 do
    local cur = tonumber(shown[i]) or DEFAULTS[i]
    local v = math.max(0, math.min(255, math.floor(
      require("RegList").num(App, "phone_delay_" .. i, x + (150 + (i - 1) * 70) * s, y, 60 * s, 28 * s, cur))))
    nextDelays[i] = v
  end
  local changed = false
  for i = 1, 4 do
    if nextDelays[i] ~= (tonumber(shown[i]) or DEFAULTS[i]) then changed = true end
  end
  if changed then write("delays", nextDelays, DEFAULTS) end
  y = y + 36 * s
  Kit.caption(x, y, "Ring below")
  local cur = g and g.passBelow
  if cur == nil then cur = 128 end
  local v = math.max(0, math.min(256, math.floor(
    require("RegList").num(App, "phone_pass", x + 280 * s, y, 90 * s, 28 * s, cur))))
  if v ~= cur then write("passBelow", v, 128) end
  return y + 36 * s
end

local function take(n, minV, maxV)
  n = tonumber(n)
  if n == nil then return nil end
  n = math.floor(n)
  if n < minV then n = minV end
  if n > maxV then n = maxV end
  return n
end

function M.emit(p, encode, out)
  local g = p.phoneOdds
  if type(g) ~= "table" then return end
  local ver = p.version
  local gen = p.generation
  local gen2 = gen == 2 or ver == "gold" or ver == "silver" or ver == "crystal"
  if not gen2 then return end
  local lines = {}
  if type(g.delays) == "table" then
    local parts = {}
    for i = 1, 4 do
      local n = take(g.delays[i], 0, 255)
      parts[i] = tostring(n or DEFAULTS[i])
    end
    lines[#lines + 1] = "    Phone.RECEIVE_CALL_DELAYS = { " .. table.concat(parts, ", ") .. " }"
  end
  local pass = take(g.passBelow, 0, 256)
  if pass ~= nil then lines[#lines + 1] = "    Phone.CALL_PASS_BELOW = " .. pass end
  if #lines == 0 then return end
  out[#out + 1] = "  mod.events:on(\"mods.loaded\", function()"
  out[#out + 1] = "    local Phone = require(\"src.core.gen2.Phone\")"
  for _, line in ipairs(lines) do out[#out + 1] = line end
  out[#out + 1] = "  end)"
  out[#out + 1] = ""
end

return M
