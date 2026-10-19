package.path='tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;'..package.path
dofile('tests/love_stub.lua')
local R=require('Gen3BattleRules')
local W=require('ModWriter')
local count=0
for _,game in ipairs({'firered','leafgreen','ruby','sapphire','emerald'}) do
 require('src.core.GameVersion').set(game)
 for _,row in ipairs(R.fields) do
  local n=row.default==row.min and row.max or row.min
  local values={[row.key]=n}
  if row.key=='damageRollMax' then values.damageRollMin=n end
  if row.key=='partialTrapMaxTurns' then values.partialTrapMinTurns=n end
  local out={}
  R.emit({game=game,gen3BattleRules=values},W.encodeLua,out)
  local f=assert(loadstring(table.concat(out,'\n')))
  setfenv(f,setmetatable({mod={hooks={wrap=function() end}}},{__index=_G}))
  local ok,err=pcall(f)
  assert(ok,game..' '..row.key..': '..tostring(err))
  count=count+1
 end
end
print('PASS '..count..' exported rule loads')
