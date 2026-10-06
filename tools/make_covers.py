"""Makes the CrazyGames cover images from the game's own sprites.

Usage: python3 tools/make_covers.py ["GAME TITLE"]
Writes store/cover_landscape_1920x1080.png, store/cover_portrait_800x1200.png
and store/cover_square_800x800.png (needs Pillow + numpy).

The scene is drawn small (pixel art) and scaled up with nearest-neighbour,
then night lighting and the title are added. Only the title is written on
the covers, as CrazyGames asks.
"""
import os
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..")
SPR = os.path.join(ROOT, "assets", "sprites")
OUT = os.path.join(ROOT, "store")
TITLE = sys.argv[1] if len(sys.argv) > 1 else "ZOMBIE VILLAGE"

_cache = {}


def img(name):
    if name not in _cache:
        _cache[name] = Image.open(os.path.join(SPR, name + ".png")).convert("RGBA")
    return _cache[name]


def frame(sheet, col, row, cols=6, rows=3, flip=False):
    s = img(sheet)
    fw, fh = s.width // cols, s.height // rows
    f = s.crop((col * fw, row * fh, col * fw + fw, row * fh + fh))
    return f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f


def tile(i):
    return img("tiles").crop((i * 16, 0, i * 16 + 16, 16))


class Scene:
    def __init__(self, w, h, seed=3):
        self.w, self.h = w, h
        self.base = Image.new("RGBA", (w, h))
        self.items = []          # (foot_y, image, x, y)
        self.lights = []         # (x, y, radius, (r, g, b), strength)
        self.r = random.Random(seed)

    def ground(self, road_y, cobble=None):
        r = self.r
        for y in range(0, self.h, 16):
            for x in range(0, self.w, 16):
                v = r.random()
                t = 4 if v < 0.06 else (14 if v < 0.12 else r.randint(0, 3))
                self.base.alpha_composite(tile(t), (x, y))
        for y in range(road_y, road_y + 48, 16):
            for x in range(0, self.w, 16):
                self.base.alpha_composite(tile(6 + r.randint(0, 2)), (x, y))
        if cobble:
            cx, cy, cw, ch = cobble
            for y in range(cy, cy + ch, 16):
                for x in range(cx, cx + cw, 16):
                    self.base.alpha_composite(tile(12 if r.random() < 0.6 else 15), (x, y))

    def put(self, im, x, y, shadow=True):
        """x, y = the feet (bottom centre) of the sprite."""
        px, py = int(x - im.width / 2), int(y - im.height)
        if shadow:
            sh = img("shadow")
            self.base.alpha_composite(sh, (int(x - sh.width / 2), int(y - 4)))
        self.items.append((y, im, px, py))

    def light(self, x, y, radius, color, strength=1.0):
        self.lights.append((x, y, radius, color, strength))

    def render(self, scale, ambient=(0.38, 0.42, 0.68)):
        out = self.base.copy()
        for _, im, px, py in sorted(self.items, key=lambda t: t[0]):
            out.alpha_composite(im, (px, py))
        a = np.asarray(out).astype(np.float32) / 255.0
        h, w = a.shape[:2]
        yy, xx = np.mgrid[0:h, 0:w]
        light = np.zeros((h, w, 3), np.float32)
        light[:] = ambient
        for (lx, ly, rad, col, st) in self.lights:
            d = np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2) / rad
            f = np.clip(1.0 - d, 0.0, 1.0) ** 1.6 * st
            light += f[..., None] * (np.array(col, np.float32) / 255.0)
        a[..., :3] = np.clip(a[..., :3] * light, 0, 1)
        lit = Image.fromarray((a * 255).astype(np.uint8), "RGBA")
        return lit.resize((w * scale, h * scale), Image.NEAREST)


def char(sheet, x, y, scene, row=2, col=0, flip=False):
    scene.put(frame(sheet, col, row, flip=flip), x, y)


def weapon(name):
    i = ["axe", "bat", "machete", "chainsaw", "pistol", "shotgun", "smg"].index(name)
    return img("weapons").crop((i * 16, 0, i * 16 + 16, 16))


def build_scene(w, h, layout):
    """layout: dict with key positions as fractions of the scene size."""
    s = Scene(w, h)
    L = {k: (v[0] * w, v[1] * h) for k, v in layout.items()}
    s.ground(int(L["road"][1]), cobble=(int(L["camp"][0] - 40), int(L["camp"][1] - 26), 80, 48))

    # houses and trees in the back
    for name, key in (("house_red", "house1"), ("home", "house2"), ("house_blue", "house3")):
        if key in L:
            s.put(img(name), *L[key], shadow=False)
    for i, key in enumerate(k for k in L if k.startswith("tree")):
        s.put(img(["tree_pine", "tree_round", "tree_round2"][i % 3]), *L[key])

    # the defence: barricades, a turret and the campfire
    cx, cy = L["camp"]
    s.put(img("campfire").crop((16, 0, 32, 16)), cx, cy)
    s.light(cx, cy - 6, 70, (255, 170, 90), 1.25)
    for i, key in enumerate(k for k in L if k.startswith("wall")):
        s.put(img(["barricade_iron", "barricade", "wall_stone"][i % 3]), *L[key])
    if "turret" in L:
        tx, ty = L["turret"]
        s.put(img("turret_base"), tx, ty)
        s.put(img("turret_gun"), tx + 3, ty - 9, shadow=False)

    # the hero with a shotgun, and the team
    px, py = L["player"]
    char("player", px, py, s, row=2, col=4)
    gun = weapon("shotgun")
    s.items.append((py + 1, gun, int(px - 2), int(py - 15)))
    flash = Image.new("RGBA", (6, 6))
    d = ImageDraw.Draw(flash)
    d.ellipse((0, 0, 5, 5), fill=(255, 230, 140, 255))
    s.items.append((py + 2, flash, int(px + 13), int(py - 15)))
    s.light(px + 14, py - 12, 40, (255, 230, 150), 1.0)
    s.light(px, py - 10, 55, (230, 220, 200), 0.55)
    bullet = img("bullet")
    for i in range(3):
        s.items.append((py + 2, bullet, int(px + 24 + i * 14), int(py - 15 + (i - 1) * 3)))
    if "ally1" in L:
        char("survivor_shooter", *L["ally1"], s, row=2, col=1)
        s.items.append((L["ally1"][1] + 1, weapon("pistol"), int(L["ally1"][0] - 1), int(L["ally1"][1] - 14)))
    if "ally2" in L:
        char("survivor_fighter", *L["ally2"], s, row=2, col=4)
        s.items.append((L["ally2"][1] + 1, weapon("bat"), int(L["ally2"][0] + 1), int(L["ally2"][1] - 18)))

    # the horde coming in from the right
    kinds = ["zombie_farmer", "zombie_granny", "zombie_cap", "zombie_girl", "zombie_worker", "zombie_runner"]
    for i, key in enumerate(sorted(k for k in L if k.startswith("z"))):
        x, y = L[key]
        if key == "zbrute":
            char("zombie_brute", x, y, s, row=2, col=4, flip=True)
        elif key == "zbloat":
            char("zombie_bloater", x, y, s, row=2, col=1, flip=True)
            s.light(x, y - 14, 26, (170, 255, 120), 0.6)
        elif key == "zdog":
            char("zombie_dog", x, y, s, row=2, col=1, flip=True)
        elif key == "zspit":
            char("zombie_spitter", x, y, s, row=2, col=4, flip=True)
            slime = img("slime")
            s.items.append((y - 40, slime, int(x - 30), int(y - 44)))
            s.light(x - 26, y - 40, 18, (150, 255, 120), 0.7)
        else:
            char(kinds[i % len(kinds)], x, y, s, row=2, col=(i * 2) % 4, flip=True)
        # glowing eyes
        s.light(x - 3, y - 16, 7, (255, 80, 60), 0.5)
    for key in (k for k in L if k.startswith("splat")):
        s.base.alpha_composite(img("splat").crop((0, 0, 12, 12)), (int(L[key][0]), int(L[key][1])))
    return s


def title(im, text, size, y, color=(158, 230, 107), outline=(30, 52, 26)):
    """Blocky pixel title with a thick outline and a drop shadow."""
    font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "kenney_blocks.ttf"), size)
    d = ImageDraw.Draw(im)
    tw = d.textlength(text, font=font)
    x = (im.width - tw) / 2
    o = max(3, size // 12)
    d.text((x + o * 1.4, y + o * 1.8), text, font=font, fill=(10, 10, 18, 200))
    for dx in range(-o, o + 1, max(1, o // 2)):
        for dy in range(-o, o + 1, max(1, o // 2)):
            d.text((x + dx, y + dy), text, font=font, fill=outline)
    d.text((x, y), text, font=font, fill=color)
    hl = (min(255, color[0] + 60), min(255, color[1] + 25), min(255, color[2] + 60))
    d.text((x, y - max(1, o // 3)), text, font=font, fill=hl)
    d.text((x, y), text, font=font, fill=color)


def fit_size(text, max_w, start):
    size = start
    while size > 16:
        font = ImageFont.truetype(os.path.join(ROOT, "assets", "fonts", "kenney_blocks.ttf"), size)
        if ImageDraw.Draw(Image.new("RGB", (1, 1))).textlength(text, font=font) <= max_w:
            return size
        size -= 4
    return size


def landscape():
    lay = {
        "road": (0, 0.7), "camp": (0.42, 0.66), "house1": (0.1, 0.36), "house2": (0.36, 0.33),
        "house3": (0.62, 0.36), "tree1": (0.02, 0.48), "tree2": (0.85, 0.38), "tree3": (0.95, 0.5),
        "tree4": (0.24, 0.42),
        "wall1": (0.55, 0.62), "wall2": (0.55, 0.72), "wall3": (0.55, 0.82), "turret": (0.5, 0.52),
        "player": (0.43, 0.8), "ally1": (0.33, 0.72), "ally2": (0.37, 0.92),
        "z1": (0.68, 0.6), "z2": (0.74, 0.76), "z3": (0.82, 0.9), "z4": (0.9, 0.64), "z5": (0.97, 0.82),
        "zbrute": (0.8, 0.66), "zdog": (0.66, 0.9), "zbloat": (0.88, 0.97), "zspit": (0.95, 0.56),
        "splat1": (0.6, 0.86), "splat2": (0.7, 0.68),
    }
    s = build_scene(320, 180, lay)
    out = s.render(6)
    title(out, TITLE, fit_size(TITLE, 1500, 176), 70)
    return out


def portrait():
    lay = {
        "road": (0, 0.62), "camp": (0.4, 0.6), "house1": (0.2, 0.32), "house2": (0.72, 0.31),
        "tree1": (0.05, 0.42), "tree2": (0.95, 0.44), "tree3": (0.5, 0.36),
        "wall1": (0.62, 0.6), "wall2": (0.62, 0.68), "wall3": (0.62, 0.76), "turret": (0.55, 0.52),
        "player": (0.4, 0.74), "ally1": (0.22, 0.68), "ally2": (0.28, 0.82),
        "z1": (0.78, 0.58), "z2": (0.86, 0.7), "z3": (0.76, 0.84), "z4": (0.94, 0.8),
        "zbrute": (0.88, 0.94), "zdog": (0.7, 0.93), "zbloat": (0.55, 0.99), "zspit": (0.92, 0.6),
        "splat1": (0.7, 0.75),
    }
    s = build_scene(200, 300, lay)
    out = s.render(4)
    title(out, TITLE.split(" ")[0], fit_size(TITLE.split(" ")[0], 700, 150), 60)
    if " " in TITLE:
        rest = " ".join(TITLE.split(" ")[1:])
        title(out, rest, fit_size(rest, 700, 150), 60 + fit_size(TITLE.split(" ")[0], 700, 150) + 20)
    return out


def square():
    lay = {
        "road": (0, 0.64), "camp": (0.38, 0.62), "house1": (0.22, 0.4), "house2": (0.74, 0.4),
        "tree1": (0.04, 0.5), "tree2": (0.96, 0.52),
        "wall1": (0.6, 0.6), "wall2": (0.6, 0.72), "wall3": (0.6, 0.84),
        "player": (0.4, 0.8), "ally1": (0.22, 0.74), "ally2": (0.26, 0.92),
        "z1": (0.76, 0.62), "z2": (0.86, 0.78), "z3": (0.78, 0.92), "zbrute": (0.95, 0.66),
        "zdog": (0.7, 0.98), "zspit": (0.94, 0.94),
    }
    s = build_scene(200, 200, lay)
    out = s.render(4)
    words = TITLE.split(" ")
    size = fit_size(max(words, key=len), 700, 140)
    y = 40
    for wd in words:
        title(out, wd, size, y)
        y += size + 10
    return out


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    landscape().convert("RGB").save(os.path.join(OUT, "cover_landscape_1920x1080.png"))
    portrait().convert("RGB").save(os.path.join(OUT, "cover_portrait_800x1200.png"))
    square().convert("RGB").save(os.path.join(OUT, "cover_square_800x800.png"))
    for f in sorted(os.listdir(OUT)):
        if f.endswith(".png"):
            print(f, Image.open(os.path.join(OUT, f)).size)
