-- Gameplay integration scenarios: exported edits, native battle turns and UI
-- state machines. No arithmetic helpers or payout functions are substituted.
local M={}
local function install(game,id,changes)
 game.mods.hooks:removeOwner('gameplay_rules')
 local p=require('State').blankProject('rules_audit_'..id);p.game=id
 for k,v in pairs(changes) do p[k]=v end
 local api=game.mods:_api(game.mods.mods[p.id]);local callbacks={}
 api.events={on=function(_,name,fn,priority) callbacks[name]=callbacks[name] or {};table.insert(callbacks[name],{fn,priority or 0}) end}
 api.hooks={wrap=function(_,name,fn,priority) return game.mods.hooks:wrap(name,fn,priority,'gameplay_rules') end}
 assert(loadstring(require('ModWriter').emitMain(p,{})))()(api)
 for _,name in ipairs({'mods.loaded','game.ready'}) do
  local rows=callbacks[name] or {};table.sort(rows,function(a,b) return a[2]>b[2] end)
  for _,row in ipairs(rows) do row[1]({game=game,data=game.data}) end
 end
end
function M.run(game,id,root,report)
 local gen=require('src.core.GameVersion').generation()
 local results={}
 local function note(s) results[#results+1]=s;report('RUNNING '..id..' '..s) end
 local function frame(n)
  if n%8==0 then game.input:sourcePress('a','gameplay_rules') else game.input:sourceRelease('a','gameplay_rules') end
  if game.fixedUpdate then game:fixedUpdate(1/60) else game:update(1/60) end
 end
 local function draw() game:draw() end
 local function turn3(divisor,poison,opts)
  opts=opts or {}
  install(game,id,{gen3Formula={statDiv=divisor},gen3BattleRules={shinyBelow=65536,critChance0=255,damageRollMin=100,damageRollMax=100,poisonFraction=poison,critMultiplier=opts.critMultiplier}})
  local P=require('src.core.game3.pokemon');local Party=require('src.core.game3.party')
  local sess=game.session;sess.party={};assert(Party.giveMon(sess,1,50))
  local mon=sess.party[1];mon.moves={129};mon.pp={35};mon.maxPp={35};mon.personality=0;mon.ivs={hp=15,atk=15,def=15,spe=15,spa=15,spd=15};mon.evs={};P.applyStats(mon);if poison then mon.status='PSN' end
  local B=require('src.core.game3.battle');local Bridge=require('src.core.game3.battle_bridge')
  local foe={species=129,level=50,moves={150},pp={40}}
  local options={fade=false,rng=function(lo,hi) return lo end}
  if opts.trainer then
   assert(Bridge.start(require('src.core.game3.runtime')._mod,game,{party={foe},trainerName='RULE TEST'},options))
  else assert(Bridge.startWild(require('src.core.game3.runtime')._mod,game,foe,options)) end
  B._auto=true
  local st=B.getState();local foe=st.enemy.mon;foe.personality=0;foe.ivs={hp=15,atk=15,def=15,spe=15,spa=15,spd=15};foe.evs={};P.applyStats(foe);st.enemy.mon.hp=1000;st.enemy.mon.maxHp=1000;st.enemy.maxHp=1000
  assert(P.isShiny(st.enemy.mon),'100% shiny rule did not make the battle foe shiny')
  local startHp=mon.hp;local maxHp=mon.maxHp
  local ended=false
  local off=require('src.mods.Runtime').events:on('battle.turn_ended',function(e) if e.battle==st then ended=true end end,0,'gameplay_rules')
  for n=1,6000 do frame(n);if n%20==0 then draw() end;if ended then break end end
  assert(ended,'native Gen3 battle turn did not finish: '..tostring(B._phase))
  local lost=1000-st.enemy.mon.hp
  assert(lost>0 and st.player.mon.pp[1]==34,'move did not damage the foe and consume PP: hp='..lost..' pp='..tostring(st.player.mon.pp[1]))
  draw();if divisor==25 and not poison then require('GameplayEvidence').capture(id,'battle',function() B.draw(game,240,160) end,true) end;B.abort('run');for n=1,30 do frame(n) end;off()
  return lost,startHp-mon.hp,maxHp
 end
 local function turn12(divisor,poison,critRate)
  install(game,id,{formulaRules={statDiv=divisor},ailments=poison and (gen==2 and {poisonFraction=poison} or {chip=poison}) or nil})
  if gen==2 then
   local Mon=require('src.battle.gen2.Mon')
   local p=assert(Mon.new(game.data,'BULBASAUR',50,{dvs={attack=10,defense=10,speed=10,special=10}}));local foe=assert(Mon.new(game.data,'MAGIKARP',50,{dvs={attack=10,defense=10,speed=10,special=10}}))
   p.moves={{id='TACKLE',pp=35}};foe.moves={{id='SPLASH',pp=40}};foe.hp=1000
   game.save.party={p};if poison then p.status='poison' end
   local startHp=p.hp;local maxHp=p.stats.hp
   local B=require('src.battle.gen2.Battle').new({data=game.data,save=game.save,party={p},wild=foe,random=function(n) return math.floor(n/2) end})
   local UI=require('src.ui.gen2.BattleState').new(game,{battle=B})
   B.enemy.hp=1000
   game.stack:push(UI)
   for n=1,4000 do frame(n);if n%20==0 then draw() end;if UI.phase=='menu' then break end end
   assert(UI.phase=='menu','Gen2 battle intro did not reach menu')
   assert(UI:chooseMenu('fight'));assert(UI:chooseMove(1))
   for n=1,4000 do frame(n);if n%20==0 then draw() end;if UI.phase=='menu' and B.turn>=1 then break end end
   assert(B.turn>=1 and UI.phase=='menu','Gen2 turn did not resolve')
   local lost=1000-B.enemy.hp;assert(lost>0 and p.moves[1].pp==34,'Gen2 attack/PP did not resolve')
   if divisor==25 and not poison then require('GameplayEvidence').capture(id,'battle',function() UI:drawScene() end,true) end
   game.stack:pop();return lost,startHp-p.hp,maxHp
  end
  local Pokemon=require('src.pokemon.Pokemon');local p=Pokemon.new(game.data,'BULBASAUR',50,function() return 0 end)
  p.moves={{id='TACKLE',pp=35}};if poison then p.status='PSN' end;game.save.party={p}
  local startHp=p.hp;local maxHp=p.stats.hp
  local UI=require('src.battle.BattleState').newWild(game,'MAGIKARP',50)
  if critRate~=nil then UI.ruleset=setmetatable({critRate=critRate},{__index=UI.ruleset}) end
  UI.enemy.curStats.defense=100;UI.enemy.curStats.special=100
  UI.enemy.mon.hp=1000;UI.enemy.mon.stats.hp=1000;UI.enemy.curMoves={{id='SPLASH',pp=40}}
  UI.rng=function(lo,hi) return lo==0 and 128 or hi end
  game.stack:push(UI)
  for n=1,4000 do frame(n);if n%20==0 then draw() end;if UI.phase=='menu' then break end end
  assert(UI.phase=='menu','Gen1 battle intro did not reach menu')
  assert(UI:chooseMenu('fight'));assert(UI:chooseMove(1))
  for n=1,4000 do frame(n);if n%20==0 then draw() end;if UI.phase=='menu' then break end end
  assert(UI.phase=='menu','Gen1 turn did not resolve')
  local lost=1000-UI.enemy.mon.hp;assert(lost>0 and p.moves[1].pp==34,'Gen1 attack/PP did not resolve hp='..lost..' pp='..tostring(p.moves[1].pp))
  if divisor==25 and not poison then require('GameplayEvidence').capture(id,'battle',function() UI:drawClassic() end,false) end
   game.stack:pop();return lost,startHp-p.hp,maxHp
 end
 local first=(gen==3 and turn3 or turn12)(50);note('native battle: default damage '..first)
 local edited=(gen==3 and turn3 or turn12)(25)
 assert(edited>first and math.abs(edited-2*first)<=6,'edited formula did not increase actual turn damage: '..first..' -> '..edited)
 note('native battle: edited damage '..edited..'; PP and turn completion verified')
 for _,divisor in ipairs({8,2}) do
  local _,chip,hp=(gen==3 and turn3 or turn12)(50,divisor)
  assert(chip==math.max(1,math.floor(hp/divisor)),'native poison turn ignored HP fraction '..divisor..': '..chip..' from '..hp)
  note('native battle: poison fraction 1/'..divisor..' removed '..chip..' HP after the turn')
 end
 if gen==3 then
  local low=turn3(50,nil,{critMultiplier=1})
  local high=turn3(50,nil,{critMultiplier=3})
  assert(high>low*2,'critical multiplier did not affect native-turn damage: '..low..' -> '..high)
  note('native critical hits: multiplier 1 damage '..low..', multiplier 3 damage '..high)
  turn3(50,nil,{trainer=true})
  note('native trainer battle: 100% shiny foe rendered and completed a turn')
 elseif gen==1 then
  local ordinary=turn12(50,nil,0);local critical=turn12(50,nil,255)
  assert(critical>ordinary,'Gen1 critical rate override did not affect native-turn damage')
  note('native critical hits: disabled damage '..ordinary..', forced damage '..critical)
 end
 require('GameplayMinigames').run(game,id,function(changes) install(game,id,changes) end,note)
 if gen==3 then require('GameplayWireless').run(game,id,function(changes) install(game,id,changes) end,note) end
 game.mods.hooks:removeOwner('gameplay_rules')
 report('PASS: '..id..'\n'..table.concat(results,'\n'))
 return results
end
return M




