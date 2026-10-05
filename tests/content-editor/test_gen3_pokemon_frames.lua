local files={}
local failWrites=false
package.loaded.ModIO={readText=function(p) return files[p] end,
  ensureDirectory=function() return true end,
  writeText=function(p,b) if failWrites then return nil,"Denied" end;files[p]=b;return true end}
local F=require("Gen3PokemonFrames")
local pixels=love.image.newImageData(64,128)
pixels:mapPixel(function(x,y) return y<64 and 1 or 0,y>=64 and 1 or 0,0,1 end)
files.picked=pixels:encode("png"):getString()
local S={path="mod",project={},data={_gen3Read=function() end}}
assert(F.import(S,25,"picked"))
local path=F.path(25)
assert(S.project.gen3Assets[path].height==128)
assert(F.read(S,25)==pixels:getString())
local dest=assert(F.export(S,25))
assert(love.image.newImageData(love.filesystem.newFileData(files[dest],"out.png")):getString()==pixels:getString())
assert(F.import(S,25,"picked",true))
assert(F.read(S,25,true)==pixels:getString())
files.bad=love.image.newImageData(128,64):encode("png"):getString()
local previous=S.project.gen3Assets[path]
assert(not F.import(S,25,"bad"));assert(S.project.gen3Assets[path]==previous)
failWrites=true;assert(not F.import(S,25,"picked"));assert(S.project.gen3Assets[path]==previous);failWrites=false
F.revert(S,25,true);assert(not S.project.gen3Assets[F.path(25,true)])
local base=love.image.newImageData(64,64):getString()
local empty={path="mod",project={},data={_gen3Read=function(p) if p:find("/front/",1,true) then return base end end}}
assert(F.export(empty,25),"FireRed should export its static sprite as a starting sheet")
local emitted={}
require("Gen3Native").emit(S.project,require("ModWriter").encodeLua,emitted)
local generated=table.concat(emitted,"\n")
assert(generated:find("pokemonFrames.install",1,true),"Saved mods omitted frame playback support")
assert(loadstring(generated),"Generated runtime has invalid Lua")
-- Preview and controls with real image/quad drawing.
package.loaded.Kit={caption=function(x,y,t) love.graphics.print(t,x,y) end,button=function() return false end}
local preview=love.graphics.newCanvas(660,250)
love.graphics.setCanvas(preview);love.graphics.clear(.1,.1,.15)
F.draw(S,25,{markDirty=function() end},20,20,600,1,false)
love.graphics.setCanvas()
local output=assert(io.open(os.getenv("EDITOR_TEST_ROOT").."/tests/content-editor/frames-smoke/preview.png","wb"))
output:write(preview:newImageData():encode("png"):getString());output:close()

-- Playback uses active mod hooks, including disable and reload.
local hooks={}
local Runtime={call=function(name,next,...) if hooks[name] then return hooks[name](next,...) end;return next(...) end}
package.loaded["src.mods.Runtime"]=Runtime
local enabled=false
local A={enabled=function() return enabled end,framePic=function() end,hasTwoFramesAnimation=function() return true end}
package.loaded["src.core.game3.mon_anim"]=A
local p={}
local B={start=function() return enabled and "native" or nil end,busy=function() return false end,reset=function() end,
  introSteps=function(steps) return A.enabled() and {"animation"} or steps end,
  switchSteps=function(steps) return A.enabled() and {"animation"} or steps end}
package.loaded["src.core.game3.battle.mon_anim_battle"]=B
package.loaded["src.core.game3.battle.anim"]={present=function() return p end}
package.loaded["src.core.game3.battle.state"]={battler=function(st) return st.enemy end,sideOf=function() return "enemy" end}
local P={frontPic=function() return "original" end,monPicSpecies=function(mon) return mon.species end,isShiny=function(mon) return mon.isShiny end}
package.loaded["src.core.game3.pokemon"]=P
package.loaded["src.core.game3.runtime"]={getSession=function() return nil end}
local cries=0
package.loaded["src.core.game3.audio"]={playCry=function() cries=cries+1 end}
local tasks={}
package.loaded["src.core.game3.task"]={spawn=function(fn) tasks[#tasks+1]=fn;return #tasks end}
local rawRead=love.filesystem.read
love.filesystem.read=function(path) return files[path] or rawRead(path) end
local mod={path="mod",read=function(self,path) return files["mod/"..path] end,hooks={wrap=function(self,name,fn) hooks[name]=fn end}}
require("Gen3PokemonFramesRuntime").install(mod,S.project.gen3Assets)
assert(B.introSteps({})[1]=="animation" and not A.enabled(),"FireRed step planning must not enable native Emerald animations")
local st={enemy={species=25,mon={species=25,isShiny=false}}}
assert(B.start("enemy","front",{st=st,noCry=true}))
assert(B.busy({"enemy"}))
for i=1,9 do assert(not tasks[1]()) end
assert(p.monFrame==1,"Second frame was not displayed")
local pic=assert(A.framePic(25,1,false))
local canvas=love.graphics.newCanvas(64,64)
love.graphics.setCanvas(canvas);love.graphics.clear();love.graphics.setColor(1,1,1,1);love.graphics.draw(pic.image);love.graphics.setCanvas()
local r,g=canvas:newImageData():getPixel(0,0)
assert(r==0 and g==1,"Runtime frame pixels changed")
for i=10,17 do tasks[1]() end
assert(not B.busy({"enemy"}) and p.monFrame==0)
assert(type(P.frontPic(25,0,false))=="table","First frame must replace the front sprite")
assert(type(P.frontPic(25,0,true))=="table","Normal sheet should fall back for shiny when no shiny sheet is imported")
assert(not B.start("enemy","back",{st=st}),"FireRed must keep native back behavior")
enabled=true;assert(B.start("enemy","front",{st=st})=="native","Emerald lost its native movement/timing");enabled=false
B.start("enemy","front",{st=st,noCry=true});B.reset();assert(not B.busy({"enemy"}))
local other={enemy={species=26,mon={species=26}}}
B.start("enemy","front",{st=other});assert(cries==1,"Unedited FireRed wild Pokemon lost their cry")
local wrapped=P.frontPic
require("Gen3PokemonFramesRuntime").install(mod,S.project.gen3Assets)
assert(P.frontPic==wrapped,"Reload installed duplicate playback wrappers")
hooks={};assert(P.frontPic(25,0,false)=="original" and not A.framePic(25,1,false),"Disabled mod retained custom frames")
love.filesystem.read=rawRead
print("PASS: entrance frame import/export, validation, preview, playback, revert, disable")
