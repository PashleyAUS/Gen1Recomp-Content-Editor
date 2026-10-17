-- RULES tab: data registries from the wiki that had no GUI yet.
-- Function APIs (hooks, events, commands, screens) stay on the CODE tab.

local Kit = require("Kit")
local Theme = require("Theme")
local State = require("State")
local RegList = require("RegList")
local FormPane = require("FormPane")
local Generation = require("Generation")
local PAL = Theme.PAL

local Rules = {}

local ALL_MODES = {
  { id = "statuses", label = "STATUSES",
    tip = "Status labels, catch/wobble bonuses, stat cuts (R29)" },
  { id = "rulesets", label = "RULESETS", gen1 = true,
    tip = "Battle quirk toggles (R38). Gold has no ruleset dispatch." },
  { id = "transitions", label = "FADES", gen1 = true,
    tip = "Warp / battle wipe frames and flash (R42). Gold uses cart wipes." },
  { id = "scales", label = "SCALES",
    tip = "Per-image battle sprite scale (R36)" },
  { id = "apricorns", label = "APRICORNS", gen2 = true,
    tip = "Kurt apricorn → ball rows" },
  { id = "radio", label = "RADIO", gen2 = true,
    tip = "Pokegear / wall-radio stations" },
  { id = "return", label = "RETURN", gen2 = true,
    tip = "Return and Frustration power" },
  { id = "flail", label = "FLAIL", gen2 = true,
    tip = "Reversal power from remaining HP" },
  { id = "magnitude", label = "MAGNITUDE", gen2 = true,
    tip = "Magnitude roll, power, and printed number" },
  { id = "moves", label = "MOVES",
    tip = "Pay Day, Rollout, Future Sight, and Hidden Power" },
  { id = "heal", label = "HEAL",
    tip = "Recover, Substitute, and time-of-day healing" },
  { id = "hits", label = "HITS",
    tip = "Multi-hit, Perish Song, and Encore" },
  { id = "residuals", label = "RESIDUALS",
    tip = "Leech Seed, Wrap, Nightmare, Curse, and Leftovers" },
  { id = "special", label = "SPECIAL",
    tip = "Protect, Bide, and one-hit KO accuracy" },
  { id = "locks", label = "LOCKS",
    tip = "Disable, Spite, Uproar, and crash damage" },
  { id = "switch", label = "SWITCH",
    tip = "Roar, Whirlwind, Teleport, and Transform PP" },
  { id = "flee", label = "FLEE",
    tip = "Running from a wild battle" },
  { id = "spikes", label = "SPIKES", gen2 = true,
    tip = "Spikes damage when a Pokémon switches in" },
  { id = "formula", label = "FORMULA",
    tip = "The level, stat, and minimum-damage steps of a damaging move" },
  { id = "accuracy", label = "ACCURACY",
    tip = "How a move's accuracy becomes a hit roll" },
  { id = "statcalc", label = "STAT CALC",
    tip = "How base stats, DVs, and effort become battle stats" },
  { id = "catchmath", label = "CATCH",
    tip = "How HP and status change a thrown ball's catch rate" },
  { id = "effort", label = "EFFORT",
    tip = "Stat experience and effort points from a defeated Pokémon" },
  { id = "pp", label = "PP UP",
    tip = "How many extra PP a PP Up adds" },
  { id = "crits", label = "CRITS",
    tip = "Critical-hit chances and damage roll" },
  { id = "exp", label = "EXP",
    tip = "Experience divisor and trainer, trade, and Lucky Egg bonuses" },
  { id = "prizes", label = "PRIZES",
    tip = "Trainer prize payout, Game Corner prices, and Buena's points" },
  { id = "badges", label = "BADGES",
    tip = "Badge stat and type boosts" },
  { id = "stab", label = "STAB",
    tip = "Same-type attack bonus" },
  { id = "screens", label = "SCREENS",
    tip = "Reflect and Light Screen defense" },
  { id = "stages", label = "STAGES",
    tip = "Stat stage multipliers from -6 to +6" },
  { id = "ailments", label = "AILMENTS",
    tip = "Poison, burn, and paralysis amounts" },
  { id = "weather", label = "WEATHER", gen2 = true,
    tip = "Rain, sun, and sandstorm battle effects" },
  { id = "pokerus", label = "POKERUS", gen2 = true,
    tip = "Spread, direction, and new-infection odds" },
  { id = "safari", label = "SAFARI", gen1 = true,
    tip = "Entry price, Safari Balls, steps and exit" },
  { id = "lua", label = "LUA",
    tip = "Wiki recipes that are functions — author them on CODE" },
}

local RULESET_FLAGS = {
  { key = "oneIn256Miss", label = "1/256 miss" },
  { key = "critUsesBaseSpeed", label = "Crit base SPD" },
  { key = "critIgnoresStages", label = "Crit ignore stages" },
  { key = "focusEnergyBug", label = "Focus Energy bug" },
  { key = "enemyUnlimitedPP", label = "Enemy free PP" },
  { key = "hyperBeamSkipRechargeOnKO", label = "Hyper Beam KO skip" },
  { key = "residualAfterMove", label = "Residual after move" },
}

local LUA_RECIPES = {
  { id = "R16", api = "growth_rates:register", note = "expForLevel(level) function" },
  { id = "R17", api = "evolution_methods:register", note = "check / describe functions" },
  { id = "R19", api = "trainers:patch(brain)", note = "custom AI chooser function" },
  { id = "R20", api = "mod.commands:register", note = "script command handler" },
  { id = "R21", api = "tokens:register", note = "text token expander" },
  { id = "R23", api = "mod.world:spawnNpc", note = "runtime NPC spawn" },
  { id = "R27", api = "events:on", note = "battle / world event listener" },
  { id = "R28", api = "hooks:wrap", note = "wrap battle.damage and other hooks" },
  { id = "R31", api = "hooks:wrap(ui.start_menu.items)", note = "Start-menu entries" },
  { id = "R32", api = "screens:register", note = "custom screen { new = fn }" },
  { id = "R33", api = "mod.save:get/set", note = "persist mod state" },
  { id = "R34", api = "mod.options:define", note = "mod options row" },
  { id = "R35", api = "mod.exports / mod.find", note = "inter-mod API" },
  { id = "R37", api = "hooks:wrap(intro.oak_speech.build)", note = "reshape Oak speech" },
  { id = "R39", api = "battle.overlay", note = "shiny / HUD overlay draw" },
  { id = "R40", api = "hooks:wrap(movement.speed)", note = "running shoes" },
  { id = "R41", api = "world.tod + map.palette", note = "day / night palettes" },
  { id = "R44", api = "hooks:wrap(music.volume)", note = "distance / indoor volume" },
  { id = "R45", api = "hooks:wrap(ui.list_menu)", note = "bag wrap / hold-scroll" },
  { id = "R46", api = "hooks:wrap(ui.naming.grid)", note = "naming-screen digits" },
  { id = "R47", api = "hooks:wrap(zoom.range)", note = "survey zoom range" },
  { id = "R48", api = "hooks:wrap(render.letterbox)", note = "SGB border" },
  { id = "R49", api = "hooks:wrap(pokemon.sprite)", note = "pick sprites at draw time" },
  { id = "R52", api = "mod.world:availableFieldActions", note = "one-button field actions" },
  { id = "R53", api = "battle.caught_marker_visible", note = "battle QoL toggles" },
  { id = "R54", api = "mod.steps", note = "real-world step events" },
}

local RADIO_FALLBACK = {
  OAKS_POKEMON_TALK = { channel = 1, name = "OAK's POKéMON Talk" },
  POKEDEX_SHOW = { channel = 2, name = "POKéDEX Show" },
  POKEMON_MUSIC = { channel = 3, name = "POKéMON Music" },
  LUCKY_CHANNEL = { channel = 4, name = "Lucky Channel" },
  UNOWN_RADIO = { channel = 5, name = "Unown Radio" },
  PLACES_AND_PEOPLE = { channel = 6, name = "Places & People" },
  LETS_ALL_SING = { channel = 7, name = "Let's All Sing" },
  ROCKET_RADIO = { channel = 8, name = "Rocket Radio" },
}

local function modesFor(S)
  local gen2 = Generation.isGen2(S)
  local out = {}
  for _, m in ipairs(ALL_MODES) do
    if m.gen1 and gen2 then
      -- skip
    elseif m.gen2 and not gen2 then
      -- skip
    else
      out[#out + 1] = m
    end
  end
  return out
end

local function cloneData(rec, extra)
  local copy = {}
  if type(rec) == "table" then
    for k, v in pairs(rec) do
      if type(k) == "string" and k:sub(1, 1) ~= "_" and type(v) ~= "function" then
        if type(v) == "table" then
          copy[k] = cloneData(v)
        else
          copy[k] = v
        end
      end
    end
  end
  if extra then
    for k, v in pairs(extra) do copy[k] = v end
  end
  return copy
end

local function allocId(proj, data, prefix)
  local nid = prefix
  local n = 1
  while proj[nid] or (data and data[nid]) do
    n = n + 1
    nid = prefix .. "_" .. n
  end
  return nid
end

local function statusData(S)
  if Generation.isGen2(S) then
    local t = S.data and (S.data.gen2Statuses or S.data.statuses)
    if type(t) == "table" and next(t) then return t end
    local ok, Battle = pcall(require, "src.battle.gen2.Battle")
    if ok and Battle and type(Battle.STATUSES) == "table" then
      return Battle.STATUSES
    end
    return {}
  end
  local t = S.data and S.data.statuses
  if type(t) == "table" and next(t) then return t end
  local ok, Status = pcall(require, "src.battle.Status")
  if ok and Status and type(Status.RECORDS) == "table" then
    return Status.RECORDS
  end
  return {}
end

local function rulesetData(S)
  local t = S.data and S.data.rulesets
  if type(t) == "table" and next(t) then return t end
  local out = {}
  local ok1, a = pcall(require, "src.battle.rulesets.gen1_faithful")
  if ok1 and type(a) == "table" and a.name then out[a.name] = a end
  local ok2, b = pcall(require, "src.battle.rulesets.modern_clean")
  if ok2 and type(b) == "table" and b.name then out[b.name] = b end
  return out
end

local function transitionData(S)
  local t = S.data and S.data.transitions
  if type(t) == "table" and next(t) then return t end
  local out = {}
  local okB, BT = pcall(require, "src.render.BattleTransition")
  if okB and BT and type(BT.STYLES) == "table" then
    for id, rec in pairs(BT.STYLES) do out[id] = rec end
  end
  local okT, Tr = pcall(require, "src.render.Transition")
  if okT and Tr and type(Tr.STYLES) == "table" then
    for id, rec in pairs(Tr.STYLES) do out[id] = rec end
  end
  return out
end

local function scaleData(S)
  return (S.data and S.data.battle_sprite_scales) or {}
end

local function apricornData(S)
  local t = S.data and (S.data.gen2Apricorns or S.data.apricorns)
  if type(t) == "table" and next(t) then return t end
  local ok, Apr = pcall(require, "src.core.gen2.Apricorns")
  if ok and Apr and type(Apr.BALLS) == "table" then
    local out = {}
    for i, row in ipairs(Apr.BALLS) do
      if type(row) == "table" and type(row.apricorn) == "string" then
        out[row.apricorn] = {
          apricorn = row.apricorn,
          ball = row.ball,
          event = row.event,
          index = i,
        }
      end
    end
    return out
  end
  return {}
end

local function radioData(S)
  local t = S.data and (S.data.gen2RadioChannels or S.data.radio_channels)
  if type(t) == "table" and next(t) then return t end
  return RADIO_FALLBACK
end

local SPECS = {
  statuses = {
    projectKey = "statuses",
    caption = "STATUSES",
    newId = "MOD_STATUS",
    data = statusData,
    newRec = function()
      return {
        label = "NEW", hudLabel = "NEW",
        catchBonus = 0, shakeBonus = 0,
        cureOnSwitch = false,
        _isNew = true,
      }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      local bits = { rec.label or rec.id or "?" }
      if rec.catchBonus then bits[#bits + 1] = "catch=" .. tostring(rec.catchBonus) end
      if rec.statPenalty and rec.statPenalty.stat then
        bits[#bits + 1] = rec.statPenalty.stat .. "/ " .. tostring(rec.statPenalty.div or 1)
      end
      return table.concat(bits, "  ·  ")
    end,
  },
  rulesets = {
    projectKey = "rulesets",
    caption = "RULESETS",
    newId = "custom_rules",
    data = rulesetData,
    newRec = function()
      return { name = "custom", _isNew = true }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      return rec.name or "?"
    end,
  },
  transitions = {
    projectKey = "transitions",
    caption = "FADES",
    newId = "custom_fade",
    data = transitionData,
    newRec = function()
      return { frames = 30, flash = false, _isNew = true }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      local bits = { tostring(rec.frames or "?") .. "f" }
      if rec.flash then bits[#bits + 1] = "flash" end
      if rec.sound and rec.sound ~= "" then bits[#bits + 1] = rec.sound end
      return table.concat(bits, "  ·  ")
    end,
  },
  scales = {
    projectKey = "battle_sprite_scales",
    caption = "SPRITE SCALES",
    newId = "custom_scale",
    data = scaleData,
    newRec = function()
      return { path = "", scale = 1, _isNew = true }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      return string.format("%s  ×%s", rec.path or "?", tostring(rec.scale or 1))
    end,
  },
  apricorns = {
    projectKey = "apricorns",
    caption = "APRICORNS",
    newId = "MOD_APRICORN",
    data = apricornData,
    newRec = function()
      return { apricorn = "MOD_APRICORN", ball = "POKE_BALL", event = 0, index = 8, _isNew = true }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      return string.format("%s → %s", rec.apricorn or "?", rec.ball or "?")
    end,
  },
  radio = {
    projectKey = "radio_channels",
    caption = "RADIO",
    newId = "MOD_RADIO",
    data = radioData,
    newRec = function()
      return { channel = 9, name = "NEW STATION", _isNew = true }
    end,
    summarize = function(rec)
      if type(rec) ~= "table" then return "" end
      return string.format("ch %s  %s", tostring(rec.channel or "?"), rec.name or "")
    end,
  },
}

local function projectBag(S, spec)
  State.ensureProjectFields(S.project)
  return S.project[spec.projectKey]
end

local function resolve(S, spec, id)
  local proj = projectBag(S, spec)
  if proj[id] ~= nil then return proj[id], true end
  local data = spec.data(S)
  if data[id] ~= nil then return data[id], false end
  return nil, false
end

local function drawLua(S, x, y, w, h)
  local s = Kit.scale
  Kit.caption(x, y, "LUA APIS  (CODE TAB)")
  local fy, view = FormPane.begin(S, "rulesLuaScroll", x, y + 22 * s, w, h - 22 * s)
  local top = fy
  Kit.text("micro",
    "These wiki recipes are Lua functions. Author them as files on the CODE tab. Data registries are the other RULES modes plus Pokémon, Items, Maps, UI, Audio, Events.",
    x, fy, PAL.muted)
  fy = fy + 36 * s
  local rowH = 36 * s
  for _, row in ipairs(LUA_RECIPES) do
    Kit.card(x, fy, w, rowH, 8 * s)
    Kit.text("small", row.id .. "  " .. row.api, x + 10 * s, fy + 4 * s, PAL.text)
    Kit.text("micro", row.note, x + 10 * s, fy + 20 * s, PAL.faint)
    fy = fy + rowH + 6 * s
  end
  FormPane.finish(S, "rulesLuaScroll", top, fy, view)
end

local function drawStatuses(S, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  local gen2 = Generation.isGen2(S)
  local r = type(rec) == "table" and rec or {}
  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end
  row("Label", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().label) or r.label or "")
    local v = RegList.field(App, "ru_st_lab", fx, fy_, fw, fh_, cur, "PSN")
    if v ~= cur then ensure().label = v end
  end)
  row("HUD label", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().hudLabel) or r.hudLabel or "")
    local v = RegList.field(App, "ru_st_hud", fx, fy_, fw, fh_, cur, "PSN")
    if v ~= cur then ensure().hudLabel = v ~= "" and v or nil end
  end)
  row("Catch bonus", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().catchBonus) or r.catchBonus or 0
    local v = RegList.num(App, "ru_st_catch", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().catchBonus = v end
  end)
  row("Shake bonus", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().shakeBonus) or r.shakeBonus or 0
    local v = RegList.num(App, "ru_st_shake", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().shakeBonus = v end
  end)
  row("Cure on switch", function(fx, fy_, fw, fh_)
    local cur = not not ((owned and ensure().cureOnSwitch) or r.cureOnSwitch)
    if Kit.chip(fx, fy_, 80 * s, fh_, cur and "YES" or "NO", cur, PAL.yellow) then
      ensure().cureOnSwitch = not cur
    end
  end)
  row("Move priority", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().beforeMovePriority) or r.beforeMovePriority or 0
    local v = RegList.num(App, "ru_st_pri", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().beforeMovePriority = v end
  end)
  local pen = (owned and ensure().statPenalty) or r.statPenalty or {}
  row("Stat penalty", function(fx, fy_, fw, fh_)
    local stat = tostring(pen.stat or "")
    local v = RegList.field(App, "ru_st_pstat", fx, fy_, math.max(80 * s, fw - 90 * s),
      fh_, stat, "attack")
    if v ~= stat then
      local e = ensure()
      e.statPenalty = e.statPenalty or {}
      e.statPenalty.stat = v ~= "" and v or nil
      if not e.statPenalty.stat then e.statPenalty = nil end
    end
    local div = tonumber(pen.div) or 1
    local dv = RegList.num(App, "ru_st_pdiv", fx + fw - 80 * s, fy_, 80 * s, fh_, div)
    if dv ~= div then
      local e = ensure()
      if type(e.statPenalty) ~= "table" or not e.statPenalty.stat then
        e.statPenalty = { stat = "attack", div = dv }
      else
        e.statPenalty.div = dv
      end
    end
  end)
  if gen2 then
    row("Heal class", function(fx, fy_, fw, fh_)
      local cur = tostring((owned and ensure().healClass) or r.healClass or "")
      local v = RegList.field(App, "ru_st_heal", fx, fy_, fw, fh_, cur, "psn")
      if v ~= cur then ensure().healClass = v ~= "" and v or nil end
    end)
    row("Inflict text", function(fx, fy_, fw, fh_)
      local cur = tostring((owned and ensure().inflictText) or r.inflictText or "")
      local v = RegList.field(App, "ru_st_inf", fx, fy_, fw, fh_, cur, " was poisoned!")
      if v ~= cur then ensure().inflictText = v ~= "" and v or nil end
    end)
  end
  Kit.text("micro",
    "canInflict / onInflict / beforeMove / residual are functions — author those on CODE.",
    viewX, fy, PAL.faint)
  fy = fy + 28 * s
  return fy
end

local function drawRulesets(_, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  local r = type(rec) == "table" and rec or {}
  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end
  row("Name", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().name) or r.name or "")
    local v = RegList.field(App, "ru_rs_name", fx, fy_, fw, fh_, cur, "custom")
    if v ~= cur then ensure().name = v end
  end)
  row("Crit rate", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().critRate) or r.critRate
    local shown = cur == nil and "" or tostring(cur)
    local v = RegList.field(App, "ru_rs_crit", fx, fy_, 80 * s, fh_, shown, "0")
    if v ~= shown then
      local n = tonumber(v)
      ensure().critRate = n
    end
  end)
  row("Rand min", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().randMin) or r.randMin or 217
    local v = RegList.num(App, "ru_rs_rmin", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().randMin = v end
  end)
  row("Rand max", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().randMax) or r.randMax or 255
    local v = RegList.num(App, "ru_rs_rmax", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().randMax = v end
  end)
  for _, flag in ipairs(RULESET_FLAGS) do
    row(flag.label, function(fx, fy_, fw, fh_)
      local cur = not not ((owned and ensure()[flag.key]) or r[flag.key])
      if Kit.chip(fx, fy_, 80 * s, fh_, cur and "YES" or "NO", cur, PAL.yellow) then
        ensure()[flag.key] = not cur
      end
    end)
  end
  return fy
end

local function drawTransitions(_, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  local r = type(rec) == "table" and rec or {}
  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end
  row("Frames", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().frames) or r.frames or 30
    local v = math.max(1, RegList.num(App, "ru_tr_fr", fx, fy_, 80 * s, fh_, cur))
    if v ~= cur then ensure().frames = v end
  end)
  row("Frames in", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().framesIn) or r.framesIn
    local shown = cur == nil and "" or tostring(cur)
    local v = RegList.field(App, "ru_tr_fin", fx, fy_, 80 * s, fh_, shown, "0")
    if v ~= shown then ensure().framesIn = tonumber(v) end
  end)
  row("Sound", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().sound) or r.sound or "")
    local v = RegList.field(App, "ru_tr_snd", fx, fy_, fw, fh_, cur, "SFX_...")
    if v ~= cur then ensure().sound = v ~= "" and v or nil end
  end)
  row("Flash", function(fx, fy_, fw, fh_)
    local cur = not not ((owned and ensure().flash) or r.flash)
    if Kit.chip(fx, fy_, 80 * s, fh_, cur and "YES" or "NO", cur, PAL.yellow) then
      ensure().flash = not cur
    end
  end)
  Kit.text("micro", "Custom wipe draw() is a function — author that on CODE.",
    viewX, fy, PAL.faint)
  fy = fy + 28 * s
  return fy
end

local function drawScales(_, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  local r = type(rec) == "table" and rec or {}
  Kit.text("small", "Path", viewX, fy + 6 * s, PAL.caption)
  local fx = viewX + labelW
  local fieldW = viewW - labelW - 8 * s
  local cur = tostring((owned and ensure().path) or r.path or "")
  local v = RegList.field(App, "ru_sc_path", fx, fy, math.max(40 * s, fieldW - 100 * s),
    fh, cur, "assets/...")
  if v ~= cur then ensure().path = v end
  if Kit.button(fx + fieldW - 96 * s, fy, 96 * s, fh, "Browse", {
      kind = "ghost", tooltip = "Import PNG into mod",
    }) then
    App.pickFile("Battle pic PNG", "PNG (*.png)|*.png|All|*.*", function(picked)
      App.importToMod(picked, nil, function(rel)
        ensure().path = rel
        local Preview = require("Preview")
        if Preview.invalidate then Preview.invalidate() end
      end)
    end)
  end
  fy = fy + fh + 8 * s
  Kit.text("small", "Scale", viewX, fy + 6 * s, PAL.caption)
  local sc = (owned and ensure().scale) or r.scale or 1
  local nv = RegList.num(App, "ru_sc_sc", fx, fy, 80 * s, fh, sc)
  if nv ~= sc then
    if nv < 0.25 then nv = 0.25 end
    if nv > 4 then nv = 4 end
    ensure().scale = nv
  end
  fy = fy + fh + 8 * s
  Kit.text("micro",
    "1 = native pixels. Image-level scale beats species battleScaleFront/Back. Range 0.25–4.",
    viewX, fy, PAL.faint)
  fy = fy + 28 * s
  return fy
end

local function drawApricorns(S, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  local r = type(rec) == "table" and rec or {}
  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end
  row("Apricorn", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().apricorn) or r.apricorn or "")
    local v = RegList.suggestField(App, S, "ru_ap_apr", fx, fy_, fw, fh_, cur,
      "RED_APRICORN", function() return require("Autocomplete").itemIds(S) end)
    if v ~= cur then ensure().apricorn = v end
  end)
  row("Ball", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().ball) or r.ball or "")
    local v = RegList.suggestField(App, S, "ru_ap_ball", fx, fy_, fw, fh_, cur,
      "LEVEL_BALL", function() return require("Autocomplete").itemIds(S) end)
    if v ~= cur then ensure().ball = v end
  end)
  row("Event", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().event) or r.event or 0
    local v = RegList.num(App, "ru_ap_ev", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().event = v end
  end)
  row("Index", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().index) or r.index or 1
    local v = math.max(1, RegList.num(App, "ru_ap_ix", fx, fy_, 80 * s, fh_, cur))
    if v ~= cur then ensure().index = v end
  end)
  return fy
end

local function drawRadio(S, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  fy = require("LotteryOdds").draw(S, viewX, fy, viewW, App)
  local r = type(rec) == "table" and rec or {}
  local function row(label, body)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    body(viewX + labelW, fy, viewW - labelW - 8 * s, fh)
    fy = fy + fh + 8 * s
  end
  row("Channel", function(fx, fy_, fw, fh_)
    local cur = (owned and ensure().channel) or r.channel or 1
    local v = RegList.num(App, "ru_rd_ch", fx, fy_, 80 * s, fh_, cur)
    if v ~= cur then ensure().channel = v end
  end)
  row("Name", function(fx, fy_, fw, fh_)
    local cur = tostring((owned and ensure().name) or r.name or "")
    local v = RegList.field(App, "ru_rd_nm", fx, fy_, fw, fh_, cur, "STATION")
    if v ~= cur then ensure().name = v ~= "" and v or nil end
  end)
  Kit.text("micro", "Channel 0 is region/time-of-day, not a station. Do not claim it.",
    viewX, fy, PAL.faint)
  fy = fy + 28 * s
  return fy
end

local function drawSpecial(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesSpecialScroll", "special", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Protect, Bide, and OHKO")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "Protect starts at 255 and halves on each repeat. Bide stores 2 or 3 turns and pays back double. A one-hit KO gains 2 accuracy for each level the user leads by."
    or "Bide stores for 2 or 3 turns and pays back double the damage it took.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.specialRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.specialRules = nil else S.project.specialRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Protect starting chance", "protectStart", 255, 0, 255, "ru_sp_pstart")
    knob("Protect decay divisor", "protectDiv", 2, 1, 16, "ru_sp_pdiv")
    knob("Bide minimum turns", "bideMin", 2, 1, 16, "ru_sp_bmin")
    knob("Bide turn span", "bideSpan", 2, 1, 16, "ru_sp_bspan")
    knob("Bide payback multiplier", "bideMult", 2, 0, 16, "ru_sp_bmult")
    knob("OHKO accuracy per level", "ohkoScale", 2, 0, 16, "ru_sp_oscale")
    knob("OHKO accuracy cap", "ohkoCap", 255, 0, 255, "ru_sp_ocap")
  else
    knob("Bide low roll", "bideLo", 2, 1, 16, "ru_sp_blo")
    knob("Bide high roll", "bideHi", 3, 1, 16, "ru_sp_bhi")
    knob("Bide payback multiplier", "bideMult", 2, 0, 16, "ru_sp_bmult")
  end
  FormPane.finish(S, "rulesSpecialScroll", contentTop, fy + fh, view)
end

local function drawLocks(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesLocksScroll", "locks", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Disable, Spite, and crashes")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "Disable rerolls a zero. The cart adds 1 to a 1-7 roll, so it lasts 2 to 8 turns. Spite removes 2 to 5 PP."
    or "Disable lasts 1 to 8 turns. Jump Kick and Hi Jump Kick crash for 1 HP.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.lockRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.lockRules = nil else S.project.lockRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Disable roll size", "disableRoll", 8, 1, 16, "ru_lk_droll")
    knob("Disable retries", "disableTries", 8, 1, 16, "ru_lk_dtry")
    knob("Disable added turns", "disableAdd", 1, 0, 16, "ru_lk_dadd")
    knob("Spite minimum PP", "spiteMin", 2, 0, 16, "ru_lk_smin")
    knob("Spite PP span", "spiteSpan", 4, 1, 16, "ru_lk_sspan")
  else
    knob("Disable low roll", "disableLo", 1, 0, 16, "ru_lk_dlo")
    knob("Disable high roll", "disableHi", 8, 0, 16, "ru_lk_dhi")
    knob("Crash damage", "crashDamage", 1, 0, 255, "ru_lk_crash")
  end
  FormPane.finish(S, "rulesLocksScroll", contentTop, fy + fh, view)
end

local function drawSwitch(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesSwitchScroll", "switch", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Forced switches")
  fy = fy + 22 * s
  Kit.text("micro",
    "A higher-level user always sends the foe away. A lower-level user still succeeds when the roll meets a quarter of the target's level. Transform copies each move with 5 PP.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.switchRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.switchRules = nil else S.project.switchRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Level divisor", "forceOutDiv", 4, 1, 255, "ru_sw_div")
  knob("Transform PP", "transformPp", 5, 0, 64, "ru_sw_pp")
  FormPane.finish(S, "rulesSwitchScroll", contentTop, fy + fh, view)
end

local function drawFlee(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesFleeScroll", "flee", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Running")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "A faster Pokémon always escapes. Otherwise the chance is your Speed times 32, divided by a quarter of the foe's Speed, plus 30 for every try including this one. 256 or more always works."
    or "A faster Pokémon always escapes. Otherwise the chance is your Speed times 32, divided by a quarter of the foe's Speed, plus 30 for each earlier try. 256 or more always works.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.fleeRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.fleeRules = nil else S.project.fleeRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Foe Speed divisor", "speedDiv", 4, 1, 255, "ru_fl_div")
  knob("Speed multiplier", "num", 32, 0, 999, "ru_fl_num")
  knob("Bonus per try", "bonus", 30, 0, 255, "ru_fl_bonus")
  knob("Always-escape total", "cap", 256, 2, 999, "ru_fl_cap")
  FormPane.finish(S, "rulesFleeScroll", contentTop, fy + fh, view)
end

local function drawPp(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesPpScroll", "pp", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "PP Up")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "Each PP Up adds the move's base PP divided by this number, and that bonus stops at the cap. A move can take up to the maximum number of PP Ups."
    or "Each PP Up adds the move's base PP divided by this number. A move can take up to the maximum number of PP Ups.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.ppRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.ppRules = nil else S.project.ppRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("PP divisor", "div", 5, 1, 255, "ru_pp_div")
  if gen2 then
    knob("Bonus cap", "cap", 7, 0, 63, "ru_pp_cap")
  end
  knob("Maximum PP Ups", "maxUps", 3, 0, 3, "ru_pp_ups")
  FormPane.finish(S, "rulesPpScroll", contentTop, fy + fh, view)
end

local function drawEffort(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesEffortScroll", "effort", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Effort")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "A defeated Pokémon adds its base stats as stat experience, up to the cap. Pokérus multiplies that gain. Exp. Share divides the base stats before the split."
    or "A defeated Pokémon adds its base stats as stat experience, split among the participants, up to the cap.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.effort
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.effort = nil else S.project.effort = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 90 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Stat experience cap", "cap", 65535, 0, 65535, "ru_ef_cap")
  if gen2 then
    knob("Pokérus multiplier", "pokerus", 2, 0, 16, "ru_ef_pk")
    knob("Exp. Share divisor", "shareDiv", 2, 1, 16, "ru_ef_share")
  end
  FormPane.finish(S, "rulesEffortScroll", contentTop, fy + fh, view)
end

local function drawCatchMath(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesCatchScroll", "catchmath", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Catch formula")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "The rate uses max HP times the first multiplier, minus current HP times the second. When the max term reaches the overflow, both terms are divided by the shift, and the max term keeps only the overflow byte."
    or "Current HP is divided by the HP divisor. Max HP is multiplied by the scale and divided by the ball's HP factor. A failed throw then shakes once for each band the result reaches.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.catchMath
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.catchMath = nil else S.project.catchMath = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 90 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Max HP multiplier", "maxMult", 3, 0, 16, "ru_ct_max")
    knob("Current HP multiplier", "curMult", 2, 0, 16, "ru_ct_cur")
    knob("Overflow", "overflow", 256, 1, 9999, "ru_ct_over")
    knob("Overflow divisor", "shift", 4, 1, 255, "ru_ct_shift")
    knob("Overflow byte", "lowByte", 256, 1, 9999, "ru_ct_low")
    knob("Catch roll", "catchDice", 256, 1, 9999, "ru_ct_dice")
    fy = require("WobbleOdds").draw(S, App, viewX, fy, w)
  else
    knob("HP divisor", "hpDiv", 4, 1, 255, "ru_ct_div")
    knob("HP scale", "hpScale", 255, 0, 255, "ru_ct_scale")
    knob("Factor cap", "factorCap", 255, 0, 255, "ru_ct_cap")
    knob("Wobble numerator", "wobbleNum", 100, 0, 255, "ru_ct_wnum")
    knob("Wobble denominator", "wobbleDen", 255, 1, 255, "ru_ct_wden")
    knob("Status shake bonus", "shakeBonus", 5, 0, 255, "ru_ct_bonus")
    knob("One shake below", "shake1", 10, 0, 255, "ru_ct_s1")
    knob("Two shakes below", "shake2", 30, 0, 255, "ru_ct_s2")
    knob("Three shakes below", "shake3", 70, 0, 255, "ru_ct_s3")
    knob("Second roll span", "checkSpan", 256, 1, 256, "ru_ct_span")
  end
  FormPane.finish(S, "rulesCatchScroll", contentTop, fy + fh, view)
end

local function drawStatCalc(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesStatCalcScroll", "statcalc", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Stat calculation")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "A stat is the base times the base multiplier, plus the DV times the DV multiplier, plus the square root of stat experience divided by the effort divisor. That total is multiplied by the level, divided by the level divisor, then the add is applied. HP also adds the level times the HP level multiplier."
    or "A stat is the base plus the DV, times the base multiplier, plus the effort term. That total is multiplied by the level and divided by the level divisor. HP then adds the level times the HP level multiplier. Other stats add the stat add.",
    viewX, fy, PAL.muted)
  fy = fy + 60 * s
  local function bag()
    return S.project.statCalc
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.statCalc = nil else S.project.statCalc = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Base multiplier", "baseMult", 2, 0, 16, "ru_sc_base")
  if gen2 then
    knob("DV multiplier", "dvMult", 2, 0, 16, "ru_sc_dv")
  else
    knob("Effort cap", "evCap", 255, 0, 255, "ru_sc_cap")
  end
  knob("Effort divisor", "evDiv", 4, 1, 255, "ru_sc_ev")
  knob("Level divisor", "levelDen", 100, 1, 255, "ru_sc_den")
  knob("Stat add", "statAdd", 5, 0, 255, "ru_sc_add")
  knob("HP add", "hpAdd", 10, 0, 255, "ru_sc_hp")
  knob("HP level multiplier", "hpLevel", 1, 0, 16, "ru_sc_hpl")
  FormPane.finish(S, "rulesStatCalcScroll", contentTop, fy + fh, view)
end

local function drawAccuracy(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesAccuracyScroll", "accuracy", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Accuracy")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "Accuracy is a percent. It is kept between the minimum and maximum, then a roll from 0 up to the span must land below it. Bright Powder subtracts its parameter times the powder numerator, divided by the powder denominator."
    or "A percent is multiplied by the numerator and divided by the denominator, then capped. The roll runs from 0 up to one less than the span, and a threshold that reaches the span always hits.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.accuracyRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.accuracyRules = nil else S.project.accuracyRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Minimum percent", "hitMin", 1, 0, 255, "ru_ac_min")
    knob("Maximum percent", "hitMax", 100, 0, 255, "ru_ac_max")
    knob("Roll span", "hitSpan", 100, 1, 256, "ru_ac_span")
    knob("Powder numerator", "powderNum", 100, 0, 255, "ru_ac_pnum")
    knob("Powder denominator", "powderDen", 256, 1, 256, "ru_ac_pden")
  else
    knob("Scale numerator", "accNum", 255, 0, 255, "ru_ac_num")
    knob("Scale denominator", "accDen", 100, 1, 255, "ru_ac_den")
    knob("Cap", "accCap", 255, 0, 255, "ru_ac_cap")
    knob("Roll span", "accSpan", 256, 1, 256, "ru_ac_span")
  end
  FormPane.finish(S, "rulesAccuracyScroll", contentTop, fy + fh, view)
end

local function drawFormula(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesFormulaScroll", "formula", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Damage formula")
  fy = fy + 22 * s
  Kit.text("micro",
    "A hit starts from the attacker's level times the numerator, divided by the denominator, plus the level add. Attack, power, and defense are then divided by the stat divisor. The result is capped, then the minimum is added back.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.formulaRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.formulaRules = nil else S.project.formulaRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 300 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Level numerator", "levelNum", 2, 0, 16, "ru_fm_num")
  knob("Level divisor", "levelDen", 5, 1, 255, "ru_fm_den")
  knob("Level add", "levelAdd", 2, 0, 255, "ru_fm_add")
  knob("Stat divisor", "statDiv", 50, 1, 255, "ru_fm_stat")
  knob("Minimum damage", "minDamage", 2, 0, 999, "ru_fm_min")
  knob("Maximum damage", "maxDamage", 999, 1, 9999, "ru_fm_max")
  FormPane.finish(S, "rulesFormulaScroll", contentTop, fy + fh, view)
end

local function drawSpikes(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesSpikesScroll", "spikes", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Spikes")
  fy = fy + 22 * s
  Kit.text("micro",
    "One layer. A switching Pokémon loses max HP divided by this number. 8 is an eighth. Flying-types take nothing.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local cur = S.project.spikesRules and S.project.spikesRules.div
  if cur == nil then cur = 8 end
  Kit.text("small", "HP divisor", viewX, fy + 6 * s, PAL.caption)
  local v = math.floor(RegList.num(App, "ru_spikes", viewX + 240 * s, fy, 72 * s, fh, cur))
  v = math.max(1, math.min(255, v))
  if v ~= cur then
    if v == 8 then
      S.project.spikesRules = nil
    else
      S.project.spikesRules = { div = v }
    end
    App.markDirty()
  end
  FormPane.finish(S, "rulesSpikesScroll", contentTop, fy + fh, view)
end

local TRAP_TURNS = { 1, 1, 1, 2, 2, 2, 3, 4 }

local function drawResiduals(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesResidualScroll", "residuals", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "End of turn")
  fy = fy + 22 * s
  Kit.text("micro", gen2
    and "Each number is the fraction of max HP. 8 means an eighth. Wrap lasts the minimum plus a roll under the span. The cart wrap is 3 to 6."
    or "Bind-class moves pick one of eight continuation counts. The cart is 1, 1, 1, 2, 2, 2, 3, 4. Thrash lasts from the low roll through the high roll.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.residualRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.residualRules = nil else S.project.residualRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 280 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Leech Seed divisor", "leechDiv", 8, 1, 255, "ru_res_leech")
    knob("Nightmare divisor", "nightmareDiv", 4, 1, 255, "ru_res_night")
    knob("Curse divisor", "curseDiv", 4, 1, 255, "ru_res_curse")
    knob("Wrap divisor", "wrapDiv", 16, 1, 255, "ru_res_wrap")
    knob("Wrap minimum turns", "wrapMin", 3, 1, 16, "ru_res_wmin")
    knob("Wrap turn span", "wrapSpan", 4, 1, 16, "ru_res_wspan")
    knob("Leftovers divisor", "leftoversDiv", 16, 1, 255, "ru_res_left")
    knob("Berry HP divisor", "berryDiv", 2, 1, 255, "ru_res_berry")
  else
    local function hitShown(i)
      local list = bag() and bag().trapTurns
      if list and list[i] ~= nil then return list[i] end
      return TRAP_TURNS[i]
    end
    local function writeHit(i, value)
      local list = {}
      local same = true
      for j, vanilla in ipairs(TRAP_TURNS) do
        local n = j == i and value or hitShown(j)
        if n ~= vanilla then same = false end
        list[j] = n
      end
      write("trapTurns", same and nil or list, nil)
    end
    for i in ipairs(TRAP_TURNS) do
      Kit.text("small", "Continuation " .. i, viewX, fy + 6 * s, PAL.caption)
      local n = math.floor(RegList.num(App, "ru_trap_" .. i, viewX + 280 * s, fy, 72 * s, fh, hitShown(i)))
      n = math.max(0, math.min(16, n))
      if n ~= hitShown(i) then writeHit(i, n) end
      fy = fy + fh + 4 * s
    end
    knob("Thrash low roll", "thrashLo", 2, 0, 16, "ru_res_tlo")
    knob("Thrash high roll", "thrashHi", 3, 0, 16, "ru_res_thi")
  end
  FormPane.finish(S, "rulesResidualScroll", contentTop, fy + fh, view)
end

local MULTI_HIT = { 2, 2, 2, 3, 3, 3, 4, 5 }

local function drawHits(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesHitsScroll", "hits", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Hit counts")
  fy = fy + 22 * s
  Kit.text("micro",
    "Fury-style moves pick one of these eight outcomes. The cart is two or three hits three times as often as four or five.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.hitRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.hitRules = nil else S.project.hitRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 280 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  local function hitShown(i)
    local list = bag() and bag().multiHit
    if list and list[i] ~= nil then return list[i] end
    return MULTI_HIT[i]
  end
  local function writeHit(i, value)
    local list = {}
    local same = true
    for j, vanilla in ipairs(MULTI_HIT) do
      local n = j == i and value or hitShown(j)
      if n ~= vanilla then same = false end
      list[j] = n
    end
    write("multiHit", same and nil or list, nil)
  end
  for i, vanilla in ipairs(MULTI_HIT) do
    Kit.text("small", "Outcome " .. i, viewX, fy + 6 * s, PAL.caption)
    local n = math.floor(RegList.num(App, "ru_hit_" .. i, viewX + 280 * s, fy, 72 * s, fh, hitShown(i)))
    n = math.max(1, math.min(16, n))
    if n ~= hitShown(i) then writeHit(i, n) end
    fy = fy + fh + 4 * s
  end
  knob("Double hit count", "doubleHits", 2, 1, 16, "ru_hit_double")
  if gen2 then
    knob("Triple Kick count", "tripleHits", 3, 1, 16, "ru_hit_triple")
    knob("Perish Song count", "perish", 4, 1, 16, "ru_hit_perish")
    knob("Encore minimum turns", "encoreMin", 3, 0, 16, "ru_hit_emin")
    knob("Encore turn span", "encoreSpan", 4, 1, 16, "ru_hit_espan")
  end
  FormPane.finish(S, "rulesHitsScroll", contentTop, fy + fh, view)
end

local HEAL_BANDS = {
  { num = 1, den = 8, label = "Smallest" },
  { num = 1, den = 4, label = "Quarter" },
  { num = 1, den = 2, label = "Half" },
  { num = 1, den = 1, label = "Full" },
}

local function drawHeal(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesHealScroll", "heal", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Healing")
  fy = fy + 22 * s
  local function bag()
    return S.project.healRules
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.healRules = nil else S.project.healRules = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 280 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Recover divisor", "recoverDiv", 2, 1, 16, "ru_heal_recover")
  knob("Substitute cost divisor", "substituteDiv", 4, 1, 16, "ru_heal_sub")
  if gen2 then
    knob("Counter multiplier", "counterMult", 2, 0, 16, "ru_heal_counter")
    knob("Belly Drum cost divisor", "bellyDiv", 2, 1, 16, "ru_heal_belly")
    knob("Ghost Curse cost divisor", "curseCost", 2, 1, 16, "ru_heal_curse")
    fy = fy + 8 * s
    Kit.text("micro",
      "Morning Sun, Synthesis, and Moonlight pick one of these fractions. The cart is 1/8, 1/4, 1/2, and all of max HP.",
      viewX, fy, PAL.muted)
    fy = fy + 36 * s
    local function bandShown(i, key)
      local bands = bag() and bag().bands
      local row = bands and bands[i]
      if row and row[key] ~= nil then return row[key] end
      return HEAL_BANDS[i][key]
    end
    local function writeBand(i, key, value)
      local bands = {}
      local same = true
      for j, vanilla in ipairs(HEAL_BANDS) do
        local num = bandShown(j, "num")
        local den = bandShown(j, "den")
        if j == i then
          if key == "num" then num = value else den = value end
        end
        if num ~= vanilla.num or den ~= vanilla.den then same = false end
        bands[j] = { num = num, den = den }
      end
      write("bands", same and nil or bands, nil)
    end
    for i, vanilla in ipairs(HEAL_BANDS) do
      Kit.text("small", vanilla.label, viewX, fy + 6 * s, PAL.caption)
      local num = math.floor(RegList.num(App, "ru_heal_n" .. i, viewX + 140 * s, fy, 56 * s, fh, bandShown(i, "num")))
      num = math.max(0, math.min(255, num))
      if num ~= bandShown(i, "num") then writeBand(i, "num", num) end
      local den = math.floor(RegList.num(App, "ru_heal_d" .. i, viewX + 210 * s, fy, 56 * s, fh, bandShown(i, "den")))
      den = math.max(1, math.min(255, den))
      if den ~= bandShown(i, "den") then writeBand(i, "den", den) end
      fy = fy + fh + 6 * s
    end
  end
  FormPane.finish(S, "rulesHealScroll", contentTop, fy + fh, view)
end

local HIDDEN_POWER_TYPES = {
  "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG", "GHOST", "STEEL",
  "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC_TYPE", "ICE", "DRAGON", "DARK",
}

local function drawMoveFormulas(S, App, x, y, w, h)
  local s = Kit.scale
  local gen2 = Generation.isGen2(S)
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesMoveScroll", "moves", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Move formulas")
  fy = fy + 22 * s
  local function bag()
    return S.project.moveFormulas
  end
  local function shown(key, default)
    local stored = bag()
    if stored and stored[key] ~= nil then return stored[key] end
    return default
  end
  local function write(key, value, default)
    local b = bag() or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.moveFormulas = nil else S.project.moveFormulas = b end
    App.markDirty()
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = shown(key, default)
    local v = math.floor(RegList.num(App, id, viewX + 280 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then write(key, v, default) end
    fy = fy + fh + 6 * s
  end
  knob("Pay Day coins per level", "payDay", 2, 0, 255, "ru_move_payday")
  knob("Super Fang divisor", "superFangDiv", 2, 1, 16, "ru_move_fang")
  knob("Psywave numerator", "psywaveNum", 3, 0, 255, "ru_move_psyn")
  knob("Psywave denominator", "psywaveDen", 2, 1, 255, "ru_move_psyd")
  knob("Recoil divisor", "recoilDiv", 4, 1, 16, "ru_move_recoil")
  knob("Drain divisor", "drainDiv", 2, 1, 16, "ru_move_drain")
  if not gen2 then
    knob("Sonic Boom damage", "sonicBoom", 20, 0, 255, "ru_move_sonic")
    knob("Dragon Rage damage", "dragonRage", 40, 0, 255, "ru_move_rage")
    knob("Struggle recoil divisor", "struggleRecoilDiv", 2, 1, 16, "ru_move_struggle")
  end
  if gen2 then
    knob("Rollout and Fury Cutter multiplier", "rampMult", 2, 0, 16, "ru_move_ramp")
    knob("Defense Curl extra multiplier", "curlMult", 2, 0, 16, "ru_move_curl")
    knob("Rollout turns", "rolloutTurns", 5, 1, 16, "ru_move_roll")
    knob("Fury Cutter doublings", "furyCap", 5, 1, 16, "ru_move_fury")
    knob("Future Sight delay", "futureTurns", 4, 1, 16, "ru_move_future")
    knob("Hidden Power base", "hpBase", 31, 0, 255, "ru_move_hpbase")
    knob("Hidden Power bit scale", "hpScale", 5, 0, 255, "ru_move_hpscale")
    knob("Hidden Power divisor", "hpDiv", 2, 1, 255, "ru_move_hpdiv")
    fy = fy + 8 * s
    Kit.text("micro", "Hidden Power types, in the order Attack and Defense pick.", viewX, fy, PAL.muted)
    fy = fy + 22 * s
    local types = bag() and bag().types
    for i, vanilla in ipairs(HIDDEN_POWER_TYPES) do
      local cur = types and types[i] or vanilla
      local v = RegList.field(App, "ru_move_hpt" .. i, viewX, fy, 220 * s, fh, cur, vanilla)
      v = tostring(v or ""):upper():gsub("%s+", "")
      if v == "" then v = vanilla end
      if v ~= cur then
        local nextTypes = {}
        local same = true
        for j, name in ipairs(HIDDEN_POWER_TYPES) do
          local picked = j == i and v or ((types and types[j]) or name)
          nextTypes[j] = picked
          if picked ~= name then same = false end
        end
        write("types", same and nil or nextTypes, nil)
      end
      fy = fy + fh + 4 * s
    end
  end
  FormPane.finish(S, "rulesMoveScroll", contentTop, fy + fh, view)
end

local MAGNITUDE_BANDS = {
  { at = 13, power = 10, number = 4 },
  { at = 38, power = 30, number = 5 },
  { at = 89, power = 50, number = 6 },
  { at = 166, power = 70, number = 7 },
  { at = 217, power = 90, number = 8 },
  { at = 242, power = 110, number = 9 },
  { at = 255, power = 150, number = 10 },
}

local function drawMagnitude(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesMagnitudeScroll", "magnitude", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Magnitude")
  fy = fy + 22 * s
  Kit.text("micro",
    "One random byte from 0 to 255 walks these rows. The first row whose roll is at or below the byte wins. The cart ends at byte 255.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function shown(i, key)
    local stored = S.project.magnitudeBands
    local row = stored and stored[i]
    if row and row[key] ~= nil then return row[key] end
    return MAGNITUDE_BANDS[i][key]
  end
  local function write(i, key, value)
    local bands = {}
    local same = true
    for j, vanilla in ipairs(MAGNITUDE_BANDS) do
      local at = shown(j, "at")
      local power = shown(j, "power")
      local number = shown(j, "number")
      if j == i then
        if key == "at" then at = value
        elseif key == "power" then power = value
        else number = value end
      end
      if at ~= vanilla.at or power ~= vanilla.power or number ~= vanilla.number then same = false end
      bands[j] = { at = at, power = power, number = number }
    end
    S.project.magnitudeBands = same and nil or bands
    App.markDirty()
  end
  for i, vanilla in ipairs(MAGNITUDE_BANDS) do
    Kit.text("small", "Band " .. i, viewX, fy + 6 * s, PAL.caption)
    local at = math.floor(RegList.num(App, "ru_mag_a" .. i, viewX + 90 * s, fy, 56 * s, fh, shown(i, "at")))
    at = math.max(0, math.min(255, at))
    if at ~= shown(i, "at") then write(i, "at", at) end
    local power = math.floor(RegList.num(App, "ru_mag_p" .. i, viewX + 160 * s, fy, 56 * s, fh, shown(i, "power")))
    power = math.max(0, math.min(255, power))
    if power ~= shown(i, "power") then write(i, "power", power) end
    local number = math.floor(RegList.num(App, "ru_mag_n" .. i, viewX + 230 * s, fy, 56 * s, fh, shown(i, "number")))
    number = math.max(0, math.min(255, number))
    if number ~= shown(i, "number") then write(i, "number", number) end
    fy = fy + fh + 6 * s
  end
  FormPane.finish(S, "rulesMagnitudeScroll", contentTop, fy + fh, view)
end

local FLAIL_BANDS = {
  { atMost = 1, power = 200, label = "Ratio at most 1" },
  { atMost = 4, power = 150, label = "Ratio at most 4" },
  { atMost = 9, power = 100, label = "Ratio at most 9" },
  { atMost = 16, power = 80, label = "Ratio at most 16" },
  { atMost = 32, power = 40, label = "Ratio at most 32" },
  { power = 20, label = "Healthier" },
}

local function drawFlail(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesFlailScroll", "flail", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Reversal")
  fy = fy + 22 * s
  Kit.text("micro",
    "Remaining HP times the scale, divided by max HP, picks a band. The cart scale is 48. One HP is power 200. A healthy Pokémon is power 20.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.flailRules
  end
  local function shownScale()
    local stored = bag()
    if stored and stored.scale ~= nil then return stored.scale end
    return 48
  end
  local function shown(i, key)
    local stored = bag()
    local row = stored and stored.bands and stored.bands[i]
    if row and row[key] ~= nil then return row[key] end
    return FLAIL_BANDS[i][key]
  end
  local function commit(scale, bands)
    local same = scale == 48
    for i, vanilla in ipairs(FLAIL_BANDS) do
      local row = bands[i]
      if vanilla.atMost ~= nil and row.atMost ~= vanilla.atMost then same = false end
      if row.power ~= vanilla.power then same = false end
    end
    S.project.flailRules = same and nil or { scale = scale == 48 and nil or scale, bands = bands }
    if S.project.flailRules and S.project.flailRules.scale == nil then
      local onlyScale = true
      for i, vanilla in ipairs(FLAIL_BANDS) do
        local row = bands[i]
        if row.power ~= vanilla.power or row.atMost ~= vanilla.atMost then onlyScale = false end
      end
      if onlyScale then S.project.flailRules = nil end
    end
    App.markDirty()
  end
  local function write(i, key, value)
    local scale = shownScale()
    local bands = {}
    for j, vanilla in ipairs(FLAIL_BANDS) do
      local atMost = shown(j, "atMost")
      local power = shown(j, "power")
      if j == i then
        if key == "atMost" then atMost = value elseif key == "power" then power = value end
      end
      if key == "scale" then scale = value end
      bands[j] = vanilla.atMost ~= nil and { atMost = atMost, power = power } or { power = power }
    end
    commit(scale, bands)
  end
  Kit.text("small", "HP scale", viewX, fy + 6 * s, PAL.caption)
  local scale = math.floor(RegList.num(App, "ru_flail_scale", viewX + 220 * s, fy, 72 * s, fh, shownScale()))
  scale = math.max(0, math.min(255, scale))
  if scale ~= shownScale() then write(nil, "scale", scale) end
  fy = fy + fh + 6 * s
  for i, vanilla in ipairs(FLAIL_BANDS) do
    Kit.text("small", vanilla.label, viewX, fy + 6 * s, PAL.caption)
    if vanilla.atMost ~= nil then
      local atMost = math.floor(RegList.num(App, "ru_flail_a" .. i, viewX + 180 * s, fy, 56 * s, fh, shown(i, "atMost")))
      atMost = math.max(0, math.min(255, atMost))
      if atMost ~= shown(i, "atMost") then write(i, "atMost", atMost) end
    end
    local power = math.floor(RegList.num(App, "ru_flail_p" .. i, viewX + 250 * s, fy, 64 * s, fh, shown(i, "power")))
    power = math.max(0, math.min(255, power))
    if power ~= shown(i, "power") then write(i, "power", power) end
    fy = fy + fh + 6 * s
  end
  FormPane.finish(S, "rulesFlailScroll", contentTop, fy + fh, view)
end

local function drawReturn(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesReturnScroll", "return", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Return and Frustration")
  fy = fy + 22 * s
  Kit.text("micro",
    "Power is friendship times the first number, divided by the second. Frustration uses 255 minus friendship. The cart is 10 and 25, so max friendship is 102 power.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.returnPower
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.returnPower = S.project.returnPower or {}
    return S.project.returnPower
  end
  local function knob(label, key, default, minV)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_ret_" .. key, viewX + 220 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(255, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.returnPower = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  knob("Numerator", "num", 10, 0)
  knob("Denominator", "den", 25, 1)
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.returnPower = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesReturnScroll", contentTop, fy + fh, view)
end

local GEN2_CRIT = { 15, 8, 4, 3, 2, 2, 2 }

local function drawCrits(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX, viewW = RegList.beginForm(S, x, y, w, h,
    "rulesCritScroll", "crits", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Critical hits")
  fy = fy + 22 * s
  if not Generation.isGen2(S) then
    Kit.text("micro",
      "The cart halves Speed, doubles it once, then halves again. A high-crit move doubles twice more instead. Focus Energy doubles three times. Each left shift stops at 255. The level multiplier is how many times a crit repeats the attacker's level in the damage formula.",
      viewX, fy, PAL.muted)
    fy = fy + 56 * s
    local function bag()
      return S.project.battleCrit
    end
    local function ensure()
      State.ensureProjectFields(S.project)
      S.project.battleCrit = S.project.battleCrit or {}
      return S.project.battleCrit
    end
    local function knob(label, key, default, minV)
      Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
      local cur = bag() and bag()[key]
      if cur == nil then cur = default end
      local v = math.floor(RegList.num(App, "ru_g1crit_" .. key, viewX + 260 * s, fy, 72 * s, fh, cur))
      v = math.max(minV, math.min(16, v))
      if v ~= cur then
        local b = ensure()
        b[key] = v == default and nil or v
        if next(b) == nil then S.project.battleCrit = nil end
        App.markDirty()
      end
      fy = fy + fh + 6 * s
    end
    knob("Speed divisor", "speedDiv", 2, 1)
    knob("Plain shifts", "plainShifts", 1, 0)
    knob("High-crit shifts", "highShifts", 2, 0)
    knob("Normal divisor", "normalDiv", 2, 1)
    knob("Focus Energy shifts", "focusShifts", 3, 0)
    knob("Focus Energy bug divisor", "focusBugDiv", 2, 1)
    knob("Crit level multiplier", "levelMult", 2, 1)
    if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
      S.project.battleCrit = nil
      App.markDirty()
    end
    FormPane.finish(S, "rulesCritScroll", contentTop, fy + fh, view)
    return
  end
  Kit.text("micro",
    "Each stage is a 1-in-N chance. Focus Energy, a high-crit move, Scope Lens, and Lucky Punch or Stick raise the stage.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.battleCrit
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.battleCrit = S.project.battleCrit or {}
    return S.project.battleCrit
  end
  local function prune(b)
    if type(b.chances) == "table" and next(b.chances) == nil then b.chances = nil end
    if next(b) == nil then S.project.battleCrit = nil end
  end
  local function knob(label, key, default, minV, maxV, id)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, id, viewX + 220 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      prune(b)
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  knob("Crit multiplier", "multiplier", 2, 1, 16, "ru_crit_mul")
  knob("Damage roll min", "variationMin", 85, 1, 100, "ru_crit_vmin")
  knob("Damage roll max", "variationMax", 100, 1, 100, "ru_crit_vmax")
  for stage = 0, 6 do
    local default = GEN2_CRIT[stage + 1]
    Kit.text("small", "Stage " .. stage, viewX, fy + 6 * s, PAL.caption)
    local chances = bag() and bag().chances
    local cur = chances and chances[stage]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_crit_" .. stage, viewX + 220 * s, fy, 72 * s, fh, cur))
    v = math.max(1, math.min(255, v))
    if v ~= cur then
      local b = ensure()
      b.chances = b.chances or {}
      b.chances[stage] = v == default and nil or v
      prune(b)
      App.markDirty()
    end
    fy = fy + fh + 4 * s
  end
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.battleCrit = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesCritScroll", contentTop, fy + fh, view)
end

local function drawExp(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesExpScroll", "exp", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  local gen2 = Generation.isGen2(S)
  Kit.caption(viewX, fy, "Experience")
  fy = fy + 22 * s
  Kit.text("micro",
    gen2 and "Base experience times the foe's level, divided by the divisor, then split. Bonuses are percents of that amount."
      or "Base experience is split, then multiplied by the foe's level and divided by the divisor. Bonuses are percents.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.expRules
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.expRules = S.project.expRules or {}
    return S.project.expRules
  end
  local function knob(label, key, default, minV, maxV)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_exp_" .. key, viewX + 220 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.expRules = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  knob("Divisor", "divisor", 7, 1, 255)
  knob("Trainer bonus %", "trainerPercent", 150, 0, 1000)
  knob("Traded bonus %", "tradedPercent", 150, 0, 1000)
  if gen2 then knob("Lucky Egg %", "luckyPercent", 150, 0, 1000) end
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.expRules = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesExpScroll", contentTop, fy + fh, view)
end

local function drawPrizes(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesPrizeScroll", "prizes", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  local gen2 = Generation.isGen2(S)
  Kit.caption(viewX, fy, "Prize money")
  fy = fy + 22 * s
  Kit.text("micro",
    gen2 and "The class reward times the last party level is one quarter. That quarter is paid this many times. The Amulet Coin multiplies the quarter first."
      or "The class reward times the fainted mon's level, then this multiplier.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.prizeRules
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.prizeRules = S.project.prizeRules or {}
    return S.project.prizeRules
  end
  local function knob(label, key, default, minV, maxV)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_prz_" .. key, viewX + 240 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.prizeRules = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Quarters paid", "quarters", 4, 0, 255)
    knob("Amulet Coin multiplier", "amulet", 2, 0, 255)
    knob("Reward wraps at", "rewardMod", 65536, 1, 9999999)
    knob("Reward ceiling", "rewardCap", 16777215, 0, 16777215)
  else
    knob("Prize multiplier", "multiplier", 1, 0, 255)
  end
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.prizeRules = nil
    App.markDirty()
  end
  fy = require("PrizeShop").draw(S, App, viewX, fy, fh, s)
  FormPane.finish(S, "rulesPrizeScroll", contentTop, fy + fh, view)
end

local function drawScreens(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesScreenScroll", "screens", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Reflect and Light Screen")
  fy = fy + 22 * s
  Kit.text("micro",
    "How many times the matching defense is multiplied. 2 is the cart. 1 leaves the defense alone. Self-Destruct and Explosion divide the target's defense by the second number. 2 is the cart. 1 leaves it alone.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function writeScreen(key, value, default)
    local b = S.project.screenRules or {}
    b[key] = value == default and nil or value
    if next(b) == nil then S.project.screenRules = nil else S.project.screenRules = b end
    App.markDirty()
  end
  local cur = S.project.screenRules and S.project.screenRules.mult
  if cur == nil then cur = 2 end
  Kit.text("small", "Defense multiplier", viewX, fy + 6 * s, PAL.caption)
  local v = math.floor(RegList.num(App, "ru_screen", viewX + 240 * s, fy, 72 * s, fh, cur))
  v = math.max(1, math.min(255, v))
  if v ~= cur then writeScreen("mult", v, 2) end
  fy = fy + fh + 6 * s
  if Generation.isGen2(S) then
    local turns = S.project.screenRules and S.project.screenRules.turns
    if turns == nil then turns = 5 end
    Kit.text("small", "Turns", viewX, fy + 6 * s, PAL.caption)
    local tv = math.floor(RegList.num(App, "ru_screen_turns", viewX + 240 * s, fy, 72 * s, fh, turns))
    tv = math.max(1, math.min(255, tv))
    if tv ~= turns then writeScreen("turns", tv, 5) end
    fy = fy + fh + 6 * s
  end
  local explode = S.project.explodeDiv
  if explode == nil then explode = 2 end
  Kit.text("small", "Explosion defense divisor", viewX, fy + 6 * s, PAL.caption)
  local ev = math.floor(RegList.num(App, "ru_explode", viewX + 240 * s, fy, 72 * s, fh, explode))
  ev = math.max(1, math.min(255, ev))
  if ev ~= explode then
    S.project.explodeDiv = ev == 2 and nil or ev
    App.markDirty()
  end
  fy = fy + fh + 6 * s
  if (S.project.screenRules or S.project.explodeDiv ~= nil)
      and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.screenRules = nil
    S.project.explodeDiv = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesScreenScroll", contentTop, fy + fh, view)
end

local function drawStab(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesStabScroll", "stab", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Same-type bonus")
  fy = fy + 22 * s
  Kit.text("micro",
    "Percent applied when the move's type matches the attacker. 150 is the cart's half again. 100 leaves the damage alone. 0 removes it.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local cur = S.project.stabPercent
  if cur == nil then cur = 150 end
  Kit.text("small", "Percent", viewX, fy + 6 * s, PAL.caption)
  local v = math.floor(RegList.num(App, "ru_stab", viewX + 240 * s, fy, 72 * s, fh, cur))
  v = math.max(0, math.min(999, v))
  if v ~= cur then
    S.project.stabPercent = v == 150 and nil or v
    App.markDirty()
  end
  fy = fy + fh + 6 * s
  if S.project.stabPercent ~= nil and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.stabPercent = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesStabScroll", contentTop, fy + fh, view)
end

local GEN1_BADGE_BOOSTS = {
  { badge = "BOULDERBADGE", stat = "attack", num = 9, den = 8, label = "Boulder (Attack)" },
  { badge = "THUNDERBADGE", stat = "defense", num = 9, den = 8, label = "Thunder (Defense)" },
  { badge = "SOULBADGE", stat = "speed", num = 9, den = 8, label = "Soul (Speed)" },
  { badge = "VOLCANOBADGE", stat = "special", num = 9, den = 8, label = "Volcano (Special)" },
}

local function drawBadges(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesBadgeScroll", "badges", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  local gen2 = Generation.isGen2(S)
  if gen2 then
    Kit.caption(viewX, fy, "Badge boost")
    fy = fy + 22 * s
    Kit.text("micro",
      "A matching badge adds the stat divided by this number, and the same fraction of damage when the move's type matches. 8 is the cart. 0 adds nothing.",
      viewX, fy, PAL.muted)
    fy = fy + 36 * s
    local cur = S.project.badgeBoost and S.project.badgeBoost.divisor
    if cur == nil then cur = 8 end
    Kit.text("small", "Divisor", viewX, fy + 6 * s, PAL.caption)
    local v = math.floor(RegList.num(App, "ru_badge_div", viewX + 240 * s, fy, 72 * s, fh, cur))
    v = math.max(0, math.min(255, v))
    if v ~= cur then
      if v == 8 then
        S.project.badgeBoost = nil
      else
        S.project.badgeBoost = { divisor = v }
      end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
    if S.project.badgeBoost and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
      S.project.badgeBoost = nil
      App.markDirty()
    end
    fy = fy + fh + 16 * s
    Kit.caption(viewX, fy, "Traded Pokémon obey up to")
    fy = fy + 22 * s
    Kit.text("micro",
      "A traded Pokémon obeys at this level and below. Hive, Fog, and Storm raise the cap. The Rising Badge still means every level obeys.",
      viewX, fy, PAL.muted)
    fy = fy + 36 * s
    local obedience = {
      { key = "none", label = "No badge", default = 10 },
      { key = "hive", label = "Hive Badge", default = 30 },
      { key = "fog", label = "Fog Badge", default = 50 },
      { key = "storm", label = "Storm Badge", default = 70 },
    }
    for _, row in ipairs(obedience) do
      local stored = S.project.obedience and S.project.obedience[row.key]
      local cur = stored ~= nil and stored or row.default
      Kit.text("small", row.label, viewX, fy + 6 * s, PAL.caption)
      local v = math.floor(RegList.num(App, "ru_obey_" .. row.key, viewX + 240 * s, fy, 72 * s, fh, cur))
      v = math.max(0, math.min(100, v))
      if v ~= cur then
        S.project.obedience = S.project.obedience or {}
        S.project.obedience[row.key] = v == row.default and nil or v
        if next(S.project.obedience) == nil then S.project.obedience = nil end
        App.markDirty()
      end
      fy = fy + fh + 6 * s
    end
  else
    Kit.caption(viewX, fy, "Badge stat boost")
    fy = fy + 22 * s
    Kit.text("micro",
      "Each owned badge multiplies its stat by the first number over the second. 9 and 8 is the cart's extra eighth.",
      viewX, fy, PAL.muted)
    fy = fy + 36 * s
    local function rows()
      local stored = S.project.badgeBoosts
      if type(stored) == "table" and #stored > 0 then return stored end
      return GEN1_BADGE_BOOSTS
    end
    local function commit(nextRows)
      local same = true
      for i, vanilla in ipairs(GEN1_BADGE_BOOSTS) do
        local row = nextRows[i]
        if not row or row.num ~= vanilla.num or row.den ~= vanilla.den then same = false end
      end
      S.project.badgeBoosts = same and nil or nextRows
      App.markDirty()
    end
    for i, vanilla in ipairs(GEN1_BADGE_BOOSTS) do
      local row = rows()[i] or vanilla
      Kit.text("small", vanilla.label, viewX, fy + 6 * s, PAL.caption)
      local num = math.floor(RegList.num(App, "ru_bb_n" .. i, viewX + 220 * s, fy, 56 * s, fh, row.num or vanilla.num))
      local den = math.floor(RegList.num(App, "ru_bb_d" .. i, viewX + 284 * s, fy, 56 * s, fh, row.den or vanilla.den))
      num = math.max(0, math.min(255, num))
      den = math.max(1, math.min(255, den))
      if num ~= (row.num or vanilla.num) or den ~= (row.den or vanilla.den) then
        local nextRows = {}
        for j, base in ipairs(GEN1_BADGE_BOOSTS) do
          local cur = rows()[j] or base
          nextRows[j] = {
            badge = base.badge, stat = base.stat,
            num = j == i and num or (cur.num or base.num),
            den = j == i and den or (cur.den or base.den),
          }
        end
        commit(nextRows)
      end
      fy = fy + fh + 6 * s
    end
    if S.project.badgeBoosts and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
      S.project.badgeBoosts = nil
      App.markDirty()
    end
  end
  FormPane.finish(S, "rulesBadgeScroll", contentTop, fy + fh, view)
end

local STAGE_PERCENT = {
  [-6] = 25, [-5] = 28, [-4] = 33, [-3] = 40, [-2] = 50, [-1] = 66,
  [0] = 100, [1] = 150, [2] = 200, [3] = 250, [4] = 300, [5] = 350, [6] = 400,
}

local function drawStages(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesStageScroll", "stages", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Stat stages")
  fy = fy + 22 * s
  Kit.text("micro",
    "Percent of the unmodified stat. 100 leaves it alone, 150 is half again, 50 is half.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.statStages
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.statStages = S.project.statStages or {}
    return S.project.statStages
  end
  for stage = -6, 6 do
    local key = tostring(stage)
    local default = STAGE_PERCENT[stage]
    Kit.text("small", "Stage " .. key, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_st_" .. key, viewX + 160 * s, fy, 72 * s, fh, cur))
    v = math.max(0, math.min(1000, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.statStages = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.statStages = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesStageScroll", contentTop, fy + fh, view)
end

local function drawAilments(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesAilmentScroll", "ailments", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  local gen2 = Generation.isGen2(S)
  Kit.caption(viewX, fy, "Status damage")
  fy = fy + 22 * s
  Kit.text("micro",
    gen2 and "Each value is the fraction of max HP, or a 1-in-N chance. Burn halves Attack and paralysis quarters Speed on the cart."
      or "Poison, burn, and Leech Seed each take 1/N of max HP. The cart uses 16.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.ailments
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.ailments = S.project.ailments or {}
    return S.project.ailments
  end
  local function knob(label, key, default, minV, maxV)
    minV = minV or 1
    maxV = maxV or 255
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_ail_" .. key, viewX + 260 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.ailments = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  if gen2 then
    knob("Burn HP fraction", "burnFraction", 8)
    knob("Poison HP fraction", "poisonFraction", 8)
    knob("Toxic step fraction", "toxicFraction", 16)
    knob("Burn Attack divisor", "burnAttack", 2)
    knob("Paralysis Speed divisor", "paralysisSpeed", 4)
    knob("Full paralysis (1 in N)", "paralysisSkip", 4)
    knob("Thaw chance (1 in N)", "thaw", 5)
    knob("Thrash confusion count", "rampageSpan", 2)
  else
    knob("HP fraction", "chip", 16)
    knob("Burn Attack divisor", "burnAttack", 2)
    knob("Paralysis Speed divisor", "paralysisSpeed", 4)
    knob("Full paralysis (out of 256)", "paralysisFull", 63, 0, 256)
  end
  knob("Confusion minimum turns", "confusionMin", 2)
  knob("Confusion turn count", "confusionSpan", 4)
  knob("Confusion self-hit (out of 256)", "confusionHit", 128, 0, 256)
  knob("Confusion self-hit power", "confusionPower", 40, 0, 255)
  if gen2 then
    knob("Sleep minimum turns", "sleepMin", 2)
    knob("Sleep turn count", "sleepSpan", 6)
    if Generation.isCrystal(S) then
      knob("Battle Tower sleep count", "sleepTowerSpan", 3)
    end
    knob("Rest turns", "restTurns", 3)
    Kit.text("micro",
      "Infatuation spends the turn when a roll of 0 to 255 is at least this number. 0 always fails. 256 always attacks.",
      viewX, fy, PAL.muted)
    fy = fy + 28 * s
    knob("Infatuation fail at or above", "attractFail", 128, 0, 256)
    knob("Nap minimum turns", "napMin", 1)
    knob("Nap turn count", "napSpan", 7)
  else
    knob("Sleep minimum turns", "sleepMin", 1)
    knob("Sleep turn count", "sleepSpan", 7)
    knob("Rest turns", "restTurns", 2)
  end
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.ailments = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesAilmentScroll", contentTop, fy + fh, view)
end

local function drawWeather(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesWeatherScroll", "weather", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Battle weather")
  fy = fy + 22 * s
  Kit.text("micro",
    "Percents are the damage multiplier. 150 is half again, 50 is half, 100 leaves the move alone.",
    viewX, fy, PAL.muted)
  fy = fy + 36 * s
  local function bag()
    return S.project.weather
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.weather = S.project.weather or {}
    return S.project.weather
  end
  local function knob(label, key, default, minV, maxV)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_wx_" .. key, viewX + 260 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.weather = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  knob("Turns", "turns", 5, 1, 255)
  knob("Sandstorm HP fraction", "sandstormFraction", 8, 1, 255)
  knob("Rain boosts Water %", "rainWater", 150, 0, 1000)
  knob("Rain cuts Fire %", "rainFire", 50, 0, 1000)
  knob("Sun boosts Fire %", "sunFire", 150, 0, 1000)
  knob("Sun cuts Water %", "sunWater", 50, 0, 1000)
  knob("Rain cuts Solar Beam %", "solarbeam", 50, 0, 1000)
  knob("Thunder accuracy in rain", "thunderRain", 100, 0, 100)
  knob("Thunder accuracy in sun", "thunderSun", 50, 0, 100)
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.weather = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesWeatherScroll", contentTop, fy + fh, view)
end

local function drawPokerus(S, App, x, y, w, h)
  local s = Kit.scale
  local fy, view, viewX = RegList.beginForm(S, x, y, w, h,
    "rulesPokerusScroll", "pokerus", 12 * s)
  local contentTop = fy
  local fh = 28 * s
  Kit.caption(viewX, fy, "Pokerus")
  fy = fy + 22 * s
  Kit.text("micro",
    "Spread and direction are rolls out of 256. A spread of 0 never moves, 256 always does. A new infection needs a first byte of 0 and a second byte below the contract number.",
    viewX, fy, PAL.muted)
  fy = fy + 48 * s
  local function bag()
    return S.project.pokerus
  end
  local function ensure()
    State.ensureProjectFields(S.project)
    S.project.pokerus = S.project.pokerus or {}
    return S.project.pokerus
  end
  local function knob(label, key, default, minV, maxV)
    Kit.text("small", label, viewX, fy + 6 * s, PAL.caption)
    local cur = bag() and bag()[key]
    if cur == nil then cur = default end
    local v = math.floor(RegList.num(App, "ru_pk_" .. key, viewX + 280 * s, fy, 72 * s, fh, cur))
    v = math.max(minV, math.min(maxV, v))
    if v ~= cur then
      local b = ensure()
      b[key] = v == default and nil or v
      if next(b) == nil then S.project.pokerus = nil end
      App.markDirty()
    end
    fy = fy + fh + 6 * s
  end
  knob("Spread (out of 256)", "spreadChance", 85, 0, 256)
  knob("Walk forward (out of 256)", "backwardChance", 128, 0, 256)
  knob("Contract below", "contractThreshold", 3, 0, 256)
  if bag() and Kit.button(viewX, fy, 140 * s, fh, "Revert", { kind = "ghost" }) then
    S.project.pokerus = nil
    App.markDirty()
  end
  FormPane.finish(S, "rulesPokerusScroll", contentTop, fy + fh, view)
end

local FORM_DRAW = {
  statuses = drawStatuses,
  rulesets = drawRulesets,
  transitions = drawTransitions,
  scales = drawScales,
  apricorns = drawApricorns,
  radio = drawRadio,
}

function Rules.draw(S, x, y, w, h, App)
  if Generation.isGen3(S) then
    if not S.project then Kit.emptyBox(x,y,w,h,"Open a mod on the Project tab first");return end
    local body=RegList.modeChips(S,"g3RulesMode",{{id="battle",label="Battle rules"},{id="classes",label="Class prizes"},{id="moves",label="Moves"},{id="heal",label="Heal"},{id="hits",label="Hits"},{id="residuals",label="Residuals"},{id="special",label="Special"},{id="locks",label="Locks"},{id="switch",label="Switch"},{id="flee",label="Flee"},{id="spikes",label="Spikes"},{id="formula",label="Formula"},{id="accuracy",label="Accuracy"},{id="statcalc",label="Stat calc"},{id="catchmath",label="Catch"},{id="effort",label="Effort"},{id="friendship",label="Friendship"},{id="pp",label="PP Up"},{id="flail",label="Flail"},{id="magnitude",label="Magnitude"},{id="lowkick",label="Low Kick"},{id="stages",label="Stages"},{id="balls",label="Balls"},{id="safari",label="Safari Zone"}},x,y,Kit.scale)
    if S.g3RulesMode=="safari" then return require("SafariSettings").draw(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="balls" then return require("Gen3BattleRules").drawBalls(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="classes" then return require("Gen3BattleRules").drawClasses(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="flail" then return require("Gen3BattleRules").drawFlail(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="moves" then return require("Gen3BattleRules").drawMoves(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="heal" then return require("Gen3BattleRules").drawHeal(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="hits" then return require("Gen3BattleRules").drawHits(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="residuals" then return require("Gen3BattleRules").drawResiduals(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="special" then return require("Gen3BattleRules").drawSpecial(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="locks" then return require("Gen3BattleRules").drawLocks(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="switch" then return require("Gen3BattleRules").drawSwitch(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="flee" then return require("Gen3BattleRules").drawFlee(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="spikes" then return require("Gen3BattleRules").drawSpikes(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="formula" then return require("Gen3BattleRules").drawFormula(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="accuracy" then return require("Gen3BattleRules").drawAccuracy(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="statcalc" then return require("Gen3BattleRules").drawStatCalc(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="catchmath" then return require("Gen3BattleRules").drawCatchMath(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="effort" then return require("Gen3BattleRules").drawEffort(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="friendship" then return require("Gen3BattleRules").drawFriendship(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="pp" then return require("Gen3BattleRules").drawPp(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="magnitude" then return require("Gen3BattleRules").drawMagnitude(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="lowkick" then return require("Gen3BattleRules").drawLowKick(S,x,body,w,h-(body-y),App) end
    if S.g3RulesMode=="stages" then return require("Gen3BattleRules").drawStages(S,x,body,w,h-(body-y),App) end
    return require("Gen3BattleRules").draw(S,x,body,w,h-(body-y),App)
  end
  local s = Kit.scale
  if not S.project then
    Kit.emptyBox(x, y, w, h, "Open a mod on the Project tab first")
    return
  end
  State.ensureProjectFields(S.project)
  local modes = modesFor(S)
  local valid = false
  for _, m in ipairs(modes) do
    if m.id == S.rulesMode then valid = true; break end
  end
  if not valid then S.rulesMode = modes[1] and modes[1].id end
  local modeY = RegList.modeChips(S, "rulesMode", modes, x, y, s)
  local mode = S.rulesMode or "statuses"
  if mode == "safari" then return require("SafariSettings").draw(S,x,modeY,w,h-(modeY-y),App) end
  if mode == "pp" then
    drawPp(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "effort" then
    drawEffort(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "catchmath" then
    drawCatchMath(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "statcalc" then
    drawStatCalc(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "accuracy" then
    drawAccuracy(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "formula" then
    drawFormula(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "spikes" then
    drawSpikes(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "flee" then
    drawFlee(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "switch" then
    drawSwitch(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "locks" then
    drawLocks(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "special" then
    drawSpecial(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "residuals" then
    drawResiduals(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "hits" then
    drawHits(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "heal" then
    drawHeal(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "moves" then
    drawMoveFormulas(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "magnitude" then
    drawMagnitude(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "flail" then
    drawFlail(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "return" then
    drawReturn(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "crits" then
    drawCrits(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "exp" then
    drawExp(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "prizes" then
    drawPrizes(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "badges" then
    drawBadges(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "stab" then
    drawStab(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "screens" then
    drawScreens(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "stages" then
    drawStages(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "ailments" then
    drawAilments(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "weather" then
    drawWeather(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "pokerus" then
    drawPokerus(S, App, x, modeY, w, h - (modeY - y))
    return
  end
  if mode == "lua" then
    drawLua(S, x, modeY, w, h - (modeY - y))
    return
  end
  local spec = SPECS[mode]
  if not spec then return end
  local proj = projectBag(S, spec)
  local data = spec.data(S)
  local ids = RegList.mergeIds(proj, data)
  local formX, formW, listY, listH, shown = RegList.drawList(S, App, x, modeY, w,
    h - (modeY - y), spec.caption, ids, {
      queryKey = "rulesQuery",
      offsetKey = "rulesListOffset",
      selKey = "rulesId_" .. mode,
      accent = PAL.yellow,
      isOwned = function(id) return proj[id] ~= nil end,
      filter = function(id, q)
        local ql = q:lower()
        if id:lower():find(ql, 1, true) then return true end
        local rec = select(1, resolve(S, spec, id))
        return tostring(spec.summarize(rec)):lower():find(ql, 1, true) ~= nil
      end,
      footerLabel = "+ New",
      onFooter = function()
        local nid = allocId(proj, data, spec.newId)
        local rec = spec.newRec()
        if mode == "apricorns" then rec.apricorn = nid end
        proj[nid] = rec
        S["rulesId_" .. mode] = nid
        App.markDirty()
      end,
    })

  local selKey = "rulesId_" .. mode
  if not S[selKey] then S[selKey] = shown[1] end
  local id = S[selKey]
  local rec, owned = resolve(S, spec, id)
  if not id then
    Kit.emptyBox(formX, listY, formW, listH, "No records")
    return
  end

  Kit.caption(formX, modeY, (id or "?") .. (owned and "" or "  (vanilla)"))
  local fy, view, viewX, viewW = RegList.beginForm(S, formX, listY, formW, listH,
    "rulesFormScroll", mode .. ":" .. tostring(id), owned and 44 * s or 12 * s)
  local contentTop = fy
  local labelW = 130 * s
  local fh = 28 * s

  local function ensure()
    if owned then return proj[id] end
    proj[id] = cloneData(rec, { _isNew = false })
    owned = true
    App.markDirty()
    return proj[id]
  end

  Kit.text("micro", spec.summarize(rec), viewX, fy, PAL.muted)
  fy = fy + 20 * s

  local drawer = FORM_DRAW[mode]
  if drawer then
    fy = drawer(S, App, rec, owned, ensure, fy, viewX, viewW, fh, s, labelW)
  end

  if not owned then
    Kit.text("micro", "Edit clones into the mod (Save emits a patch).",
      viewX, fy, PAL.faint)
    fy = fy + 18 * s
    if Kit.button(viewX, fy, 140 * s, fh, "Clone to mod", { kind = "accent" }) then
      ensure()
    end
    fy = fy + fh + 8 * s
  end

  FormPane.finish(S, "rulesFormScroll", contentTop, fy, view)
  if owned and Kit.button(formX + 12 * s, listY + listH - 40 * s, 120 * s, 32 * s,
      "Revert", { kind = "danger" }) then
    proj[id] = nil
    App.markDirty()
  end
end

return Rules
