import os, struct, zlib
from pathlib import Path
from PIL import Image, ImageDraw
root=Path(__file__).parent
groups={}
for line in (root/'props-catalog.tsv').read_text().splitlines():
    game,id,pair,x,y,mid=line.split('\t')
    groups.setdefault((game,id,pair),[]).append((int(x),int(y),int(mid)))
for (game,id,pair),cells in groups.items():
    folder=Path(os.environ['APPDATA'])/'LOVE/pokemon-love2d'/game/'data/generated/gba/native'/pair
    pals=struct.unpack('<256H',(folder/'palettes.bin').read_bytes()[8:])
    blobs=[zlib.decompress((folder/n).read_bytes()) for n in ('mids.idx','mids_over.idx')]
    count=struct.unpack_from('<H',blobs[0],6)[0]
    ids=struct.unpack_from('<'+str(count)+'H',blobs[0],12)
    out=Image.new('RGB',((max(x for x,y,m in cells)+1)*48,(max(y for x,y,m in cells)+1)*58))
    draw=ImageDraw.Draw(out)
    for x,y,mid in cells:
        if mid not in ids: continue
        tile=Image.new('RGB',(16,16));slot=ids.index(mid)
        for layer,blob in enumerate(blobs):
            for k,v in enumerate(blob[12+count*2+slot*256:12+count*2+(slot+1)*256]):
                if v%16 or layer==0:
                    c=pals[v];tile.putpixel((k%16,k//16),tuple(round((c//(32**n)%32)*255/31) for n in range(3)))
        out.paste(tile.resize((48,48)),(x*48,y*58))
        draw.text((x*48,y*58+47),str(mid),fill='white')
    out.save(root/('inspect-'+id+'.png'))
