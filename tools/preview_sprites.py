"""Render the sprites defined in PixelSprites.swift to a PNG sheet for visual checking."""
import re, sys
from PIL import Image, ImageDraw
src = open(sys.argv[1]).read()
pal = {'o':'#3B2F3F','w':'#F6A25E','l':'#FFE6CC','s':'#E07B39','p':'#FF8FA3','e':'#2B2230','h':'#FFFFFF','c':'#FF9EAE',
       'r':'#FF5A5F','R':'#C83C45','g':'#6BCB77','G':'#3E9E55','b':'#6EC6FF','B':'#3D8FD1','y':'#FFC145','n':'#9C6B4E',
       'k':'#C9C2D0','K':'#8F879A','W':'#FFFFFF','a':'#FF8A4A','A':'#D9662B','m':'#E08A6A','M':'#B8583C','Y':'#E0A22E'}
sprites = re.findall(r'static let (\w+) = PixelSprite\(\[(.*?)\]\)', src, re.S)
S = 10
imgs = []
for name, body in sprites:
    rows = re.findall(r'"([^"]*)"', body)
    w = max(len(r) for r in rows); h = len(rows)
    widths = {len(r) for r in rows}
    if len(widths) > 1: print("WARN uneven rows", name, widths)
    im = Image.new('RGB', (w*S+20, h*S+30), '#F6EEE6')
    d = ImageDraw.Draw(im)
    for y, r in enumerate(rows):
        for x, c in enumerate(r):
            if c in pal: d.rectangle([10+x*S, 20+y*S, 10+x*S+S-1, 20+y*S+S-1], fill=pal[c])
    d.text((10, 4), name, fill='black')
    imgs.append(im)
W = sum(i.width for i in imgs[:6]); 
cols = 6
rows_n = (len(imgs)+cols-1)//cols
cw = max(i.width for i in imgs); ch = max(i.height for i in imgs)
sheet = Image.new('RGB', (cw*cols, ch*rows_n), '#F6EEE6')
for i, im in enumerate(imgs):
    sheet.paste(im, ((i%cols)*cw, (i//cols)*ch))
sheet.save(sys.argv[2])
