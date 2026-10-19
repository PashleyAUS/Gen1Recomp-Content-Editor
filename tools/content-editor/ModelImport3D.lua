-- Convert static OBJ/glTF scenes to portable, data-only map assets.
local M={MAX_BYTES=32*1024*1024,MAX_VERTICES=150000}
local Codec=require('ModelAssetCodec3D')
M.encode,M.decode=Codec.encode,Codec.decode
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<1e12 end
local function number(s) local n=tonumber(s);assert(finite(n),'Invalid model coordinate');return n end
local function read(path)
  local f=assert(io.open(path,'rb'),'Cannot read '..path)
  local n=f:seek('end');f:seek('set');if n>M.MAX_BYTES then f:close();error('Model dependency exceeds 32 MB') end
  local data=f:read('*a');f:close();return data
end
local function resolver(path,reader)
  local root=path:gsub('\\','/'):match('^(.*)/') or '.'
  local total=0
  return function(uri)
    local data
    if uri:match('^data:') then
      local encoded=assert(uri:match('^data:[^,]*;base64,(.*)$'),'Only base64 data URIs are supported')
      assert(#encoded<M.MAX_BYTES*1.4,'Embedded asset exceeds 32 MB');data=M.decode(encoded)
    else
      uri=uri:gsub('%%(%x%x)',function(h) return string.char(tonumber(h,16)) end):gsub('\\','/')
      assert(not uri:find('[%z%c]') and not uri:match('^/') and not uri:find(':',1,true),'Model dependencies must be local relative files')
      for part in uri:gmatch('[^/]+') do assert(part~='..','Keep model dependencies inside the model folder') end
      data=reader(root..'/'..uri)
    end
    total=total+#data;assert(total<=M.MAX_BYTES,'Combined model dependencies exceed 32 MB')
    return data
  end
end
local function texture(bytes)
  local png=bytes:sub(1,8)=='\137PNG\r\n\26\n'
  local jpg=bytes:byte(1)==255 and bytes:byte(2)==216
  assert(png or jpg,'Use PNG or JPEG model textures')
  return M.encode(bytes)
end
local function material() return {color={1,1,1,1}} end
local function append(model,vertices,mat)
  assert(#vertices%3==0,'Model primitive has incomplete triangles')
  model.vertexCount=model.vertexCount+#vertices
  assert(model.vertexCount<=M.MAX_VERTICES,'Model exceeds 50,000 triangles; simplify it before importing')
  model.parts[#model.parts+1]={vertices=vertices,material=mat or material()}
end
local function obj(data,load,model)
  local positions,uvs,materials,groups={},{},{},{}
  local current=''
  for line in data:gmatch('[^\r\n]+') do
    line=line:gsub('#.*$','')
    local op,args=line:match('^%s*(%S+)%s*(.-)%s*$')
    if op=='v' then
      local v={};for s in args:gmatch('%S+') do v[#v+1]=number(s) end
      assert(#v>=3,'OBJ vertex needs XYZ')
      if #v==4 then
        assert(v[4]~=0,'OBJ homogeneous position has zero weight')
        v={v[1]/v[4],v[2]/v[4],v[3]/v[4]}
      end
      positions[#positions+1]=v
    elseif op=='vt' then
      local u,v=args:match('^(%S+)%s+(%S+)');uvs[#uvs+1]={number(u),1-number(v)}
    elseif op=='mtllib' then
      local active
      -- Names containing spaces are accepted as a single library path.
      for mline in load(args):gmatch('[^\r\n]+') do
        local key,value=mline:match('^%s*(%S+)%s*(.-)%s*$')
        if key=='newmtl' then active=material();materials[value]=active
        elseif active and key=='Kd' then
          local r,g,b=value:match('^(%S+)%s+(%S+)%s+(%S+)');active.color={number(r),number(g),number(b),active.color[4]}
        elseif active and (key=='d' or key=='Tr') then active.color[4]=key=='Tr' and 1-number(value) or number(value)
        elseif active and key=='map_Kd' then
          assert(not value:match('^%-'),'OBJ texture map options are unsupported; export plain map_Kd paths')
          local folder=args:match('^(.*[/\\])') or ''
          active.image=texture(load(folder..value))
        end
      end
    elseif op=='usemtl' then current=args
    elseif op=='f' then
      local face={}
      for spec in args:gmatch('%S+') do
        local pi,ti=spec:match('^([%-0-9]+)/?([%-0-9]*)')
        pi=number(pi);assert(pi%1==0 and pi~=0,'Invalid OBJ index')
        if pi<0 then pi=#positions+pi+1 end
        local p=assert(positions[pi],'OBJ position index out of range')
        local uv={0,0}
        if ti~='' then ti=number(ti);if ti<0 then ti=#uvs+ti+1 end;uv=assert(uvs[ti],'OBJ UV index out of range') end
        face[#face+1]={p[1],p[2],p[3],uv[1],uv[2],p[4] or 1,p[5] or 1,p[6] or 1,1}
      end
      assert(#face>=3,'OBJ face needs at least three vertices')
      groups[current]=groups[current] or {}
      for i=2,#face-1 do for _,v in ipairs({face[1],face[i],face[i+1]}) do
        groups[current][#groups[current]+1]=v
        assert(#groups[current]<=M.MAX_VERTICES,'OBJ exceeds 50,000 triangles')
      end end
    end
  end
  for name,vertices in pairs(groups) do append(model,vertices,name~='' and assert(materials[name],'Missing OBJ material: '..name) or nil) end
end
local function uint(data,offset,bytes)
  assert(offset>=0 and offset+bytes<=#data,'Truncated glTF binary data')
  local n=0;for i=bytes,1,-1 do n=n*256+data:byte(offset+i) end;return n
end
local function float(data,offset)
  local n=uint(data,offset,4);local sign=n>=2147483648 and -1 or 1
  local e=math.floor(n/8388608)%256;local f=n%8388608
  assert(e~=255,'Non-finite glTF coordinate')
  return sign*(e==0 and f*2^-149 or (1+f/8388608)*2^(e-127))
end
local function identity() return {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1} end
local function multiply(a,b)
  local out={}
  for c=0,3 do for r=0,3 do
    local n=0;for k=0,3 do n=n+a[k*4+r+1]*b[c*4+k+1] end;out[c*4+r+1]=n
  end end
  return out
end
local function matrix(node)
  if node.matrix then assert(#node.matrix==16,'Invalid node matrix');return node.matrix end
  local t,s,q=node.translation or {0,0,0},node.scale or {1,1,1},node.rotation or {0,0,0,1}
  local x,y,z,w=q[1],q[2],q[3],q[4]
  return {(1-2*y*y-2*z*z)*s[1],(2*x*y+2*z*w)*s[1],(2*x*z-2*y*w)*s[1],0,
    (2*x*y-2*z*w)*s[2],(1-2*x*x-2*z*z)*s[2],(2*y*z+2*x*w)*s[2],0,
    (2*x*z+2*y*w)*s[3],(2*y*z-2*x*w)*s[3],(1-2*x*x-2*y*y)*s[3],0,t[1],t[2],t[3],1}
end
local function gltf(data,load,model)
  local bin
  if data:sub(1,4)=='glTF' then
    assert(uint(data,4,4)==2 and uint(data,8,4)==#data,'Invalid GLB 2.0 header')
    local offset,json=12
    while offset<#data do
      local size,kind=uint(data,offset,4),uint(data,offset+4,4)
      assert(offset+8+size<=#data,'Truncated GLB chunk')
      local chunk=data:sub(offset+9,offset+8+size)
      if kind==0x4E4F534A then json=chunk elseif kind==0x004E4942 then bin=chunk end
      offset=offset+8+size
    end
    data=assert(json,'GLB JSON chunk missing')
  end
  local doc=require('src.link.Json').decode(data)
  assert(doc.asset and doc.asset.version=='2.0','Use glTF 2.0')
  for _,ext in ipairs(doc.extensionsRequired or {}) do assert(ext=='KHR_materials_unlit','Unsupported required glTF extension: '..ext..'; export without compression') end
  assert(not doc.skins or #doc.skins==0,'Skinned models are unsupported; export a static mesh')
  assert(not doc.animations or #doc.animations==0,'Animated models are unsupported; export a static mesh')
  local buffers={}
  for i,b in ipairs(doc.buffers or {}) do
    buffers[i]=b.uri and load(b.uri) or assert(bin,'Missing glTF buffer')
    assert(#buffers[i]>=b.byteLength,'Truncated glTF buffer')
  end
  local components={SCALAR=1,VEC2=2,VEC3=3,VEC4=4}
  local sizes={[5120]=1,[5121]=1,[5122]=2,[5123]=2,[5125]=4,[5126]=4}
  local accessorCache={}
  local function accessor(id)
    if accessorCache[id] then return accessorCache[id] end
    local a=assert((doc.accessors or {})[id+1],'Missing glTF accessor')
    assert(not a.sparse,'Sparse glTF accessors are unsupported; export dense mesh buffers')
    local view=assert((doc.bufferViews or {})[(a.bufferView or -1)+1],'Missing accessor buffer view')
    local raw=assert(buffers[view.buffer+1],'Missing buffer')
    local count,bytes=assert(components[a.type],'Unsupported accessor type'),assert(sizes[a.componentType],'Unsupported component type')
    assert(a.count<=M.MAX_VERTICES,'glTF accessor exceeds model limit')
    local stride=view.byteStride or count*bytes
    assert(stride>=count*bytes,'Invalid accessor stride')
    local start=(view.byteOffset or 0)+(a.byteOffset or 0)
    assert((a.byteOffset or 0)+math.max(0,a.count-1)*stride+count*bytes<=view.byteLength,'Accessor exceeds buffer view')
    local values={}
    for i=0,a.count-1 do
      local v={}
      for c=0,count-1 do
        local p=start+i*stride+c*bytes
        local n=a.componentType==5126 and float(raw,p) or uint(raw,p,bytes)
        if a.componentType==5120 or a.componentType==5122 then if n>=2^(bytes*8-1) then n=n-2^(bytes*8) end end
        if a.normalized and a.componentType~=5126 then
          n=(a.componentType==5120 or a.componentType==5122) and math.max(-1,n/(2^(bytes*8-1)-1)) or n/(2^(bytes*8)-1)
        end
        v[#v+1]=n
      end
      values[#values+1]=v
    end
    accessorCache[id]=values;return values
  end
  local images,mats={},{}
  local function image(id)
    if images[id] then return images[id] end
    local img=assert((doc.images or {})[id+1],'Missing image')
    local bytes
    if img.uri then bytes=load(img.uri) else
      local view=assert(doc.bufferViews[img.bufferView+1],'Missing image view')
      local raw=assert(buffers[view.buffer+1]);local start=view.byteOffset or 0
      assert(start+view.byteLength<=#raw,'Truncated glTF image');bytes=raw:sub(start+1,start+view.byteLength)
    end
    images[id]=texture(bytes);return images[id]
  end
  local function mat(id)
    if id==nil then return material() end
    if mats[id] then return mats[id] end
    local raw=assert((doc.materials or {})[id+1],'Missing glTF material')
    local pbr=raw.pbrMetallicRoughness or {};local m={color=pbr.baseColorFactor or {1,1,1,1}}
    if pbr.baseColorTexture then
      assert((pbr.baseColorTexture.texCoord or 0)==0 and not pbr.baseColorTexture.extensions,'Export base-color textures using UV0 without texture transforms')
      local t=assert(doc.textures[pbr.baseColorTexture.index+1],'Missing texture')
      m.image=image(assert(t.source,'Missing texture source'))
      local sampler=(doc.samplers or {})[(t.sampler or -1)+1] or {}
      local wrap={[10497]='repeat',[33071]='clamp',[33648]='mirroredrepeat'}
      m.wrapS=assert(wrap[sampler.wrapS or 10497],'Unsupported texture wrap')
      m.wrapT=assert(wrap[sampler.wrapT or 10497],'Unsupported texture wrap')
    end
    m.alphaCutoff=raw.alphaMode=='MASK' and (raw.alphaCutoff or .5) or .01
    if raw.alphaMode~='BLEND' and raw.alphaMode~='MASK' then m.color={m.color[1],m.color[2],m.color[3],1} end
    mats[id]=m;return m
  end
  local active={}
  local function visit(id,parent,depth)
    assert(depth<100 and not active[id],'Cyclic or excessively deep glTF nodes');active[id]=true
    local node=assert((doc.nodes or {})[id+1],'Missing glTF node');local world=multiply(parent,matrix(node))
    if node.mesh~=nil then
      for _,p in ipairs(assert(doc.meshes[node.mesh+1],'Missing mesh').primitives or {}) do
        assert(not p.targets,'Morph targets are unsupported; export a static mesh')
        assert(not p.extensions,'Compressed mesh primitives are unsupported')
        local mode=p.mode or 4;assert(mode==4 or mode==5 or mode==6,'Use triangle meshes')
        local positions=accessor(assert(p.attributes.POSITION,'Missing model positions'))
        local tex=p.attributes.TEXCOORD_0 and accessor(p.attributes.TEXCOORD_0)
        local colors=p.attributes.COLOR_0 and accessor(p.attributes.COLOR_0)
        local indices={}
        if p.indices~=nil then for _,v in ipairs(accessor(p.indices)) do indices[#indices+1]=v[1]+1 end
        else for i=1,#positions do indices[i]=i end end
        local triangles={}
        if mode==4 then assert(#indices%3==0,'Incomplete triangles');triangles=indices
        else for i=3,#indices do
          local a,b=mode==6 and indices[1] or indices[i-2],indices[i-1]
          if mode==5 and i%2==0 then a,b=b,a end
          triangles[#triangles+1]=a;triangles[#triangles+1]=b;triangles[#triangles+1]=indices[i]
        end end
        local vertices={}
        for _,i in ipairs(triangles) do
          local v=assert(positions[i],'glTF index out of range');local uv=tex and assert(tex[i]) or {0,0};local c=colors and assert(colors[i]) or {1,1,1,1}
          vertices[#vertices+1]={world[1]*v[1]+world[5]*v[2]+world[9]*v[3]+world[13],
            world[2]*v[1]+world[6]*v[2]+world[10]*v[3]+world[14],
            world[3]*v[1]+world[7]*v[2]+world[11]*v[3]+world[15],uv[1],uv[2],c[1],c[2],c[3],c[4] or 1}
        end
        append(model,vertices,mat(p.material))
      end
    end
    for _,child in ipairs(node.children or {}) do visit(child,world,depth+1) end
    active[id]=nil
  end
  local scene=(doc.scenes or {})[(doc.scene or 0)+1]
  if scene then for _,id in ipairs(scene.nodes or {}) do visit(id,identity(),0) end
  else
    local children={};for _,n in ipairs(doc.nodes or {}) do for _,id in ipairs(n.children or {}) do children[id]=true end end
    for i in ipairs(doc.nodes or {}) do if not children[i-1] then visit(i-1,identity(),0) end end
  end
end
function M.parse(path,data,reader)
  assert(#data<=M.MAX_BYTES,'Model exceeds 32 MB')
  local model={name=path:gsub('\\','/'):match('([^/]+)$'),parts={},vertexCount=0,version=1}
  local load=resolver(path,reader or read)
  if path:lower():match('%.obj$') then obj(data,load,model)
  else assert(path:lower():match('%.gltf$') or path:lower():match('%.glb$'),'Choose an OBJ, glTF or GLB model');gltf(data,load,model) end
  assert(model.vertexCount>0,'Model contains no triangles')
  local min,max={math.huge,math.huge,math.huge},{-math.huge,-math.huge,-math.huge}
  for _,p in ipairs(model.parts) do for _,v in ipairs(p.vertices) do
    for i=1,9 do assert(finite(v[i]),'Invalid model vertex') end
    for i=1,3 do min[i]=math.min(min[i],v[i]);max[i]=math.max(max[i],v[i]) end
  end end
  local extent=math.max(max[1]-min[1],max[2]-min[2],max[3]-min[3]);assert(extent>1e-9,'Model has zero extent')
  -- Store Y-up geometry centered horizontally, with its feet at Y=0.
  local scale=max[2]-min[2];if scale<1e-9 then scale=extent end
  for _,p in ipairs(model.parts) do for _,v in ipairs(p.vertices) do
    v[1]=(v[1]-(min[1]+max[1])/2)/scale;v[2]=(v[2]-min[2])/scale;v[3]=(v[3]-(min[3]+max[3])/2)/scale
  end end
  model.width,model.depth=(max[1]-min[1])/scale,(max[3]-min[3])/scale
  -- A single numeric stream avoids Lua's per-function constant limit in exports.
  for _,p in ipairs(model.parts) do
    local values={}
    for _,v in ipairs(p.vertices) do for i=1,9 do values[#values+1]=string.format('%.9g',v[i]) end end
    p.data=table.concat(values,',');p.vertices=nil
  end
  return model
end
function M.load(path)
  local ok,result=pcall(function() return M.parse(path,read(path)) end)
  if ok then return result end
  return nil,tostring(result):gsub('^.-:%d+: ','')
end
return M
