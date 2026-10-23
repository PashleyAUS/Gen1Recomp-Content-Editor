local M = {}

function M.validate(pages)
  local codes, sequences = {}, {}
  local function integer(v, low, high)
    return type(v) == "number" and v == math.floor(v) and v >= low and v <= high
  end
  for _, page in pairs(pages) do
    assert(type(page) == "table", "Invalid font page")
    assert(type(page.image) == "string" and page.image:match("^assets/.*%.png$")
      and not page.image:find("..", 1, true) and not page.image:find("\\", 1, true), "Font sheet must be a mod assets PNG")
    assert(integer(page.base, 0, 65535), "Font Base must be 0–65535")
    assert(integer(page.glyphsPerRow, 1, 256), "Glyphs/row must be 1–256")
    assert(integer(page.advance or 8, 1, 64), "Font Advance must be 1–64")
    assert(integer(page.cellWidth or 8, 1, 32) and integer(page.cellHeight or 8, 1, 32), "Font tile dimensions must be 1–32")
    for _, row in ipairs(page.charmap or {}) do
      assert(type(row.seq) == "string" and row.seq ~= "" and not row.seq:find("[%c{}]"), "Font mappings cannot contain control characters or braces")
      -- Validate UTF-8 without relying on Lua 5.3's utf8 library.
      local i = 1
      while i <= #row.seq do
        local b = row.seq:byte(i)
        local n = b < 128 and 1 or b >= 194 and b <= 223 and 2 or b >= 224 and b <= 239 and 3 or b >= 240 and b <= 244 and 4
        assert(n and i + n - 1 <= #row.seq, "Font mapping must be valid UTF-8")
        for j = 1, n - 1 do local c = row.seq:byte(i+j); assert(c >= 128 and c <= 191, "Font mapping must be valid UTF-8") end
        local c = row.seq:byte(i+1)
        assert(not (b == 224 and c < 160 or b == 237 and c >= 160 or b == 240 and c < 144 or b == 244 and c >= 144), "Invalid Unicode codepoint")
        i = i + n
      end
      assert(integer(row.code, page.base, 65535), "Glyph code must be at least the page Base and at most 65535")
      assert(not sequences[row.seq], "Duplicate font character mapping: " .. row.seq)
      assert(not codes[row.code] or codes[row.code] == page, "Font pages contain overlapping mapped codes")
      sequences[row.seq], codes[row.code] = true, page
    end
  end
end

function M.build(pages, imageLoader, quadBuilder)
  M.validate(pages)
  local glyphs, sequences = {}, {}
  for _, page in pairs(pages) do
    local image = imageLoader(page.image)
    local width, height = image:getDimensions()
    local cw, ch = page.cellWidth or 8, page.cellHeight or 8
    assert(width == page.glyphsPerRow * cw and height >= ch and height % ch == 0, "Font PNG must match Glyphs/row and contain whole tiles")
    for _, row in ipairs(page.charmap or {}) do
      local index = row.code - page.base
      assert(index < page.glyphsPerRow * height / ch, "Mapped glyph is outside the font PNG: " .. row.seq)
      local id = 0x100000 + row.code
      local glyph = { id = id, image = image, advance = page.advance or 8,
        quad = quadBuilder(index % page.glyphsPerRow * cw, math.floor(index / page.glyphsPerRow) * ch, cw, ch, width, height) }
      glyphs[id], glyphs[row.seq] = glyph, glyph
      sequences[#sequences+1] = row.seq
    end
  end
  table.sort(sequences, function(a,b) return #a > #b end)
  return glyphs, function(text, offset)
    for _, seq in ipairs(sequences) do if text:sub(offset, offset+#seq-1) == seq then return seq end end
  end
end

function M.install(mod, pages)
  M.validate(pages)
  local Font = require("src.ui.game3.frlg_font")
  assert(Font.customGlyph and Font.customMatch, "Language fonts require an updated Gen1Recomp runtime")
  local Runtime = require("src.mods.Runtime")
  if not Font._editorLanguageDispatch then
    Font._editorLanguageDispatch = true
    for _, name in ipairs({"customGlyph", "customMatch"}) do
      local base = Font[name]
      Font[name] = function(...) return Runtime.call("editor.gen3.font."..name, base, ...) end
    end
  end
  local glyphs, match
  local function load()
    if not glyphs then
      glyphs, match = M.build(pages, function(path)
        local image = mod.assets:image(path); image:setFilter("nearest", "nearest"); return image
      end, love.graphics.newQuad)
    end
  end
  mod.hooks:wrap("editor.gen3.font.customGlyph", function(proceed, key, opts)
    load(); return glyphs[key] or proceed(key, opts)
  end)
  mod.hooks:wrap("editor.gen3.font.customMatch", function(proceed, text, offset)
    load(); return match(text, offset) or proceed(text, offset)
  end)
end
return M
