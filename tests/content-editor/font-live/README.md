# Live Gen 3 language font verification

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
