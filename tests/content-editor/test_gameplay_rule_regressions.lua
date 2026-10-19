package.path='tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;'..package.path
love=require('tests.love_stub')
local Writer=require('ModWriter')
for _,game in ipairs({'gold','silver','crystal'}) do
 local source=Writer.emitMain({id='target',game=game,slotPayouts={seven=17},slotBets={one=5},cardFlipRules={bet=5,card=19}})
 assert(source:find('src.ui.gen2.SlotMachine',1,true),game..' targets the native slot machine')
 assert(source:find('PAYOUTS[0] = 17',1,true),game..' exports the edited payout')
 assert(source:find('BET_COST[1] = 5',1,true),game..' exports the edited bet')
 assert(source:find('CardFlip.BET = 5',1,true),game..' exports Card Flip rules')
end
for _,game in ipairs({'firered','leafgreen','ruby','sapphire','emerald'}) do
 local p={game=game,generation=2,slotPayouts={seven=17,red7=17},slotBets={max=1}}
 local out={};require('SlotPayouts').emit(p,Writer.encodeLua,out);require('SlotBets').emit(p,Writer.encodeLua,out)
 local source=table.concat(out,'\n')
 assert(not source:find('src.ui.gen2.SlotMachine',1,true),game..' takes precedence over stale generation metadata')
 assert(source:find('MAX_BET = 1',1,true),game..' exports the edited native cap')
end
local UI=require('src.ui.game3.rse.roulette')
local data={[1]=0,[13]=100};local nextTask
local ui=setmetatable({task=function() return {data=data} end,startTaskAfterDelayOrInput=function(_,_,name) nextTask=name end},UI)
ui:taskGivePayout(1)
assert(data[13]==100 and data[1]==0 and nextTask=='taskEndTurn','zero roulette payout ends without crediting a coin')
local BattleState=require('src.ui.gen2.BattleState')
local battle=setmetatable({},BattleState)
battle:drawExpBurst()
assert(type(BattleState.expBurst)=='function','experience-burst timing helper remains available')
print('PASS game-field exports, zero roulette payout and inactive Gen2 experience burst')
