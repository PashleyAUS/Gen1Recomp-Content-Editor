package.path="tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;"..package.path
love=require("tests.love_stub")
local State=require("State")
local Writer=require("ModWriter")
for _,game in ipairs({"red","blue","yellow","gold","silver","crystal"}) do
  local project=State.blankProject("form_check");project.game=game
  project.pokemon.PIKACHU={forms={Winter={spriteFront="winter-front.png",spriteBack="winter-back.png"}}}
  project.pokemon.UNOWN={letters={A={spriteFront="a-front.png"},Extra={spriteBack="extra-back.png"}}}
  local restored=assert(loadstring(Writer.serializeProject(project)))()
  assert(restored.pokemon.PIKACHU.forms.Winter.spriteBack=="winter-back.png")
  local hooks,records={},{}
  local mod={content={pokemon={}}}
  function mod.content.pokemon:patch(id,rec) records[id]=rec end
  function mod.content.pokemon:add(id,rec) records[id]=rec end
  mod.hooks={wrap=function(_,id,fn) hooks[id]=fn end}
  assert(loadstring(Writer.emitMain(restored)))()(mod)
  local sprite=assert(hooks["pokemon.sprite"],game.." missing sprite hook")
  local function pick(species,form,side)
    return sprite(function(path) return path end,"original.png",{mon={form=form},species=species,side=side,data={pokemon=records}})
  end
  assert(pick("PIKACHU","Winter","front")=="winter-front.png",game)
  assert(pick("PIKACHU","Winter","back")=="winter-back.png",game)
  assert(pick("PIKACHU","Unknown","front")=="original.png",game)
  assert(pick("UNOWN","Extra","back")=="extra-back.png",game)
  assert(pick("UNOWN","A","back")=="original.png",game)
  print("PASS "..game..": form serialization, exported front/back selection and fallback")
end
local Forms=require("Gen3Forms")
local expected={firered="Attack",leafgreen="Defense",ruby="Normal",sapphire="Normal",emerald="Speed"}
local pictures={}
package.loaded.Gen3Rom={formPicture=function(_,species,back,frame,palette,shiny)
  pictures[#pictures+1]={species=species,frame=frame}
  return {encode=function() return {getString=function() return "image" end} end}
end}
package.loaded.ModIO={ensureDirectory=function() return true end,writeText=function() return true end}
for _,game in ipairs({"firered","leafgreen","ruby","sapphire","emerald"}) do
  local S=State.new();S.version=game;S.project=State.blankProject("native_forms");S.path="unused"
  S.data={pokemon={DEOXYS={id="DEOXYS",index=410,name="DEOXYS",baseStats={}}}}
  local ids,labels=Forms.encounterChoices(S,"DEOXYS")
  assert(#ids==5 and labels["1"]==expected[game],game.." encounter labels")
  local family=Forms.template(S,"DEOXYS")
  assert(#family.forms==4 and family.forms[1].name==expected[game],game.." native form")
  local seen={}
  for _,row in ipairs(family.forms) do
    assert(not seen[row.name],game.." duplicate form");seen[row.name]=true
    if row.name=="Normal" or row.name=="Speed" and game=="emerald" then
      assert(not row.needsArtwork,game.." available artwork marked missing")
    else assert(row.needsArtwork,game.." unavailable artwork accepted") end
  end
  assert(seen.Normal and seen.Attack and seen.Defense and seen.Speed)
  print("PASS "..game..": Deoxys native identity, four unique forms and artwork availability")
end
