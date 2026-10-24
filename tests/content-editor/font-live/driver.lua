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
  local palette={fg={1,0,0,1},shadow={0,0,1,1},bg={0,0,0,0}}
  assert(F.advance(F.glyphId("i"))==6 and F.advance(F.glyphId("W"))==12)
  if os.getenv("FONT_EXPECT_E") then
    assert(F.advance(F.glyphId("E"))==tonumber(os.getenv("FONT_EXPECT_E")),"Saved UI letter width did not reach the game")
    print("PASS saved editor E width="..F.advance(F.glyphId("E")))
  end
  assert(F.measure("WiWi")==36 and F.measure("iii WWW")==58)
  if os.getenv("FONT_EXPECT_PIXEL")=="1" then
    local tile=love.graphics.newCanvas(16,16)
    love.graphics.push("all");love.graphics.setCanvas(tile);love.graphics.clear(0,0,0,0)
    F.drawGlyph(F.glyphId("W"),0,0,{colors=palette})
    love.graphics.pop()
    local data=tile:newImageData()
    local r,g,b,a=data:getPixel(15,0)
    assert(r>.9 and b<.1 and a>.9,"Painted foreground missing in game")
    r,g,b,a=data:getPixel(14,0)
    assert(b>.9 and r<.1 and a>.9,"Painted shadow missing in game")
    print("PASS app-painted foreground and shadow pixels reached the game")
  end
  local canvas=love.graphics.newCanvas(120,32)
  love.graphics.push("all");love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0)
  local _,pen=F.draw("WiWi",0,0,{colors=palette,small=true})
  love.graphics.pop();assert(pen==36)
  local pixels=canvas:newImageData();local red,blue=0,0
  for y=0,31 do for x=0,119 do local r,g,b,a=pixels:getPixel(x,y)
    if a>.5 and r>.9 and b<.1 then red=red+1 end
    if a>.5 and b>.9 and r<.1 then blue=blue+1 end
  end end
  assert(red>0 and blue>0,"Foreground/shadow colors were not rendered separately")
  local f=assert(io.open(dir.."/layer-pixels.png","wb"));f:write(pixels:encode("png"):getString());f:close()
  print("PASS layer pixel colors red="..red.." blue="..blue.."; per-letter widths and pen=36")
  Message.close();Message.show("WiWi iii WWW",{hold=true,colors=palette});U.wait(150)
  U.shot(game,dir.."/widths-shadows.png");U.wait(3)
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
