package.path='tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;'..package.path
love=require('tests.love_stub')
local Damage=require('src.battle.Damage')
local attacker={def={baseStats={speed=100}},curStats={speed=100},stages={}}
for _,game in ipairs({'red','blue','yellow'}) do
 require('src.core.GameVersion').set(game)
 assert(not Damage.critRoll({critRate=0},attacker,'POUND',function() return 0 end,false),game..' zero crits')
 assert(Damage.critRoll({critRate=128},attacker,'POUND',function() return 127 end,false),game..' under threshold')
 assert(not Damage.critRoll({critRate=128},attacker,'POUND',function() return 128 end,false),game..' at threshold')
end
print('PASS Gen 1 ruleset critical rate is applied')
