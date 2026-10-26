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
-- A save reloads the mod as a new chunk while the picture tables are still shifted.
Pic.front[681],Pic.back[681],Pic.front[700],Pic.back[700]=-1,10,10,4
local reloaded=assert(loadfile("tools/content-editor/Gen3BattlePositionsRuntime.lua"))()
reloaded.install({content={pokemon={get=function() end}},hooks={wrap=function(_,_,fn) hook=fn end},events={on=function() end}},
  {ACCELGOR={frontY=-5,backY=8},DWEBBLE={frontY=10,backY=4}})
assert(Pic.front[681]==-1 and Pic.back[681]==10,"Reloading the mod must not apply the offset again")
assert(Pic.front[700]==10 and Pic.back[700]==4,"Reload keeps one copy of the saved offset")
reloaded.install({content={pokemon={get=function() end}},hooks={wrap=function(_,_,fn) hook=fn end}},
  {ACCELGOR={frontY=0,backY=0}})
assert(Pic.front[681]==4 and Pic.back[681]==2,"Clearing an offset restores the original picture Y")
assert(Pic.front[700]==0 and Pic.back[700]==0,"A species left out of the saved offsets returns to its original Y")
local Positions=require("Gen3BattlePositions")
local project={}
assert(Positions.commit(project,"DWEBBLE",10,4).frontY==10)
assert(Positions.commit(project,"DWEBBLE",0,4).backY==4 and project.gen3BattlePositions.DWEBBLE.frontY==0)
assert(Positions.commit(project,"DWEBBLE",0,0)==nil)
assert(project.gen3BattlePositions==nil,"Zero offsets are removed instead of saved")
-- Editor preview: once the runtime has shifted PicCoords in this process
-- (Share/Validate run the mod), the preview must not add the offset twice.
do
  local Pic2={front={[681]=4},back={[681]=2}}
  package.loaded["src.core.game3.battle.pic_coords"]=Pic2
  local Ui2={battlerSpriteCenter=function(side,sp,base) return base.x,base.y+((side=="player" and Pic2.back or Pic2.front)[sp] or 0) end,
    bounceOffset=function() error("preview must not call bounceOffset") end}
  local rec={frontY=10,backY=-6}
  local function preview(back) return Positions.previewY(Ui2,back,681,back and {x=72,y=80} or {x=176,y=40},rec) end
  assert(preview(false)==54 and preview(true)==76,"Preview is vanilla pic Y plus the offset")
  rawset(Pic2,"_editorPositionBase",{[Pic2.front]={[681]=4},[Pic2.back]={[681]=2}})
  Pic2.front[681],Pic2.back[681]=14,-4
  assert(preview(false)==54 and preview(true)==76,"A shift the runtime already applied is not counted twice")
end
print("PASS: battle positions move picture coordinates, keep bounce lift, resolve live species ids and unload")
