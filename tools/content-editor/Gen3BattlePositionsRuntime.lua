local M={}
-- Battle sprites read PicCoords on every draw (the local center in battle/ui.lua).
-- Bounce only adds the hop, so the editor offset has to live in those tables.
local function fromName(P,id)
  if P.speciesFromName then
    local ok,n=pcall(P.speciesFromName,id)
    n=ok and tonumber(n)
    if n and n>0 then return n end
  end
  local names=P._names
  if type(names)~="table" or not P.keyName then return nil end
  for sp in pairs(names) do
    if type(sp)=="number" and sp>0 then
      local ok,key=pcall(P.keyName,sp)
      if ok and key==id then return sp end
    end
  end
end
local function fromContent(mod,id)
  if not (mod.content and mod.content.pokemon and mod.content.pokemon.get) then return nil end
  local ok,rec=pcall(mod.content.pokemon.get,mod.content.pokemon,id)
  if not (ok and type(rec)=="table") then return nil end
  local n=tonumber(rec.index) or tonumber(rec.gen3Species)
  if n and n>0 then return n end
end
function M.install(mod,positions)
  local Ui=require("src.core.game3.battle.ui")
  local Runtime=require("src.mods.Runtime")
  local P=require("src.core.game3.pokemon")
  local okPic,Pic=pcall(require,"src.core.game3.battle.pic_coords")
  if not okPic then Pic=nil end
  local resolved,snap={},{}
  local function numberFor(id)
    if resolved[id] then return resolved[id] end
    local named=fromName(P,id)
    if named then resolved[id]=named;return named end
    return fromContent(mod,id)
  end
  local function baseOf(tbl,sp)
    local saved=snap[tbl]
    if not saved then saved={};snap[tbl]=saved end
    if saved[sp]==nil then saved[sp]=tonumber(tbl[sp]) or 0 end
    return saved[sp]
  end
  local function restore()
    for tbl,saved in pairs(snap) do
      for sp,base in pairs(saved) do tbl[sp]=base end
    end
  end
  local function apply()
    restore()
    if not Pic then return end
    local ok,front,back=pcall(function() return Pic.front,Pic.back end)
    if not ok or type(front)~="table" or type(back)~="table" then return end
    for id,rec in pairs(positions) do
      local sp=type(rec)=="table" and numberFor(id)
      if sp then
        front[sp]=baseOf(front,sp)+(tonumber(rec.frontY) or 0)
        back[sp]=baseOf(back,sp)+(tonumber(rec.backY) or 0)
      end
    end
  end
  if not Ui._editorPositionDispatch then
    Ui._editorPositionDispatch=true
    local original=Ui.bounceOffset
    Ui.bounceOffset=function(...)
      Runtime.call("editor.gen3.battle.positions",function() restore();return 0 end)
      return original(...)
    end
  end
  mod.hooks:wrap("editor.gen3.battle.positions",function(proceed)
    proceed();apply();return 0
  end)
  if mod.events and mod.events.on then
    mod.events:on("game.ready",function()
      for id in pairs(resolved) do resolved[id]=nil end
      apply()
    end)
  end
  apply()
end
return M
