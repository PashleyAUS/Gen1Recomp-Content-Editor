local U=require("tests.drivers.util")
return function(game)
  for _=1,900 do if game.phase=="boot" and game.boot then break end;U.wait(1) end
  game:_handleBootAction({action="new_game",name="RED"});U.wait(240)
  assert(require("src.core.game3.runtime").getSession(),"No game session")
  local F=require("src.ui.game3.frlg_font")
  assert(F.customGlyph("あ") or F.customGlyph("こ"),"Language mod did not load")
  local samples={"Español: ¡Hola! café","Français: été Noël","Ελληνικά: Γειά","Русский: Привет","日本語: こんにちは","中文: 你好"}
  local Message=require("src.ui.game3.message")
  local dir=os.getenv("EDITOR_TEST_ROOT").."/tests/content-editor/font-live/"..os.getenv("POKEPORT_GAME")
  for i,text in ipairs(samples) do
    Message.close();Message.show(text,{hold=true});U.wait(150)
    U.shot(game,dir.."/language-"..i..".png");U.wait(3)
    print("PASS dialogue "..text.." width="..F.measure(text))
  end
  Message.close();Message.show("日本語: こんにちは\n中文: 你好",{hold=true});U.wait(150)
  U.shot(game,dir.."/multiline.png");U.wait(3)
  print("PASS live game languages")
  if os.getenv("FONT_TEST_HOLD")=="1" then while true do U.wait(60) end end
  love.event.quit()
end
