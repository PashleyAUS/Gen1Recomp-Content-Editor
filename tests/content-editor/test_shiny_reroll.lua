-- Exercise the real Frontier party loop with a bounded RNG; the old code
-- exhausts this budget when every personality is shiny.
package.path='runtime/gen1recomp/?.lua;'..package.path
dofile('tests/love_stub.lua')
local P=require('src.core.game3.pokemon')
local D=require('src.core.game3.rse.frontier.trainers')
local saved={}
for _,key in ipairs({'pack','rng','brainSymbol','createMon','setHeldItem','setEvs','setMoves','isMove'}) do saved[key]=D[key] end
local row={species=1,nature=0,fixedIV=31,moves={},evs={}}
D.pack=function() return {mons={[0]={[1]={row,row,row}}}} end
D.brainSymbol=function() return 0 end
D.createMon=function() return {} end
D.setHeldItem=function() end;D.setEvs=function() end;D.setMoves=function() end;D.isMove=function() return false end
for _,threshold in ipairs({0,8,65535,65536}) do
 P.SHINY_BELOW=threshold
 local calls=0
 D.rng=function() return {Random32=function()
  calls=calls+1;assert(calls<=10,'shiny reroll did not terminate at '..threshold)
  -- 65535 XOR the OT halves is non-shiny for every threshold below 65536.
  local bit=require('bit')
  local pid=bit.bxor(65535,bit.bxor(bit.rshift(D.FRONTIER_BRAIN_OTID,16),bit.band(D.FRONTIER_BRAIN_OTID,65535)))
  row.nature=pid%25
  return pid
 end} end
 assert(#D.brainParty({},0,50,1)==1)
 assert(calls==1)
end
for key,value in pairs(saved) do D[key]=value end
P.SHINY_BELOW=65536
local Rng=require('src.core.game3.rng');local original=Rng.Random32
local calls=0
Rng.Random32=function() calls=calls+1;assert(calls<3,'RS trainer shiny reroll did not terminate');return 0 end
local mon=require('src.core.game3.battle.trainer_rs').prepareMon({personality=0,heldItem=5})
assert(calls==1 and mon.item==5 and P.isShiny(mon))
Rng.Random32=original
P.SHINY_BELOW=8
print('PASS Frontier shiny reroll boundaries terminate')

