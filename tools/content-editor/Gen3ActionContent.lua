local M={}
local copy=require("src.mods.Merge").deepCopy
function M.shop(S,key)
  local edit=(S.project.marts or {})[tostring(key)]
  if edit then return copy(edit) end
  S.data._g3ActionMarts=S.data._g3ActionMarts or require("Gen3Resources").readTable(S.data,"data/generated/gba/scripts/marts.lua")
  local pack=S.data._g3ActionMarts
  local n=type(key)=="number" and key or tonumber(key) or tonumber(tostring(key):match("^g3:(%x+)$"),16)
  for _,rec in pairs(pack.marts or {}) do
    if rec.key==key or (n and rec.ptr==n) then
      local override=(S.project.marts or {})[rec.key]
      if override then return copy(override) end
      local stock={}
      for _,index in ipairs(rec.items or {}) do stock[#stock+1]=require("ItemPicker").idForIndex(S,index) or tostring(index) end
      return stock
    end
  end
end
function M.drawDestination(S,group,number,x,y,w,pick)
  local C=require("src.import.gba.map_catalog")
  local labels,ids={},{}
  local current=tostring(group)..":"..tostring(number)
  for _,maps in ipairs({S.data.maps or {},S.project.maps or {}}) do
    for id in pairs(maps) do
      local slot=C.slotKeyFor(id)
      if slot then slot=slot:gsub("_",":") end
      if slot and not labels[slot] then ids[#ids+1]=slot;labels[slot]=require("Gen3Labels").map(id) end
    end
  end
  if not labels[current] then ids[#ids+1]=current;labels[current]="Current destination ("..current..")" end
  table.sort(ids,function(a,b) return labels[a]<labels[b] end)
  require("ChoicePicker").field(S,{x=x,y=y,w=w,h=29*require("Kit").scale,current=current,ids=ids,labels=labels,title="DESTINATION MAP",onPick=function(id)
    local g,n=id:match("^(%d+):(%d+)$");if g then pick(tonumber(g),tonumber(n)) end
  end})
end
function M.saveShop(S,stock,pick)
  -- A new inventory belongs to this action; other shops retain their stock.
  S.project.marts=S.project.marts or {}
  local base="EditorActionShop_"..tostring(S.project.id):gsub("[^%w_]","_").."_";local n=1
  while S.project.marts[base..n] do n=n+1 end
  local id=base..n
  S.project.marts[id]=copy(stock);S.project.gen3Workbench=true;pick(id)
end
function M.decorStock(S,key)
  local edit=(S.project.marts or {})[tostring(key)]
  if type(edit)=="table" and type(edit.items)=="table" then return copy(edit.items), edit.martType or "DECOR" end
  S.data._g3ActionMarts=S.data._g3ActionMarts or require("Gen3Resources").readTable(S.data,"data/generated/gba/scripts/marts.lua")
  local n=type(key)=="number" and key or tonumber(key) or tonumber(tostring(key):match("^g3:(%x+)$"),16)
  for _,rec in pairs(S.data._g3ActionMarts.marts or {}) do
    if rec.key==key or (n and rec.ptr==n) then
      local override=(S.project.marts or {})[rec.key]
      if type(override)=="table" and not override.items then return copy(override), rec.martType or "DECOR" end
      local cat=require("Gen3Workbench").decorationCatalog(S)
      local stock={}
      for _,index in ipairs(rec.items or {}) do stock[#stock+1]=cat.byId[index] or tostring(index) end
      return stock, rec.martType or "DECOR"
    end
  end
  return nil, "DECOR"
end
function M.saveDecorShop(S,stock,martType,pick)
  S.project.marts=S.project.marts or {}
  local base="EditorDecorShop_"..tostring(S.project.id):gsub("[^%w_]","_").."_";local n=1
  while S.project.marts[base..n] do n=n+1 end
  local id=base..n
  S.project.marts[id]={items=copy(stock),martType=martType or "DECOR",kind="decorations"}
  S.project.gen3Workbench=true
  pick(id)
end
function M.drawDecorShop(S,key,old,x,y,w,pick)
  local K=require("Kit");local s=K.scale;local Choice=require("ChoicePicker")
  local stock,martType=M.decorStock(S,old)
  local note=stock and "Decorations sold by this action. Other shops keep their own inventory." or "The original inventory is unavailable. Add decorations to create one for this action."
  K.text("small",K.ellipsize("small",note,w),x,y,require("Theme").PAL.text);K.offerTooltip(x,y,w,24*s,note);y=y+28*s
  stock=stock or {}
  local cat=require("Gen3Workbench").decorationCatalog(S)
  for i,id in ipairs(stock) do
    Choice.field(S,{x=x,y=y,w=w-85*s,h=29*s,current=id,ids=cat.ids,labels=cat.labels,title="DECORATION",onPick=function(value)
      local rows=copy(stock);rows[i]=value;M.saveDecorShop(S,rows,martType,pick)
    end})
    if K.button(x+w-77*s,y,77*s,29*s,"Remove",{}) then
      local rows=copy(stock);table.remove(rows,i);M.saveDecorShop(S,rows,martType,pick);return y+40*s
    end
    y=y+36*s
  end
  Choice.field(S,{x=x,y=y,w=w,h=29*s,current="",emptyLabel="Add a decoration to sell",ids=cat.ids,labels=cat.labels,title="ADD DECORATION",onPick=function(id)
    local rows=copy(stock);rows[#rows+1]=id;M.saveDecorShop(S,rows,martType,pick)
  end})
  return y+36*s
end
function M.drawShop(S,key,old,x,y,w,pick)
  local K=require("Kit");local s=K.scale;local P=require("ItemPicker")
  local stock=M.shop(S,old)
  local note=stock and "Items sold by this action. Other shops keep their own inventory." or "The original inventory is unavailable. Add items to create an inventory for this action."
  K.text("small",K.ellipsize("small",note,w),x,y,require("Theme").PAL.text);K.offerTooltip(x,y,w,24*s,note);y=y+28*s
  stock=stock or {}
  for i,id in ipairs(stock) do
    P.field(S,{x=x,y=y,w=w-85*s,h=29*s,current=id,title="SHOP ITEM",onPick=function(value) local rows=copy(stock);rows[i]=value;M.saveShop(S,rows,pick) end})
    if K.button(x+w-77*s,y,77*s,29*s,"Remove",{}) then local rows=copy(stock);table.remove(rows,i);M.saveShop(S,rows,pick);return y+40*s end
    y=y+36*s
  end
  P.field(S,{x=x,y=y,w=w,h=29*s,current="",emptyLabel="Add an item to sell",title="ADD SHOP ITEM",onPick=function(id) local rows=copy(stock);rows[#rows+1]=id;M.saveShop(S,rows,pick) end})
  return y+36*s
end
function M.drawDialogue(S,key,old,x,y,w,pick)
  local K=require("Kit");local s=K.scale;local A=require("Gen3EventActions")
  local text=A.text(S,{op="message",ptr=old})
  if text then
    S._g3ActionDialogue=S._g3ActionDialogue or {}
    local entry=S._g3ActionDialogue[key]
    if not entry or entry.pointer~=old then entry={pointer=old,step={op="message",ptr=old}};S._g3ActionDialogue[key]=entry end
    local previous=S._g3MessageDraft;S._g3MessageDraft=entry.draft
    local _,bottom=require("Gen3EventCommands").drawText(S,key,entry.step,x,y,w,function() pick(entry.step.ptr) end)
    entry.draft=S._g3MessageDraft;S._g3MessageDraft=previous
    return bottom
  end
  S._g3ActionText=S._g3ActionText or {}
  local draft=S._g3ActionText[key]
  if not draft or draft.pointer~=old then draft={pointer=old,value=text or ""};S._g3ActionText[key]=draft end
  draft.value=K.textfield(key.."/dialogue",x,y,w,29*s,draft.value,"What the player reads");y=y+36*s
  if K.button(x,y,140*s,28*s,"Apply dialogue",{kind="good",enabled=draft.value~=(text or "")}) then
    local step={op="message",ptr=old};A.setText(S,step,draft.value:gsub("\\n","\n"));pick(step.ptr);S._g3ActionText[key]=nil
  end
  K.text("small","Use \\n for a new line; {PLAYER} for the player's name.",x,y+35*s,require("Theme").PAL.text)
  return y+63*s
end
return M
