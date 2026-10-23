local root=assert(os.getenv("EDITOR_TEST_ROOT")):gsub("\\","/")
local runtime=root.."/runtime/gen1recomp"
local dir=root.."/tests/content-editor/font-live"
local game=os.getenv("POKEPORT_GAME") or "firered"
local cache=assert(os.getenv("POKEPORT_GEN3_CACHE")):gsub("\\","/")
local mode=os.getenv("FONT_TEST_MODE") or "editor"
local run=dir.."/"..game
package.path=root.."/tools/content-editor/?.lua;"..root.."/tools/content-editor/panels/?.lua;"..root.."/tools/save-editor/?.lua;"..runtime.."/?.lua;"..package.path
local function write(path,s) local f=assert(io.open(path,"wb"));f:write(s);f:close() end
local function log(s) local f=assert(io.open(run.."/result.log","ab"));f:write(tostring(s),"\n");f:close() end
print=function(...) local s={};for i=1,select('#',...) do s[i]=tostring(select(i,...)) end;log(table.concat(s," ")) end
love.errorhandler=function(err) log(debug.traceback(tostring(err)));return function() return 1 end end
local ffi=require("ffi");ffi.cdef("int PHYSFS_mount(const char*,const char*,int); int PHYSFS_setWriteDir(const char*);")
local lib=ffi.load(root.."/love/love.dll")
assert(lib.PHYSFS_setWriteDir(run.."/save")~=0)
assert(lib.PHYSFS_mount(run.."/save","",0)~=0)
assert(lib.PHYSFS_mount(runtime,"",1)~=0);assert(lib.PHYSFS_mount(root,"",1)~=0)
assert(lib.PHYSFS_mount(cache,game,0)~=0);assert(lib.PHYSFS_mount(cache,"",0)~=0)
assert(lib.PHYSFS_mount(cache.."/data/generated","data/generated",0)~=0)
lib.PHYSFS_mount(cache.."/assets/generated","assets/generated",0)
love.filesystem.getSaveDirectory=function() return run.."/save" end
require("src.core.GameVersion").set(game)
if mode=="game" then
  local getItems=love.filesystem.getDirectoryItems
  love.filesystem.getDirectoryItems=function(path) if path=="mods" then return {"language_test"} end;return getItems(path) end
  dofile(runtime.."/main.lua")
  return
end
local App,S
function love.load()
  local p=require("State").blankProject("language_test");p.game=game
  local samples={"Español: ¡Hola! café","Français: été Noël","Ελληνικά: Γειά","Русский: Привет","日本語: こんにちは","中文: 你好"}
  local font=love.graphics.newFont("assets/fonts/plainpixel/PlainPixel-Regular.ttf",15)
  local chars,seen={},{}
  local utf8=require("utf8")
  for _,sample in ipairs(samples) do for _,code in utf8.codes(sample) do
    local c=utf8.char(code)
    assert(font:hasGlyphs(c),"Fixture font missing "..c)
    if not seen[c] then seen[c]=true;chars[#chars+1]=c end
  end end
  local canvas=love.graphics.newCanvas(256,math.ceil(#chars/16)*16)
  love.graphics.push("all");love.graphics.setCanvas(canvas);love.graphics.clear(0,0,0,0);love.graphics.setFont(font);love.graphics.setColor(1,1,1,1)
  local page={image="assets/font/languages.png",base=256,glyphsPerRow=16,cellWidth=16,cellHeight=16,advance=12,charmap={}}
  for i,c in ipairs(chars) do
    love.graphics.print(c,(i-1)%16*16,math.floor((i-1)/16)*16 + 12 - font:getBaseline())
    page.charmap[i]={seq=c,code=255+i}
  end
  love.graphics.pop()
  local path=run.."/save/mods/language_test"
  write(path.."/assets/font/languages.png",canvas:newImageData():encode("png"):getString())
  p.gen3Fonts={languages=page}
  local W=require("ModWriter")
  write(path..".editor_project.lua",W.serializeProject(p))
  write(path.."/main.lua",require("Gen3").emit(p,W.encodeLua))
  write(path.."/manifest.json",require("src.link.Json").encode({id=p.id,name="Language Test",version="0.1.0",api=2,entry="main.lua",profile="content",games={game},permissions={"engine_internals"}}))
  write(run.."/samples.lua",W.encodeLua(samples))
  write(run.."/save/options.lua",'return {textSpeed=3,mods={language_test=true},modsByVersion={["'..game..'"]={language_test=true}},modsByVersionMigrated=true}')
  if mode=="prepare" then log("FIXTURE READY");love.event.quit();return end
  App=require("App");App.load(path,{version=game,eventWindow=true});S=App.getState()
  assert(S.project.gen3Fonts.languages.charmap[1].seq==page.charmap[1].seq,"Reopen lost mappings")
  S.tab="ui";S.g3UiMode="fonts";S.uiFontId="languages"
  log("EDITOR READY: "..#chars.." glyphs; exported and reopened project")
end
function love.update(dt) if App then App.update(dt) end end
function love.draw() if App then App.draw() end end
function love.textinput(t) App.textinput(t) end
function love.keypressed(k) App.keypressed(k) end
function love.mousepressed(x,y,b) App.mousepressed(x,y,b) end
function love.mousereleased(x,y,b) App.mousereleased(x,y,b) end
function love.wheelmoved(x,y) App.wheelmoved(x,y) end
