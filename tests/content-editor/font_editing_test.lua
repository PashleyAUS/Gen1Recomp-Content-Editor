-- Run from the repository root with tools/tooling/luajit/luajit.exe.
package.path = "tools/content-editor/?.lua;tools/content-editor/panels/?.lua;" .. package.path
local click, edits = nil, {}
local noop = function() end
for _, name in ipairs({"Preview", "UiMenus", "Generation", "ChoicePicker",
    "SpeciesPicker", "ColorWheel", "UiSafe", "UiScripts"}) do package.loaded[name] = {} end
package.loaded.Theme = { PAL = {} }
package.loaded.State = { ensureProjectFields = noop }
package.loaded.FormPane = { finish = noop }
package.loaded.UiPreview = { draw = function(_, _, _, y) return y end }
package.loaded.Kit = { scale = 1, text = noop, caption = noop,
  button = function(_, _, _, _, label)
    if label == click then click = nil; return true end
    return false
  end }
local list = require("RegList")
list.drawList = function(_, _, _, y, _, h, _, ids) return 220, 600, y, h, ids end
list.beginForm = function(_, x, y, w) return y, {}, x, w end
list.field = function(_, id, _, _, _, _, value) return edits[id] or value end
local Ui = require("Ui")
local draw
for i = 1, 100 do
  local name, value = debug.getupvalue(Ui.draw, i)
  if not name then break end
  if name == "drawFonts" then draw = value end
end
assert(draw, "font panel is reachable")
local dirty = 0
local App = { markDirty = function() dirty = dirty + 1 end }
local original = { image = "font.png", base = 128, glyphsPerRow = 16,
  charmap = {{seq = "A", code = 128}} }
local S = { project = {}, data = {font = {pages = {main = original}}}, uiFontId = "main" }
local function frame() draw(S, 0, 0, 900, 800, App) end
edits.ui_font_map_main_1 = "é"
frame()
assert(original.charmap[1].seq == "A", "editing must not mutate imported data")
assert(S.project.font.main.charmap[1].seq == "é")
edits = {}; click = "+ Font page"; frame()
local page = S.project.font[S.uiFontId]
assert(page._isNew and page.base >= 256)
S.uiFontNewChar = "あ"; click = "Add glyph"; frame()
assert(page.charmap[1].seq == "あ" and page.charmap[1].code == page.base)
S.uiFontNewChar = "あ"; click = "Add glyph"; frame()
assert(#page.charmap == 1, "duplicate additions must be ignored")
click = "Remove"; frame(); assert(#page.charmap == 0)
local before = dirty
edits.ui_font_base = "1024"; frame()
assert(page.base == 1024 and dirty > before, "existing page changes must mark dirty")
print("font editing tests passed")
package.loaded.Generation.isGen3 = function() return true end
local G = {project={},data={}}
click="+ Font page"; draw(G,0,0,900,800,App)
assert(G.project.gen3Fonts.language_1 and not G.project.font)
G.uiFontNewChar="界";click="Add glyph";draw(G,0,0,900,800,App)
assert(G.project.gen3Fonts.language_1.charmap[1].seq=="界")
print("Gen 3 font panel isolation passed")
edits={ui_font_map_language_1_1_advance="5",ui_font_shadow_language_1="assets/font/shadow.png"}
draw(G,0,0,900,800,App)
assert(G.project.gen3Fonts.language_1.charmap[1].advance==5)
edits={ui_font_map_language_1_1="語"};draw(G,0,0,900,800,App)
assert(G.project.gen3Fonts.language_1.charmap[1].advance==5,"editing a sequence must preserve width")
edits={ui_font_map_language_1_1_advance=""};draw(G,0,0,900,800,App)
assert(G.project.gen3Fonts.language_1.charmap[1].advance==nil)
assert(G.project.gen3Fonts.language_1.shadowImage=="assets/font/shadow.png")
print("Shadow field and per-letter width editing passed")
