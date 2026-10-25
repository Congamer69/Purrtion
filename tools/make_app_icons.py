#!/usr/bin/env python3
"""Builds the alternative app icons (light, dark and tinted) from the default pixel icon.

The default icon is a 32x32 pixel grid. Every cell gets a role (background, ring, tail, face, outline, ...); each variant
recolours the roles and adds a few decoration pixels on the background. Output: Purrtion/Assets.xcassets/Icon<Name>.appiconset
and a small preview image set per icon for the picker in Profil → Darstellung.
"""
import json, os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CAT = os.path.join(ROOT, "Purrtion", "Assets.xcassets")
SRC = os.path.join(CAT, "AppIcon.appiconset", "AppIcon.png")
CELL = 32

def hex_rgb(h): h = h.lstrip("#"); return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))

# colours of the default icon → role
ROLE_OF = {"FF8A4A": "bg", "FFF4E6": "cream", "F47436": "tail", "3B2F3F": "outline", "2B2230": "eye", "FF5A5F": "apple", "C83C45": "appleDark",
           "3E9E55": "leaf", "FFFFFF": "white", "FF8FA3": "nose", "FFB3C0": "cheek", "F3D9BC": "stripe"}

def roles():
    im = Image.open(SRC).convert("RGB")
    grid = [[None] * 32 for _ in range(32)]
    for y in range(32):
        for x in range(32):
            h = "%02X%02X%02X" % im.getpixel((x * CELL + 16, y * CELL + 16))
            grid[y][x] = ROLE_OF.get(h, "bg")
    # cream inside the outline's box is the face, the rest is the ring
    pts = [(x, y) for y in range(32) for x in range(32) if grid[y][x] == "outline"]
    x0, x1 = min(p[0] for p in pts), max(p[0] for p in pts)
    y0, y1 = min(p[1] for p in pts), max(p[1] for p in pts)
    for y in range(32):
        for x in range(32):
            if grid[y][x] == "cream":
                grid[y][x] = "face" if x0 <= x <= x1 and y0 <= y <= y1 else "ring"
    return grid

BASE = {"nose": "FF8FA3", "cheek": "FFB3C0", "stripe": "F3D9BC", "eye": "2B2230", "white": "FFFFFF", "apple": "FF5A5F", "appleDark": "C83C45", "leaf": "3E9E55"}

# decoration: (x, y, colour); painted only where the background is
def stars(c1, c2, pts): return [(x, y, c1 if i % 2 == 0 else c2) for i, (x, y) in enumerate(pts)]
STAR_PTS = [(2, 2), (5, 5), (28, 1), (30, 6), (1, 12), (30, 15), (3, 24), (29, 25), (12, 1), (26, 30), (7, 30), (31, 20), (0, 18), (14, 30)]
CROSS = lambda x, y, c: [(x, y, c), (x - 1, y, c), (x + 1, y, c), (x, y - 1, c), (x, y + 1, c)]

VARIANTS = [
    dict(name="Midnight", label="Mitternacht", bg="25204A", ring="9A92F0", ringDark="9A92F0", tail="3A3270", face="FFF4E6", outline="1A1530",
         decor=CROSS(3, 3, "FFD86B") + CROSS(29, 8, "FFFFFF") + stars("FFD86B", "FFFFFF", STAR_PTS[3:])),
    dict(name="Mint", label="Minze", bg="3FC9A2", ring="F2FFF9", ringDark="5FE0BB", tail="2BA987", face="F7FFFB", outline="1F4D44",
         decor=CROSS(3, 3, "FFFFFF") + CROSS(29, 27, "D9FFF0") + stars("FFFFFF", "D9FFF0", STAR_PTS[3:10])),
    dict(name="Sakura", label="Sakura", bg="FF9EC1", ring="FFF1F6", ringDark="FFB3D0", tail="F276A5", face="FFF7FA", outline="5C2A45",
         decor=[(x, y, c) for (x, y, c) in stars("FFE0EC", "FFFFFF", [(2, 3), (3, 3), (6, 6), (29, 2), (30, 2), (27, 7), (2, 16), (1, 17), (30, 19), (29, 20), (4, 27), (5, 27), (28, 28), (27, 29), (31, 12), (12, 30)])]),
    dict(name="Retro", label="Retro", bg="8BAC0F", ring="CADC9F", ringDark="CADC9F", tail="306230", face="CADC9F", outline="0F380F", eye="0F380F",
         nose="306230", cheek="9BBC0F", stripe="8BAC0F", apple="306230", appleDark="0F380F", leaf="0F380F", white="CADC9F",
         decor=[(x, y, "9BBC0F") for (x, y) in [(2, 2), (4, 2), (3, 3), (28, 1), (30, 1), (29, 2), (1, 28), (3, 28), (2, 29), (29, 29), (30, 30), (31, 24)]]),
    dict(name="Dusk", label="Dämmerung", bg="FF8A4A", ring="FFF4E6", ringDark="FFB07A", tail="D9456B", face="FFF4E6", outline="3B2F3F",
         bands=["FFC27A", "FFA45F", "FF8A4A", "F0685A", "D9456B", "9A3F8E", "6B3F9A"],
         decor=[(x, y, "FFF4E6") for (x, y) in [(3, 28), (8, 30), (27, 29), (30, 26), (15, 31), (1, 24), (22, 30)]]),
    dict(name="Noir", label="Noir", bg="0E0D12", ring="FF8A4A", ringDark="FF8A4A", tail="B8501F", face="FFF4E6", outline="3B2F3F",
         decor=[(x, y, "2B2733") for (x, y) in STAR_PTS]),
    dict(name="Berry", label="Blaubeere", bg="4C7DFF", ring="EAF1FF", ringDark="8FB0FF", tail="2F58D6", face="F4F7FF", outline="1B2A5C",
         apple="6C4FD6", appleDark="4A34A3", leaf="3E9E55",
         decor=CROSS(3, 3, "FFFFFF") + CROSS(28, 29, "CFE0FF") + stars("FFFFFF", "CFE0FF", STAR_PTS[3:11])),
]

def palette(v, mode):
    p = dict(BASE)
    for k in ("apple", "appleDark", "leaf", "nose", "cheek", "stripe", "eye", "white"):
        if k in v: p[k] = v[k]
    p.update(face=v["face"], outline=v["outline"], tail=v["tail"], ring=v["ring"] if mode == "light" else v["ringDark"], bg=v["bg"])
    return p

GRAY = {"ring": "FFFFFF", "face": "E8E8E8", "tail": "4A4A4A", "outline": "5A5A5A", "eye": "202020", "apple": "D0D0D0", "appleDark": "8A8A8A",
        "leaf": "9A9A9A", "white": "FFFFFF", "nose": "A0A0A0", "cheek": "B8B8B8", "stripe": "C8C8C8"}

def render(grid, v, mode):
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    pal = palette(v, "light" if mode == "light" else "dark")
    deco = {(x, y): c for x, y, c in v["decor"] if 0 <= x < 32 and 0 <= y < 32}
    for y in range(32):
        for x in range(32):
            role = grid[y][x]
            if role == "bg":
                if (x, y) in deco:
                    col = deco[(x, y)] if mode != "tinted" else "D8D8D8"
                elif mode == "light":
                    col = v["bands"][min(len(v["bands"]) - 1, y * len(v["bands"]) // 32)] if "bands" in v else v["bg"]
                else:
                    continue                      # dark and tinted keep a transparent background
            else:
                col = GRAY[role] if mode == "tinted" else pal[role]
            block = Image.new("RGBA", (CELL, CELL), hex_rgb(col) + (255,))
            img.paste(block, (x * CELL, y * CELL))
    if mode == "light": img = img.convert("RGB").convert("RGBA")
    return img

def write(v, grid):
    name = "Icon" + v["name"]
    d = os.path.join(CAT, name + ".appiconset"); os.makedirs(d, exist_ok=True)
    files = {"light": name + ".png", "dark": name + "-dark.png", "tinted": name + "-tinted.png"}
    for mode, fn in files.items():
        im = render(grid, v, mode)
        (im.convert("RGB") if mode == "light" else im).save(os.path.join(d, fn))
    contents = {"images": [
        {"filename": files["light"], "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "dark"}], "filename": files["dark"], "idiom": "universal", "platform": "ios", "size": "1024x1024"},
        {"appearances": [{"appearance": "luminosity", "value": "tinted"}], "filename": files["tinted"], "idiom": "universal", "platform": "ios", "size": "1024x1024"}],
        "info": {"author": "xcode", "version": 1}}
    json.dump(contents, open(os.path.join(d, "Contents.json"), "w"), indent=2)
    # preview for the picker (an alternate app icon set cannot be loaded as an image)
    pd = os.path.join(CAT, "Preview" + v["name"] + ".imageset"); os.makedirs(pd, exist_ok=True)
    render(grid, v, "light").convert("RGB").resize((256, 256), Image.NEAREST).save(os.path.join(pd, "preview.png"))
    json.dump({"images": [{"filename": "preview.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, open(os.path.join(pd, "Contents.json"), "w"), indent=2)

if __name__ == "__main__":
    grid = roles()
    for v in VARIANTS: write(v, grid)
    # contact sheet for a quick look
    sheet = Image.new("RGB", (4 * 256, 3 * 256), (40, 40, 44))
    for i, v in enumerate(VARIANTS):
        for j, mode in enumerate(("light", "dark", "tinted")):
            im = render(grid, v, mode).resize((200, 200), Image.NEAREST)
            bg = Image.new("RGBA", im.size, (30, 30, 34, 255) if mode != "light" else (255, 255, 255, 255))
            bg.alpha_composite(im)
            sheet.paste(bg.convert("RGB"), ((i % 4) * 256 + 28, (i // 4) * 256 * 1 + 28)) if j == 0 else None
    print(" ".join(v["name"] for v in VARIANTS))
