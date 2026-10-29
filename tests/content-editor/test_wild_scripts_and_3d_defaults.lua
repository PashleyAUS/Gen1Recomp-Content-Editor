package.path='tools/content-editor/?.lua;tools/content-editor/panels/?.lua;runtime/gen1recomp/?.lua;'..package.path
local Talk=require('Gen2Talk')
local S={project={scripts={},scriptSteps={},text={}},data={scripts={}}}
local obj={pokemon='SUDOWOODO',level=30}
local key=Talk.bindFixedWild(S,'TEST',obj,1,185)
local bag=Talk.getScriptSteps(S,key)
table.insert(bag.steps,1,{kind='show_text',text='mod:INTRO',jumptext=false})
S.project.text['mod:INTRO']='Hello!'
obj.level=45;obj.forceShiny=true
assert(Talk.bindFixedWild(S,'TEST',obj,1,185)==key)
assert(bag.steps[1].kind=='show_text' and bag.steps[1].text=='mod:INTRO')
local text,battle,hide=false,false,false
for _,cmd in ipairs(S.project.scripts[key]) do
  if cmd.op=='writetext' then text=true end
  if cmd.op=='loadwildmon' then assert(cmd.species==185 and cmd.level==45);battle=true end
  if cmd.op=='disappear' then hide=true end
end
assert(text and battle and hide)
S.project.maps={TEST={objects={obj}}}
require('ModWriter').applyGen2FixedWildBinds(S.project,{pokemon={SUDOWOODO={index=185}}})
assert(S.project.scriptSteps[key]==bag and bag.steps[1].kind=='show_text')
assert(S.project.scripts[key][1].op=='writetext','Save erased the dialogue')
obj.forceShiny=false;Talk.bindFixedWild(S,'TEST',obj,1,185)
for _,step in ipairs(bag.steps) do if step.kind=='wild_battle' then assert(not step.forceShiny) end end

-- Execute the generated map selection with stubbed embedded modules.
love={filesystem={read=function(path)
  local f=assert(io.open(path,'rb'));local value=f:read('*a');f:close();return value
end}}
local out={}
require('Gen3SceneExport').emit({game='emerald',gen3Layered={TEST={}}},out)
local captured
local maps={PLAIN={},DISABLED={visualPlayable=false},ENABLED={visualPlayable=true}}
local code=table.concat(out,'\n')
local start=assert(code:find('local sceneObjects=',1,true))
local selection=code:sub(1,start-1)..'capture(sceneMaps) end'
local run=assert(loadstring(selection));setfenv(run,{layered={maps=maps},pairs=pairs,capture=function(v) captured=v end});run()
assert(captured.ENABLED==maps.ENABLED and not captured.PLAIN and not captured.DISABLED)

package.loaded.Gen3Workspace={convert=function(state,id) return {cellWidth=8},state.project.maps[id] end}
package.loaded.SpeciesPicker={indexForId=function() return 144 end}
package.loaded.Gen3={catalog=function() return {} end}
package.loaded.Gen3EventWindow={request=function() end}
S={mapId='TEST',placeWildSpecies='ARTICUNO',placeWildLevel=50,project={maps={TEST={objects={}}}},data={}}
local dirty=0;local App={markDirty=function() dirty=dirty+1 end}
local Events=require('Gen3MapEvents')
assert(Events.place(S,'wild',2,3,App))
local ev=S.project.maps.TEST.objects[1]
local script=S.project.gen3.map_scripts[ev.scriptKey]
assert(script[3].op=='setwildbattle' and script[3].species==144 and script[4].op=='dowildbattle')
assert(S.project.gen3Modes.map_scripts[ev.scriptKey]=='register' and dirty==1)
S.project.maps.TEST.objects[2]={pokemon='ARTICUNO',level=60}
assert(Events.ensureWildScript(S,'TEST',2))
local repaired=S.project.maps.TEST.objects[2].scriptKey
assert(S.project.gen3.map_scripts[repaired][3].level==60)
assert(not Events.ensureWildScript(S,'TEST',2))
print('OK wild scripts and explicit 3D export')
