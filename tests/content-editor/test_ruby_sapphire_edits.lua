-- Read real imports; all writes go to disposable test projects.
package.path="runtime/gen1recomp/?.lua;tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;"..package.path
love={filesystem={read=function(path) local f=io.open(path,"rb");if not f then return end;local s=f:read("*a");f:close();return s end,getInfo=function() return nil end,getSource=function() return "." end}}
local GV=require("src.core.GameVersion")
local G=require("Gen3")
local IO=require("ModIO")
local Json=require("src.link.Json")
local State=require("State")
local Schemas=require("src.mods.Schemas")
local base=assert(os.getenv("POKEPORT_RS_CACHE"),"Set POKEPORT_RS_CACHE to the folder containing ruby/ and sapphire/")
for _,game in ipairs({"ruby","sapphire"}) do
 GV.set(game)
 local function read(rel) return IO.readText(base.."/"..game.."/"..rel) end
 local data={};G.load(data,read)
 local prefix=require("Generation").gen3MapPrefix({version=game})
 local map=prefix.."LITTLEROOT_TOWN"
 assert(data.maps[map],"Missing native town: "..map)
 local layout=assert(require("Gen3Map").layout(data,map))
 data.maps[map].midLayout=layout
 local texts=G.catalog(data,"text")
 local textKey="gBirchSpeech_Welcome";assert(texts[textKey])
 local trainerKey;for k in pairs(G.catalog(data,"trainers")) do trainerKey=k;break end
 local project=State.blankProject("rs_edit_test_"..game,"RS Edit Test")
 project.game=game
 local Panel=require("Gen3StartersPanel")
 local state={version=game,data=data,project=project}
 Panel.add(state,"starters")
 assert(#project.gen3Starters==3)
 for _,rule in ipairs(project.gen3Starters) do assert(rule.map==prefix.."ROUTE101") end
 local gift=assert(Panel.addGift(state,"BELDUM"),"Missing native Beldum gift preset")
 assert(gift.map:sub(1,#prefix)==prefix and data.maps[gift.map],"gift uses a foreign map")
 assert(not Panel.addGift(state,"CHIKORITA"),"Emerald-only Johto gift offered")
 gift.species="MEW";gift.level=28;gift.nickname="EDITOR"
 project.gen3Starters={gift}
 project.gen3={pokemon={TREECKO={baseStats={hp=77,specialAttack=88}}},moves={POUND={power=67,pp=23}},items={POTION={price=321}},trainers={[trainerKey]={name="EDITED"}},text={[textKey]="Edited Birch welcome"},map_scripts={EDITOR_RS_TEST={{op="end"}}},encounters={[map]={land={rate=25}}},maps={[map]={name="Edited Littleroot"}}}
 project.gen3Modes={map_scripts={EDITOR_RS_TEST="register"}}
 project.gen3Terrain={[map]={[1025]={mid=1,coll=0,elev=3}}}
 local dir=(os.getenv("TEMP") or "/tmp").."/"..project.id.."_"..os.time()
 assert(IO.ensureDirectory(dir))
 assert(IO.writeText(dir.."/manifest.json",Json.encode({id=project.id,name=project.name,version="1.0.0",entry="main.lua",games={game}})))
 IO._emitBaseData=data
 assert(IO.save(dir,project))
 project.gen3.moves.POUND.power=69
 assert(IO.save(dir,project))
 local reopened=assert(IO.load(dir))
 assert(reopened.game==game and reopened.gen3.moves.POUND.power==69)
 local mf=assert(Json.decode(assert(IO.readText(dir.."/manifest.json"))))
 assert(#mf.games==1 and mf.games[1]==game)
 local fresh={};G.load(fresh,read)
 fresh.maps[map].midLayout=assert(require("Gen3Map").layout(fresh,map))
 local loader,err=require("Gen3Mod").load(fresh,dir);assert(loader,err)
 assert(#fresh._editorGen3Report.rejected==0)
 local ctx={overworld={map={id=gift.map}},save={flags={},party={}}}
 local received={species="BELDUM",level=5,ctx=ctx}
 loader.events:emit("pokemon.before_give",received)
 assert(received.species=="MEW" and received.level==28 and received.nickname=="EDITOR")
 local unrelated={species="TREECKO",level=5,ctx=ctx}
 loader.events:emit("pokemon.before_give",unrelated)
 assert(unrelated.species=="TREECKO" and unrelated.level==5)
 assert(G.catalog(fresh,"pokemon").TREECKO.baseStats.hp==77)
 assert(G.catalog(fresh,"pokemon").TREECKO.baseStats.specialAttack==88)
 assert(G.catalog(fresh,"moves").POUND.power==69)
 assert(G.catalog(fresh,"moves").POUND.pp==23)
 assert(G.catalog(fresh,"items").POTION.price==321)
 assert(G.catalog(fresh,"trainers")[trainerKey].name=="EDITED")
 assert(G.catalog(fresh,"text")[textKey]=="Edited Birch welcome")
 assert(G.catalog(fresh,"map_scripts").EDITOR_RS_TEST[1].op=="end")
 assert(G.catalog(fresh,"encounters")[map].land.rate==25)
 assert(G.catalog(fresh,"maps")[map].name=="Edited Littleroot")
 assert(fresh.gen3Pokemon.stats[277].hp==77,"raw runtime species stats missing edit")
 loader.events:emit("game.ready",{game={data=fresh}})
 local edited=fresh.maps[map].midLayout
 assert(edited:midAt(1,1)==1 and edited:elevAt(1,1)==3,"native terrain edit missing")
 for _,file in ipairs({"manifest.json","main.lua","editor_project.lua"}) do os.remove(dir.."/"..file) end
 os.execute('rmdir "'..dir..'"')
 print("ok "..game.." real-cache save/reopen/export/runtime: Pokemon, moves, items, trainers, Birch text, scripts, encounters, maps, terrain, gift presets/events")
end
