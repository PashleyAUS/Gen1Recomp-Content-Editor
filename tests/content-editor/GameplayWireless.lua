-- Wireless minigames run native leader/member simulations with scripted local
-- peers and real ROM art. This tests gameplay and awards, not a live relay.
local M={}
local function input(button)
 return {wasPressed=function(_,b) return b==button end,isDown=function(_,b) return b==button end}
end
function M.run(game,id,install,note)
 if id~='firered' and id~='leafgreen' and id~='emerald' then return end
 local MG=require('src.core.game3.minigames.common')
 local G=require('src.core.game3.minigames.pokemon_jump')
 local art=assert(G.loadArt())
 for _,points in ipairs({17,0}) do
  install({jumpRules={points=points,bonus2=0,bonus3=0,bonus4=0,bonus5=0,prize1=0}})
  local players={{seat=0,name='RULE TEST',species=4},{seat=1,name='SCRIPTED PEER',species=4}}
  local sims={}
  for seat=0,1 do
   sims[seat+1]=G.new({game='jump',seat=seat,leader=seat==0,players=players,art=art,seed=5,rng=MG.rng(5),partyMon={species=4,personality=0,otId=0},hooks=seat==0 and G.defaultHooks() or {},newCountdown=function() return require('src.ui.game3.minigames.common_countdown').new(120,80) end})
  end
  local leader=sims[1];local Game=G.Game;local clears=0;local over=false
  for n=1,12000 do
   local packets={}
   for i=2,1,-1 do
    local sim=sims[i];local g=sim.game;local button
    if g.comm.funcId==Game.FUNC.GAME_ROUND then
     if clears<4 and g.vineState==4 and g.player.monState==Game.MONSTATE.NORMAL then button='a' end
    elseif g.gfx.yesno then button=g.gfx.yesno.cursor==1 and 'a' or 'down'
    elseif n%8==0 then button='a' end
    packets[i]=sim:localInput(input(button))
   end
   leader:leaderStep(packets,{true,true})
   local snap=leader:snapshot();sims[2]:applySnapshot(snap)
   for _,sim in ipairs(sims) do sim:update() end
   require('src.core.game3.audio').update(1/60)
   if n%120==0 then leader:draw() end
   clears=math.max(clears,leader.game.comm.jumpsInRow or 0)
   if leader.game.comm.funcId==Game.FUNC.GAME_OVER then over=true end
   if over and leader:finished() then break end
  end
  local result=leader:results().results[1]
  assert(over and clears>=1,'Pokemon Jump did not clear a vine and finish a real round')
  assert(result.score==result.stats.jumpsInRow*points,'Pokemon Jump score ignored edited per-vine points: '..result.score..' / '..result.stats.jumpsInRow)
  note('Pokemon Jump: native vine/jump round with scripted peer, '..result.stats.jumpsInRow..' clears, edited points '..points..', score '..result.score)
 end
 local Crush=require('src.core.game3.minigames.berry_crush')
 local crushArt=assert(Crush.loadArt())
 local Bag=require('src.core.game3.bag')
 for _,denominator in ipairs({100,0}) do
  install({berryCrush={powderDen=denominator}})
  local players={{seat=0,name='RULE TEST'},{seat=1,name='SCRIPTED PEER'}}
  local sims={};game.session.berryPowder=0
  for seat=0,1 do
   local session=seat==0 and game.session or {bag=Bag.new(),berryPowder=0}
   Bag.add(session.bag,133,2)
   local module=setmetatable({},{__index=Crush})
   module.hooks=setmetatable({session=function() return session end,pickBerry=function(sim,done) done(133) end},{__index=Crush.hooks})
   sims[seat+1]=Crush.Sim.new(module,{seat=seat,leader=seat==0,players=players,art=crushArt,seed=5,rng=MG.rng(5)})
  end
  local leader=sims[1];local played=false
  for n=1,16000 do
   local packets={}
   for i,sim in ipairs(sims) do packets[i]=sim:localInput(input(n%2==0 and 'a' or nil)) end
   leader:leaderStep(packets,{true,true});sims[2]:applySnapshot(leader:snapshot())
   for _,sim in ipairs(sims) do sim:update(1/60) end
   require('src.core.game3.audio').update(1/60)
   if n%120==0 then leader:draw() end
   if leader.stage=='play' then played=true end
   if played and leader.res and leader.pageOpen then break end
  end
  assert(played and leader.res and not leader.res.timeUp,'Berry Crush did not complete its native crushing round: '..leader.stage)
  assert(game.session.berryPowder==leader.res.powder,'Berry Crush results were not credited to the player')
  assert((leader.res.powder>0)==(denominator>0),'Berry Crush ignored zero powder denominator')
  note('Berry Crush: native press/crush/results with scripted peer, powder denominator '..denominator..', awarded '..leader.res.powder)
 end

 local Pick=require('src.core.game3.minigames.dodrio_berry_picking')
 local pickArt=assert(Pick.loadArt());local R=Pick.Rules
 for _,points in ipairs({37,0}) do
  install({dodrioRules={blue=points,missed=0,prize=0}})
  local players={{seat=0,name='RULE TEST'},{seat=1,name='SCRIPTED PEER 1'},{seat=2,name='SCRIPTED PEER 2'}}
  local sims={};local recordScore,awarded
  for seat=0,2 do
   local hooks=Pick.defaultHooksFor()
   if seat==0 then
    local record=hooks.updateRecords;hooks.updateRecords=function(score,...) recordScore=score;return record(score,...) end
    local add=hooks.addItem;hooks.addItem=function(item,qty) local before=Bag.get(game.session.bag,item);local ok=add(item,qty);if ok then awarded={item,qty,before} end;return ok end
   else hooks={} end
   sims[seat+1]=Pick.new({game='pick',seat=seat,seats=3,leader=seat==0,players=players,art=pickArt,seed=5,rng=MG.rng(5),partyMon={species=85,personality=0,otId=0},hooks=hooks})
  end
  local lead=sims[1];local staged=false
  for n=1,12000 do
   local button
   if not staged and lead.started and lead.view.ph==R.PHASE_PLAY then
    local col=R.headColumn(lead.T,3,0,1)
    lead.st.state[col],lead.st.fall[col],lead.st.fallTimer[col],lead.st.ids[col]=R.BS_NONE,6,0,R.BERRY_BLUE
    staged=true;button='up'
   elseif staged and lead.flow=='game' and (lead.st.res[0][0] or 0)==0 then button='up'
   elseif lead.flow~='game' and n%8==0 then button='a' end
   local packets={}
   for i,sim in ipairs(sims) do packets[i]=sim:localInput(input(i==1 and button or nil)) end
   lead:leaderStep(packets,{true,true,true});local snap=lead:snapshot()
   for i=2,3 do sims[i]:applySnapshot(snap) end
   for _,sim in ipairs(sims) do sim:update() end
   require('src.core.game3.audio').update(1/60)
   if n%120==0 then lead:draw() end
   if awarded then break end
  end
  assert(staged and (lead.st.res[0][0] or 0)>0,'Dodrio did not pick the controlled blue berry')
  assert(recordScore==points*lead.st.res[0][0],'Dodrio results ignored edited blue-berry points: '..tostring(recordScore))
  assert(awarded and Bag.get(game.session.bag,awarded[1])==awarded[3]+awarded[2],'Dodrio did not award the edited zero-threshold prize')
  note('Dodrio: native picking, missed-berry ending and results with scripted peers; blue points '..points..', score '..recordScore..', prize delivered')
 end

end
return M
