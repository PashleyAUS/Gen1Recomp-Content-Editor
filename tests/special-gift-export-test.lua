package.path = 'tools/content-editor/?.lua;runtime/gen1recomp/?.lua;' .. package.path
local Writer = require('ModWriter')
local State = require('State')
local project = {id='gift_test', specialEncounters={
  FISH={mapId='NEW_BARK_TOWN',bindTextId='MOD:FISH',species='MAGIKARP',level=99,
    flag='GOT_FISH',text='Take this!',after='Already gifted.',moves={'HYDRO_PUMP'},dvs={attack=15}},
  PLAIN={mapId='NEW_BARK_TOWN',species='MAGIKARP',level=5},
  REPEAT={mapId='NEW_BARK_TOWN',species='MAGIKARP',level=5,unique=false},
}}
local save = {party={},pokedex={}}
local handlers = {}
local mod = {world={game={save=save,data={moves={HYDRO_PUMP={pp=5}}}}},
  content={commands={register=function(_,key,rec) handlers[key]=rec.fn end}}}
package.loaded['src.battle.gen2.Mon'] = {
  new=function(_,species,level,opts) return {species=species,level=level,opts=opts} end,
  stampOT=function() end,
}
local out={}
Writer.emitSpecialEncounters(project,out,true)
assert(loadstring('local mod = ...\n'..table.concat(out,'\n')))(mod)
local faced,text=0,{}
local ctx={vm={facePlayerFn=function() faced=faced+1 end,
  showRaw=function(_,body) text[#text+1]=body end}}
local give=assert(handlers['gift_test:give_special'])
give(ctx,'FISH')
assert(#save.party==1 and save.party[1].opts.moves[1].id=='HYDRO_PUMP')
assert(save.flags[State.modFlag(project,'GOT_FISH')])
assert(save.pokedex.caught.MAGIKARP, 'gift registers as caught')
assert(text[#text]:find('received'), 'gift prints the received line')
-- Round-trip the save to ensure the named flag persists.
local Serializer=require('src.core.SaveSerializer')
mod.world.game.save=assert(loadstring(Serializer.encode(save)))()
save=mod.world.game.save
give(ctx,'FISH')
assert(#save.party==1 and text[#text]=='Already gifted.' and faced==2)
for i=2,6 do save.party[i]={} end
give(ctx,'PLAIN')
assert(not save.flags[State.modFlag(project,'GOT_PLAIN')])
assert(text[#text]:find('party is full'))
save.party[6]=nil
give(ctx,'PLAIN')
assert(#save.party==6 and save.flags[State.modFlag(project,'GOT_PLAIN')])
save.party={}
give(ctx,'REPEAT'); give(ctx,'REPEAT')
assert(#save.party==2)
Writer.applySpecialEncounterBindsGold(project)
assert(project.scripts['MOD:FISH'][1].op=='faceplayer')
assert(project.scripts['MOD:FISH'][3].op=='modcommand')
assert(project.scripts['mod:SPECIAL_PLAIN'][3].op=='modcommand')
local scripts={}
Writer.applySpecialEncounterBinds(project,scripts)
assert(scripts.NEW_BARK_TOWN.talk['MOD:FISH'][1][1]=='face_player')
print('OK special gift flags, save reload, facing, party-full retry, plain/custom and repeat gifts')
