return function(game)
 local U=require("tests.drivers.util")
 local Mon=require("src.battle.gen2.Mon")
 local Anim=require("src.ui.gen2.EvolutionAnim")
 local Party=require("src.ui.gen2.PartyMenu")
 local Pack=require("src.ui.gen2.PackMenu")
 local shots=assert(os.getenv("POKEPORT_SHOT_DIR"))
 local failed=false
 local function check(ok,label) print((ok and "PASS " or "FAIL ")..label);failed=failed or not ok;return ok end
 local function waitFor(fn,n) for i=1,n or 1800 do if fn() then return true end;U.wait(1) end;return fn() end
 game:continueGame(require("src.core.gen2.Save").newGame())
 U.wait(60)
 game.save.party={Mon.new(game.data,"WEEPINBELL",30),Mon.new(game.data,"PIKACHU",20)}
 game.save.inventory={CUSTOM_STONE=2};game.save.bagOrder={"CUSTOM_STONE"}
 game:pushStartMenuItem("pack")
 U.wait(20)
 local pack=game.stack:top()
 if not check(getmetatable(pack)==Pack,"custom stone pack opened") then love.event.quit(1);return end
 U.shot(game,shots.."/01-custom-stone-pack.png")
 U.tap(game,"a");U.wait(20);U.tap(game,"a")
 if not check(waitFor(function() return getmetatable(game.stack:top())==Party end,300),"custom stone party picker") then love.event.quit(1);return end
 U.shot(game,shots.."/02-custom-stone-party.png")
 U.tap(game,"a")
 if not check(waitFor(function() return getmetatable(game.stack:top())==Anim end,300),"custom stone evolution animation started") then love.event.quit(1);return end
 U.wait(100);U.shot(game,shots.."/03-custom-stone-evolving.png")
 for i=1,900 do if game.save.party[1].species=="VICTREEBEL" and getmetatable(game.stack:top())~=Anim then break end;U.tap(game,"a");U.wait(3) end
 check(game.save.party[1].species=="VICTREEBEL","custom stone evolved WEEPINBELL to VICTREEBEL")
 check(game.save.inventory.CUSTOM_STONE==1,"one custom stone consumed")
 U.shot(game,shots.."/04-custom-stone-result.png")
 print(failed and "FAIL evolution_stone" or "PASS evolution_stone")
 love.event.quit(failed and 1 or 0)
end
