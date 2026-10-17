local M={}
local games={slots="Slot Machine",crush="Berry Crush",jump="Pokemon Jump",dodrio="Dodrio Berry Picking"}
function M.draw(S,x,y,w,h,App)
 local K=require("Kit");local P=require("ChoicePicker");local s=K.scale
 if require("Generation").isRse(S) then y=require("RouletteRules").draw(S,x,y,w,App) y=require("BlenderRules").draw(S,x,y,w,App) y=require("BlenderOpponents").draw(S,x,y,w,App) end
 local id=games[S.g3Minigame] and S.g3Minigame or "slots"
 P.field(S,{x=x,y=y,w=w,h=28*s,ids={"slots","crush","jump","dodrio"},labels=games,current=id,title="CHOOSE MINI-GAME",onPick=function(v) S.g3Minigame=v;S.g3MinigameImage="1" end})
 if id=="slots" then y=require("SlotPayouts").draw(S,x,y+36*s,w,App) y=require("SlotBets").draw(S,x,y,w,App) if require("Generation").isRse(S) then y=require("RseSlotLuck").draw(S,x,y,w,App) else y=require("FrlgSlotBias").draw(S,x,y,w,App) end end
 if id=="crush" then y=require("BerryCrushRules").draw(S,x,y+36*s,w,App) end
 if id=="dodrio" then y=require("DodrioRules").draw(S,x,y+36*s,w,App) end
 if id=="jump" then y=require("JumpRules").draw(S,x,y+36*s,w,App) end
 local top=require("RegList").modeChips(S,"g3MinigameView",{{id="playback",label="Animation preview"},{id="images",label="Image library"}},x,y+38*s,s)
 h=h-(top-y);y=top
 if S.g3MinigameView=="playback" then require("Gen3MinigamePreview").draw(S,id,x,y,w,h);return end
 require("Gen3MinigamePreview").stop(S)
 local Images=require("Gen3MinigameImages");local ids,labels={},{}
 for i,rec in ipairs(Images.list(S,id) or {}) do ids[i]=tostring(i);labels[tostring(i)]=rec.name end
 local selected=tostring(S.g3MinigameImage or "1");if not labels[selected] then selected="1" end
 P.field(S,{x=x,y=y,w=w,h=28*s,ids=ids,labels=labels,current=selected,title="CHOOSE IMAGE",onPick=function(v) S.g3MinigameImage=v end})
 local index=tonumber(selected)
 local path,pathErr,entry=Images.cachePath(S,id,index)
 local data,err=Images.image(S,id,index)
 if not data then K.caption(x,y+80*s,err or pathErr or "Unable to read mini-game image");return end
 local rec=Images.list(S,id)[index]
 local override=path and (S.project.gen3Assets or {})[path]
 if S._miniGameImageData~=data then S._miniGameImageData=data;S._miniGameTexture=love.graphics.newImage(data);S._miniGameTexture:setFilter("nearest","nearest") end
 local image=S._miniGameTexture
 local scale=math.min((w-24*s)/data:getWidth(),math.max(1,h-180*s)/data:getHeight(),4*s)
 love.graphics.setColor(1,1,1,1);love.graphics.draw(image,x+12*s,y+80*s,0,scale,scale)
 local pw=(entry and entry.width) or data:getWidth()
 local ph=(entry and entry.height) or data:getHeight()
 K.caption(x,y+h-72*s,rec.name.." ("..pw.." x "..ph..")"..(override and " — mod replacement" or " — original"))
 if K.button(x,y+h-36*s,240*s,28*s,"Import "..pw.." x "..ph.." PNG",{}) then
  App.pickFile("Replace "..rec.name.." ("..pw.." x "..ph..")","PNG|*.png",function(picked)
   local IO=require("ModIO")
   if not path or not S.path then S.status="Open a mod before replacing this image";return end
   local bytes=IO.readText(picked)
   local ok,img=pcall(function() return love.image.newImageData(love.filesystem.newFileData(bytes,"replacement.png")) end)
   if not ok or img:getWidth()~=pw or img:getHeight()~=ph then S.status="Replacement must be "..pw.." x "..ph;return end
   local rel="assets/gen3/"..path:gsub("^data/generated/gba/","")
   local output=path:match("%.rgba$") and img:getString() or bytes
   IO.ensureDirectory((S.path.."/"..rel):match("^(.*)/"))
   local saved,writeErr=IO.writeText(S.path.."/"..rel,output)
   if not saved then S.status=tostring(writeErr);return end
   S.project.gen3Assets=S.project.gen3Assets or {}
   S.project.gen3Assets[path]={file=rel,width=pw,height=ph}
   S._miniGameImageData=nil
   App.markDirty();S.status="Imported "..rec.name.."; Save to apply"
  end)
 end
 if override and K.button(x+250*s,y+h-36*s,140*s,28*s,"Revert image",{}) then
  S.project.gen3Assets[path]=nil
  S._miniGameImageData=nil
  App.markDirty();S.status="Reverted "..rec.name
 end
end
return M
