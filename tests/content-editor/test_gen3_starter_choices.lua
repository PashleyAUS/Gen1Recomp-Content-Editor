package.path="tools/content-editor/?.lua;tools/content-editor/panels/?.lua;"..package.path
local M=require("Gen3Starters")
local rules={{map="FR_OAKS_LAB",matchSpecies={"BULBASAUR"},species="CHARMANDER",level=12,onlyFirst=true},{map="FR_OAKS_LAB",matchSpecies={"CHARMANDER"},species="SQUIRTLE",level=8,onlyFirst=true}}
local out={};M.emit({gen3Starters=rules},function() return "rules" end,out)
local records={BULBASAUR={index=1},CHARMANDER={index=4},SQUIRTLE={index=7}}
local listeners={};local command=function(_,_,row) return row end
local mod={content={pokemon={get=function(_,id) return records[id] end}},hooks={wrap=function(_,_,fn) local next=command;command=function(...) return fn(next,...) end end},events={on=function(_,_,fn) listeners[#listeners+1]=fn end}}
local fn=assert(loadstring("return function(mod,rules) "..table.concat(out,"\n").." end"))();fn(mod,rules)
local ctx={overworld={map={id="FR_OAKS_LAB"}},save={party={},flags={}}}
local row=command(ctx,"setvar",{var=0x4002,value=1});assert(row.value==4)
local gift={ctx=ctx,species="CHARMANDER",level=5};for _,f in ipairs(listeners) do f(gift) end
assert(gift.species=="CHARMANDER" and gift.level==12,"Starter replacements cascaded")
print("PASS starter swaps do not cascade")
-- Rival dialogue happens after the player's party and starter flag are populated.
ctx.save.party={{species="CHARMANDER"}};ctx.save.flags.EVENT_GOT_STARTER=true
for _,map in ipairs({"FR_OAKS_LAB","OAKS_LAB"}) do
  ctx.overworld.map.id=map
  local original={dest=0,src=1}
  local rival=command(ctx,"bufferspeciesname",original)
  assert(rival.src==4 and rival[2]==4 and rival.dest==0,"Rival name replacement cascaded or failed")
  assert(original.src==1 and original[2]==nil,"Shared script row was mutated")
  assert(command(ctx,"bufferspeciesname",{0,4}).src==7,"Positional rival name was not replaced")
  for _,src in ipairs({0x4002,25}) do
    local untouched={dest=0,src=src}
    assert(command(ctx,"bufferspeciesname",untouched)==untouched,"Unrelated name was replaced")
  end
end
ctx.overworld.map.id="FR_ROUTE1"
local elsewhere={dest=0,src=1}
assert(command(ctx,"bufferspeciesname",elsewhere)==elsewhere,"Name outside Oak's lab was replaced")
ctx.overworld.map.id="FR_OAKS_LAB"
ctx.save.party={};ctx.save.flags={}
print("PASS rival starter dialogue after player receives starter")
records.SCIZOR={index=212}
listeners={};command=function(_,_,row) return row end
rules={{map="FR_OAKS_LAB",matchSpecies={"BULBASAUR"},species="SCIZOR",level=5,onlyFirst=true}}
fn(mod,rules)
local changed=command(ctx,"setvar",{var=0x4002,value=1});assert(changed.value==212)
local received={ctx=ctx,species="SCIZOR",level=5};for _,f in ipairs(listeners) do f(received) end
assert(received.species=="SCIZOR","Replacement starter was not given")
local unrelated={ctx=ctx,species="PIKACHU",level=8};for _,f in ipairs(listeners) do f(unrelated) end
assert(unrelated.species=="PIKACHU" and unrelated.level==8,"Starter selection changed an unrelated gift")
print("PASS Bulbasaur choice gives Scizor")
