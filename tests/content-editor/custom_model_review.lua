-- Import through the editor API, then exercise the same placement as a drag.
return function(S,source,root)
  local W=require('ModWriter');local before=W.encodeLua({source.layers,source.collision})
  local dirty=0
  local app={markDirty=function() dirty=dirty+1 end}
  for i,ext in ipairs({'obj','gltf','glb'}) do
    assert(require('MapBuilder').importModel(S,root..'/tests/content-editor/fixtures/models3d/pyramid.'..ext,app,source),S.status)
    assert(S.tab=='maps3d' and S.builderObjectKind=='model' and S.builderModelIndex==i)
    local x=2+i*2
    local y=math.min(source.cellHeight-3,6)
    assert(require('MapObjects3D').place(source,{x0=x,y0=y,x1=x,y1=y},'model',1.3,(i-1)*45,0,0,source.visualModelLibrary[i]))
  end
  assert(dirty==3 and #source.visualModelLibrary==3)
  assert(before==W.encodeLua({source.layers,source.collision}),'Custom models changed native passage or artwork')
end
