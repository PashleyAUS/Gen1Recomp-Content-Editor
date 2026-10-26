-- A connected path through the existing map, script and runtime editors.
local M={}
function M.draw(S,x,y,w,h,App)
  local K=require("Kit");local P=require("ChoicePicker");local s=K.scale
  local top,view=require("FormPane").begin(S,"adventureWorkflow",x,y,w,h)
  y=top;w=view.contentW
  if S._adventureProject~=S.project then
    S._adventureProject=S.project
    S.adventure={kind="branch",place=true,x="2",y="2",graphics="19",
      text="Will you help me?",yes="Thank you! Let's begin.",no="Come back when you are ready."}
  end
  local d=S.adventure
  local function caption(text) K.caption(x,y,K.ellipsize("micro",text,w));y=y+28*s end
  local function field(key,label)
    caption(label);d[key]=K.textfield("adventure/"..key,x,y,w,28*s,tostring(d[key] or ""),"");y=y+36*s
  end
  local function button(label,fn)
    if K.button(x,y,math.min(w,320*s),28*s,label,{}) then fn() end
    y=y+36*s
  end
  caption("1. BUILD A MAP")
  caption("Create a map in Maps. Paint terrain, collision, and doors, then return here.")
  button("Open Maps",function() S.tab="maps";if d.map then S.mapId=d.map end end)
  local maps=require("RegList").mergeIds(S.project.maps or {},require("Generation").dataMaps(S) or {})
  if not d.map then d.map=S.mapId or maps[1] end
  P.field(S,{x=x,y=y,w=w,h=28*s,ids=maps,current=d.map,title="SCENE MAP",onPick=function(id) d.map=id;d.npc=nil;d.created=nil end});y=y+38*s
  caption("2. ADD OR CHOOSE A CHARACTER")
  P.field(S,{x=x,y=y,w=w,h=28*s,ids={"new","existing"},current=d.place and "new" or "existing",
    labels={new="Place a new character",existing="Use an existing character"},title="CHARACTER",
    onPick=function(id) d.place=id=="new";d.created=nil end});y=y+38*s
  local map=(S.project.maps or {})[d.map] or (require("Generation").dataMaps(S) or {})[d.map]
  if d.place then
    field("x","Tile column (0 is the left edge)");field("y","Tile row (0 is the top edge)")
    local ids,labels={},{}
    for path in pairs(require("Gen3Resources").assets(S.data,S.project)) do
      local id=path:match("/ow/(%d+)%.rgba$")
      if id and not labels[id] then ids[#ids+1]=id;labels[id]=require("Gen3SpriteNames").label(S,id) end
    end
    if not labels[d.graphics] then ids[#ids+1]=d.graphics;labels[d.graphics]=require("Gen3SpriteNames").label(S,d.graphics) end
    table.sort(ids,require("Gen3Labels").natural)
    P.field(S,{x=x,y=y,w=w,h=28*s,ids=ids,labels=labels,current=d.graphics,title="CHARACTER SPRITE",onPick=function(id) d.graphics=id end});y=y+38*s
  else
    local ids,labels={},{}
    for i,o in ipairs(map and map.objects or {}) do
      local id=tostring(i);ids[#ids+1]=id;labels[id]="Character "..tostring(o.localId or i).." at "..tostring(o.x)..", "..tostring(o.y)
    end
    P.field(S,{x=x,y=y,w=w,h=28*s,ids=ids,labels=labels,current=d.npc,title="EXISTING CHARACTER",onPick=function(id) d.npc=id;d.created=nil end});y=y+38*s
    caption("Creating replaces this character's interaction. Use Undo to restore it.")
  end
  caption("3. CREATE A BRANCHING CUTSCENE")
  field("text","Question shown before the Yes / No choice")
  field("yes","What happens when the player says Yes")
  field("no","What happens when the player says No")
  button("Create and attach cutscene",function()
    local request=require("src.mods.Merge").deepCopy(d)
    request.x=tonumber(d.x);request.y=tonumber(d.y)
    local id,err=require("Gen3EventBuilder").create(S,request)
    if id then
      d.created=id;d.npc=tostring(d.place and #S.project.maps[d.map].objects or d.npc)
      d.place=false;App.markDirty();S.status="Cutscene attached. Talk to the character to run it."
    else S.status=err end
  end)
  if d.created and ((S.project.gen3 or {}).map_scripts or {})[d.created] then
    caption("Add dialogue, movement and timing in the maker for each story path.")
    for _,part in ipairs({{"Question",d.created},{"Yes path",d.created.."_Yes"},{"No path",d.created.."_No"}}) do
      local id=part[2]
      button("Edit "..part[1],function()
        S.g3CutsceneId=id;S.g3CutsceneView=false;S.g3EventMode="cutscenes";S._cutscenePlayer=nil
      end)
    end
    button("Show character on map",function()
      S.mapId=d.map;S.mapObjectIndex=tonumber(d.npc);S.mapSection="objects";S.mapEditMode="events";S.tab="maps"
    end)
    caption("4. PREVIEW AND PLAYTEST")
    caption("Restart the viewer and try both answers. Game playtest runs real movement and effects.")
    button("Preview both story paths",function()
      S.g3CutsceneId=d.created;S.g3CutsceneView=true;S.g3EventMode="cutscenes";S._cutscenePlayer=nil
    end)
    button("Playtest this cutscene",function()
      local object=((S.project.maps[d.map] or {}).objects or {})[tonumber(d.npc)]
      if object then
        local request,err=require("Gen3EventPlaytest").request(S,d.created,d.map,object,object.localId or tonumber(d.npc))
        if request then App.playtestMod(request) else S.status=err end
      else S.status="Choose the character again; it is no longer on this map." end
    end)
  else
    caption("For an existing scene, open Cutscenes to edit or preview its attached script.")
    button("Open cutscene maker / viewer",function() S.g3EventMode="cutscenes" end)
  end
  caption("5. SAVE AND SHARE")
  caption("Validate and playtest your mod, then export a ZIP from Project > Share mod.")
  button("Open Project checks and sharing",function() S.tab="project" end)
  require("FormPane").finish(S,"adventureWorkflow",top,y,view)
end
return M
