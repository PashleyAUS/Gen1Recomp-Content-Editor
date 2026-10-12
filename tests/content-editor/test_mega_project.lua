package.path="tools/content-editor/?.lua;"..package.path
local path="mods/Mega/Megas.editor_project.lua"
local project=assert(loadfile(path))()
local before=assert(loadfile(path..".before-mega-fix.bak"))()
local count=0
for parent,f in pairs(project.gen3Forms) do
  require("Gen3AdvancedForms").validate(f)
  assert(f.default==1 and f.forms[1].species==parent)
  assert(not f.forms[1].mechanic,"Base form must not be a Mega result: "..parent)
  local mega=f.forms[2]
  assert(mega.mechanic.kind=="mega" and (mega.mechanic.from or 1)==1)
  assert(mega.mechanic.item==before.gen3Forms[parent].forms[2].mechanic.item,"Mega item changed")
  assert(project.pokemon[mega.species].index==before.pokemon[mega.species].index,"Species index changed")
  count=count+1
end
assert(count==11)
assert(loadfile("mods/Mega/Megas/main.lua"),"Exported mod syntax is invalid")
local file=assert(io.open("mods/Mega/Megas/main.lua","rb"));local src=file:read("*a");file:close()
assert(not src:find('mechanic = { from = 2',1,true),"Export still contains reverse transformations")
print("PASS: all 11 Mega families use base -> Mega; items and species indices preserved; exported Lua compiles")
