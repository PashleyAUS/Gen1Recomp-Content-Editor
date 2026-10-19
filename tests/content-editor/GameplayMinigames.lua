local M={}
local function fill(t,value)
 local saved={}
 for _,row in pairs(t) do for k,v in pairs(row) do saved[#saved+1]={row,k,v};row[k]=value end end
 return function() for _,v in ipairs(saved) do v[1][v[2]]=v[3] end end
end
function M.run(game,id,install,note)
 local gen=require('src.core.GameVersion').generation()
 local function keys(btn)
  for _,b in ipairs({'a','down','r','start'}) do
   if b==btn then game.input:sourcePress(b,'gameplay_minigame') else game.input:sourceRelease(b,'gameplay_minigame') end
  end
  game.input:step()
 end
 for _,prize in ipairs({17,0}) do
  if gen<3 then
   install({slotPayouts={seven=prize},slotBets={one=5}})
   local S=require(gen==1 and 'src.ui.SlotMachine' or 'src.ui.gen2.SlotMachine')
   local restore=fill(gen==1 and game.data.field.slotWheels or S.REELS,gen==1 and '7' or 0)
   if gen==1 then game.save.coins=100 else game.save.player.coins=100 end
   local ui=gen==1 and S.new(game,true) or S.new(game,{random=function(n) return 0 end})
   if gen==1 then ui.betIndex=2;ui.sevenBar=true;ui.canWin=true else ui.betIndex=3;ui.bias=S.SEVEN end
   local spinning,done=false,false
   for n=1,5000 do
    keys(n%8==0 and 'a' or nil);ui:update(1/60)
    if n%120==0 then ui:draw() end
    local phase=ui.stage or ui.phase
    if phase=='spinup' or phase=='spin' or phase=='spinning' then spinning=true end
    if spinning and (phase=='onemore' or phase=='again') then done=true;break end
   end
   if prize==17 then require('GameplayEvidence').capture(id,'slots',function() ui:draw() end,gen==3) end
   restore();keys(nil)
   local balance=gen==1 and game.save.coins or game.save.player.coins
   assert(done,'native slot round did not finish: '..tostring(ui.stage or ui.phase))
   assert(balance==95+prize,'native slots credited '..balance..', expected '..(95+prize))
   note('slots: native spin, stops and payout; prize '..prize..', balance '..balance)
  elseif id=='firered' or id=='leafgreen' then
   install({slotPayouts={seven=prize},slotBets={max=1}})
   local S=require('src.core.game3.slot_machine');local UI=require('src.ui.game3.slot_machine')
   local restore=fill(S.REELS,S.ICON.SEVEN)
   game.session.coins=100;local st=UI.show({session=game.session})
   local started,done=false,false
   for n=1,5000 do
    local btn=n%8==0 and (UI.task=='bet' and st.bet==0 and 'down' or 'a') or nil
    keys(btn);UI.handleInput(game.input);UI.update(1/60);require("src.core.game3.audio").update(1/60)
    if n%120==0 then UI.draw() end
    if UI.task=='spin' or UI.task=='stopping' then started=true end
    if started and UI.task=='bet' and st.bet==0 then done=true;break end
   end
   local balance=S.coins(game.session);if prize==17 then require('GameplayEvidence').capture(id,'slots',UI.draw,true) end;UI.close();restore();keys(nil)
   assert(done,'native FRLG slot round did not finish: '..tostring(UI.task))
   assert(balance==99+prize,'native FRLG slots credited '..balance..', expected '..(99+prize))
   note('slots: native spin, stops and payout; prize '..prize..', balance '..balance)
  else
   install({slotPayouts={red7=prize},slotBets={max=1}})
   local S=require('src.core.game3.rse.slot_machine')
   local path=id=='emerald' and 'src.ui.game3.rse.slot_machine' or 'src.ui.game3.rs.slot_machine'
   local UI=require(path);local ui=UI.new({coins=100,session=game.session,random=function() return 100 end})
   local restore=fill(ui.T.reelSymbols,S.SYMBOL.RED_7)
   local started,done=false,false
   for n=1,8000 do
    local state=ui.core.state
    if state==UI.STATE.BET_INPUT and ui.core.bet==0 then ui.core.machineBias=S.BIAS.STRAIGHT_7 end
    local btn=n%8==0 and (state==UI.STATE.BET_INPUT and ui.core.bet==0 and 'down' or 'a') or nil
    local inp={new={},held={}};if btn then inp.new[btn]=true end
    ui:frame(inp);require("src.core.game3.audio").update(1/60);if n%120==0 then ui:draw() end
    if ui.core.bet>0 then started=true end
    if started and ui.core.state==UI.STATE.BET_INPUT and ui.core.bet==0 then done=true;break end
   end
   if prize==17 then require('GameplayEvidence').capture(id,'slots',function() ui:draw() end,true) end
   restore()
   assert(done,'native RSE slot round did not finish: '..tostring(ui.core.state))
   assert(ui.core.coins==99+prize,'native RSE slots credited '..ui.core.coins..', expected '..(99+prize))
   note('slots: native spin, stops and payout; prize '..prize..', balance '..ui.core.coins)
  end
 end
 if gen==3 and id~='firered' and id~='leafgreen' then
  local winningSquare
  for _,payout in ipairs({12,7,0}) do
   install({rouletteRules={step4=payout,balls=1}})
   local seed=71
   local function rng() seed=(require('src.core.game3.rng').mulU32(seed,1103515245)+24691)%4294967296;return math.floor(seed/65536) end
   local path=id=='emerald' and 'src.ui.game3.rse.roulette' or 'src.ui.game3.rs.roulette'
   local ui=require(path).new({coins=100,session=game.session,var8004=0,hours=12,random=rng})
   local finished,balance,landed,wager,lastTask
   for n=1,15000 do
    local tid=ui.st and ui.st.playTaskId
    local task=tid and ui:task(tid);local name
    if task then for k,v in pairs(ui.fn) do if v==task.func then name=k;break end end end
    if name=='taskHandleBetGridInput' and winningSquare then task.data[4]=winningSquare end
    lastTask=name
    if name=="taskTryIncrementWins" then love.timer.sleep(1/60) end
    if name=='taskEndTurn' or name=='taskTryPrintEndTurnMsg' then finished=true;balance=task.data[13];landed=task.data[12];wager=ui.st.minBet;break end
    ui:frame({new=n%8==0 and {a=true} or {},held={}})
    require('src.core.game3.audio').update(1/60)
    if n%120==0 then ui:draw() end
   end
   assert(finished,'native roulette spin did not finish: '..tostring(lastTask))
   if winningSquare then assert(balance==100-wager+wager*payout,'roulette ignored multiplier '..payout..': '..balance) end
   winningSquare=landed
   note('Roulette: native ball spin and payout, multiplier '..payout..', balance '..balance)
  end
  local P=require('src.core.game3.rse.pokeblock')
  local Bag=require('src.core.game3.bag')
  for _,threshold in ipairs({0,255}) do
   install({gen3Blender={goldAt=threshold,progressCap=20,hitSpan=256,bestSpan=256,bestGain=1,goodGain=1}})
   P.clearAll(game.session);Bag.add(game.session.bag,133,5)
   local before=Bag.get(game.session.bag,133)
   local path=id=='emerald' and 'src.ui.game3.rse.berry_blender' or 'src.ui.game3.rs.berry_blender'
   local ui=require(path).new({session=game.session,version=id,opponents=1,playerName='RULE TEST',random=function() return 100 end,chooseBerry=function(picked) picked(133) end})
   local played,done=false,false
   for n=1,12000 do
    local inp={new={},held={}}
    if n%8==0 or ui.cb=='play' then inp.new.a=true end
    ui:frame(inp);require('src.core.game3.audio').update(1/60)
    if n%120==0 then ui:draw() end
    if ui.cb=='play' then played=true end
    if played and game.session.pokeblocks[1].color~=0 then done=true;break end
   end
   assert(done,'native Berry Blender did not produce a block: '..tostring(ui.cb)..'/'..tostring(ui.game and ui.game.gameEndState))
   local block=game.session.pokeblocks[1]
   assert((block.color==P.COLOR.GOLD)==(threshold==0),'Berry Blender ignored the gold threshold: '..block.color)
   assert(Bag.get(game.session.bag,133)==before-1,'Berry Blender did not consume the selected berry')
   note('Berry Blender: native mixing and results, threshold '..threshold..', awarded color '..block.color)
  end
 end
 if gen==2 then
  for _,prize in ipairs({19,0}) do
   install({cardFlipRules={bet=5,card=prize}})
   local C=require('src.ui.gen2.CardFlip');game.save.player.coins=100
   local ui=C.new(game,{random=function(n) return 0 end})
   -- A legal pre-shuffled deck that deterministically deals card zero.
   for i=1,24 do ui.deck[i]=i-1 end
   local played,done=false,false
   for n=1,2000 do
    if ui.phase=='bet' then local card=C.dealt(ui.deck,ui.played,ui.which);ui.cursorX=C.mon(card)+2;ui.cursorY=C.level(card)+2 end
    keys(n%8==0 and 'a' or nil);ui:update(1/60)
    if n%120==0 then ui:draw() end
    if ui.phase=='flipping' then played=true end
    if played and ui.phase=='result' then done=true;break end
   end
   keys(nil);assert(done,'Card Flip hand did not finish: '..tostring(ui.phase))
   assert(game.save.player.coins==95+prize,'Card Flip balance '..game.save.player.coins..', expected '..(95+prize))
   note('Card Flip: native selection, flip and coin payout; prize '..prize)
  end
 end
end
return M





