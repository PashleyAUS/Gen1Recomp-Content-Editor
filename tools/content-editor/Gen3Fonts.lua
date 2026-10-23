local M = {}
function M.preview(S, rec, x, y, w)
  local K = require("Kit")
  local s = K.scale
  local key = require("ModWriter").encodeLua(rec)
  if K.button(x,y,180*s,28*s,"Validate / preview sheet",{}) then
    local ok, result = pcall(function()
      local bytes = assert(require("ModIO").readText(S.path .. "/" .. rec.image))
      local image = love.graphics.newImage(love.filesystem.newFileData(bytes,"font.png"))
      image:setFilter("nearest","nearest")
      require("Gen3FontsRuntime").build({page=rec},function() return image end,love.graphics.newQuad)
      return image
    end)
    S._gen3FontPreview = {key=key,project=S.project,image=ok and result or nil,error=not ok and tostring(result) or nil}
    S.status = ok and "Font sheet and character mappings are valid" or tostring(result)
  end
  y = y + 36*s
  local p = S._gen3FontPreview
  if p and p.key==key and p.project==S.project and p.image then
    local iw,ih = p.image:getDimensions()
    local scale = math.min(3*s,w/iw,160*s/ih)
    love.graphics.setColor(0.18,0.18,0.2,1)
    love.graphics.rectangle("fill",x,y,iw*scale,ih*scale)
    love.graphics.setColor(1,1,1,1)
    love.graphics.draw(p.image,x,y,0,scale,scale)
    y = y + ih*scale + 12*s
  end
  return y
end
function M.emit(project, encode, out)
  local pages = project.gen3Fonts
  if not pages or not next(pages) then return end
  require("Gen3FontsRuntime").validate(pages)
  out[#out+1] = "local languageFonts=(function()\n"
    .. assert(love.filesystem.read("tools/content-editor/Gen3FontsRuntime.lua"))
    .. "\nend)()\nlanguageFonts.install(mod," .. encode(pages) .. ")"
end
return M
