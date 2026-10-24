package.path="tools/content-editor/?.lua;runtime/gen1recomp/?.lua;"..package.path
local F=require("Gen3Forms")
local W=require("ModWriter")
love={filesystem={read=function(path)
  local f=assert(io.open(path,"rb"));local text=f:read("*a");f:close();return text
end}}
local S={data={pokemon={BASE={id="BASE",index=1}}},project={pokemon={}},pokemonId="BASE_FORM_2"}
local a=F.add(S,"BASE","A")
local b=F.add(S,"BASE","B")
local family=S.project.gen3Forms.BASE
family.mode="rules";family.default=3
family.rules={{trigger="battle_start",target=2,from=0},{trigger="battle_start",target=3,from=0}}
family.forms[3].mechanic={kind="mega",from=2}
S.project.encounters={ROUTE={land={slots={{species=a.species}}}}}
S.project.trainers={T={party={{species=a.species}}}}
S.project.pokedex={[a.species]={name="A"}}
S.project.text={dialogue=a.species.." is a form"}
S.g3FormSelection={BASE=3}
F.remove(S,a.species)
assert(#family.forms==2 and family.forms[2].species==b.species)
assert(family.default==2 and S.g3FormSelection.BASE==2 and S.pokemonId=="BASE")
assert(#family.rules==1 and family.rules[1].target==2)
assert(not family.forms[2].mechanic)
assert(S.project.encounters.ROUTE.land.slots[1].species=="BASE")
assert(S.project.trainers.T.party[1].species=="BASE")
assert(not S.project.pokemon[a.species] and not S.project.pokedex[a.species])
assert(S.project.text.dialogue==a.species.." is a form")
-- Persist/reload and run the real export-time form validators.
local p=assert(loadstring("return "..W.encodeLua(S.project)))()
local out={};F.emit(p,W.encodeLua,out)
assert(#out>0);assert(loadstring(table.concat(out,"\n")))
S.project=p;F.remove(S,b.species)
assert(not p.gen3Forms.BASE and not p.pokemon[b.species])
out={};F.emit(p,W.encodeLua,out);assert(#out==0)
-- Reverting edits to a stock parent must preserve the custom forms.
F.add(S,"BASE","C");p.pokemon.BASE={id="BASE"}
F.remove(S,"BASE");assert(not p.pokemon.BASE and #p.gen3Forms.BASE.forms==2)
print("PASS: form deletion, rule indexes, references, persistence and export validation")
