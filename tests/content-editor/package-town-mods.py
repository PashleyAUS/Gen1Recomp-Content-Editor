"""Package the exact mods and screenshots produced by the native town game test."""
import argparse
import json
import math
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from PIL import Image

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('games', nargs='*', default=['emerald', 'firered', 'leafgreen'])
args = parser.parse_args()
root = Path(__file__).resolve().parent / 'terrain3d-towns'
for game in args.games:
    if game not in {'emerald', 'firered', 'leafgreen'}:
        parser.error('Unsupported game: ' + game)
    folder = root / game
    manifest = json.loads((folder / 'mod' / 'manifest.json').read_text())
    assert manifest['games'] == [game]
    mod_id = manifest['id']
    readme = (
        manifest['name'] + ' (' + game + ')\n\n'
        'Extract the ' + mod_id + ' folder into the runtime mods directory and enable it for this game.\n'
        'Visit the original Littleroot Town (Emerald) or Pallet Town (FireRed/LeafGreen).\n'
        'Includes connected Route 101 (Emerald), or Route 1 and northern Route 21 (FireRed/LeafGreen).\n'
        'Native connections and Surf requirements are preserved.\n'
        'The mod does not move your save or bypass story events. Use a save after the introduction.\n'
        'Disable other town/map replacement mods while testing.\n'
        'The adjacent editor_project.lua is the editable content editor source.\n\n'
        'Validated through the real mod loader, Emerald/FireRed/LeafGreen gameplay update loop,\n'
        'directional input, native interior entrances/exits, slopes and centered follow camera.\n'
        'The 3D world renders at physical window resolution; the UI stays at 240x160.\n'
        'Town houses, upstairs bedrooms and labs use roofless 3D interiors with native collision and scripts.\n'
        'Camera: [ / ] rotate, Page Up / Page Down tilt, - / = zoom, Home resets.\n'
        'F6 switches between 2D and 3D during play; the view choice lasts for this session.\n'
        'Objects use complete native game artwork on upright or tilted planes, without reconstructed models.\n'
        'Known wall clocks, potted plants, signs and Pallet fences retain their original artwork.\n'
        'Editor: 3D Objects > Wall prop / Plant / Sign / Fence; Mount Z raises a prop above the floor.\n'
    )
    with ZipFile(folder / (mod_id + '.zip'), 'w', ZIP_DEFLATED) as archive:
        for file in (folder / 'mod').iterdir():
            if file.is_file():
                archive.write(file, mod_id + '/' + file.name)
        archive.write(folder / 'mod.editor_project.lua', mod_id + '.editor_project.lua')
        archive.writestr('README.txt', readme)
    cutoff = (folder / 'town-start.png').stat().st_mtime
    frames = [f for f in sorted(folder.glob('town-walk-*.png')) if f.stat().st_mtime >= cutoff]
    stride = max(1, math.ceil(len(frames) / 120))
    images = [Image.open(f).convert('RGB') for f in frames[::stride]]
    assert images, 'No current gameplay recording found'
    images[0].save(folder / 'town-walk.gif', save_all=True, append_images=images[1:],
                   duration=100 * stride, loop=0)
    print(game + ': packaged ' + mod_id + '.zip and ' + str(len(images)) + ' gameplay frames')

    frames = sorted((f for f in folder.glob('connection-*.png') if f.stat().st_mtime >= cutoff), key=lambda f: (f.stat().st_mtime, f.name))
    if frames:
        stride = max(1, math.ceil(len(frames) / 120))
        images = [Image.open(f).convert('RGB') for f in frames[::stride]]
        durations = [100 * stride if f.stem.removeprefix('connection-').isdigit() else 750 for f in frames[::stride]]
        images[0].save(folder / 'connections.gif', save_all=True, append_images=images[1:],
                       duration=durations, loop=0)
        print(game + ': packaged ' + str(len(images)) + ' connection gameplay frames')

    frames = sorted((f for f in folder.glob('*.png')
                     if f.stat().st_mtime >= cutoff and
                     (f.stem.startswith('interior-') or
                      (f.stem.startswith('door-') and f.stem.endswith(('-inside', '-upstairs', '-downstairs'))))),
                    key=lambda f: (f.stat().st_mtime, f.name))
    if frames:
        images = [Image.open(f).convert('RGB') for f in frames]
        images[0].save(folder / 'interiors.gif', save_all=True, append_images=images[1:],
                       duration=1200, loop=0)
        print(game + ': packaged ' + str(len(images)) + ' interior gameplay screenshots')

    frames = sorted((f for f in folder.glob('toggle-*.png') if f.stat().st_mtime >= cutoff),
                    key=lambda f: (f.stat().st_mtime, f.name))
    if frames:
        images = [Image.open(f).convert('RGB') for f in frames]
        images[0].save(folder / 'view-toggle.gif', save_all=True, append_images=images[1:],
                       duration=1200, loop=0)
        print(game + ': packaged ' + str(len(images)) + ' view toggle screenshots')
