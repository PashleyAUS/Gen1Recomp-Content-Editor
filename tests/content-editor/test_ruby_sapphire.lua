package.path="runtime/gen1recomp/?.lua;tools/content-editor/?.lua;"..package.path
local GV=require("src.core.GameVersion")
local Profile=require("src.core.game3.profile")
local Generation=require("Generation")
local Writer=require("ModWriter")
local G=require("Gen3")
local Birch=require("Gen3Birch")
for _,game in ipairs({"ruby","sapphire","emerald","firered","leafgreen"}) do
 GV.set(game)
 local S={version=game}
 assert(Generation.num(S)==3 and Generation.engine(S)=="game3")
 assert(Generation.manifestGames(S)[1]==game)
 local profile=Profile.of(game)
 assert(Generation.gen3MapPrefix(S)==profile.map.enginePrefix)
 assert(GV.cachePrefix(game)==game.."/")
 local id=profile.map.enginePrefix.."TEST"
 local data={}
 G.load(data,function(path)
  if path=="data/generated/maps.lua" then return "return "..Writer.encodeLua({[id]={id=id,width=10,height=10}}) end
  return "return {}"
 end)
 assert(G.catalog(data,"maps")[id].width==10)
 if game=="ruby" or game=="sapphire" then
  assert(profile.boot.newGame=="src.ui.game3.rs.birch_speech")
  assert(profile.boot.title=="src.ui.game3.rs.title")
  assert(profile.ui.screens.slot_machine=="src.ui.game3.rs.slot_machine")
  assert(Birch.keys(S)[1]=="gBirchSpeech_Welcome")
 end
end
print("ok Ruby/Sapphire profiles, generation, cache paths, map catalogs and intro text")
