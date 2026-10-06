package.path="runtime/gen1recomp/?.lua;tools/content-editor/?.lua;"..package.path
local Emit=require("Gen3Starters")
local Writer=require("ModWriter")
local GV=require("src.core.GameVersion")
for _,game in ipairs({"ruby","sapphire"}) do
 GV.set(game)
 local hooks={}
 local function call(key,proceed,...)
  if hooks[key] then return hooks[key](proceed,...) end
  return proceed(...)
 end
 local received={}
 local Party={giveMonToPlayer=function(session,species,level,nickname)
  received[#received+1]={species=species,level=level,nickname=nickname};return 0
 end}
 local Choose={species=function(_,selection) return 277+selection end,open=function(opts) return opts.onDone(0) end}
 local Field={giveStarter=function() error("RS should bypass Emerald helper") end}
 local modules={
  ["src.core.GameVersion"]=GV,["src.ui.game3.rse.starter_choose"]=Choose,
  ["src.core.game3.party"]=Party,["src.core.game3.scripting.natives_field_rse"]=Field,
  ["src.mods.Runtime"]={call=call}
 }
 local out={}
 Emit.emit({gen3Starters={{map="unused",starterSlot=0,matchSpecies={"TREECKO"},species="MEW",level=28,nickname="EDITOR",onlyFirst=true}}},Writer.encodeLua,out)
 local chunk=assert(loadstring("return function(mod)\n"..table.concat(out,"\n").."\nend"))
 setfenv(chunk,setmetatable({require=function(name) return assert(modules[name],name) end},{__index=_G}))
 local species={TREECKO={index=277},MEW={index=151}}
 chunk()({content={pokemon={get=function(_,id) return species[id] end}},hooks={wrap=function(_,key,fn) hooks[key]=fn end}})
 Choose.open({onDone=function(selection)
  assert(selection==0);Party.giveMonToPlayer({},277,5)
 end})
 assert(received[1].species==151 and received[1].level==28 and received[1].nickname=="EDITOR")
 Party.giveMonToPlayer({},298,10,"NORMAL")
 assert(received[2].species==298 and received[2].level==10 and received[2].nickname=="NORMAL")
 local ok=pcall(Choose.open,{onDone=function() error("callback failure") end})
 assert(not ok)
 Party.giveMonToPlayer({},280,7)
 assert(received[3].species==280 and received[3].level==7,"starter scope leaked after failure")
 print("ok "..game.." starter species/level/nickname; unrelated gifts and callback errors")
end
