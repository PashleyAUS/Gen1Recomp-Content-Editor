-- Enumerate numeric controls by running the actual Rules forms. Mutations go
-- through their normal clamping/project-writing code, one control at a time.
local M={}
function M.collect(game,data)
 local saved={}
 for _,name in ipairs({'Kit','RegList','FormPane','Rules','ChoicePicker'}) do saved[name]=package.loaded[name];package.loaded[name]=nil end
 local oldRead=love.filesystem.read;local sourceCache={}
 love.filesystem.read=function(path,...)
  if type(path)=='string' and path:match('^tools/content%-editor/.+%.lua$') then
   if sourceCache[path] then return sourceCache[path] end
   local text,err=oldRead(path,...)
   if not text then local f=io.open(path,'rb');if f then text=f:read('*a');f:close() end end
   if text then sourceCache[path]=text end
   return text,err
  end
  return oldRead(path,...)
 end
 local controls,modes,target,value={}, {},nil,nil
 local choices,registryIds={},{}
 local chipIndex=0
 local noop=function() end
 local K=setmetatable({scale=1,button=function() return false end,textWidth=function() return 100 end},{__index=function() return noop end})
 K.chip=function(x,y,w,h,label,active)
  chipIndex=chipIndex+1;local id='toggle:'..chipIndex
  controls[id]=not not active
  return id==target and value~=active
 end
 package.loaded.Kit=K
 package.loaded.ChoicePicker={field=function(S,opts)
  if opts.onPick and opts.ids then
   choices[#choices+1]=opts
  end
 end}
 package.loaded.FormPane={finish=noop,begin=function(_,_,x,y,w,h) return y,{contentW=w} end}
 local L={}
 function L.num(_,id,x,y,w,h,n) controls[id]=n;return id==target and value or n end
 function L.modeChips(S,key,list,x,y) for _,row in ipairs(list) do modes[row.id]=true end;return y end
 function L.beginForm(_,x,y,w,h) return y,{},x,w end
 function L.sortedKeys(t) local a={} for k in pairs(t or {}) do a[#a+1]=k end;table.sort(a);return a end
 function L.mergeIds(a,b) local t={} for k in pairs(a or {}) do t[k]=true end;for k in pairs(b or {}) do t[k]=true end;return L.sortedKeys(t) end
 function L.drawList(_,_,x,y,w,h,_,ids) registryIds=ids;return x,w,y,h,ids end
 function L.suggestField(_,_,_,_,_,_,_,v) return v end
 function L.field(_,id,x,y,w,h,v)
  if id=='ru_rs_crit' or id=='ru_tr_fin' then
   controls[id]=tonumber(v) or 0
   if id==target then return tostring(value) end
  end
  return v
 end
 package.loaded.RegList=L
 local State=require('State');local W=require('ModWriter');local Rules=require('Rules')
 local function state(mode)
  local S=State.new();S.version=game;S.data=data or {};S.project=State.blankProject('rules_inventory_'..game);S.project.game=game
  S.rulesMode=mode;S.g3RulesMode=mode
  if mode=='safari' then S.project.safariSettings=require('SafariSettings').defaults(require('Generation').num(S)) end
  return S
 end
 local App={markDirty=noop}
 local cases,errors={},{}
 local function draw(S)
  chipIndex=0
  local extra=S.rulesMode:match('^extra_(.+)')
  local ok,e
  if extra then ok,e=pcall(require(extra).draw,S,0,0,1400,App)
  else ok,e=pcall(Rules.draw,S,0,0,1400,900,App) end;if not ok then errors[#errors+1]=(S.rulesMode or '')..': '..tostring(e) end;return ok end
 draw(state('battle'))
 local extra={'CardFlipRules','RouletteRules','BlenderRules','BerryCrushRules','JumpRules','DodrioRules','SlotPayouts','SlotBets','RseSlotLuck','FrlgSlotBias','BlenderOpponents'}
 for _,name in ipairs(extra) do modes['extra_'..name]=true end
 local list=L.sortedKeys(modes)
 for _,mode in ipairs(list) do
  controls={};choices={};registryIds={};target=nil
  if draw(state(mode)) then
   local variants={{label='default'}}
   local captured=choices
   local baseline={} for id,n in pairs(controls) do baseline[id]=n end
   for ci,opts in ipairs(captured) do
    for _,pick in ipairs(opts.ids) do
     if tostring(pick)~=tostring(opts.current) and tostring(opts.title):find('ROW',1,true) then
      variants[#variants+1]={label=(opts.title or tostring(ci))..'='..tostring(pick),choice=ci,pick=pick}
     end
    end
   end
   for _,id in ipairs(registryIds) do variants[#variants+1]={label='record='..id,record=id} end
   for _,variant in ipairs(variants) do
    local function prepared()
     local S=state(mode)
     if variant.record then S['rulesId_'..mode]=variant.record end
     if variant.choice then
      target=nil;choices={};draw(S)
      assert(choices[variant.choice],'missing selector').onPick(variant.pick)
     end
     return S
    end
    target=nil;local initial=prepared();controls={};draw(initial)
    local ids=L.sortedKeys(controls);local defaults={} for id,n in pairs(controls) do defaults[id]=n end
    for _,id in ipairs(ids) do
     if not variant.choice or baseline[id]==nil or baseline[id]~=defaults[id] then
     local edits=type(defaults[id])=='boolean' and {not defaults[id]} or {defaults[id]+1,-1000000,1000000}
     for _,n in ipairs(edits) do
      local S=prepared();target=id;value=n
      if draw(S) then
       local ok,source=pcall(W.emitMain,S.project,{})
       cases[#cases+1]={id=id,mode=mode..'/'..variant.label,project=S.project,source=ok and source or nil,error=not ok and source or nil,requested=n,default=defaults[id]}
      end
     end
     end
    end
   end
  end
 end
 for name,old in pairs(saved) do package.loaded[name]=old end
 -- Keep loaded form modules bound to the instrumented Kit until this process ends.
 love.filesystem.read=oldRead
 return cases,errors,list
end
return M


