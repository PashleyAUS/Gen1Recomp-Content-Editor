local M = {}
function M.preview(S, rec, x, y, w)
  local K = require("Kit")
  local s = K.scale
  local key = require("ModWriter").encodeLua(rec)
  if K.button(x,y,180*s,28*s,"Validate / preview sheet",{}) then
    local ok, result = pcall(function()
      local images = {}
      local function load(path)
        if not images[path] then
          local bytes = assert(require("ModIO").readText(S.path .. "/" .. path))
          local image = love.graphics.newImage(love.filesystem.newFileData(bytes,"font.png"))
          image:setFilter("nearest","nearest");images[path]=image
        end
        return images[path]
      end
      require("Gen3FontsRuntime").build({page=rec},load,love.graphics.newQuad)
      return {image=load(rec.image),shadow=rec.shadowImage and load(rec.shadowImage)}
    end)
    S._gen3FontPreview = {key=key,project=S.project,image=ok and result.image or nil,
      sourceImage=rec.image,sourceShadow=rec.shadowImage,
      shadow=ok and result.shadow or nil,error=not ok and tostring(result) or nil}
    S.status = ok and "Font sheet and character mappings are valid" or tostring(result)
  end
  y = y + 36*s
  local p = S._gen3FontPreview
  if p and p.sourceImage==rec.image and p.sourceShadow==rec.shadowImage and p.project==S.project and p.image then
    local iw,ih = p.image:getDimensions()
    local scale = math.min(3*s,w/iw,160*s/ih)
    love.graphics.setColor(0.95,0.95,0.95,1)
    love.graphics.rectangle("fill",x,y,iw*scale,ih*scale)
    if p.shadow then
      love.graphics.setColor(0.65,0.65,0.65,1)
      love.graphics.draw(p.shadow,x,y,0,scale,scale)
    end
    love.graphics.setColor(0.2,0.2,0.2,1)
    love.graphics.draw(p.image,x,y,0,scale,scale)
    love.graphics.setColor(1,1,1,1)
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
