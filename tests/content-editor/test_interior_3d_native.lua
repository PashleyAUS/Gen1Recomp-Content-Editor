return function(data,root,output,game)
  local L,IO,W=require('LayeredMap'),require('ModIO'),require('ModWriter')
  local S={data=data,version=game,project=require('State').blankProject('interior_review')}
  S.project.game=game
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local id=os.getenv('POKEPORT_INTERIOR_MAP') or 'EM_ABANDONED_SHIP_CAPTAINS_OFFICE'
  local catalog={}
  for key in pairs(data.maps) do if key:find('CAVE') or key:find('MOON') or key:find('UNDERWATER') or key:find('POKEMON_CENTER') then catalog[#catalog+1]=key end end
  table.sort(catalog);IO.writeText(output..'/interior-catalog.txt',table.concat(catalog,'\n'))
  local source=assert(L.convertMap(S,id))
  local folder=output..'/'..(id=='EM_ABANDONED_SHIP_CAPTAINS_OFFICE' and 'captains-office' or id:lower());IO.ensureDirectory(folder)
  local lines={}
  for y=0,source.cellHeight-1 do for x=0,source.cellWidth-1 do
    local i=y*source.cellWidth+x+1
    lines[#lines+1]=table.concat({x,y,source.layers[1].cells[i].tile,source.collision[i],source.gen3Behavior[i]},'\t')
  end end
  IO.writeText(folder..'/tiles.tsv',table.concat(lines,'\n'))
  IO.writeText(folder..'/map.lua','return '..W.encodeLua(S.project.maps[id]))
  IO.writeText(folder..'/source.lua','return '..W.encodeLua(source))
  local function render(label)
    local g,K=love.graphics,require('Kit')
    local canvas=g.newCanvas(1000,700)
    g.setCanvas({canvas,stencil=true});g.clear(.04,.06,.12,1)
    K.layout(1000,700);K.beginFrame(0,0,false,0)
    require('MapPreview3D').draw(S,source,0,0,1000,700)
    K.endFrame();g.setCanvas()
    local f=assert(io.open(folder..'/'..label..'.png','wb'))
    f:write(canvas:newImageData():encode('png'):getString());f:close()
    if label=='before' then
      local a=assert(io.open(folder..'/atlas.png','wb'))
      a:write(S._terrain3D.atlas:newImageData():encode('png'):getString());a:close()
    end
  end
  render('before')
  local unchanged=W.encodeLua({source.layers,source.collision,source.gen3Behavior,source.gen3Collision,source.gen3Elevation})
  require('Interior3D').apply(source,S.project.maps[id])
  assert(unchanged==W.encodeLua({source.layers,source.collision,source.gen3Behavior,source.gen3Collision,source.gen3Elevation}),
    'Interior changed native art, collision or behavior')
  if os.getenv('POKEPORT_CUSTOM_MODEL_REVIEW')=='1' then dofile(root..'/tests/content-editor/custom_model_review.lua')(S,source,root) end
  render('after')
  if os.getenv('POKEPORT_CUSTOM_MODEL_REVIEW')=='1' then assert(#S._terrain3D.modelMeshes==3,'Custom textured meshes did not reach the editor preview') end
end
