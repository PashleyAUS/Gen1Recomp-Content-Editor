-- Rotated model navigation, installed through removable mod-owned hooks.
local M={}
function M.install(mod,maps,models,navigation,game)
  local Runtime=require('src.mods.Runtime')
  local C=require('src.core.game3.collision')
  local Map=require('src.core.game3.map')
  local P=require('src.core.game3.player')
  local Warp=require('src.core.game3.warp')
  local byId,byDef={},{}
  local directions={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  for id,source in pairs(maps) do
    local def=game and game.data and game.data.maps and game.data.maps[id]
    if def then
      local nav=navigation.prepare(source,def.warps,models.objects(source))
      if #nav.errors>0 then error(id..': '..table.concat(nav.errors,'; ')) end
      if #nav.models>0 then
        nav.source=source;byId[id]=nav;byDef[def]=nav
        -- Keep indices stable: an interior's destWarp still names the same door.
        local warps={}
        for i,w in ipairs(def.warps or {}) do
          local row={};for k,v in pairs(w) do row[k]=v end
          local e=nav.byWarp[i]
          if e then row.x,row.y=e.x,e.y end
          warps[i]=row
        end
        def.warps=warps
      end
    end
  end
  local function dispatch(target,method,name)
    local key='_editorBuilding_'..method
    if target[key] then return end
    target[key]=true
    local original=target[method]
    target[method]=function(...) return Runtime.call(name,original,...) end
  end
  dispatch(C,'behaviorOn','editor.gen3.building.behavior')
  mod.hooks:wrap('editor.gen3.building.behavior',function(proceed,def,x,y)
    local nav=byDef[def]
    local override=nav and x and y and nav.behaviors[y*1024+x]
    if override~=nil then return override end
    return proceed(def,x,y)
  end)
  dispatch(C,'elevationOn','editor.gen3.building.elevation')
  mod.hooks:wrap('editor.gen3.building.elevation',function(proceed,def,x,y)
    local nav=byDef[def]
    if nav and x and y and x>=0 and y>=0 and x<nav.source.cellWidth
        and y<nav.source.cellHeight and nav.cells[y*nav.source.cellWidth+x+1]==0 then return 3 end
    return proceed(def,x,y)
  end)
  dispatch(C,'installWarps','editor.gen3.building.warps')
  mod.hooks:wrap('editor.gen3.building.warps',function(proceed,def)
    proceed(def)
    local nav=byDef[def]
    if nav then
      for _,e in pairs(nav.entries) do C._warps[e.oldY*1024+e.oldX]=nil end
      for key,e in pairs(nav.entries) do C._warps[key]=def.warps[e.index] end
    end
  end)
  dispatch(C,'bindMap','editor.gen3.building.bind')
  mod.hooks:wrap('editor.gen3.building.bind',function(proceed,g,id,def)
    local result=proceed(g,id,def)
    local nav=byDef[def]
    if nav and C._grid then for i,coll in pairs(nav.cells) do C._grid[i]=coll end end
    return result
  end)
  dispatch(C,'canEnter','editor.gen3.building.enter')
  mod.hooks:wrap('editor.gen3.building.enter',function(proceed,g,x,y,opts)
    local nav=byId[C._mapId];opts=opts or {}
    local fx,fy=opts.fromX or P.cellX,opts.fromY or P.cellY
    if nav and fx and fy and navigation.blocked(nav,fx,fy,x,y) then return false,'3d_building' end
    return proceed(g,x,y,opts)
  end)
  dispatch(C,'tryWarpAt','editor.gen3.building.warp')
  mod.hooks:wrap('editor.gen3.building.warp',function(proceed,g,x,y,facing,opts)
    local nav=byId[C._mapId];local e=nav and nav.entries[y*1024+x]
    if not e then return proceed(g,x,y,facing,opts) end
    local d=directions[facing or P.facing]
    if not d or d[1]*e.nx+d[2]*e.ny>=-.1 or Warp.isBusy() then return false end
    local Space=require('src.core.game3.scripting.space')
    if Space.vm and Space.vm.isRunning and Space.vm:isRunning() then return false end
    local warp=C.warpAt(x,y)
    if not warp then return false end
    local dest,dx,dy=C.resolveWarpDestination(g,warp)
    if not dest then return false end
    local Core=require('src.core.game3.runtime')
    return Warp.request(Core._mod or mod,g,dest,dx,dy,
      C.destArrivalFacing(g,dest,dx,dy,facing),{fade=true,se=false,doorX=x,doorY=y})
  end)
  dispatch(P,'tryMove','editor.gen3.building.move')
  mod.hooks:wrap('editor.gen3.building.move',function(proceed,dir,g,...)
    local nav=byId[C._mapId];local e=nav and nav.entries[P.cellY*1024+P.cellX]
    local d=directions[dir]
    if e and d and not P.moving and d[1]*e.nx+d[2]*e.ny<-.1 then
      if C.tryWarpAt(g,P.cellX,P.cellY,dir) then return true end
    end
    return proceed(dir,g,...)
  end)
  dispatch(Map,'load','editor.gen3.building.load')
  mod.hooks:wrap('editor.gen3.building.load',function(proceed,owner,g,id,opts)
    local nav=byId[id]
    if nav and opts and opts.x and opts.y then
      local entry=nav.entries[opts.y*1024+opts.x]
      if not entry then
        for _,e in pairs(nav.entries) do
          if opts.x==e.oldX and opts.y==e.oldY then entry=e;break end
        end
      end
      if entry then
        local copy={};for k,v in pairs(opts) do copy[k]=v end
        copy.x,copy.y,copy.facing=entry.x,entry.y,entry.outward
        opts=copy
      end
    end
    return proceed(owner,g,id,opts)
  end)
  -- Also support hot-loading a mod while already standing on its map.
  local def=Map.current and game and game.data and game.data.maps[Map.current]
  if def and byDef[def] then C.bindMap(game,Map.current,def) end
end
return M
