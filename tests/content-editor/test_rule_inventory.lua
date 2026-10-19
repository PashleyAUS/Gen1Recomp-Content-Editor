package.path='tests/content-editor/?.lua;tools/content-editor/?.lua;tools/content-editor/panels/?.lua;tools/save-editor/?.lua;runtime/gen1recomp/?.lua;'..package.path
love=require('tests.love_stub')
love.filesystem.read=function(path) local f=io.open(path,'rb');if not f then return nil end;local s=f:read('*a');f:close();return s end
local cases,errors,modes=require('RuleInventory').collect(arg[1] or 'emerald')
print('CASES',#cases,'MODES',#modes,'FORM ERRORS',#errors)
for _,e in ipairs(errors) do print('FORM ERROR',e) end
local failures=0
for _,c in ipairs(cases) do if c.error then failures=failures+1;print('EXPORT ERROR',c.id,c.requested,c.error) end end
print('EXPORT FAILURES',failures)

assert(#errors==0, table.concat(errors,"\n"))
assert(failures==0, "rule controls produced invalid exports")
for _,c in ipairs(cases) do assert(loadstring(c.source),c.id.." export syntax");assert(loadstring(require("ModWriter").serializeProject(c.project)),c.id.." project serialization") end
