local M={}
-- Capture module-owned rule tables so each edit runs against the same defaults.
local function snapshot()
 local records,seen={},{}
 local function visit(t,depth,all)
  if type(t)~='table' or seen[t] then return end
  seen[t]=true;local copy={};for k,v in pairs(t) do copy[k]=v end
  records[#records+1]={t,copy}
  if depth>0 then for k,v in pairs(copy) do if type(v)=='table' and (all or type(k)=='number' or type(k)=='string' and k:match('^[A-Z_][A-Z_0-9]*$')) then visit(v,depth-1,all) end end end
 end
 for name,t in pairs(package.loaded) do
  if name:match('^src%.battle%.') or name:match('^src%.core%.gen2%.') or name:match('^src%.core%.game3%.battle%.') or name:match('^src%.core%.game3%.rse%.') or name:match('^src%.core%.game3%.minigames%.') or name=='src.core.game3.slot_machine' or name=='src.ui.SlotMachine' or name=='src.ui.gen2.SlotMachine' or name=='src.ui.gen2.CardFlip' or name=='src.core.game3.pokemon' then visit(t,2,name=='src.core.game3.battle.rules') end
 end
 return function()
  for _,rec in ipairs(records) do
   for k in pairs(rec[1]) do if rec[2][k]==nil then rec[1][k]=nil end end
   for k,v in pairs(rec[2]) do rec[1][k]=v end
  end
 end
end
function M.run(game,gameId,root,report)
 package.path=root..'/tests/content-editor/?.lua;'..package.path
 local cases,errors,modes=require('RuleInventory').collect(gameId,game.data)
 local failures={};for _,e in ipairs(errors) do failures[#failures+1]='FORM '..e end
 local passed=0
 for i,c in ipairs(cases) do
  -- Load constants before taking the baseline, including rule modules
  -- that the current field scene has not needed yet.
  for name in (c.source or ''):gmatch('require%("([%w_.]+)"%)') do
   if name:match('^src%.') then pcall(require,name) end
  end
  local restore=snapshot()
  local targets={}
  report('RUNNING '..gameId..' '..i..'/'..#cases..' '..c.mode..'/'..c.id..'='..tostring(c.requested))
  local ticks=0
  debug.sethook(function() ticks=ticks+1;if ticks>2000 then error('rule execution exceeded 20 million Lua instructions') end end,'',10000)
  local ok,err=pcall(function()
   assert(c.source,c.error)
   -- A fresh registry set models the pre-merge loading phase; the live
   -- loader's registries are correctly frozen once a game has booted.
   local loader=setmetatable({},getmetatable(game.mods))
   for k,v in pairs(game.mods) do loader[k]=v end
   loader.content={}
   local Registry=require('src.mods.Registry')
   for name,old in pairs(game.mods.content) do
    local r=Registry.new(name,old.spec);r.base=old.base;loader.content[name]=r
   end
   local original=game.mods.mods['rules_audit_'..gameId]
   local mod={} for k,v in pairs(original) do mod[k]=v end
   mod.manifest=require('src.mods.Merge').deepCopy(original.manifest);mod.manifest.api=2
   local api=loader:_api(mod)
   local handlers={}
   api.events={on=function(_,name,fn,priority)
    handlers[name]=handlers[name] or {};table.insert(handlers[name],{fn,priority or 0});return function() end
   end}
   api.events.once=api.events.on
   api.hooks={wrap=function(_,name,fn,priority) return game.mods.hooks:wrap(name,fn,priority,'rule_boundary_audit') end}
   assert(loadstring(c.source))()(api)
   for _,name in ipairs(loader:_mergeOrder()) do
    local registry=loader.content[name];local spec=registry.spec
    local path=loader:_target(name,spec)
    if path and next(registry.ops) then
     local t=require('src.core.Data').ensure(game.data,path)
     local before={};for k,v in pairs(t) do before[k]=v end;targets[#targets+1]={t,before}
     if spec.write then spec.write(t,registry)
     else for id in pairs(registry.ops) do t[id]=registry:get(id) end end
    end
   end
   for _,event in ipairs({'mods.loaded','game.ready'}) do
    local list=handlers[event] or {};table.sort(list,function(a,b) return a[2]>b[2] end)
    for _,row in ipairs(list) do row[1]({game=game,data=game.data}) end
   end
   require('RuleProbes').run(gameId,game,c)
   if game.fixedUpdate then game:fixedUpdate(1/60) else game:update(1/60) end
   game:draw()
  end)
  debug.sethook()
  game.mods.hooks:removeOwner('rule_boundary_audit');restore()
  for _,rec in ipairs(targets) do
   for k in pairs(rec[1]) do if rec[2][k]==nil then rec[1][k]=nil end end
   for k,v in pairs(rec[2]) do rec[1][k]=v end
  end
  if ok then passed=passed+1 else failures[#failures+1]=c.mode..'/'..c.id..' ('..tostring(c.requested)..'): '..tostring(err) end
  if i%100==0 then report('RUNNING '..gameId..': '..i..'/'..#cases..' controls, '..#failures..' failures') end
 end
 local summary=string.format('%s: %s %d/%d rule edits across %d modes; strict exported mod validation, lifecycle callbacks, battle/Pokemon calculations and game update/draw',#failures==0 and 'PASS' or 'FAIL',gameId,passed,#cases,#modes)
 for _,e in ipairs(failures) do summary=summary..'\n'..e end
 report(summary)
 return #failures==0
end
return M

