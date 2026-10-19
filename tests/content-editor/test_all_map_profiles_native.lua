return function(data,root,output,game)
  local L,IO,W,P=require('LayeredMap'),require('ModIO'),require('ModWriter'),require('NativeMapProfiles3D')
  local folder=output..'/all-profiles-'..game;IO.ensureDirectory(folder)
  local S={data=data,version=game,project=require('State').blankProject('all_profiles_'..game)}
  S.project.game=game;S.path=folder..'/mod';IO.ensureDirectory(S.path)
  require('Gen3ContentAdapter').prepare(S);require('Gen3Workspace').prepare(S)
  local ids={};for id in pairs(data.maps) do ids[#ids+1]=id end;table.sort(ids)
  local context,counts,rows,errors={}, {}, {'map\tcategory\tobjects\tfallback_cells'},{}
  for n,id in ipairs(ids) do
    local ok,err=pcall(function()
      local source=assert(L.convertMap(S,id))
      local def=S.project.maps[id]
      local function gameplay() return love.data.hash('sha256',W.encodeLua({source.layers,source.collision,source.gen3Collision,
        source.gen3Elevation,source.gen3Behavior,def.warps,def.objects,def.signs,def.coordEvents})) end
      local before=gameplay();P.build(S,id,context)
      assert(before==gameplay(),'Native art/collision/scripts/warps changed')
      local profile=assert(source.visualNativeProfile)
      assert(source.visualPlayable and profile.version==P.VERSION,'Map lacks playable profile')
      counts[profile.category]=(counts[profile.category] or 0)+1
      rows[#rows+1]=table.concat({id,profile.category,#(source.visualObjects or {}),profile.fallbackCells},'\t')
    end)
    if not ok then errors[#errors+1]=id..': '..tostring(err) end
    if n%50==0 then print('PROFILE AUDIT '..game..' '..n..'/'..#ids);collectgarbage('collect') end
  end
  P.connect(S)
  IO.writeText(folder..'/coverage.tsv',table.concat(rows,'\n'))
  IO.writeText(folder..'/errors.txt',table.concat(errors,'\n'))
  assert(#errors==0,table.concat(errors,'\n'))
  -- Real native atlas previews cover each environment and multiple tilesets.
  local samples=game=='emerald' and {'EM_LITTLEROOT_TOWN','EM_ROUTE101','EM_OLDALE_TOWN_POKEMON_CENTER_1F',
    'EM_LITTLEROOT_TOWN_PROFESSOR_BIRCHS_LAB','EM_GRANITE_CAVE_1F','EM_UNDERWATER_ROUTE124'}
    or {'FR_PALLET_TOWN','FR_ROUTE1','FR_VIRIDIAN_CITY_POKEMON_CENTER_1F','FR_MT_MOON_1F'}
  for _,id in ipairs(samples) do if S.project.layeredMaps[id] then
    local g,K=love.graphics,require('Kit');local canvas=g.newCanvas(1000,700)
    g.setCanvas({canvas,stencil=true});g.clear(.04,.06,.12,1)
    K.layout(1000,700);K.beginFrame(0,0,false,0)
    require('MapPreview3D').draw(S,S.project.layeredMaps[id],0,0,1000,700);K.endFrame();g.setCanvas()
    local pixels=canvas:newImageData();IO.writeText(folder..'/'..id:lower()..'.png',pixels:encode('png'):getString())
    pixels:release();canvas:release()
  end end
  assert(L.compileProject(S));assert(IO.save(S.path,S.project))
  local manifest='{"id":"all_profiles_'..game..'","name":"Native 3D map profiles","version":"1.0.0","entry":"main.lua","games":["'..game..'"]}'
  IO.writeText(S.path..'/manifest.json',manifest)
  local fresh={};require('Gen3').load(fresh,data._gen3Read)
  local loader=assert(require('Gen3Mod').load(fresh,S.path))
  assert(#(loader:status().errors or {})==0,'All-map exported mod did not load')
  local summary={game=game,maps=#ids,categories=counts,errors=#errors}
  IO.writeText(folder..'/result.lua','return '..W.encodeLua(summary))
  print('PASS: '..game..' '..#ids..' native maps profiled, gameplay data preserved, all-map mod exported and loaded')
end
