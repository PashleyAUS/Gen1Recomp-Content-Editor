-- Installed once; the dispatcher follows the active mod lifecycle.
local M={}
function M.install(mod,assets)
  local Runtime=require("src.mods.Runtime")
  mod.hooks:wrap("editor.gen3.front_frames",function(next,species,shiny)
    local root="data/generated/gba/pokemon/front_anim"
    local asset=assets[root..(shiny and "_shiny" or "").."/"..species..".rgba"]
      or (shiny and assets[root.."/"..species..".rgba"])
    if asset then return {file=mod.path.."/"..asset.file,count=asset.height/64,bytes=mod:read(asset.file)} end
    return next(species,shiny)
  end)
  mod.hooks:wrap("editor.gen3.has_front_frames",function() return true end)
  local B=require("src.core.game3.battle.mon_anim_battle")
  if B._editorFrames then return end
  B._editorFrames=true
  local A=require("src.core.game3.mon_anim")
  local P=require("src.core.game3.pokemon")
  local active,images={},{}
  local function config(species,shiny)
    if not tonumber(species) then return end
    return Runtime.call("editor.gen3.front_frames",function() end,species,shiny)
  end
  local function customPic(species,frame,shiny)
    local c=config(species,shiny)
    if not c or frame<0 then return end
    frame=math.min(frame,c.count-1)
    local bytes=c.bytes
    if not bytes or #bytes~=c.count*64*64*4 then return end
    local key=c.file..":"..frame
    local cached=images[key]
    if cached and cached.bytes==bytes then return cached.entry end
    local pixels=love.image.newImageData(64,64,"rgba8",bytes:sub(frame*16384+1,(frame+1)*16384))
    local img=love.graphics.newImage(pixels);img:setFilter("nearest","nearest")
    local entry={image=img,w=64,h=64};images[key]={bytes=bytes,entry=entry}
    return entry
  end
  local framePic=A.framePic
  A.framePic=function(species,frame,shiny) return customPic(species,frame,shiny) or framePic(species,frame,shiny) end
  local frontPic=P.frontPic
  P.frontPic=function(species,form,shiny,...)
    return ((tonumber(form) or 0)==0 and customPic(species,0,shiny)) or frontPic(species,form,shiny,...)
  end
  local start=B.start
  B.start=function(key,kind,opts)
    opts=opts or {}
    local State=require("src.core.game3.battle.state")
    local st=opts.st or (package.loaded["src.core.game3.battle"] or {})._st
    local b=st and (type(key)=="number" and State.battler(st,key) or st[key])
    local species=b and (b.species or (b.mon and (b.mon.species or b.mon.speciesId)))
    local shown=species and P.monPicSpecies and P.monPicSpecies(b.mon or {species=species}) or species
    local shiny=b and b.mon and P.isShiny(b.mon)
    local c=shown and kind~="back" and config(shown,shiny)
    if not c then
      -- FireRed's wild cry is moved into the entrance step by introSteps.
      if species and kind~="back" and not opts.noCry and not A.enabled() then
        require("src.core.game3.audio").playCry(species,opts.cryMode or 0,1)
      end
      return start(key,kind,opts)
    end
    -- Replacing Emerald's original one/two-frame art retains its native
    -- timing, bouncing, stretching and rotation. Longer sheets use a sequence.
    if A.enabled() and (c.count==1 or (c.count==2 and A.hasTwoFramesAnimation(shown))) then return start(key,kind,opts) end
    local Anim=require("src.core.game3.battle.anim")
    local p=Anim.present(key) or (type(key)=="number" and key<2 and Anim.present(State.sideOf(key)))
    if not p then return end
    if not opts.noCry then require("src.core.game3.audio").playCry(species,opts.cryMode or 0,1) end
    local session=require("src.core.game3.runtime").getSession()
    if session and require("src.core.game3.options").battleScene(session)==false then return end
    if active[p] then active[p].stopped=true end
    local s={frames=0,stopped=false};active[p]=s
    s.task=require("src.core.game3.task").spawn(function()
      if active[p]~=s then return true end
      if s.stopped or s.frames>=c.count*8 then
        p.monFrame=0;active[p]=nil;return true
      end
      p.monFrame=math.floor(s.frames/8);s.frames=s.frames+1
    end)
    return s
  end
  local busy=B.busy
  B.busy=function(keys)
    local Anim=require("src.core.game3.battle.anim")
    local State=require("src.core.game3.battle.state")
    for _,key in ipairs(keys or {}) do
      local p=Anim.present(key) or (type(key)=="number" and key<2 and Anim.present(State.sideOf(key)))
      if p and active[p] then return true end
    end
    return busy(keys)
  end
  local reset=B.reset
  B.reset=function()
    for p,s in pairs(active) do s.stopped=true;p.monFrame=0 end
    active={};images={};return reset()
  end
  -- Allow FireRed to enqueue entrance steps without enabling Emerald's
  -- native animation engine elsewhere (e.g. the summary screen).
  for _,name in ipairs({"introSteps","switchSteps"}) do
    local original=B[name]
    B[name]=function(...)
      if not Runtime.call("editor.gen3.has_front_frames",function() return false end) then return original(...) end
      local enabled=A.enabled;A.enabled=function() return true end
      local ok,result=pcall(original,...);A.enabled=enabled
      if not ok then error(result) end
      return result
    end
  end
end
return M
