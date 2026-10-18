-- Navigation derived from the same centre and yaw as MapGeometry3D.
-- Coordinates use cell edges; actor feet are at (cellX+.5,cellY+.5).
local M={}
local RADIUS=.16

function M.localPoint(o,x,y)
  local a=math.rad(o.rotation or 0)
  local cx,cy=o.x+o.width/2,o.y+o.height/2
  local dx,dy=x-cx,y-cy
  return cx+dx*math.cos(a)+dy*math.sin(a),cy-dx*math.sin(a)+dy*math.cos(a)
end

function M.worldPoint(o,x,y)
  local a=math.rad(o.rotation or 0)
  local cx,cy=o.x+o.width/2,o.y+o.height/2
  local dx,dy=x-cx,y-cy
  return cx+dx*math.cos(a)-dy*math.sin(a),cy+dx*math.sin(a)+dy*math.cos(a)
end

function M.contains(o,x,y,radius)
  x,y=M.localPoint(o,x,y)
  radius=radius or 0
  return x>o.x-radius and x<o.x+o.width+radius
    and y>o.y-radius and y<o.y+o.height+radius
end

function M.crosses(o,fx,fy,tx,ty)
  fx,fy=M.localPoint(o,fx,fy);tx,ty=M.localPoint(o,tx,ty)
  local first,last=0,1
  for _,axis in ipairs({{fx,tx-fx,o.x-RADIUS,o.x+o.width+RADIUS},
      {fy,ty-fy,o.y-RADIUS,o.y+o.height+RADIUS}}) do
    if math.abs(axis[2])<1e-9 then
      if axis[1]<=axis[3] or axis[1]>=axis[4] then return false end
    else
      local a,b=(axis[3]-axis[1])/axis[2],(axis[4]-axis[1])/axis[2]
      if a>b then a,b=b,a end
      first,last=math.max(first,a),math.min(last,b)
      if first>=last then return false end
    end
  end
  return first<last
end

function M.blocked(nav,fx,fy,tx,ty)
  for _,o in ipairs(nav.models) do
    if M.crosses(o,fx+.5,fy+.5,tx+.5,ty+.5) then return true end
  end
  return false
end

function M.prepare(source,warps,models)
  local nav={models={},cells={},behaviors={},entries={},byWarp={},errors={}}
  local old={}
  for _,o in ipairs(models or {}) do
    if o.kind=='building' and (o.rotation or 0)%360~=0 then
      nav.models[#nav.models+1]=o
      for y=o.y,o.y+o.height-1 do for x=o.x,o.x+o.width-1 do old[y*source.cellWidth+x+1]=true end end
    end
  end
  local function insideAny(x,y,radius)
    for _,o in ipairs(nav.models) do if M.contains(o,x,y,radius) then return true end end
    return false
  end
  if #nav.models==0 then return nav end
  for y=0,source.cellHeight-1 do for x=0,source.cellWidth-1 do
    local i=y*source.cellWidth+x+1
    if insideAny(x+.5,y+.5,RADIUS) then nav.cells[i]=0xff
    elseif old[i] then nav.cells[i]=0 end
    if nav.cells[i]~=nil then nav.behaviors[y*1024+x]=0 end
  end end
  local reserved={}
  for i,w in ipairs(warps or {}) do if w.x and w.y then reserved[w.y*1024+w.x]=i end end
  for index,w in ipairs(warps or {}) do
    if not w.disabled then
      for _,o in ipairs(nav.models) do
        if w.x and w.y and w.x>=o.x and w.x<o.x+o.width and w.y>=o.y and w.y<o.y+o.height then
          local doorX,doorY=M.worldPoint(o,w.x+.5,o.y+o.height)
          local a=math.rad(o.rotation or 0)
          local nx,ny=-math.sin(a),math.cos(a)
          local best,score
          for y=math.max(0,math.floor(doorY)-3),math.min(source.cellHeight-1,math.floor(doorY)+3) do
            for x=math.max(0,math.floor(doorX)-3),math.min(source.cellWidth-1,math.floor(doorX)+3) do
              local lx,ly=M.localPoint(o,x+.5,y+.5)
              local i=y*source.cellWidth+x+1;local mode=(source.collision or {})[i]
              local floor=old[i] or mode=='walk' or mode=='grass'
              local key=y*1024+x
              local side=math.abs(lx-(w.x+.5))
              local gap=ly-(o.y+o.height)
              local outward,outScore
              for _,d in ipairs({{'down',0,1},{'up',0,-1},{'right',1,0},{'left',-1,0}}) do
                local ax,ay=x+d[2],y+d[3]
                local ai=ay*source.cellWidth+ax+1
                local amode=(source.collision or {})[ai]
                local dot=d[2]*nx+d[3]*ny
                local akey=ay*1024+ax
                if dot>.1 and ax>=0 and ay>=0 and ax<source.cellWidth and ay<source.cellHeight
                    and (old[ai] or amode=='walk' or amode=='grass')
                    and not insideAny(ax+.5,ay+.5,RADIUS)
                    and not reserved[akey] and not nav.entries[akey]
                    and (not outScore or dot>outScore+1e-8) then outward,outScore=d[1],dot end
              end
              -- Leave room for the upright player sprite in front of the facade.
              if floor and outward and side<=.85 and gap>=.5 and gap<=1.5
                  and not insideAny(x+.5,y+.5,RADIUS)
                  and (not reserved[key] or reserved[key]==index) and not nav.entries[key] then
                local distance=(x+.5-doorX)^2+(y+.5-doorY)^2
                if not score or distance<score then best,score={x=x,y=y,outward=outward},distance end
              end
            end
          end
          if best then
            best.index,best.oldX,best.oldY=index,w.x,w.y
            best.doorX,best.doorY,best.nx,best.ny=doorX,doorY,nx,ny
            nav.entries[best.y*1024+best.x]=best;nav.byWarp[index]=best
            nav.cells[best.y*source.cellWidth+best.x+1]=0
            nav.behaviors[best.y*1024+best.x]=0
          else
            nav.errors[#nav.errors+1]='Warp '..index..' has no safe entrance outside its rotated building'
          end
          break
        end
      end
    end
  end
  return nav
end

function M.draw2D(source,warps,models)
  local nav=M.prepare(source,warps,models)
  local g=love.graphics
  for _,o in ipairs(nav.models) do
    local p={}
    for _,v in ipairs({{o.x,o.y},{o.x+o.width,o.y},{o.x+o.width,o.y+o.height},{o.x,o.y+o.height}}) do
      local x,y=M.worldPoint(o,v[1],v[2]);p[#p+1]=x*16;p[#p+1]=y*16
    end
    g.setColor(1,.65,.1,.9);g.polygon('line',p)
  end
  for _,e in pairs(nav.entries) do
    g.setColor(.2,1,1,1);g.rectangle('line',e.x*16+1,e.y*16+1,14,14)
    g.line((e.x+.5)*16,(e.y+.5)*16,e.doorX*16,e.doorY*16)
  end
end

return M
