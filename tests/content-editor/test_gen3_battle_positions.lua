package.path="tools/content-editor/?.lua;"..package.path
local hook
local Ui={bounceOffset=function(kind) return kind=="mon" and -14 or 2 end}
local Pic={front={[681]=4,[1]=9},back={[681]=2,[1]=3}}
package.loaded["src.core.game3.battle.ui"]=Ui
package.loaded["src.core.game3.battle.pic_coords"]=Pic
package.loaded["src.core.game3.pokemon"]={
  speciesFromName=function(id) if id=="ACCELGOR" then return 681 end end,
  keyName=function(sp) if sp==700 then return "DWEBBLE" end end,
  _names={[700]="Dwebble"},
}
package.loaded["src.mods.Runtime"]={call=function(_,original,...) if hook then return hook(original,...) end return original(...) end}
require("Gen3BattlePositionsRuntime").install({content={pokemon={get=function(_,id)
  if id=="ACCELGOR" then return {index=1} end
end}},hooks={wrap=function(_,_,fn) hook=fn end}},
  {ACCELGOR={frontY=-5,backY=8},DWEBBLE={frontY=10,backY=4}})
Ui.bounceOffset("mon",1)
assert(Pic.front[681]==-1 and Pic.back[681]==10,"Accelgor follows the live species id, not the stale content index")
assert(Pic.front[1]==9 and Pic.back[1]==3,"Stale content index must not move a different species")
assert(Pic.front[700]==10 and Pic.back[700]==4,"Name lookup covers species whose content index is not ready")
assert(Ui.bounceOffset("mon",1)==-14 and Ui.bounceOffset("hb",1)==2,"Bounce lift stays on the bounce channel")
assert(Pic.front[681]==-1,"Reapplying must not stack the offset")
assert((Pic.front[681] or 0)+Ui.bounceOffset("mon",1)==-15,"Drawn enemy Y is vanilla pic Y plus the editor offset plus bounce")
assert((Pic.back[681] or 0)+Ui.bounceOffset("mon",0)==-4,"Drawn player Y is vanilla pic Y plus the editor offset plus bounce")
hook=nil
Ui.bounceOffset("mon",1)
assert(Pic.front[681]==4 and Pic.back[681]==2 and Pic.front[700]==0 and Pic.back[700]==0,"Unload restores the original picture offsets")
print("PASS: battle positions move picture coordinates, keep bounce lift, resolve live species ids and unload")
