local U=require("tests.drivers.util")
local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local dir=root.."/tests/content-editor/mega-ingame/shots"
local project=assert(loadfile(root.."/mods/Mega/Megas.editor_project.lua"))()
return function(game)
  local failures=0
  local function check(ok,label)
    print((ok and "PASS " or "FAIL ")..label)
    if not ok then failures=failures+1 end
    return ok
  end
  for _=1,900 do if game.phase=="boot" and game.boot then break end;U.wait(1) end
  game:_handleBootAction({action="new_game",name="RED"});U.wait(240)
  local Runtime=require("src.core.game3.runtime")
  local P=require("src.core.game3.pokemon")
  local Party=require("src.core.game3.party")
  local Bridge=require("src.core.game3.battle_bridge")
  local Battle=require("src.core.game3.battle")
  local Ui=require("src.core.game3.battle.ui")
  local Anim=require("src.core.game3.battle.anim")
  local session=assert(Runtime.getSession())
  local function pump(pred,limit)
    for i=1,limit or 6000 do
      if pred() then return true end
      if Ui.dialogPending() and not Anim.busy() and i%14==0 then U.tap(game,"a") else U.wait(1) end
    end
    print("TIMEOUT phase="..tostring(Battle._phase).." ui="..tostring(Ui._mode))
    return false
  end
  local function menu() return Battle.isActive() and Battle._phase=="command" and Ui._mode=="menu" end
  local function shot(name)
    game.capturePath=dir.."/"..name..".png"
    for _=1,4000 do if not game.capturePath then break end;U.wait(1) end
    local f=io.open(dir.."/"..name..".png","rb");check(f~=nil,"screenshot "..name);if f then f:close() end
  end
  for _,name in ipairs({"SHIFTRY","TORKOAL"}) do
    local family=project.gen3Forms[name]
    local base=assert(P.speciesFromName(name))
    local mega=project.pokemon[family.forms[2].species].index
    local item=project.items[family.forms[2].mechanic.item].index
    print("TEST "..name.." base="..base.." mega="..mega.." item="..item)
    session.party={};Party.giveMon(session,base,50)
    local mon=session.party[1];mon.item=item;mon.heldItem=item;mon.moves={33};mon.pp={35};mon.maxPp={35}
    check(mon.species==base,name.." starts as base in party")
    assert(Bridge.startWild(Runtime._mod,game,{species=25,level=3,moves={150},pp={40}},{fade=false}))
    assert(pump(menu),"Battle menu did not open")
    local st=Battle.getState()
    check(st.player.species==base and st.player.mon.species==base,name.." starts as base in battle")
    shot(name.."_01_base")
    U.tap(game,"a");U.wait(5)
    check(Ui._mode=="moves",name.." FIGHT opens move menu")
    U.tap(game,"select");U.wait(5)
    local request=st._editorAdvanced and st._editorAdvanced.requests[0]
    check(request and request.index==mega and request.source==base,name.." SELECT queues base -> Mega")
    shot(name.."_02_selected")
    st.enemy.mon.hp=1
    U.tap(game,"a")
    assert(pump(function() return st.player._editorAdvanced~=nil end),"Mega did not activate")
    check(st.player.species==mega,name.." Mega activates before the move")
    check(mon.species==base,name.." saved party identity remains base while Mega")
    shot(name.."_03_mega")
    assert(pump(function() return not Battle.isActive() end,10000),"Battle did not finish")
    check(st.result=="win",name.." completed battle by winning (result="..tostring(st.result)..")")
    check(mon.species==base and mon.speciesId==base,name.." returns to base in party after battle")
    check(not st._editorAdvanced and not st.player._editorAdvanced,name.." temporary Mega state cleared")
    check(mon.item==item,name.." Mega Stone retained")
    U.wait(30)
    assert(Bridge.startWild(Runtime._mod,game,{species=25,level=3,moves={150},pp={40}},{fade=false}))
    assert(pump(menu))
    check(Battle.getState().player.species==base,name.." next battle starts as base again")
    shot(name.."_04_next_battle_base")
    Battle.abort("run");U.wait(60)
  end
  print("RESULT: "..failures.." failure(s)")
  love.event.quit(failures==0 and 0 or 1)
end
