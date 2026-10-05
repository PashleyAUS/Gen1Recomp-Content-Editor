local M={}
local IO=require("ModIO")
function M.path(index,shiny)
  assert(type(index)=="number" and index>=1 and index%1==0,"Invalid species index")
  return "data/generated/gba/pokemon/front_anim"..(shiny and "_shiny" or "").."/"..index..".rgba"
end
function M.read(S,index,shiny)
  local path=M.path(index,shiny)
  local asset=(S.project.gen3Assets or {})[path]
  if asset then return IO.readText(S.path.."/"..asset.file) end
  return S.data._gen3Read and S.data._gen3Read(path)
end
function M.import(S,index,picked,shiny)
  if not S.path then return nil,"Save the project before importing frames" end
  local ok,img=pcall(function()
    local bytes=assert(IO.readText(picked))
    assert(#bytes<=8*1024*1024,"Image exceeds 8 MiB")
    return love.image.newImageData(love.filesystem.newFileData(bytes,"frames.png"))
  end)
  if not ok or img:getWidth()~=64 or img:getHeight()%64~=0 or img:getHeight()<64 or img:getHeight()>64*32 then
    return nil,"Use a 64-pixel-wide PNG with 1–32 full 64 × 64 frames stacked vertically"
  end
  local rel="assets/gen3/pokemon/front_anim"..(shiny and "_shiny" or "").."/"..index..".rgba"
  local made,err=IO.ensureDirectory((S.path.."/"..rel):match("^(.*)/"))
  if made==false then return nil,err end
  local saved,writeErr=IO.writeText(S.path.."/"..rel,img:getString())
  if not saved then return nil,writeErr end
  S.project.gen3Assets=S.project.gen3Assets or {}
  S.project.gen3Assets[M.path(index,shiny)]={file=rel,width=64,height=img:getHeight()}
  S._g3FramePreview=nil
  return true
end
function M.export(S,index,shiny)
  if not S.path then return nil,"Save the project before exporting frames" end
  local bytes=M.read(S,index,shiny)
  -- FireRed has no native moving frames: export its front picture as a starting sheet.
  if not bytes and S.data._gen3Read then
    bytes=S.data._gen3Read("data/generated/gba/pokemon/front"..(shiny and "_shiny" or "").."/"..index..".rgba")
  end
  if not bytes or #bytes==0 or #bytes%(64*64*4)~=0 then return nil,"Animation frames are missing" end
  local img=love.image.newImageData(64,#bytes/256,"rgba8",bytes)
  local dest=S.path.."/assets/gen3-export/pokemon/front_anim"..(shiny and "_shiny" or "").."/"..index..".png"
  IO.ensureDirectory(dest:match("^(.*)/"))
  local ok,err=IO.writeText(dest,img:encode("png"):getString())
  return ok and dest or nil,err
end
function M.revert(S,index,shiny)
  if S.project.gen3Assets then S.project.gen3Assets[M.path(index,shiny)]=nil end
  S._g3FramePreview=nil
end
function M.draw(S,index,App,x,y,w,s,shiny)
  local K=require("Kit")
  K.caption(x,y,(shiny and "Shiny" or "Normal").." entrance frames — 64 × 64, stacked vertically")
  local bytes=M.read(S,index,shiny)
  local count=bytes and #bytes/(64*64*4) or 0
  if count>=1 and count%1==0 then
    local c=S._g3FramePreview
    if not c or c.bytes~=bytes then
      c={bytes=bytes,image=love.graphics.newImage(love.image.newImageData(64,count*64,"rgba8",bytes))}
      c.image:setFilter("nearest","nearest");S._g3FramePreview=c
    end
    local frame=math.floor(love.timer.getTime()*8)%count
    local quad=love.graphics.newQuad(0,frame*64,64,64,64,count*64)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(c.image,quad,x,y+28*s,0,2*s,2*s)
    K.caption(x+140*s,y+65*s,"Frame "..(frame+1).." / "..count.." · preview 8 fps")
  else K.caption(x,y+65*s,"No native frames. Export a front sprite to create a sheet.") end
  local by=y+168*s;local bw=(w-16*s)/3
  if K.button(x,by,bw,28*s,"Import frames",{}) then
    App.pickFile("Import entrance frames (64 wide, stacked 64 × 64 frames)","PNG (*.png)|*.png",function(picked)
      if not picked then return end
      local ok,err=M.import(S,index,picked,shiny)
      if ok then App.markDirty();S.status="Imported entrance frames; Save to apply in game" else S.status=tostring(err) end
    end)
  end
  if K.button(x+bw+8*s,by,bw,28*s,"Export frames",{}) then
    local dest,err=M.export(S,index,shiny);S.status=dest and ("Exported "..dest) or tostring(err)
  end
  if K.button(x+2*(bw+8*s),by,bw,28*s,"Revert frames",{enabled=(S.project.gen3Assets or {})[M.path(index,shiny)]~=nil}) then
    M.revert(S,index,shiny);App.markDirty();S.status="Restored original entrance frames"
  end
  return by+40*s
end
return M
