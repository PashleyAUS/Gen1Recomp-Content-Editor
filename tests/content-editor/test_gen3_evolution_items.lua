-- Run from the repository root with LuaJIT.
package.path = "tools/content-editor/?.lua;" .. package.path
local M = require("Gen3EvolutionItems")
assert(M.compile({}) == nil)
local project = {gen3 = {
  items = {CUSTOM_STONE = {index = 400}},
  pokemon = {
    BULBASAUR = {evolutions = {
      {method = "EVO_ITEM", item = "CUSTOM_STONE", species = "IVYSAUR"},
      {method = "EVO_TRADE_ITEM", item = "CUSTOM_STONE", species = "IVYSAUR"},
      {method = "EVO_LEVEL", level = 16, species = "IVYSAUR"},
      {method = "EVO_ITEM", item = "FIRE_STONE", species = "IVYSAUR"}}},
    NEW_MON = {index = 440, evolutions = {
      {method = "EVO_ITEM", item = "CUSTOM_STONE", species = "IVYSAUR"}}}
  }
}}
local fixes = assert(M.compile(project))
assert(fixes.BULBASAUR.rows[1] == 400 and fixes.BULBASAUR.rows[2] == 400)
assert(fixes.BULBASAUR.rows[3] == nil and fixes.BULBASAUR.rows[4] == nil)
local function encode(v)
  if type(v) ~= "table" then return type(v) == "string" and string.format("%q",v) or tostring(v) end
  local out = {}
  for k,x in pairs(v) do out[#out+1] = "["..encode(k).."]="..encode(x) end
  return "{"..table.concat(out,",").."}"
end
do
  local rows = {[1] = {{method=7,param=0,target=2},{6,0,2},{4,16,2},{7,95,2}}}
  local P = {
    speciesFromName = function(id) return id == "BULBASAUR" and 1 or nil end,
    speciesOf = function(mon) return mon.species end,
    evolutions = function(id)
      if type(id)=="table" then id=id.species end
      if type(id)=="string" then id=1 end
      -- New species rows can be populated lazily after game.ready.
      rows[id]=rows[id] or {{method=7,param=0,target=2}}
      return rows[id]
    end
  }
  package.loaded["src.core.game3.pokemon"] = P
  local ready
  local mod = {events = {on = function(_,event,fn) assert(event=="game.ready");ready=fn end}}
  local out={};M.emit(project,encode,out)
  assert(loadstring("return function(mod) "..table.concat(out,"\n").." end"))()(mod)
  ready()
  assert(P.evolutions("BULBASAUR")[1].param == 400)
  assert(P.evolutions({species=1})[2][2] == 400)
  assert(rows[1][3][2] == 16 and rows[1][4][2] == 95)
  rows[440]=nil
  assert(P.evolutions(440)[1].param == 400)
  print("ok custom stone and trade item references, vanilla rules, and lazy species rows")
end
