local M={}
local function finite(n,label)
 assert(type(n)=='number' and n==n and n~=math.huge and n~=-math.huge,label..' produced a non-finite number')
 return n
end
function M.run(gameId,game,case)
 local gen=require('src.core.GameVersion').generation()
 if gen==3 then
  local P=require('src.core.game3.pokemon')
  local R=require('Gen3BattleRules')
  local aliases={Catching=require('src.core.game3.battle.catching'),Capabilities=require('src.core.game3.battle.capabilities'),Hazards=require('src.core.game3.battle.effects.hazards'),Pokemon=P,Damage=require('src.core.game3.battle.damage'),Rules=require('src.core.game3.battle.rules'),Healing=require('src.core.game3.battle.effects.healing'),Volatiles=require('src.core.game3.battle.effects.volatiles')}
  local groups={moveFields='gen3MovePower',healFields='gen3Heal',hitFields='gen3Hits',residualFields='gen3Residual',specialFields='gen3Special',lockFields='gen3Locks',switchFields='gen3Switch',fleeFields='gen3Flee',spikeFields='gen3Spikes',formulaFields='gen3Formula',accuracyFields='gen3Accuracy',statCalcFields='gen3StatCalc',catchFields='gen3CatchMath',effortFields='gen3Effort',ppFields='gen3Pp'}
  for fields,bag in pairs(groups) do
   for _,row in ipairs(R[fields] or {}) do
    local authored=case and case.project[bag] and case.project[bag][row.key]
    if authored~=nil and row.field then
     local parts={} for key in row.field:gmatch('[^.]+') do parts[#parts+1]=key end
     local actual=aliases[parts[1]]
     assert(actual,'unknown rule module '..parts[1])
     for i=2,#parts do actual=actual[parts[i]] end
     assert(actual==authored,row.field..' did not apply the edited value: '..tostring(actual)..' ~= '..tostring(authored))
    end
   end
  end
  local stats=P.calcStats(1,50,{},{},0)
  finite(stats.maxHp,'Pokemon HP');finite(stats.attack,'Pokemon Attack')
  P.gender(1,1);P.abilityId(1,1);P.isShiny({personality=8,otId=0,otSecretId=0})
  finite(P.maxPp(20,3),'PP')
  local D=require('src.core.game3.battle.damage')
  local mon={level=50,attack=100,defense=100,spAtk=100,spDef=100,hp=100,maxHp=100}
  local a,b={mon=mon,stages={}},{mon=mon,stages={}}
  finite(D.base(a,b,{power=40,type=0},{}),'battle damage')
  finite(D.applyStab(40),'STAB');finite(D.screenDamage(40,true),'screens')
  finite(D.friendshipPower(255,false),'Return');finite(D.flailPower(1,100),'Flail')
  finite(D.fleeOdds(50,100,1),'flee');finite(D.hiddenPower({ivs={}}),'Hidden Power')
  finite(D.bidePayout(20),'Bide');finite(D.crashDamage(20,100),'crash')
  finite(D.presentHeal(100),'Present');finite(D.eruptionPower(50,100,150),'Eruption')
  finite(D.rolloutPower(30,2,true),'Rollout')
  local H=require('src.core.game3.battle.effects.healing')
  for _,weather in ipairs({'SUN','RAIN','CLEAR'}) do finite(H.weatherHeal(100,weather),'weather healing') end
  for i=1,3 do finite(H.swallowAmount(100,i),'Swallow') end
  finite(require('src.core.game3.battle.catching').catchOdds(4,{mon={hp=50,maxHp=100}}),'catch odds')
 elseif gen==2 then
  local D=require('src.battle.gen2.Damage')
  finite(D.base(50,40,100,100),'battle damage')
  local E=require('src.battle.gen2.Effects')
  finite(E.multiHitCount(function() return 0 end),'multi hit');finite(E.encoreTurns(function() return 0 end),'Encore')
  finite(E.healAmount(100),'healing');finite(E.substituteCost(100),'Substitute');finite(E.counterDamage(20),'Counter')
  finite(require('src.battle.gen2.Catching').rate({ball='POKE_BALL',maxHp=40,hp=20,catchRate=45}),'catch odds')
  local stats=require('src.battle.gen2.Mon').stats({hp=100,attack=100,defense=100,speed=100,specialAttack=100,specialDefense=100},{attack=0,defense=0,speed=0,special=0},50,{})
  finite(stats.attack,'Pokemon Attack');finite(stats.hp,'Pokemon HP')
 else
  local D=require('src.battle.Damage')
  for _,ruleset in pairs(game and game.data.rulesets or {}) do
   if type(ruleset)=='table' then
    local attacker={def={baseStats={speed=100}},curStats={speed=100},stages={}}
    local function rng(lo,hi) assert(lo<=hi,'inverted rule RNG interval');return lo end
    D.critRoll(ruleset,attacker,'POUND',rng,false)
    if ruleset.critRate~=nil then
     assert(D.critRoll(ruleset,attacker,'POUND',function() return 0 end,false)==(ruleset.critRate>0),'edited critical rate ignored')
    end
   end
  end
  finite(D.compute({}, {mon={level=50},curStats={attack=100,defense=100},stages={},curTypes={}}, {curStats={attack=100,defense=100},stages={},curTypes={}}, {power=40,category='physical',type='NORMAL'}, {forceCrit=false,typeless=true,rng=function() return 1 end}),'battle damage')
  local Stats=require('src.pokemon.Stats')
  local stats=Stats.calc({baseStats={hp=100,attack=100,defense=100,speed=100,special=100}},50,{hp=0,attack=0,defense=0,speed=0,special=0},{})
  finite(stats.hp,'Pokemon HP');finite(stats.attack,'Pokemon Attack')
  require('src.battle.Catching').attempt('POKE_BALL',{hp=50,stats={hp=100}},{catchRate=45},function() return 0 end)
 end
end
return M

