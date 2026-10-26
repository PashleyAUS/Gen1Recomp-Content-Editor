local M={}
local function clamp(value)
  local n=tonumber(value)
  if n==nil then return nil end
  n=math.max(-64,math.min(64,math.floor(n)))
  return n
end
function M.commit(project,id,frontY,backY)
  frontY,backY=clamp(frontY),clamp(backY)
  if frontY==nil or backY==nil then return nil end
  project.gen3BattlePositions=project.gen3BattlePositions or {}
  if frontY==0 and backY==0 then
    project.gen3BattlePositions[id]=nil
    if not next(project.gen3BattlePositions) then project.gen3BattlePositions=nil end
    return nil
  end
  local rec={frontY=frontY,backY=backY}
  project.gen3BattlePositions[id]=rec
  return rec
end
function M.emit(p,encode,out)
  local positions={}
  for id,rec in pairs(p.gen3BattlePositions or {}) do
    local frontY,backY=clamp(rec.frontY),clamp(rec.backY)
    if frontY and backY and (frontY~=0 or backY~=0) then
      positions[id]={frontY=frontY,backY=backY}
    end
  end
  if not next(positions) then return end
  out[#out+1]="local positions=(function()\n"..assert(love.filesystem.read("tools/content-editor/Gen3BattlePositionsRuntime.lua"))
    .."\nend)()\npositions.install(mod,"..encode(positions)..")"
end
function M.draw(S,mon,x,y,w,App)
  local K,Preview=require("Kit"),require("Preview")
  local s=K.scale
  local p=S.project
  local rec=(p.gen3BattlePositions or {})[mon.id] or {frontY=0,backY=0}
  K.text("small","Battle position offsets (pixels)",x,y,require("Theme").PAL.heading);y=y+28*s
  K.text("micro","Negative moves up; positive moves down. Existing mod positioning is preserved.",x,y,require("Theme").PAL.muted);y=y+26*s
  for _,row in ipairs({{"frontY","Opponent / front Y"},{"backY","Player / back Y"}}) do
    K.text("small",row[2],x,y+6*s,require("Theme").PAL.text)
    local value=require("RegList").num(App,"battle_pos_"..mon.id..row[1],x+180*s,y,100*s,30*s,rec[row[1]])
    if value~=rec[row[1]] then
      local nextRec={frontY=rec.frontY,backY=rec.backY}
      nextRec[row[1]]=value
      rec=M.commit(p,mon.id,nextRec.frontY,nextRec.backY) or {frontY=0,backY=0}
      App.markDirty()
    end
    y=y+38*s
  end
  if K.button(x,y,160*s,30*s,"Reset offsets",{}) then
    M.commit(p,mon.id,0,0)
    rec={frontY=0,backY=0};App.markDirty()
  end
  if K.chip(x+170*s,y,80*s,30*s,"Shiny",S.battlePositionShiny,require("Theme").PAL.blue) then S.battlePositionShiny=not S.battlePositionShiny end
  y=y+42*s
  local scale=math.min(w/240,2*s)
  local g=love.graphics
  g.push("all");g.translate(x,y);g.scale(scale)
  g.setColor(.64,.77,.72,1);g.rectangle("fill",0,0,240,112)
  g.setColor(.42,.59,.48,1);g.ellipse("fill",176,68,47,11);g.ellipse("fill",72,106,60,14)
  local Ui=require("src.core.game3.battle.ui")
  for _,back in ipairs({false,true}) do
    local field=S.battlePositionShiny and (back and "spriteShinyBack" or "spriteShinyFront") or (back and "spriteBack" or "spriteFront")
    local path=require("ModPokemonArt").path(S,mon,field) or require("Gen3Forms").spritePath(mon,back,S.battlePositionShiny,S)
    local image=Preview.image(S,path)
    local base=back and {x=72,y=80} or {x=176,y=40}
    local cx,cy=Ui.battlerSpriteCenter(back and "player" or "enemy",mon.index,base,0,false)
    cy=cy+Ui.bounceOffset("mon",back and 0 or 1)+(back and rec.backY or rec.frontY)
    g.setColor(1,1,1,1)
    if image then g.draw(image,cx-32,cy-32,0,64/image:getWidth(),64/image:getHeight()) end
    g.setColor(1,.25,.25,.8);g.line(cx-3,cy,cx+3,cy);g.line(cx,cy-3,cx,cy+3)
  end
  g.pop()
  return y+112*scale+16*s
end
return M
