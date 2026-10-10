"""Generates the Purrtion app icon: a pixel cat face inside a calorie progress ring."""
import math, sys
from PIL import Image, ImageDraw

def build(dark=False, tinted=False):
    """dark/tinted variants use a transparent background so iOS can draw its own (glassy) backdrop."""
    N = 32; S = 32
    clear = (0, 0, 0, 0)
    bg = clear if (dark or tinted) else '#FF8A4A'
    track = '#3A3442' if dark else '#F47436'
    prog = '#FF8A4A' if dark else '#FFF4E6'
    if tinted:
        track, prog = '#4A4A4A', '#FFFFFF'
    knob = '#FFC145'
    pal = {'o':'#3B2F3F','w':'#FFF4E6' if not dark else '#F6A25E','l':'#FFFFFF' if not dark else '#FFE6CC',
           'p':'#FF8FA3','e':'#2B2230','h':'#FFFFFF','c':'#FFB3C0','s':'#F3D9BC' if not dark else '#E07B39',
           'r':'#FF5A5F','R':'#C83C45','G':'#3E9E55','g':'#6BCB77','W':'#FFFFFF'}
    if tinted:  # grayscale: iOS applies the tint colour by luminance
        pal.update({'o':'#5A5A5A','w':'#E8E8E8','l':'#FFFFFF','p':'#A0A0A0','e':'#202020','h':'#FFFFFF',
                    'c':'#B8B8B8','s':'#C8C8C8','r':'#D0D0D0','R':'#9A9A9A','G':'#8A8A8A','W':'#FFFFFF'})
    grid = [[bg]*N for _ in range(N)]
    cx = cy = 15.5
    for y in range(N):
        for x in range(N):
            dx, dy = x - cx, y - cy
            r = math.hypot(dx, dy)
            if 10.6 <= r <= 13.9:
                ang = (math.degrees(math.atan2(dx, -dy)) + 360) % 360  # 0 at top, clockwise
                grid[y][x] = prog if ang <= 270 else track
    cat = [
        ".oo..........oo.",
        ".owo........owo.",
        ".opwo......owpo.",
        ".opwwoooooowwpo.",
        "owwwswwsswwswwwo",
        "owwwwwwwwwwwwwwo",
        "owwhewwwwwwhewwo",
        "owweewwwwwweewwo",
        "owweewwwwwweewwo",
        "owccwwwppwwwccwo",
        "owwwwwowwowwwwwo",
        "owwwwwwoowwwwwwo",
        ".owwwwwwwwwwwwo.",
        "..oooooooooooo..",
    ]
    ox, oy = 8, 8
    for y, row in enumerate(cat):
        for x, c in enumerate(row):
            if c in pal: grid[oy+y][ox+x] = pal[c]
    # tiny apple as the ring's end knob (at 270 deg -> left side)
    apple = ["..G.", ".rGr", "rWrr", "rrrR", ".rR."]
    ax, ay = 1, 12
    for y, row in enumerate(apple):
        for x, c in enumerate(row):
            if c in pal: grid[ay+y][ax+x] = pal[c]
    im = Image.new('RGBA', (N*S, N*S), clear)
    d = ImageDraw.Draw(im)
    for y in range(N):
        for x in range(N):
            d.rectangle([x*S, y*S, x*S+S-1, y*S+S-1], fill=grid[y][x])
    return im

out = sys.argv[1]
build(False).convert("RGB").save(f"{out}/AppIcon.png")
build(True).save(f"{out}/AppIcon-dark.png")
build(tinted=True).save(f"{out}/AppIcon-tinted.png")
