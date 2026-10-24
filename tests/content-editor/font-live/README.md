# Live Gen 3 language font verification

## Shadow and width verification — October 24, 2026

The fixture now has separate foreground and shadow PNGs, with `i` advancing
6 pixels, `W` 12 pixels, and space 4 pixels. All five game runs passed pixel
checks for independently colored red foreground and blue shadow, the 36-pixel
pen position for `WiWi`, and normal multilingual dialogue rendering.
See each game's `widths-shadows.png` and `layer-pixels.png`.

In the live editor, validated and previewed both sheets, changed E's width
from inherited to 8 using its Width field, and saved. The sidecar retained
both the width override and shadow sheet. Reopened the project successfully
and verified the saved E width of 8 in a fresh FireRed game run using
`FONT_EXPECT_E=8` without regenerating fixtures.
Also fixed the preview disappearing and shifting the form while editing widths.
`shadow-width-matrix.png` compares the two-color, variable-width sample in all
five games. Each run counted 86 red foreground pixels and 78 blue shadow pixels
in the dedicated small-font render check.

Headless tests cover width reset/inheritance, preserving widths during other
mapping edits, mismatched sheet rejection, invalid width rejection, layer order,
independent colors, normal/small rendering, wrapping and export round trips.

Verified October 23, 2026 using the real LÖVE editor, imported game caches,
exported mods, and the runtime's frame driver. All game saves and options are
isolated under this directory; normal player saves are not used.

## Results

| Game | Spanish | French | Greek | Russian | Japanese | Chinese | Multiline |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FireRed | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| LeafGreen | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Emerald | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Ruby | Pass | Pass | Pass | Pass | Pass | Pass | Pass |
| Sapphire | Pass | Pass | Pass | Pass | Pass | Pass | Pass |

Each game's directory contains six dialogue captures, a multiline capture and
the runtime log. `language-matrix.png` compares the six samples across games.
The tests cover these samples, not every character or every UI screen.

In the live editor, checked sheet validation/preview, scrolling, Unicode
mapping display, keyboard editing of a mapping containing Chinese, and Save.
Verified the saved sidecar retained `好a` after adding an ASCII suffix to `好`.
Automated Windows Unicode text injection did not reach SDL; native IME input
was not verified. UTF-8 mappings were loaded from the fixture and rendered in
the actual editable fields.

Found and fixed missing Japanese/Chinese characters in the editor's mapping
fields by adding the bundled Plain Pixel font as a UI fallback. Rechecked the
fields visually. The first test atlas also exposed incorrect baseline placement
in the test fixture; its rasterization now aligns each glyph within its cell.
Final captures were regenerated with the corrected fixture.

Fixtures rasterize the bundled Plain Pixel font (Douglas Vautour, CC-BY 4.0;
see runtime/gen1recomp/assets/fonts/plainpixel/README.md) into 16×16 cells with
12-pixel advance. This verifies font mapping, rendering, and word wrapping;
it does not test shaping or right-to-left scripts.

## Reproduce

From the repository root, set `EDITOR_TEST_ROOT` to the absolute repository
path, `POKEPORT_RECOMP` to its runtime/gen1recomp directory, `POKEPORT_GAME` to
the game ID, and `POKEPORT_GEN3_CACHE` to that game's imported cache directory.
Create `tests/content-editor/font-live/<game>/save/mods/language_test/assets/font`.

1. Set `FONT_TEST_MODE=prepare`; run `love/lovec.exe tests/content-editor/font-live`.
2. Set `FONT_TEST_MODE=game` and `POKEPORT_DRIVER` to the absolute path of
   `tests/content-editor/font-live/driver.lua`.
3. Run `love/lovec.exe tests/content-editor/font-live --game=<game>`.
4. Confirm `PASS live game languages` in the game's result.log and inspect PNGs.

Use `FONT_TEST_MODE=editor` to open the actual editor on the disposable project.
Use `FONT_TEST_HOLD=1` for an in-game window that stays open after capturing.

## Direct pixel editing

`FONT_TEST_MODE=pixel-test` runs actual LÖVE image tests for blank sheets,
foreground/shadow strokes, erasing, undo/redo, sheet growth, neighboring glyph
preservation, cancellation, failed writes, and serialization/runtime roundtrip.

The Draw canvas was also exercised in the real editor: painted W foreground
at (15, 0) and shadow at (14, 0), applied the glyph, and saved. Running the
FireRed game with `FONT_EXPECT_PIXEL=1` verified those exact pixels rendered
red and blue respectively, alongside the six language dialogue checks.
The result is recorded in `firered/result.log`. This optional assertion requires
the saved UI edits; preparing a fresh fixture replaces them.
