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
  local resolved={}
  local function numberFor(id)
    if resolved[id] then return resolved[id] end
    local named=fromName(P,id)
    if named then resolved[id]=named;return named end
    return fromContent(mod,id)
  end
  -- The picture tables live for the whole game. A later save reloads this mod,
  -- so the original Y has to be remembered on Pic itself. A fresh snapshot of
  -- the current value would include the offset already applied.
  local function vault()
    if not Pic then return nil end
    local saved=rawget(Pic,"_editorPositionBase")
    if type(saved)~="table" then saved={};rawset(Pic,"_editorPositionBase",saved) end
    return saved
  end
  local function baseOf(tbl,sp)
    local saved=vault()
    if not saved then return tonumber(tbl[sp]) or 0 end
    local row=saved[tbl]
    if not row then row={};saved[tbl]=row end
    if row[sp]==nil then row[sp]=tonumber(tbl[sp]) or 0 end
    return row[sp]
  end
  local function restore()
    local saved=vault()
    if not saved then return end
    for tbl,row in pairs(saved) do
      if type(tbl)=="table" and type(row)=="table" then
        for sp,base in pairs(row) do tbl[sp]=base end
      end
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
        local frontY,backY=tonumber(rec.frontY) or 0,tonumber(rec.backY) or 0
        if frontY~=0 then front[sp]=baseOf(front,sp)+frontY end
        if backY~=0 then back[sp]=baseOf(back,sp)+backY end
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
