local M={}
function M.join(row,game,ow,done)
  local TextBox,ChoiceBox=require("src.render.TextBox"),require("src.ui.ChoiceBox")
  done=done or function() end
  local function say(text,after) game.stack:push(TextBox.new(game,text,after)) end
  local function back(text) say(text,function() ow:scriptMove(ow.player,"down",1,done) end) end
  local function start(balls,price)
    local p=ow.player
    local warp=p.cellY==2 and ow.map:warpAtCell(p.cellX,0) or nil
    game.save.safari={balls=balls,steps=row.steps+(warp and 2 or 0)}
    game.save.safariNags=nil
    say("Paid "..price.."!\nReceived "..balls.." SAFARI BALLs!\fYou have "..row.steps.." steps.\nGood luck!",function()
      done()
      if warp then ow:scriptMove(p,"up",2,function()
        if game.save.safari then game.save.safari.steps=game.save.safari.steps-2 end
        ow:takeWarp(warp.def)
      end) end
    end)
  end
  say("SAFARI ZONE\nEntry: "..row.fee.."\f"..row.balls.." balls, "..row.steps.." steps.\nWould you like to enter?",function()
    game.stack:push(ChoiceBox.new(game,function(yes)
      if not yes then back("Please come again!");return end
      local money=game.save.money or 0
      if money>=row.fee then game.save.money=money-row.fee;start(row.balls,row.fee);return end
      if row.yellowDiscount and require("src.core.GameVersion").isYellow() then
        if money>0 then
          local price=math.max(1,math.floor(tonumber(row.yellowBallPrice) or 23))
          local balls=math.min(math.max(1,row.balls-1),math.floor(money/price)+1)
          game.save.money=0;start(balls,money);return
        end
        local nags=game.save.safariNags or 0;game.save.safariNags=nags+1
        local needed=math.max(1,math.floor(tonumber(row.yellowFreeNags) or 3))
        if nags>=needed then start(1,0);return end
      end
      back("You don't have enough money.")
    end))
  end)
end
function M.applyBattle(row,generation)
  if type(row)~="table" then return end
  local function set(target,key,field)
    if row[key]~=nil then target[field]=row[key] end
  end
  if generation==1 then
    local Battle=require("src.battle.BattleState")
    set(Battle,"baitDiv","SAFARI_BAIT_DIV")
    set(Battle,"rockMult","SAFARI_ROCK_MULT")
    set(Battle,"factorLo","SAFARI_FACTOR_LO")
    set(Battle,"factorHi","SAFARI_FACTOR_HI")
    set(Battle,"fleeAbove","SAFARI_FLEE_ABOVE")
    set(Battle,"eatingDiv","SAFARI_EATING_DIV")
    set(Battle,"angryMult","SAFARI_ANGRY_MULT")
  elseif generation==3 then
    local Safari=require("src.core.game3.battle.rules").safari
    set(Safari,"baitDiv","BAIT_DIV")
    set(Safari,"rockMult","ROCK_MULT")
    set(Safari,"baitFloorAt","BAIT_FLOOR_AT")
    set(Safari,"baitFloor","BAIT_FLOOR")
    set(Safari,"rockCap","ROCK_CAP")
    set(Safari,"counterAdd","COUNTER_ADD")
    set(Safari,"counterSpan","COUNTER_SPAN")
    set(Safari,"counterCap","COUNTER_CAP")
    set(Safari,"fleeScale","FLEE_SCALE")
  end
end
function M.install(mod,row,generation)
  if mod.generation~=generation then return end
  M.applyBattle(row,generation)
  local Runtime=require("src.mods.Runtime")
  if generation==3 then
    local Safari=require("src.core.game3.safari")
    if not Safari._editorEnterBridge then
      Safari._editorEnterBridge=true;local original=Safari.enter
      Safari.enter=function(...) return Runtime.call("editor.safari.enter",original,...) end
    end
    mod.hooks:wrap("editor.safari.enter",function(proceed,session)
      session=session or require("src.core.game3.runtime").getSession() or require("src.core.game3.field").getSession()
      local result=proceed(session)
      if result and session and session.safari then session.safari.balls=row.balls;session.safari.steps=row.steps end
      return result
    end)
    return
  end
  local gate=require("data.scripts.safari").SAFARI_ZONE_GATE
  mod.content.map_scripts:register("SAFARI_ZONE_GATE",{
    onStep=function(game,ow,x,y)
      if y~=2 or (x~=3 and x~=4) or game.save.safari then return false end
      M.join(row,game,ow);return true
    end,
    talk={TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1=function(game,ow,npc,done)
      if game.save.safari then return gate.talk.TEXT_SAFARIZONEGATE_SAFARI_ZONE_WORKER1(game,ow,npc,done) end
      M.join(row,game,ow,done)
    end},
  })
  mod.content.field:patch("safari",{exitWarp={map=row.exitMap,x=row.exitX,y=row.exitY,facing=row.facing}})
end
return M
