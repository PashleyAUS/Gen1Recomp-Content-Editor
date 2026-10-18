local M={}
function M.emit(project,out)
  if not ({emerald=true,firered=true,leafgreen=true})[project.game] or not next(project.gen3Layered or {}) then return end
  local function module(name,replace)
    local text=assert(love.filesystem.read('tools/content-editor/'..name..'.lua'))
    if replace then text=replace(text) end
    return '(function()\n'..text..'\nend)()'
  end
  out[#out+1]='do local sceneMaps={} for id,source in pairs(layered.maps) do if source.visualPlayable~=false then sceneMaps[id]=source end end'
  out[#out+1]='local sceneObjects='..module('MapObjects3D')
  out[#out+1]='local sceneTerrain='..module('MapPreview3D')
  out[#out+1]='local sceneGeometry='..module('MapGeometry3D',function(text)
    return (text:gsub("local Objects=require%('MapObjects3D'%)",'local Objects=sceneObjects',1))
  end)
  out[#out+1]='local sceneRenderer='..module('MapScene3D')
  out[#out+1]='local sceneWorld='..module('MapWorld3D')
  out[#out+1]='local sceneRuntime='..module('Gen3SceneRuntime')
  out[#out+1]='local sceneNavigation='..module('MapNavigation3D')
  out[#out+1]='local buildingRuntime='..module('Gen3BuildingRuntime')
  out[#out+1]='mod.events:on("game.ready",function(ctx) sceneRuntime.install(mod,sceneMaps,sceneTerrain,sceneGeometry,sceneRenderer,sceneObjects,sceneWorld); buildingRuntime.install(mod,sceneMaps,sceneObjects,sceneNavigation,ctx.game) end,-200) end'
end
return M
