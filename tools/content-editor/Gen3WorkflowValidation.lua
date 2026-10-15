-- Validate the saved runtime module against fresh game data, without changing
-- the live editor catalogs, saves, or mod enablement.
local M={}
function M.validate(S)
  local lines={};local errors=0
  local function fail(message) errors=errors+1;lines[#lines+1]="ERROR "..message end
  local ok,err=pcall(function()
    assert(S.data and S.data._gen3Read,"Import or link Gen 3 game data before validating")
    local G=require("Gen3");local data={}
    G.load(data,S.data._gen3Read,S.data._gen3List)
    local loader,why=require("Gen3Mod").load(data,S.path)
    assert(loader,why)
    local report=data._editorGen3Report or {}
    for _,entry in ipairs(report.rejected or {}) do fail(entry.registry.."."..tostring(entry.id)..": "..tostring(entry.error)) end
    for _,message in ipairs(report.messages or {}) do lines[#lines+1]="NOTE "..tostring(message) end
    local scripts=G.catalog(data,"map_scripts");local texts=G.catalog(data,"text")
    local authored=(S.project.gen3 or {}).map_scripts or {}
    local function target(id,where)
      if type(id)=="string" and id~="" and not scripts[id] then fail(where.." references missing script "..id) end
    end
    for id,rows in pairs(authored) do
      for i,row in ipairs(rows) do
        local where=id.." command "..i
        if row.op=="goto" or row.op=="call" then target(row.target or row[1],where)
        elseif row.op=="goto_if" or row.op=="call_if" then target(row.target or row[2],where)
        elseif row.op=="message" or row.op=="loadword" and (row.dest or row[1])==0 then
          local ptr=row.op=="message" and (row.ptr or row[1]) or (row.value or row[2])
          if type(ptr)=="string" and not texts[ptr] then fail(where.." references missing dialogue "..ptr) end
        end
      end
    end
    for id,map in pairs(S.project.maps or {}) do
      for _,kind in ipairs({"objects","signs","bgEvents","coordEvents"}) do
        for i,event in ipairs(map[kind] or {}) do target(event.scriptKey,id.." "..kind.." "..i);target(event.touchScriptKey,id.." "..kind.." "..i) end
      end
    end
  end)
  if not ok then fail(tostring(err)) end
  lines[#lines+1]=errors==0 and "OK Gen 3 runtime loader, event links and dialogue references" or ("FAIL "..errors.." validation error(s)")
  return errors==0,table.concat(lines,"\n")
end
return M
