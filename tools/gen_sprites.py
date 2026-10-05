"""Generates all pixel-art sprites for Zombie Dorp.

Usage: python3 tools/gen_sprites.py   (needs Pillow)
Writes PNG files into assets/sprites/.

Everything is drawn pixel by pixel so the style stays consistent:
chibi villagers with big heads and dark outlines (Stardew-like),
and zombies that are built from exactly the same body template.
"""
import math
import os
import random

from PIL import Image

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites")
OUTLINE = (40, 24, 32, 255)


def rgba(c, a=255):
    return (c[0], c[1], c[2], a)


def mix(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def darker(c, f=0.78):
    return (int(c[0] * f), int(c[1] * f), int(c[2] * f))


def lighter(c, f=0.25):
    return mix(c, (255, 255, 255), f)


class Canvas:
    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.p = self.img.load()

    def px(self, x, y, c, a=255):
        if 0 <= x < self.w and 0 <= y < self.h and c is not None:
            self.p[x, y] = rgba(c, a)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.p[x, y]
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, c):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.px(x, y, c)

    def clear(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.p[x, y] = (0, 0, 0, 0)

    def outline(self, color=OUTLINE, diagonal=False):
        pts = []
        for y in range(self.h):
            for x in range(self.w):
                if self.p[x, y][3] != 0:
                    continue
                nb = [(1, 0), (-1, 0), (0, 1), (0, -1)]
                if diagonal:
                    nb += [(1, 1), (-1, 1), (1, -1), (-1, -1)]
                for dx, dy in nb:
                    q = self.get(x + dx, y + dy)
                    if q[3] > 200 and q != color:
                        pts.append((x, y))
                        break
        for x, y in pts:
            self.p[x, y] = color

    def paste(self, other, x, y):
        self.img.alpha_composite(other.img, (x, y))
        self.p = self.img.load()


# ---------------------------------------------------------------- characters

SKIN_LIGHT = (247, 200, 156)
SKIN_TAN = (214, 160, 112)
SKIN_DARK = (140, 92, 62)
Z_GREEN = (138, 176, 106)
Z_GREY = (156, 176, 146)
Z_DARK = (96, 128, 80)
EYE_BLUE = (70, 140, 210)
Z_EYE = (236, 70, 48)
Z_EYE_Y = (240, 222, 90)
BLOOD = (128, 26, 36)


def draw_character(d, frame, cfg):
    """d: 0=down 1=up 2=right. frame: 0..3 walk, 4..5 attack."""
    big = cfg.get("big", False)
    W, H = (20, 26) if big else (16, 24)
    cv = Canvas(W, H)
    cx = W // 2
    zombie = cfg.get("zombie", False)
    rnd = random.Random(cfg.get("seed", 1) * 100 + d * 10 + frame)
    skin = cfg["skin"]
    skin_s = darker(skin, 0.82)
    hair = cfg.get("hair", (90, 56, 36))
    hair_s = darker(hair, 0.75)
    shirt = cfg["shirt"]
    shirt_s = darker(shirt, 0.78)
    pants = cfg.get("pants", (70, 80, 120))
    pants_s = darker(pants, 0.78)
    shoes = cfg.get("shoes", (84, 54, 40))
    attack = frame >= 4
    walk = frame % 4
    bob = -1 if walk in (1, 3) else 0
    if attack:
        bob = 0

    ht = 3 + bob + (1 if big else 0)  # head top
    tt = ht + 10                      # torso top
    trows = 8 if big else 6
    tb = tt + trows - 1               # torso bottom
    tw = 6 if big else 4              # torso half width
    foot_y = H - 2

    # ---------------- legs / dress
    def leg_front(x0, x1, lifted):
        fy = foot_y - (1 if lifted else 0)
        for y in range(tb + 1, fy):
            cv.rect(x0, y, x1, y, pants if not cfg.get("shorts") or y < tb + 2 else skin)
        cv.rect(x0, fy, x1, fy, shoes)

    if d in (0, 1):
        lw = 3 if big else 2
        if cfg.get("dress"):
            dress = cfg["dress"]
            for i, y in enumerate(range(tb - 1, foot_y - 1)):
                spread = tw + min(i, 2)
                cv.rect(cx - spread, y, cx + spread - 1, y, dress if i < 3 else darker(dress, 0.85))
            cv.rect(cx - 3, foot_y - 1, cx - 2, foot_y - 1, skin)
            cv.rect(cx + 1, foot_y - 1, cx + 2, foot_y - 1, skin)
            cv.rect(cx - 3, foot_y, cx - 2, foot_y, shoes)
            cv.rect(cx + 1, foot_y, cx + 2, foot_y, shoes)
        else:
            leg_front(cx - 1 - lw, cx - 1, walk == 1)
            leg_front(cx, cx + lw, walk == 3)
            for y in range(tb + 1, foot_y - 1):
                cv.px(cx - 1, y, pants_s)
    else:
        if cfg.get("dress"):
            dress = cfg["dress"]
            for i, y in enumerate(range(tb - 1, foot_y - 1)):
                cv.rect(cx - 4 - min(i, 1), y, cx + 3 + min(i, 2), y, dress if i < 3 else darker(dress, 0.85))
            off = [0, 1, 0, -1, 1, 1][frame]
            cv.rect(cx - 1 + off, foot_y - 1, cx + off, foot_y - 1, skin)
            cv.rect(cx - 1 + off, foot_y, cx + 1 + off, foot_y, shoes)
        else:
            lw = 3 if big else 2
            if walk in (0, 2) or attack:
                cv.rect(cx - 2, tb + 1, cx - 2 + lw, foot_y - 1, pants)
                cv.rect(cx - 2, foot_y, cx - 1 + lw, foot_y, shoes)
            else:
                fwd, back = (pants, pants_s) if walk == 1 else (pants_s, pants)
                # back leg
                cv.rect(cx - 4, tb + 1, cx - 4 + lw - 1, foot_y - 1, back)
                cv.rect(cx - 5, foot_y, cx - 4 + lw - 1, foot_y, darker(shoes, 0.85))
                # front leg
                cv.rect(cx + 1, tb + 1, cx + lw, foot_y - 1, fwd)
                cv.rect(cx + 1, foot_y, cx + lw + 1, foot_y, shoes)

    # ---------------- torso
    if d in (0, 1):
        x0, x1 = cx - tw, cx + tw - 1
    else:
        x0, x1 = cx - tw + 1, cx + tw - 2
    cv.rect(x0, tt, x1, tb, shirt)
    cv.rect(x1, tt, x1, tb, shirt_s)
    cv.rect(x0, tb, x1, tb, shirt_s)
    if cfg.get("plaid"):
        for y in range(tt, tb + 1):
            for x in range(x0, x1 + 1):
                if (x + y) % 3 == 0 or y % 3 == 0:
                    cv.px(x, y, darker(shirt, 0.7))
    if cfg.get("overalls") and d != 1:
        ov = cfg["overalls"]
        cv.rect(x0 + (1 if d == 0 else 0), tt + 2, x1 - (1 if d == 0 else 0), tb, ov)
        cv.rect(x0, tb, x1, tb, darker(ov, 0.8))
        if d == 0:
            cv.px(x0 + 1, tt, ov)
            cv.px(x0 + 1, tt + 1, ov)
            cv.px(x1 - 1, tt, ov)
            cv.px(x1 - 1, tt + 1, ov)
            cv.px(cx - 1, tt + 3, (230, 200, 90))
        else:
            cv.px(cx, tt, ov)
            cv.px(cx, tt + 1, ov)
    elif cfg.get("overalls"):
        ov = cfg["overalls"]
        cv.rect(x0, tt + 3, x1, tb, ov)
        cv.px(x0 + 1, tt, ov)
        cv.px(x1 - 1, tt, ov)
        cv.rect(x0 + 1, tt + 1, x1 - 1, tt + 2, ov)
    if cfg.get("cross") and d in (0, 1):
        cv.rect(cx - 1, tt + 1, cx, tt + 4, (220, 50, 50))
        cv.rect(cx - 2, tt + 2, cx + 1, tt + 3, (220, 50, 50))
    if cfg.get("scarf") and d != 1:
        cv.rect(x0, tt, x1, tt, cfg["scarf"])
        cv.px(x0 + 1, tt + 1, cfg["scarf"])
    if d == 0 and not cfg.get("overalls") and not cfg.get("dress_top") and not cfg.get("cross"):
        cv.px(cx - 1, tt, skin)
        cv.px(cx, tt, skin)
    if zombie:
        # torn spots and blood stains
        for _ in range(3 if big else 2):
            x = rnd.randint(x0, x1)
            y = rnd.randint(tt + 1, tb)
            cv.px(x, y, skin_s)
        bx = rnd.randint(x0, x1 - 1)
        by = rnd.randint(tt + 1, tb - 1)
        cv.px(bx, by, BLOOD)
        cv.px(bx + 1, by, BLOOD)
        cv.px(bx, by + 1, darker(BLOOD, 0.8))
        # ragged hem
        for x in range(x0, x1 + 1):
            if rnd.random() < 0.35:
                cv.px(x, tb + 1, shirt_s)
    if cfg.get("belly") and d != 1:
        bcx = cx - 0.5 if d == 0 else cx + 1.5
        bcy = tt + 4.5
        rx, ry = (6.6, 4.6) if d == 0 else (5.2, 4.6)
        belly, belly_l = (150, 186, 96), (190, 222, 120)
        for y in range(tt, tb + 2):
            for x in range(x0 - 2, x1 + 4):
                if ((x - bcx) / rx) ** 2 + ((y - bcy) / ry) ** 2 <= 1.0:
                    c = belly
                    if x < bcx - 1 and y < bcy:
                        c = belly_l
                    cv.px(x, y, c)
        for (px_, py_) in ((-3, -1), (2, 1), (-1, 2), (3, -2)):
            cv.px(int(bcx) + px_, int(bcy) + py_, (210, 230, 80))
        cv.px(int(bcx), int(bcy), (90, 120, 60))

    # ---------------- arms
    sleeve = shirt_s if not cfg.get("plaid") else darker(shirt, 0.85)
    reach = 2 if attack else 0
    if d == 0:
        if zombie:
            lift = [0, 1, 0, -1, 0, 0][frame]
            for side in (-1, 1):
                ax = x0 - 1 if side < 0 else x1 + 1
                cv.rect(ax, tt + 1, ax, tt + 2 + lift, sleeve)
                hx = ax + (1 if side < 0 else -1)
                hy = tt + 2 + lift + (1 if attack else 0)
                cv.px(ax, hy + 1, skin)
                cv.px(hx, hy + 1, skin)
                cv.px(hx, hy + 2 - (1 if attack and frame == 5 else 0), skin_s)
        else:
            sw = [0, 1, 0, -1, 0, 0][frame]
            for side, s in ((-1, sw), (1, -sw)):
                ax = x0 - 1 if side < 0 else x1 + 1
                cv.rect(ax, tt, ax, tt + 3 + s, sleeve)
                cv.px(ax, tt + 4 + s, skin)
    elif d == 1:
        if zombie:
            for side in (-1, 1):
                ax = x0 - 1 if side < 0 else x1 + 1
                cv.rect(ax, tt - 1, ax, tt + 1, sleeve)
                cv.px(ax, tt - 2, skin)
        else:
            sw = [0, 1, 0, -1, 0, 0][frame]
            for side, s in ((-1, -sw), (1, sw)):
                ax = x0 - 1 if side < 0 else x1 + 1
                cv.rect(ax, tt, ax, tt + 3 + s, sleeve)
                cv.px(ax, tt + 4 + s, skin)
    else:
        if zombie:
            lift = [0, 1, 0, -1, 0, 0][frame]
            ay = tt + 1 + (1 if lift > 0 else 0)
            cv.rect(cx - 1, ay, cx + 3 + reach, ay + 1, sleeve)
            cv.rect(cx + 4 + reach, ay, cx + 5 + reach, ay + 1, skin)
            cv.px(cx + 4 + reach, ay + 1, skin_s)
        else:
            sw = [0, 1, 0, -1, 0, 0][frame]
            cv.rect(cx - 1, tt, cx, tt + 3, sleeve)
            cv.px(cx - 1 + sw, tt + 4, skin)
            cv.px(cx + sw, tt + 4, skin)

    # ---------------- head
    hx0, hx1 = (cx - 5, cx + 4) if d != 2 else (cx - 5, cx + 3)
    hb = ht + 9
    cv.rect(hx0, ht, hx1, hb, skin)
    cv.rect(hx1, ht + 1, hx1, hb, skin_s)
    cv.rect(hx0 + 1, hb, hx1, hb, skin_s)
    for (x, y) in ((hx0, ht), (hx1, ht), (hx0, hb), (hx1, hb)):
        cv.clear(x, y)

    style = cfg.get("hair_style", "short")
    ey = ht + 5
    if d == 0:
        # face
        eye = cfg.get("eye", EYE_BLUE)
        lx, rx = cx - 3, cx + 2
        if zombie:
            cv.px(lx, ey, OUTLINE[:3])
            cv.px(lx, ey + 1, eye)
            cv.px(rx, ey, OUTLINE[:3])
            cv.px(rx, ey + 1, eye if not cfg.get("one_eye") else OUTLINE[:3])
            cv.px(lx - 1, ey, skin_s)
            cv.px(rx + 1, ey, skin_s)
            cv.rect(cx - 2, ht + 8, cx + 1, ht + 8, (70, 30, 40))
            cv.px(cx - 1, ht + 8, (230, 225, 200))
            cv.px(cx + 1, ht + 7, BLOOD)
            if cfg.get("scar"):
                cv.px(hx0 + 1, ht + 4, BLOOD)
                cv.px(hx0 + 2, ht + 5, BLOOD)
        else:
            cv.px(lx, ey, (40, 30, 40))
            cv.px(lx, ey + 1, eye)
            cv.px(rx, ey, (40, 30, 40))
            cv.px(rx, ey + 1, eye)
            cv.px(lx - 1, ey + 2, mix(skin, (240, 120, 120), 0.35))
            cv.px(rx + 1, ey + 2, mix(skin, (240, 120, 120), 0.35))
            cv.px(cx - 1, ht + 8, skin_s)
            cv.px(cx, ht + 8, skin_s)
    elif d == 2:
        eye = cfg.get("eye", EYE_BLUE)
        ex = cx + 1
        cv.px(ex, ey, OUTLINE[:3] if zombie else (40, 30, 40))
        cv.px(ex, ey + 1, eye)
        if zombie:
            cv.px(cx + 2, ht + 8, (70, 30, 40))
            cv.px(cx + 3, ht + 8, (70, 30, 40))
            cv.px(cx + 3, ht + 7, (230, 225, 200))
        else:
            cv.px(cx + 3, ht + 8, skin_s)
        cv.px(cx - 2, ey + 1, skin_s)  # ear

    if cfg.get("drool") and d != 1:
        slime, slime_d = (120, 230, 80), (70, 170, 50)
        if d == 0:
            cv.rect(cx - 2, ht + 8, cx + 1, ht + 8, slime_d)
            cv.px(cx - 1, ht + 9, slime)
            cv.px(cx - 1, ht + 10, slime)
            cv.px(cx + 1, ht + 9, slime)
        else:
            cv.rect(cx + 2, ht + 8, cx + 3, ht + 8, slime_d)
            cv.px(cx + 3, ht + 9, slime)
            cv.px(cx + 3, ht + 10, slime)

    # hair
    def hair_px(x, y, c=None):
        cv.px(x, y, c or hair)

    if style != "bald":
        if d == 0:
            cv.rect(hx0, ht, hx1, ht + 2, hair)
            for x in range(hx0, hx1 + 1):
                if style == "messy" and rnd.random() < 0.25:
                    continue
                if (x - hx0) % 3 != 1 or style in ("bun", "long"):
                    hair_px(x, ht + 3)
            cv.rect(hx0, ht + 3, hx0, ht + 5, hair)
            cv.rect(hx1, ht + 3, hx1, ht + 5, hair_s)
            if style == "long":
                cv.rect(hx0 - 1, ht + 3, hx0, hb + 3, hair)
                cv.rect(hx1, ht + 3, hx1 + 1, hb + 3, hair_s)
            cv.rect(hx0 + 1, ht, hx1 - 1, ht, lighter(hair, 0.2))
        elif d == 1:
            cv.rect(hx0, ht, hx1, hb - (2 if style != "long" else 0), hair)
            cv.rect(hx1, ht, hx1, hb - 2, hair_s)
            if style == "long":
                cv.rect(hx0 - 1, ht + 3, hx1 + 1, hb + 3, hair)
                cv.rect(hx1 + 1, ht + 3, hx1 + 1, hb + 3, hair_s)
            cv.rect(hx0 + 1, ht, hx1 - 1, ht, lighter(hair, 0.2))
        else:
            cv.rect(hx0, ht, hx1, ht + 2, hair)
            cv.rect(hx0, ht + 3, cx - 2, ht + 6, hair)
            cv.px(cx - 1, ht + 3, hair)
            cv.px(hx1, ht + 3, hair)
            if style == "long":
                cv.rect(hx0 - 1, ht + 3, cx - 2, hb + 3, hair)
            cv.rect(hx0 + 1, ht, hx1 - 1, ht, lighter(hair, 0.2))
        if style == "bun":
            cv.rect(cx - 2, ht - 2, cx + 1, ht - 1, hair)
            cv.px(cx + 1, ht - 1, hair_s)
        if style == "spiky":
            for x in range(hx0 + 1, hx1, 2):
                hair_px(x, ht - 1)
        if style == "messy":
            for x in range(hx0, hx1 + 1):
                if rnd.random() < 0.4:
                    hair_px(x, ht - 1)
    if style == "bald" and zombie:
        cv.px(cx - 2, ht + 1, skin_s)
        cv.px(cx + 1, ht + 2, BLOOD)

    hat = cfg.get("hat")
    if hat == "straw":
        hc = cfg.get("hat_color", (226, 186, 106))
        hs = darker(hc, 0.8)
        band = cfg.get("band", (170, 60, 50))
        cv.rect(cx - 3, ht - 3, cx + 2, ht + 1, hc)
        cv.rect(cx + 2, ht - 3, cx + 2, ht + 1, hs)
        cv.rect(cx - 3, ht + 1, cx + 2, ht + 1, band)
        bx0, bx1 = (cx - 7, cx + 6) if d != 2 else (cx - 7, cx + 6)
        cv.rect(bx0, ht + 2, bx1, ht + 2, hc)
        cv.rect(bx0 + 1, ht + 3, bx1 - 1, ht + 3, hs)
        if zombie:
            cv.clear(bx0 + 2, ht + 3)
            cv.px(cx, ht - 3, hs)
    elif hat == "cap":
        hc = cfg.get("hat_color", (60, 90, 170))
        cv.rect(hx0, ht - 1, hx1, ht + 2, hc)
        cv.rect(hx1, ht - 1, hx1, ht + 2, darker(hc))
        cv.rect(hx0 + 2, ht - 2, hx1 - 2, ht - 2, hc)
        if d == 0:
            cv.rect(hx0, ht + 3, hx1, ht + 3, darker(hc, 0.7))
        elif d == 2:
            cv.rect(hx1 - 1, ht + 2, hx1 + 3, ht + 2, darker(hc, 0.7))
        cv.px(cx, ht - 1, lighter(hc, 0.4))

    cv.outline()
    return cv


def character_sheet(name, cfg):
    W, H = (20, 26) if cfg.get("big") else (16, 24)
    sheet = Image.new("RGBA", (W * 6, H * 3), (0, 0, 0, 0))
    for d in range(3):
        for f in range(6):
            sheet.alpha_composite(draw_character(d, f, cfg).img, (f * W, d * H))
    sheet.save(os.path.join(OUT, name + ".png"))
    return sheet


PLAYER = dict(skin=SKIN_LIGHT, hair=(118, 70, 40), hair_style="short", shirt=(236, 232, 220),
              overalls=(70, 108, 184), pants=(70, 108, 184), shoes=(96, 60, 42), seed=1)

ZOMBIES = {
    "zombie_farmer": dict(zombie=True, skin=Z_GREEN, hair=(196, 160, 80), hat="straw", shirt=(150, 98, 60),
                          pants=(196, 176, 130), eye=Z_EYE, seed=2),
    "zombie_cap": dict(zombie=True, skin=Z_GREY, hair=(60, 40, 30), hat="cap", hat_color=(52, 92, 180),
                       shirt=(232, 232, 224), pants=(60, 100, 170), shorts=True, eye=Z_EYE_Y, seed=3, scar=True),
    "zombie_granny": dict(zombie=True, skin=Z_GREY, hair=(222, 222, 228), hair_style="bun", shirt=(150, 92, 170),
                          dress=(150, 92, 170), eye=Z_EYE, seed=4),
    "zombie_girl": dict(zombie=True, skin=Z_GREEN, hair=(232, 196, 96), hair_style="long", shirt=(232, 150, 176),
                        dress=(232, 150, 176), eye=Z_EYE_Y, seed=5, one_eye=True),
    "zombie_worker": dict(zombie=True, skin=Z_DARK, hair=(36, 30, 30), hair_style="messy", shirt=(70, 150, 110),
                          pants=(46, 46, 56), eye=Z_EYE, seed=6),
    "zombie_runner": dict(zombie=True, skin=Z_GREEN, hair=(70, 44, 30), hat="cap", hat_color=(196, 52, 52),
                          shirt=(206, 64, 56), pants=(60, 64, 80), eye=Z_EYE_Y, seed=7, scar=True),
    "zombie_brute": dict(zombie=True, big=True, skin=Z_DARK, hair_style="bald", shirt=(190, 60, 54), plaid=True,
                         overalls=(80, 94, 140), pants=(80, 94, 140), eye=Z_EYE, seed=8, scar=True),
    "zombie_bloater": dict(zombie=True, big=True, skin=(126, 164, 92), hair_style="bald", shirt=(236, 230, 210),
                           pants=(110, 90, 70), eye=Z_EYE_Y, seed=15, belly=True),
    "zombie_spitter": dict(zombie=True, skin=(150, 172, 120), hair=(50, 40, 60), hair_style="messy",
                           shirt=(224, 190, 60), pants=(70, 70, 90), eye=Z_EYE_Y, seed=16, drool=True),
}

VILLAGERS_FOR_MENU = {
    "villager_farmer": dict(skin=SKIN_TAN, hair=(196, 160, 80), hat="straw", shirt=(150, 98, 60),
                            pants=(196, 176, 130), seed=2),
    "shopkeeper": dict(skin=SKIN_DARK, hair=(40, 30, 28), hair_style="short", shirt=(236, 232, 220),
                       overalls=(70, 140, 90), pants=(60, 60, 80), seed=9),
    # Survivors you can find and take along.
    "survivor_shooter": dict(skin=SKIN_TAN, hair=(60, 40, 30), hat="cap", hat_color=(70, 110, 60),
                             shirt=(96, 120, 70), pants=(70, 64, 54), scarf=(200, 170, 90), seed=11),
    "survivor_fighter": dict(skin=SKIN_LIGHT, hair=(200, 80, 50), hair_style="spiky", shirt=(230, 130, 50),
                             pants=(50, 54, 70), scarf=(200, 40, 40), seed=12),
    "survivor_medic": dict(skin=SKIN_DARK, hair=(30, 24, 24), hair_style="long", shirt=(240, 240, 236),
                           pants=(110, 160, 200), cross=True, seed=13),
    "survivor_builder": dict(skin=SKIN_LIGHT, hair=(150, 100, 60), hat="cap", hat_color=(240, 200, 40),
                             shirt=(200, 90, 60), overalls=(70, 90, 150), pants=(70, 90, 150), seed=14),
}


# ---------------------------------------------------------------- tiles

GRASS = (104, 172, 84)
GRASS_D = (82, 148, 70)
GRASS_L = (132, 196, 100)
DIRT = (172, 124, 82)
DIRT_D = (146, 102, 66)
DIRT_L = (190, 144, 98)
WATER = (76, 132, 206)
WATER_D = (58, 104, 176)
WATER_L = (130, 180, 236)
STONE = (168, 164, 156)
STONE_D = (128, 124, 120)
STONE_L = (196, 192, 184)
SOIL = (126, 84, 58)
SOIL_D = (98, 64, 44)


def tile_grass(seed, flowers=False, tufts=3):
    r = random.Random(seed)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, GRASS)
    for _ in range(18):
        cv.px(r.randint(0, 15), r.randint(0, 15), mix(GRASS, GRASS_L, 0.5))
    for _ in range(tufts):
        x, y = r.randint(1, 13), r.randint(2, 14)
        cv.px(x, y, GRASS_D)
        cv.px(x + 2, y, GRASS_D)
        cv.px(x + 1, y + 1, GRASS_D)
        cv.px(x + 1, y - 1, GRASS_L)
    if flowers:
        for _ in range(2):
            x, y = r.randint(2, 12), r.randint(2, 12)
            petal = r.choice([(250, 250, 240), (250, 240, 120), (240, 160, 200)])
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                cv.px(x + dx, y + dy, petal)
            cv.px(x, y, (240, 150, 60))
    return cv


def tile_dirt(seed):
    r = random.Random(seed)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, DIRT)
    for _ in range(14):
        cv.px(r.randint(0, 15), r.randint(0, 15), DIRT_L)
    for _ in range(r.randint(0, 2)):
        x, y = r.randint(1, 12), r.randint(1, 13)
        cv.rect(x, y, x + 2, y + 1, DIRT_D)
        cv.px(x + 3, y + 1, DIRT_D)
    return cv


def tile_water(seed):
    r = random.Random(seed)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, WATER)
    for _ in range(3):
        x, y = r.randint(1, 11), r.randint(1, 14)
        cv.rect(x, y, x + 3, y, WATER_L)
    for _ in range(4):
        cv.px(r.randint(0, 15), r.randint(0, 15), WATER_D)
    return cv


def tile_lily(seed):
    cv = tile_water(seed)
    lp = (80, 160, 80)
    cv.rect(5, 6, 10, 9, lp)
    cv.rect(6, 5, 9, 10, lp)
    cv.clear(8, 5)
    cv.px(8, 5, WATER)
    cv.px(8, 6, WATER)
    cv.px(7, 7, (236, 120, 160))
    cv.px(6, 8, (236, 120, 160))
    return cv


def tile_cobble(seed):
    r = random.Random(seed)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, STONE_D)
    for by in range(0, 16, 4):
        off = 0 if (by // 4) % 2 == 0 else 3
        for bx in range(-off, 16, 6):
            c = mix(STONE, STONE_L, r.random() * 0.4)
            cv.rect(bx + 1, by + 1, bx + 4, by + 3, c)
            cv.rect(bx + 1, by + 3, bx + 4, by + 3, STONE)
    return cv


def tile_soil(seed):
    r = random.Random(seed)
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, SOIL)
    for y in (3, 7, 11, 15):
        cv.rect(0, y, 15, y, SOIL_D)
    for _ in range(8):
        cv.px(r.randint(0, 15), r.randint(0, 15), mix(SOIL, DIRT_L, 0.4))
    return cv


def edge_overlay(side, bank=False, seed=0):
    """Grass fringe hanging over a lower tile (dirt/water). side: n,s,e,w,ne,nw,se,sw."""
    r = random.Random(seed + sum(ord(ch) for ch in side))
    cv = Canvas(16, 16)

    def depth_at(i):
        return 2 + ((i * 7 + seed) % 3 == 0) + (r.random() < 0.3)

    if side in ("n", "s", "e", "w"):
        for i in range(16):
            dd = depth_at(i)
            for k in range(dd):
                if side == "n":
                    cv.px(i, k, GRASS)
                elif side == "s":
                    cv.px(i, 15 - k, GRASS)
                elif side == "w":
                    cv.px(k, i, GRASS)
                else:
                    cv.px(15 - k, i, GRASS)
            edge = GRASS_D
            if side == "n":
                cv.px(i, dd, edge)
                if bank:
                    cv.px(i, dd + 1, (120, 84, 56))
                    cv.px(i, dd + 2, WATER_D)
            elif side == "s":
                cv.px(i, 15 - dd, GRASS_L)
            elif side == "w":
                cv.px(dd, i, edge)
                if bank:
                    cv.px(dd + 1, i, WATER_D)
            else:
                cv.px(15 - dd, i, edge)
                if bank:
                    cv.px(15 - dd - 1, i, WATER_D)
    else:
        corner = {"nw": (0, 0), "ne": (15, 0), "sw": (0, 15), "se": (15, 15)}[side]
        for y in range(16):
            for x in range(16):
                dist = abs(x - corner[0]) + abs(y - corner[1])
                if dist <= 3:
                    cv.px(x, y, GRASS)
                elif dist == 4:
                    cv.px(x, y, GRASS_D if side[0] == "n" else GRASS_L)
    return cv


def make_tiles(suffix=""):
    tiles = []
    for i in range(4):
        tiles.append(tile_grass(10 + i))                  # 0-3 grass
    tiles.append(tile_grass(20, flowers=True))           # 4 flowers
    tiles.append(tile_grass(21, flowers=True, tufts=1))  # 5 flowers
    for i in range(3):
        tiles.append(tile_dirt(30 + i))                   # 6-8 dirt
    tiles.append(tile_water(40))                          # 9 water
    tiles.append(tile_water(41))                          # 10 water
    tiles.append(tile_lily(42))                           # 11 lily
    tiles.append(tile_cobble(50))                         # 12 cobble
    tiles.append(tile_soil(60))                           # 13 soil
    tiles.append(tile_grass(70, tufts=6))                 # 14 tall grass
    tiles.append(tile_cobble(51))                         # 15 cobble 2
    sheet = Image.new("RGBA", (16 * 16, 16), (0, 0, 0, 0))
    for i, t in enumerate(tiles):
        sheet.alpha_composite(t.img, (i * 16, 0))
    sheet.save(os.path.join(OUT, "tiles%s.png" % suffix))

    edges = Image.new("RGBA", (16 * 8, 32), (0, 0, 0, 0))
    for i, s in enumerate(["n", "s", "e", "w", "ne", "nw", "se", "sw"]):
        edges.alpha_composite(edge_overlay(s, False, 3).img, (i * 16, 0))
        edges.alpha_composite(edge_overlay(s, True, 5).img, (i * 16, 16))
    edges.save(os.path.join(OUT, "edges%s.png" % suffix))


# ---------------------------------------------------------------- props

TREE = (66, 142, 66)
TREE_D = (44, 108, 54)
TREE_L = (104, 178, 82)
TREE_O = (28, 62, 38)
BARK = (124, 82, 50)
BARK_D = (92, 58, 38)


def blob(cv, circles, base, shade, light, seed, out=None):
    r = random.Random(seed)
    filled = set()
    for (ccx, ccy, rad) in circles:
        for y in range(int(ccy - rad - 1), int(ccy + rad + 2)):
            for x in range(int(ccx - rad - 1), int(ccx + rad + 2)):
                if (x - ccx) ** 2 + (y - ccy) ** 2 <= rad * rad:
                    filled.add((x, y))
    if not filled:
        return
    minx = min(p[0] for p in filled)
    maxx = max(p[0] for p in filled)
    miny = min(p[1] for p in filled)
    maxy = max(p[1] for p in filled)
    for (x, y) in filled:
        nx = (x - minx) / max(1, maxx - minx)
        ny = (y - miny) / max(1, maxy - miny)
        v = nx * 0.5 + ny * 0.7
        c = base
        if v > 0.85:
            c = shade
        elif v < 0.42 and r.random() < 0.55:
            c = light
        cv.px(x, y, c)
    # leafy clumps
    for _ in range(len(filled) // 25):
        x, y = r.choice(list(filled))
        if (x + 1, y + 1) in filled:
            cv.px(x, y, shade)
            cv.px(x + 1, y, shade)
            cv.px(x - 1, y - 1, light)
    if out:
        cv.outline(out)


def make_round_tree(seed, w=32, h=42):
    r = random.Random(seed)
    cv = Canvas(w, h)
    # trunk
    tx = w // 2
    cv.rect(tx - 3, h - 13, tx + 2, h - 2, BARK)
    cv.rect(tx + 1, h - 13, tx + 2, h - 2, BARK_D)
    cv.px(tx - 4, h - 2, BARK)
    cv.px(tx + 3, h - 2, BARK_D)
    cv.px(tx - 1, h - 7, BARK_D)
    cv.px(tx - 1, h - 6, BARK_D)
    circles = [(w / 2, 14, 11), (w / 2 - 7, 18, 8), (w / 2 + 7, 18, 8), (w / 2, 22, 9),
               (w / 2 - 4, 9, 7), (w / 2 + 5, 10, 7)]
    circles = [(x + r.uniform(-1, 1), y + r.uniform(-1, 1), rad) for (x, y, rad) in circles]
    leaves = Canvas(w, h)
    blob(leaves, circles, TREE, TREE_D, TREE_L, seed)
    cv.outline(OUTLINE)
    cv.paste(leaves, 0, 0)
    cv.outline(TREE_O)
    return cv


def make_fruit_tree(seed):
    cv = make_round_tree(seed)
    r = random.Random(seed)
    for _ in range(7):
        x, y = r.randint(6, 25), r.randint(6, 24)
        if cv.get(x, y)[3] and cv.get(x, y)[:3] != TREE_O[:3]:
            cv.px(x, y, (220, 60, 60))
            cv.px(x, y + 1, (160, 40, 40))
    return cv


def make_pine(seed, w=24, h=38):
    cv = Canvas(w, h)
    cx = w // 2
    cv.rect(cx - 2, h - 8, cx + 1, h - 2, BARK)
    cv.rect(cx + 1, h - 8, cx + 1, h - 2, BARK_D)
    p, pd, pl = (44, 126, 96), (30, 96, 74), (72, 158, 116)
    tiers = [(2, 10, 5), (8, 18, 8), (15, 27, 11)]
    for (top, bot, half) in tiers:
        for y in range(top, bot + 1):
            t = (y - top) / max(1, bot - top)
            hw = int(1 + half * t)
            for x in range(cx - hw, cx + hw):
                c = p
                if x >= cx + hw // 3:
                    c = pd
                elif x < cx - hw // 2 and (x + y) % 2 == 0:
                    c = pl
                cv.px(x, y, c)
        for x in range(cx - half, cx + half, 2):
            cv.px(x, bot, pd)
    cv.outline((24, 60, 48))
    return cv


def make_bush(seed, berries=False):
    cv = Canvas(18, 16)
    blob(cv, [(9, 9, 6), (5, 10, 4), (13, 10, 4), (9, 6, 4)], TREE, TREE_D, TREE_L, seed)
    if berries:
        r = random.Random(seed)
        for _ in range(5):
            x, y = r.randint(4, 13), r.randint(5, 12)
            if cv.get(x, y)[3]:
                cv.px(x, y, (110, 80, 200))
                cv.px(x + 1, y, (70, 50, 150))
    cv.outline(TREE_O)
    return cv


def make_rock(seed, big=False):
    w, h = (22, 18) if big else (16, 14)
    cv = Canvas(w, h)
    r = random.Random(seed)
    base, shade, light = (150, 152, 166), (112, 114, 130), (190, 192, 204)
    if big:
        circles = [(8, 10, 6), (14, 10, 6), (11, 7, 5)]
    else:
        circles = [(8, 8, 5), (6, 9, 4), (10, 9, 4)]
    blob(cv, circles, base, shade, light, seed)
    for _ in range(2):
        x, y = r.randint(4, w - 6), r.randint(5, h - 5)
        cv.px(x, y, shade)
        cv.px(x + 1, y + 1, shade)
    cv.outline((60, 60, 74))
    return cv


def make_log():
    cv = Canvas(26, 12)
    cv.rect(2, 2, 21, 9, BARK)
    cv.rect(2, 8, 21, 9, BARK_D)
    cv.rect(2, 2, 21, 2, mix(BARK, (255, 220, 180), 0.2))
    for x in (6, 11, 16):
        cv.px(x, 5, BARK_D)
        cv.px(x + 1, 5, BARK_D)
    cv.rect(21, 2, 23, 9, (212, 170, 120))
    cv.rect(22, 4, 22, 7, (180, 130, 90))
    cv.px(23, 2, None)
    cv.clear(23, 2)
    cv.clear(23, 9)
    cv.outline()
    return cv


def make_stump():
    cv = Canvas(18, 14)
    cv.rect(3, 4, 14, 11, BARK)
    cv.rect(11, 4, 14, 11, BARK_D)
    cv.rect(3, 3, 14, 5, (212, 170, 120))
    cv.rect(5, 4, 12, 4, (186, 140, 96))
    cv.px(2, 11, BARK)
    cv.px(15, 11, BARK_D)
    cv.clear(3, 3)
    cv.clear(14, 3)
    cv.outline()
    return cv


def make_fence_h():
    cv = Canvas(16, 18)
    wood, wd = (150, 100, 60), (112, 72, 44)
    cv.rect(0, 6, 15, 8, wood)
    cv.rect(0, 8, 15, 8, wd)
    cv.rect(5, 2, 10, 15, wood)
    cv.rect(9, 2, 10, 15, wd)
    cv.rect(5, 2, 10, 2, (190, 140, 90))
    cv.outline()
    return cv


def make_crate():
    cv = Canvas(16, 16)
    w, wd, wl = (176, 124, 70), (130, 88, 50), (204, 156, 96)
    cv.rect(1, 2, 14, 14, w)
    cv.rect(1, 2, 14, 3, wl)
    cv.rect(1, 13, 14, 14, wd)
    cv.rect(1, 2, 2, 14, wd)
    cv.rect(13, 2, 14, 14, wd)
    for i in range(10):
        cv.px(3 + i, 4 + i, wd)
    cv.outline()
    return cv


def make_barrel():
    cv = Canvas(14, 16)
    w, wd = (150, 96, 56), (110, 68, 40)
    cv.rect(2, 2, 11, 14, w)
    cv.rect(9, 2, 11, 14, wd)
    for y in (4, 11):
        cv.rect(2, y, 11, y, (110, 110, 120))
    cv.rect(3, 1, 10, 1, (90, 60, 40))
    cv.outline()
    return cv


def make_car():
    cv = Canvas(40, 26)
    body, bd = (176, 72, 64), (130, 50, 46)
    cv.rect(2, 10, 37, 20, body)
    cv.rect(2, 18, 37, 20, bd)
    cv.rect(9, 3, 30, 10, body)
    cv.rect(11, 4, 18, 9, (120, 170, 200))
    cv.rect(21, 4, 28, 9, (120, 170, 200))
    cv.rect(12, 5, 13, 6, (200, 230, 240))
    cv.rect(22, 5, 23, 6, (200, 230, 240))
    for x in (8, 30):
        cv.rect(x - 3, 19, x + 3, 24, (40, 40, 44))
        cv.rect(x - 1, 21, x + 1, 22, (120, 120, 130))
    cv.rect(34, 12, 36, 14, (240, 220, 120))
    cv.rect(20, 12, 24, 15, (90, 70, 60))  # rust
    cv.outline()
    return cv


def make_sign():
    cv = Canvas(16, 16)
    w, wd = (176, 124, 70), (130, 88, 50)
    cv.rect(7, 8, 8, 15, wd)
    cv.rect(1, 2, 14, 9, w)
    cv.rect(1, 9, 14, 9, wd)
    cv.rect(3, 4, 6, 4, wd)
    cv.rect(8, 4, 12, 4, wd)
    cv.rect(3, 6, 11, 6, wd)
    cv.outline()
    return cv


def make_well():
    cv = Canvas(24, 28)
    st, sd = (160, 158, 160), (120, 118, 124)
    cv.rect(2, 14, 21, 25, st)
    for y in (16, 19, 22, 25):
        cv.rect(2, y, 21, y, sd)
    cv.rect(4, 13, 19, 15, (40, 60, 90))
    cv.rect(3, 4, 4, 14, (120, 80, 50))
    cv.rect(19, 4, 20, 14, (120, 80, 50))
    cv.rect(0, 1, 23, 4, (190, 70, 60))
    cv.rect(0, 4, 23, 4, (140, 50, 44))
    cv.rect(11, 5, 11, 10, (90, 80, 70))
    cv.rect(10, 10, 13, 12, (140, 100, 60))
    cv.outline()
    return cv


def make_house(wall, wall_d, door, seed, w=64, h=64):
    r = random.Random(seed)
    cv = Canvas(w, h)
    thatch, thatch_d, thatch_l = (230, 180, 110), (204, 148, 86), (244, 204, 140)
    moss, moss_d = (150, 200, 96), (112, 168, 76)
    eave = (222, 132, 92)
    post, post_d = (110, 70, 48), (80, 50, 34)
    roof_bottom = 34
    wall_top = roof_bottom - 2
    wall_bottom = h - 4
    # walls
    cv.rect(4, wall_top, w - 5, wall_bottom, wall)
    for y in range(wall_top + 2, wall_bottom, 3):
        cv.rect(4, y, w - 5, y, wall_d)
        off = 0 if (y // 3) % 2 == 0 else 3
        for x in range(4 + off, w - 4, 6):
            cv.px(x, y + 1, wall_d)
            cv.px(x, y + 2, wall_d)
    cv.rect(4, wall_bottom - 1, w - 5, wall_bottom, darker(wall, 0.7))
    for x in (4, w // 2 - 12, w // 2 + 11, w - 7):
        cv.rect(x, wall_top, x + 2, wall_bottom, post)
        cv.rect(x + 2, wall_top, x + 2, wall_bottom, post_d)
    # door
    dx = w // 2 - 5
    cv.rect(dx, wall_bottom - 14, dx + 9, wall_bottom, door)
    cv.rect(dx, wall_bottom - 14, dx + 9, wall_bottom - 14, darker(door, 0.6))
    cv.rect(dx + 4, wall_bottom - 13, dx + 5, wall_bottom, darker(door, 0.75))
    cv.px(dx + 7, wall_bottom - 7, (240, 210, 110))
    cv.rect(dx - 1, wall_bottom + 1, dx + 10, wall_bottom + 2, (196, 120, 96))
    # windows
    for wx in (10, w - 21):
        cv.rect(wx, wall_top + 6, wx + 9, wall_top + 15, (90, 60, 44))
        cv.rect(wx + 1, wall_top + 7, wx + 8, wall_top + 14, (250, 222, 140))
        cv.rect(wx + 1, wall_top + 11, wx + 8, wall_top + 11, (90, 60, 44))
        cv.rect(wx + 4, wall_top + 7, wx + 5, wall_top + 14, (90, 60, 44))
        cv.rect(wx + 1, wall_top + 7, wx + 3, wall_top + 7, (255, 246, 210))
        cv.rect(wx, wall_top + 16, wx + 9, wall_top + 16, post_d)
    # roof (trapezoid with thatch strokes)
    for y in range(2, roof_bottom + 1):
        t = (y - 2) / (roof_bottom - 2)
        inset = int(10 * (1 - t))
        x0, x1 = inset + 1, w - inset - 2
        for x in range(x0, x1 + 1):
            c = thatch
            if (x * 3 + y * 7 + r.randint(0, 3)) % 9 == 0:
                c = thatch_d
            elif (x + y) % 11 == 0:
                c = thatch_l
            if x > x1 - 3:
                c = thatch_d
            cv.px(x, y, c)
    cv.rect(1, roof_bottom - 2, w - 2, roof_bottom, eave)
    cv.rect(1, roof_bottom, w - 2, roof_bottom, darker(eave, 0.75))
    for x in range(2, w - 2, 4):
        cv.px(x, roof_bottom + 1, darker(eave, 0.75))
    cv.rect(10, 2, w - 11, 3, thatch_l)
    # moss patches
    for _ in range(4):
        mx, my = r.randint(8, w - 18), r.randint(6, roof_bottom - 10)
        for yy in range(4):
            for xx in range(r.randint(5, 9)):
                if r.random() < 0.85:
                    cv.px(mx + xx + (yy % 2), my + yy, moss if yy < 3 else moss_d)
        cv.px(mx + 2, my - 1, (240, 220, 90))
    # dormer window
    dx0 = w // 2 - 6
    cv.rect(dx0, 12, dx0 + 11, 22, thatch_d)
    cv.rect(dx0 + 2, 15, dx0 + 9, 21, (90, 60, 44))
    cv.rect(dx0 + 3, 16, dx0 + 8, 20, (250, 222, 140))
    cv.rect(dx0 + 5, 16, dx0 + 6, 20, (90, 60, 44))
    cv.rect(dx0 - 1, 11, dx0 + 12, 12, thatch_l)
    cv.outline()
    return cv


def make_barricade():
    cv = Canvas(16, 20)
    w, wd, wl = (168, 116, 68), (122, 82, 48), (200, 150, 96)
    for x in (2, 12):
        cv.rect(x, 3, x + 1, 18, wd)
    for y in (5, 10, 15):
        cv.rect(0, y, 15, y + 2, w)
        cv.rect(0, y, 15, y, wl)
        cv.rect(0, y + 2, 15, y + 2, wd)
        cv.px(3, y + 1, (160, 160, 170))
        cv.px(12, y + 1, (160, 160, 170))
    for i in range(12):
        cv.px(2 + i, 5 + i, wd)
        cv.px(3 + i, 5 + i, w)
    cv.outline()
    return cv


def make_stone_wall():
    cv = Canvas(16, 22)
    r = random.Random(4)
    cv.rect(0, 4, 15, 20, (110, 108, 116))
    for by in range(4, 20, 4):
        off = 0 if (by // 4) % 2 == 0 else 4
        for bx in range(-off, 16, 8):
            c = mix((160, 158, 166), (196, 194, 202), r.random() * 0.6)
            cv.rect(bx + 1, by + 1, bx + 6, by + 3, c)
            cv.rect(bx + 1, by + 3, bx + 6, by + 3, (140, 138, 146))
    cv.rect(0, 2, 15, 4, (200, 198, 206))
    cv.outline()
    return cv


def make_spikes():
    cv = Canvas(16, 16)
    cv.rect(1, 10, 14, 13, (122, 82, 48))
    cv.rect(1, 10, 14, 10, (168, 116, 68))
    for x in range(2, 14, 3):
        cv.rect(x, 5, x + 1, 9, (190, 194, 204))
        cv.px(x, 4, (230, 232, 240))
        cv.px(x + 1, 9, (130, 134, 146))
    cv.outline()
    return cv


def make_turret():
    base = Canvas(16, 16)
    base.rect(2, 7, 13, 14, (122, 82, 48))
    base.rect(2, 7, 13, 8, (168, 116, 68))
    base.rect(5, 3, 10, 8, (100, 104, 116))
    base.rect(5, 3, 10, 4, (150, 154, 166))
    base.rect(2, 12, 13, 12, (90, 60, 36))
    base.outline()
    gun = Canvas(14, 8)
    gun.rect(1, 2, 8, 5, (80, 84, 96))
    gun.rect(1, 2, 8, 2, (140, 144, 156))
    gun.rect(8, 3, 12, 4, (60, 62, 72))
    gun.outline()
    return base, gun


def make_campfire():
    sheet = Canvas(48, 16)
    for f in range(3):
        cv = Canvas(16, 16)
        cv.rect(2, 12, 13, 13, BARK)
        cv.rect(4, 11, 11, 11, BARK_D)
        cv.rect(1, 13, 14, 14, (130, 130, 140))
        flame = [(240, 90, 40), (250, 160, 50), (255, 230, 120)]
        heights = [[7, 9, 6], [8, 6, 9], [6, 8, 7]][f]
        for i, hx in enumerate((5, 8, 10)):
            hh = heights[i]
            for y in range(11 - hh, 11):
                t = (y - (11 - hh)) / hh
                wdt = 1 if t < 0.4 else 2
                c = flame[2] if t > 0.7 else (flame[1] if t > 0.35 else flame[0])
                cv.rect(hx - wdt + 1, y, hx + wdt - 1, y, c)
        cv.outline()
        sheet.paste(cv, f * 16, 0)
    return sheet


# ---------------------------------------------------------------- items / fx / ui

def make_items():
    """12x12 icons: wood, stone, scrap, ammo, food, heart, skull, moon, sun, zombie, axe, gun, sound, mute, coin"""
    icons = []
    # wood
    cv = Canvas(12, 12)
    cv.rect(1, 4, 9, 7, BARK)
    cv.rect(1, 7, 9, 7, BARK_D)
    cv.rect(9, 4, 10, 7, (212, 170, 120))
    cv.rect(2, 1, 8, 3, BARK)
    cv.rect(8, 1, 9, 3, (212, 170, 120))
    cv.outline()
    icons.append(cv)
    # stone
    cv = Canvas(12, 12)
    blob(cv, [(6, 6, 4), (4, 7, 3), (8, 7, 3)], (150, 152, 166), (112, 114, 130), (196, 198, 210), 3)
    cv.outline((60, 60, 74))
    icons.append(cv)
    # scrap (gear)
    cv = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            dx, dy = x - 5.5, y - 5.5
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            rr = 4.2 + (1.0 if math.cos(a * 6) > 0.3 else 0)
            if d <= rr and d > 1.5:
                cv.px(x, y, (170, 174, 186) if dx + dy < 0 else (120, 124, 136))
    cv.outline()
    icons.append(cv)
    # ammo
    cv = Canvas(12, 12)
    for bx in (2, 5, 8):
        cv.rect(bx, 4, bx + 1, 10, (200, 160, 60))
        cv.rect(bx, 2, bx + 1, 3, (190, 110, 70))
        cv.px(bx + 1, 5, (240, 210, 120))
    cv.outline()
    icons.append(cv)
    # food (apple)
    cv = Canvas(12, 12)
    blob(cv, [(6, 7, 4)], (220, 56, 56), (160, 36, 40), (250, 130, 120), 1)
    cv.rect(6, 1, 6, 3, BARK_D)
    cv.rect(7, 2, 8, 2, (90, 170, 70))
    cv.outline()
    icons.append(cv)
    # heart
    cv = Canvas(12, 12)
    hp = ["............", "..XX...XX...", ".XXXX.XXXX..", ".XXXXXXXXX..", ".XXXXXXXXX..",
          "..XXXXXXX...", "...XXXXX....", "....XXX.....", ".....X......"]
    for y, row in enumerate(hp):
        for x, ch in enumerate(row):
            if ch == "X":
                cv.px(x + 1, y + 1, (226, 52, 64))
    cv.px(3, 3, (255, 180, 180))
    cv.outline()
    icons.append(cv)
    # skull
    cv = Canvas(12, 12)
    cv.rect(2, 2, 9, 7, (236, 232, 220))
    cv.rect(3, 8, 8, 9, (236, 232, 220))
    cv.rect(3, 4, 4, 5, OUTLINE[:3])
    cv.rect(7, 4, 8, 5, OUTLINE[:3])
    cv.px(4, 9, (150, 146, 140))
    cv.px(6, 9, (150, 146, 140))
    cv.outline()
    icons.append(cv)
    # moon
    cv = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            if math.hypot(x - 5.5, y - 5.5) < 4.6 and math.hypot(x - 7.5, y - 4) > 3.6:
                cv.px(x, y, (236, 232, 170))
    cv.outline()
    icons.append(cv)
    # sun
    cv = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            d = math.hypot(x - 5.5, y - 5.5)
            if d < 3.2:
                cv.px(x, y, (255, 214, 80))
            elif d < 5.2 and (x + y) % 3 == 0:
                cv.px(x, y, (250, 170, 60))
    cv.outline()
    icons.append(cv)
    # zombie head
    zc = draw_character(0, 0, ZOMBIES["zombie_worker"])
    cv = Canvas(12, 12)
    head = zc.img.crop((2, 1, 14, 13))
    cv.img.alpha_composite(head, (0, 0))
    cv.p = cv.img.load()
    icons.append(cv)
    # axe
    cv = make_axe()
    small = Canvas(12, 12)
    small.img.alpha_composite(cv.img.crop((1, 1, 13, 13)), (0, 0))
    small.p = small.img.load()
    icons.append(small)
    # gun
    g = make_pistol()
    cv = Canvas(12, 12)
    cv.img.alpha_composite(g.img, (0, 3))
    cv.p = cv.img.load()
    icons.append(cv)
    # speaker on / off
    for on in (True, False):
        cv = Canvas(12, 12)
        cv.rect(1, 4, 3, 7, (236, 232, 220))
        for i in range(4):
            cv.rect(4 + i, 4 - i, 4 + i, 7 + i, (236, 232, 220))
        if on:
            cv.rect(9, 4, 9, 7, (236, 232, 220))
            cv.px(10, 3, (236, 232, 220))
            cv.px(10, 8, (236, 232, 220))
        else:
            for i in range(3):
                cv.px(8 + i, 4 + i, (230, 70, 60))
                cv.px(10 - i, 4 + i, (230, 70, 60))
        cv.outline()
        icons.append(cv)
    # coin
    cv = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            d = math.hypot(x - 5.5, y - 5.5)
            if d < 4.6:
                cv.px(x, y, (250, 206, 70) if d < 3.4 else (210, 150, 40))
    cv.rect(5, 3, 6, 8, (255, 240, 150))
    cv.px(4, 4, (255, 250, 210))
    cv.outline()
    icons.append(cv)
    sheet = Image.new("RGBA", (12 * len(icons), 12), (0, 0, 0, 0))
    for i, c in enumerate(icons):
        sheet.alpha_composite(c.img, (i * 12, 0))
    sheet.save(os.path.join(OUT, "items.png"))


def make_axe():
    cv = Canvas(14, 14)
    for i in range(10):
        cv.px(2 + i, 11 - i, (150, 100, 60))
        cv.px(3 + i, 11 - i, (110, 72, 44))
    cv.rect(8, 1, 12, 5, (180, 186, 198))
    cv.rect(11, 1, 12, 5, (130, 136, 150))
    cv.px(8, 1, (230, 232, 240))
    cv.outline()
    return cv


def make_pistol():
    cv = Canvas(12, 8)
    cv.rect(1, 1, 10, 3, (70, 72, 84))
    cv.rect(1, 1, 10, 1, (130, 134, 146))
    cv.rect(2, 3, 4, 6, (110, 76, 50))
    cv.px(6, 4, (70, 72, 84))
    cv.outline()
    return cv


def make_fx():
    # slash arc, 3 frames of 28x28
    sheet = Canvas(84, 28)
    for f in range(3):
        cv = Canvas(28, 28)
        a0 = -1.2 + f * 0.25
        a1 = a0 + 1.6 - f * 0.3
        for i in range(60):
            a = a0 + (a1 - a0) * i / 59
            for rr in (10, 11, 12):
                x = int(14 + math.cos(a) * rr)
                y = int(14 + math.sin(a) * rr)
                alpha = 255 if rr == 11 else 170
                cv.px(x, y, (255, 255, 240), alpha - f * 60)
        sheet.paste(cv, f * 28, 0)
    sheet.img.save(os.path.join(OUT, "slash.png"))

    b = Canvas(6, 6)
    b.rect(1, 2, 4, 3, (255, 236, 140))
    b.rect(2, 1, 3, 4, (255, 236, 140))
    b.rect(2, 2, 3, 3, (255, 255, 230))
    b.img.save(os.path.join(OUT, "bullet.png"))

    sh = Canvas(14, 6)
    for y in range(6):
        for x in range(14):
            if ((x - 6.5) / 7) ** 2 + ((y - 2.5) / 3) ** 2 <= 1:
                sh.px(x, y, (20, 30, 20), 90)
    sh.img.save(os.path.join(OUT, "shadow.png"))

    bl = Canvas(48, 12)
    r = random.Random(9)
    for i in range(4):
        for _ in range(14):
            x, y = r.randint(3, 12), r.randint(3, 9)
            bl.px(i * 12 + x, y, (110, 30, 36) if r.random() < 0.6 else (80, 120, 60), 220)
    bl.img.save(os.path.join(OUT, "splat.png"))

    make_axe().img.save(os.path.join(OUT, "axe.png"))
    make_pistol().img.save(os.path.join(OUT, "pistol.png"))


def make_ui():
    # wooden 9-slice panel 24x24
    cv = Canvas(24, 24)
    cv.rect(1, 1, 22, 22, (124, 82, 52))
    cv.rect(2, 2, 21, 21, (172, 120, 74))
    cv.rect(3, 3, 20, 20, (196, 144, 92))
    for y in range(4, 20, 4):
        cv.rect(3, y, 20, y, (180, 128, 80))
    cv.outline()
    cv.img.save(os.path.join(OUT, "panel.png"))
    # dark translucent panel
    cv = Canvas(24, 24)
    cv.rect(1, 1, 22, 22, (24, 20, 30))
    cv.rect(1, 1, 22, 1, (70, 60, 80))
    for y in range(2, 23):
        for x in range(1, 23):
            cv.px(x, y, (30, 26, 40), 210)
    cv.outline((12, 10, 16))
    cv.img.save(os.path.join(OUT, "panel_dark.png"))
    # slot
    cv = Canvas(22, 22)
    cv.rect(1, 1, 20, 20, (60, 48, 40))
    cv.rect(2, 2, 19, 19, (92, 74, 60))
    cv.rect(2, 2, 19, 2, (120, 98, 80))
    cv.outline()
    cv.img.save(os.path.join(OUT, "slot.png"))
    cv = Canvas(22, 22)
    cv.rect(0, 0, 21, 21, (255, 220, 110))
    cv.rect(2, 2, 19, 19, (0, 0, 0))
    for y in range(2, 20):
        for x in range(2, 20):
            cv.clear(x, y)
    cv.img.save(os.path.join(OUT, "slot_sel.png"))
    # joystick
    for name, rad, col, alpha in (("joy_base", 22, (255, 255, 255), 50), ("joy_knob", 10, (255, 255, 255), 140)):
        size = rad * 2 + 2
        cv = Canvas(size, size)
        for y in range(size):
            for x in range(size):
                d = math.hypot(x - size / 2 + 0.5, y - size / 2 + 0.5)
                if d <= rad:
                    cv.px(x, y, col, alpha if d < rad - 1.5 else 200)
        cv.img.save(os.path.join(OUT, name + ".png"))
    # round touch button
    cv = Canvas(30, 30)
    for y in range(30):
        for x in range(30):
            d = math.hypot(x - 14.5, y - 14.5)
            if d <= 14:
                cv.px(x, y, (255, 255, 255), 70 if d < 12.5 else 190)
    cv.img.save(os.path.join(OUT, "touch_btn.png"))


# ---------------------------------------------------------------- shop, van, weapons

def make_shop():
    cv = make_house((150, 120, 170), (126, 98, 146), (120, 70, 40), 7)
    w = cv.w
    wall_top = 32
    # striped awning above the door
    for x in range(w // 2 - 14, w // 2 + 14):
        stripe = (220, 60, 56) if ((x - (w // 2 - 14)) // 3) % 2 == 0 else (244, 240, 230)
        cv.rect(x, wall_top + 8, x, wall_top + 11, stripe)
        if x % 3 == 0:
            cv.px(x, wall_top + 12, stripe)
    # hanging sign with crossed weapons
    sx, sy = w // 2 - 9, wall_top + 1
    cv.rect(sx, sy, sx + 17, sy + 6, (96, 62, 40))
    cv.rect(sx + 1, sy + 1, sx + 16, sy + 5, (232, 200, 130))
    for i in range(5):
        cv.px(sx + 6 + i, sy + 1 + i, (90, 92, 104))
        cv.px(sx + 11 - i, sy + 1 + i, (90, 92, 104))
    cv.rect(sx + 2, sy + 2, sx + 3, sy + 4, (250, 206, 70))
    cv.rect(sx + 14, sy + 2, sx + 15, sy + 4, (250, 206, 70))
    # little crates with goods in front
    for bx in (6, w - 15):
        cv.rect(bx, 54, bx + 8, 59, (176, 124, 70))
        cv.rect(bx, 54, bx + 8, 54, (204, 156, 96))
        cv.px(bx + 2, 53, (220, 60, 56))
        cv.px(bx + 5, 53, (250, 206, 70))
    cv.outline()
    return cv


def make_van(broken):
    cv = Canvas(44, 28)
    body = (70, 120, 190) if not broken else (86, 110, 150)
    bd = darker(body, 0.75)
    cv.rect(2, 9, 41, 21, body)
    cv.rect(2, 19, 41, 21, bd)
    cv.rect(4, 3, 30, 9, body)
    cv.rect(30, 6, 38, 9, body)
    cv.rect(31, 6, 37, 9, (140, 190, 220))
    cv.rect(6, 4, 13, 8, (140, 190, 220))
    cv.rect(16, 4, 23, 8, (140, 190, 220))
    cv.rect(7, 5, 8, 6, (220, 240, 250))
    cv.rect(2, 13, 41, 13, (236, 232, 220))
    cv.rect(39, 15, 41, 17, (250, 230, 130))
    for x in (9, 33):
        cv.rect(x - 4, 20, x + 4, 26, (40, 40, 46))
        cv.rect(x - 1, 22, x + 1, 24, (130, 130, 140))
    if broken:
        # rust spots, a cracked window, a flat front tyre and an open bonnet
        r = random.Random(3)
        for _ in range(14):
            x, y = r.randint(3, 40), r.randint(10, 20)
            cv.px(x, y, (130, 80, 56))
        cv.px(18, 5, (60, 80, 100))
        cv.px(19, 6, (60, 80, 100))
        cv.px(20, 7, (60, 80, 100))
        for y in range(20, 27):
            for x in range(29, 38):
                cv.clear(x, y)
        cv.rect(29, 24, 37, 26, (40, 40, 46))
        cv.rect(31, 1, 41, 4, bd)
        cv.rect(31, 5, 41, 5, (60, 60, 66))
    else:
        cv.rect(3, 10, 40, 10, lighter(body, 0.35))
    cv.outline()
    return cv


def weapon_icon(kind):
    cv = Canvas(16, 16)
    wood, wood_d = (150, 100, 60), (110, 72, 44)
    steel, steel_d, steel_l = (180, 186, 198), (120, 126, 140), (232, 236, 244)
    gun, gun_l = (70, 72, 84), (130, 134, 146)
    if kind == "axe":
        for i in range(11):
            cv.px(2 + i, 13 - i, wood)
            cv.px(3 + i, 13 - i, wood_d)
        cv.rect(9, 1, 13, 6, steel)
        cv.rect(12, 1, 13, 6, steel_d)
        cv.px(9, 1, steel_l)
    elif kind == "bat":
        for i in range(12):
            t = 1 if i < 5 else 2
            for k in range(t):
                cv.px(2 + i + k, 13 - i, (196, 150, 96) if k == 0 else (160, 116, 70))
        cv.rect(1, 13, 3, 14, (60, 40, 30))
    elif kind == "machete":
        for i in range(4):
            cv.px(2 + i, 13 - i, (60, 40, 30))
            cv.px(3 + i, 13 - i, (40, 30, 24))
        for i in range(9):
            cv.px(6 + i, 9 - i, steel)
            cv.px(6 + i, 10 - i, steel_d)
            cv.px(7 + i, 9 - i, steel_l)
    elif kind == "chainsaw":
        cv.rect(1, 6, 7, 12, (232, 130, 40))
        cv.rect(1, 11, 7, 12, (190, 96, 30))
        cv.rect(2, 4, 5, 5, (40, 40, 46))
        cv.rect(8, 8, 15, 10, steel)
        for x in range(8, 16, 2):
            cv.px(x, 7, steel_d)
            cv.px(x + 1, 11, steel_d)
    elif kind == "pistol":
        cv.rect(2, 5, 12, 7, gun)
        cv.rect(2, 5, 12, 5, gun_l)
        cv.rect(3, 8, 5, 11, (110, 76, 50))
    elif kind == "shotgun":
        cv.rect(0, 6, 15, 7, gun)
        cv.rect(0, 6, 15, 6, gun_l)
        cv.rect(5, 8, 9, 8, gun)
        cv.rect(0, 8, 4, 11, (130, 86, 52))
        cv.rect(8, 8, 11, 9, (130, 86, 52))
    elif kind == "smg":
        cv.rect(2, 5, 14, 8, gun)
        cv.rect(2, 5, 14, 5, gun_l)
        cv.rect(6, 9, 8, 13, (50, 52, 60))
        cv.rect(11, 9, 12, 11, (50, 52, 60))
        cv.rect(0, 6, 2, 7, gun)
    cv.outline()
    return cv


WEAPON_ORDER = ["axe", "bat", "machete", "chainsaw", "pistol", "shotgun", "smg"]


def make_weapons():
    sheet = Image.new("RGBA", (16 * len(WEAPON_ORDER), 16), (0, 0, 0, 0))
    for i, k in enumerate(WEAPON_ORDER):
        sheet.alpha_composite(weapon_icon(k).img, (i * 16, 0))
    sheet.save(os.path.join(OUT, "weapons.png"))


def make_smoke():
    cv = Canvas(8, 8)
    for y in range(8):
        for x in range(8):
            d = math.hypot(x - 3.5, y - 3.5)
            if d < 3.6:
                cv.px(x, y, (200, 200, 205), 200 if d < 2.5 else 120)
    cv.img.save(os.path.join(OUT, "smoke.png"))


# ---------------------------------------------------------------- dog, iron, gate, slime

DOG = (112, 124, 98)
DOG_D = (82, 92, 72)
DOG_L = (146, 156, 124)


def draw_dog(d, frame):
    cv = Canvas(16, 16)
    walk = frame % 4
    attack = frame >= 4
    eye = Z_EYE
    if d == 2:
        lunge = 1 if attack else 0
        # legs (front pair and back pair alternate)
        off = [0, 1, 0, -1, 1, 1][frame]
        for lx, o in ((4, off), (6, -off), (10, -off), (12, off)):
            cv.rect(lx + o if lx > 8 else lx + o, 11, lx + o, 13, DOG_D if lx in (6, 12) else DOG)
        # body
        cv.rect(3, 7, 11, 10, DOG)
        cv.rect(3, 10, 11, 10, DOG_D)
        cv.rect(4, 7, 9, 7, DOG_L)
        cv.px(6, 9, (160, 70, 70))
        cv.px(8, 9, (160, 70, 70))
        cv.px(7, 8, (200, 190, 170))
        # tail
        cv.px(2, 7, DOG)
        cv.px(1, 6 - (walk % 2), DOG)
        # head
        hx = 10 + lunge
        cv.rect(hx, 4, hx + 3, 8, DOG)
        cv.rect(hx + 3, 6, hx + 5, 8, DOG)
        cv.px(hx, 3, DOG_D)
        cv.px(hx + 1, 2, DOG_D)
        cv.px(hx + 2, 5, eye)
        cv.rect(hx + 3, 8, hx + 5, 8, (70, 30, 40))
        cv.px(hx + 4, 8, (230, 225, 200))
        if attack:
            cv.rect(hx + 3, 9, hx + 5, 9, (70, 30, 40))
    elif d == 0:
        off = [0, 1, 0, -1, 0, 0][frame]
        cv.rect(5, 12 - max(off, 0), 5, 13 - max(off, 0), DOG_D)
        cv.rect(10, 12 - max(-off, 0), 10, 13 - max(-off, 0), DOG_D)
        cv.rect(4, 8, 11, 11, DOG)
        cv.rect(4, 11, 11, 11, DOG_D)
        hy = 3 + (1 if attack else 0)
        cv.rect(5, hy, 10, hy + 5, DOG)
        cv.rect(5, hy, 10, hy, DOG_L)
        cv.px(5, hy - 1, DOG_D)
        cv.px(10, hy - 1, DOG_D)
        cv.px(4, hy - 1, DOG_D)
        cv.px(11, hy - 1, DOG_D)
        cv.px(6, hy + 2, eye)
        cv.px(9, hy + 2, eye)
        cv.rect(7, hy + 3, 8, hy + 6, DOG_L)
        cv.rect(7, hy + 6, 8, hy + 6, (70, 30, 40))
        if attack:
            cv.px(7, hy + 7, (230, 225, 200))
            cv.px(8, hy + 7, (70, 30, 40))
        cv.px(6, 9, (160, 70, 70))
    else:
        off = [0, 1, 0, -1, 0, 0][frame]
        cv.rect(5, 11 + max(off, 0) - 1, 5, 13, DOG_D)
        cv.rect(10, 11 + max(-off, 0) - 1, 10, 13, DOG_D)
        cv.rect(4, 5, 11, 11, DOG)
        cv.rect(4, 5, 5, 11, DOG_L)
        cv.rect(10, 5, 11, 11, DOG_D)
        cv.px(7, 7, (160, 70, 70))
        cv.px(8, 8, (160, 70, 70))
        cv.rect(6, 2, 9, 4, DOG)
        cv.px(6, 1, DOG_D)
        cv.px(9, 1, DOG_D)
        tx = 7 + [0, 1, 0, -1, 0, 0][frame]
        cv.rect(tx, 12, tx + 1, 14, DOG)
    cv.outline()
    return cv


def make_dog_sheet():
    sheet = Image.new("RGBA", (16 * 6, 16 * 3), (0, 0, 0, 0))
    for d in range(3):
        for f in range(6):
            sheet.alpha_composite(draw_dog(d, f).img, (f * 16, d * 16))
    sheet.save(os.path.join(OUT, "zombie_dog.png"))


def make_iron_barricade():
    cv = Canvas(16, 20)
    iron, iron_d, iron_l = (130, 136, 150), (88, 92, 106), (184, 190, 204)
    for x in (2, 12):
        cv.rect(x, 3, x + 1, 18, iron_d)
    for y in (4, 9, 14):
        cv.rect(0, y, 15, y + 3, iron)
        cv.rect(0, y, 15, y, iron_l)
        cv.rect(0, y + 3, 15, y + 3, iron_d)
        for x in (1, 5, 10, 14):
            cv.px(x, y + 1, (220, 224, 232))
    for i in range(10):
        cv.px(3 + i, 5 + i, iron_d)
    cv.px(6, 12, (150, 90, 60))
    cv.px(7, 12, (150, 90, 60))
    cv.outline()
    return cv


def make_gate():
    sheet = Canvas(32, 20)
    wood, wood_d, wood_l = (168, 116, 68), (122, 82, 48), (200, 150, 96)
    for f in range(2):
        cv = Canvas(16, 20)
        cv.rect(0, 2, 1, 19, wood_d)
        cv.rect(14, 2, 15, 19, wood_d)
        cv.rect(0, 1, 1, 1, wood_l)
        cv.rect(14, 1, 15, 1, wood_l)
        if f == 0:
            for x in range(2, 14, 3):
                cv.rect(x, 4, x + 1, 18, wood)
                cv.px(x, 4, wood_l)
            cv.rect(2, 7, 13, 8, wood_d)
            cv.rect(2, 14, 13, 15, wood_d)
            cv.rect(7, 10, 8, 12, (120, 124, 136))
        else:
            # open: the two doors folded to the sides
            cv.rect(2, 4, 3, 18, wood)
            cv.rect(12, 4, 13, 18, wood)
            cv.px(2, 4, wood_l)
            cv.px(13, 4, wood_l)
        cv.rect(0, 1, 15, 2, wood_d)
        cv.rect(0, 1, 15, 1, wood_l)
        cv.outline()
        sheet.paste(cv, f * 16, 0)
    return sheet


def make_slime():
    cv = Canvas(8, 8)
    for y in range(8):
        for x in range(8):
            dd = math.hypot(x - 3.5, y - 3.8)
            if dd < 3.2:
                cv.px(x, y, (110, 210, 70) if dd < 2.2 else (70, 160, 50))
    cv.px(2, 2, (220, 255, 180))
    cv.outline((30, 70, 30))
    cv.img.save(os.path.join(OUT, "slime.png"))
    pd = Canvas(20, 10)
    for y in range(10):
        for x in range(20):
            dd = ((x - 9.5) / 9.5) ** 2 + ((y - 4.5) / 4.5) ** 2
            if dd < 1.0:
                pd.px(x, y, (110, 210, 70) if dd < 0.6 else (80, 170, 55), 170)
    pd.px(6, 3, (200, 250, 160), 200)
    pd.px(12, 5, (200, 250, 160), 200)
    pd.img.save(os.path.join(OUT, "puddle.png"))


# ---------------------------------------------------------------- seasons

def recolor(cv, mapping):
    """Swap exact RGB colours (used for autumn leaves and snowy roofs)."""
    out = Canvas(cv.w, cv.h)
    for y in range(cv.h):
        for x in range(cv.w):
            px = cv.get(x, y)
            if px[3] == 0:
                continue
            c = mapping.get(px[:3], px[:3])
            out.px(x, y, c, px[3])
    return out


SEASON_GROUND = {
    "autumn": dict(GRASS=(150, 158, 78), GRASS_D=(124, 132, 62), GRASS_L=(186, 182, 98)),
    "winter": dict(GRASS=(230, 236, 244), GRASS_D=(196, 208, 226), GRASS_L=(250, 252, 255),
                   DIRT=(166, 150, 140), DIRT_D=(140, 126, 118), DIRT_L=(196, 188, 184),
                   WATER=(168, 208, 232), WATER_D=(136, 182, 216), WATER_L=(226, 242, 252)),
}

LEAVES_AUTUMN = {TREE: (214, 128, 52), TREE_D: (170, 86, 40), TREE_L: (240, 178, 74), TREE_O: (90, 44, 24)}
LEAVES_RED = {TREE: (196, 70, 50), TREE_D: (150, 44, 38), TREE_L: (232, 116, 72), TREE_O: (80, 30, 24)}
LEAVES_SNOW = {TREE: (234, 238, 246), TREE_D: (196, 208, 228), TREE_L: (252, 253, 255), TREE_O: (84, 96, 120)}
PINE_SNOW = {(72, 158, 116): (248, 250, 255), (44, 126, 96): (52, 120, 96)}
ROOF_SNOW = {
    (230, 180, 110): (238, 242, 250), (204, 148, 86): (200, 212, 232), (244, 204, 140): (252, 253, 255),
    (150, 200, 96): (226, 234, 244), (112, 168, 76): (206, 218, 236), (240, 220, 90): (238, 242, 250),
}


def season_tiles():
    g = globals()
    for season, colors in SEASON_GROUND.items():
        saved = {k: g[k] for k in colors}
        g.update(colors)
        make_tiles("_" + season)
        g.update(saved)


def snowy_roof(cv):
    out = recolor(cv, ROOF_SNOW)
    # icicles under the eave
    for y in range(out.h - 1):
        for x in range(2, out.w - 2, 5):
            if out.get(x, y)[:3] == darker((222, 132, 92), 0.75) and out.get(x, y + 1)[3] == 255:
                out.px(x, y + 1, (200, 230, 250))
                out.px(x, y + 2, (220, 240, 255))
                break
    return out


def make_home(snow=False):
    cv = make_house((126, 170, 110), (104, 146, 92), (200, 64, 60), 9)
    w = cv.w
    # heart sign next to the door + flower boxes: "this is your home"
    hx, hy = w // 2 + 8, 40
    cv.rect(hx, hy, hx + 8, hy + 7, (96, 62, 40))
    cv.rect(hx + 1, hy + 1, hx + 7, hy + 6, (240, 226, 196))
    heart = [".X.X.", "XXXXX", "XXXXX", ".XXX.", "..X.."]
    for yy, row in enumerate(heart):
        for xx, ch in enumerate(row):
            if ch == "X":
                cv.px(hx + 2 + xx, hy + 1 + yy, (220, 50, 70))
    for bx in (9, w - 20):
        cv.rect(bx, 49, bx + 11, 51, (120, 80, 50))
        for i in range(0, 11, 3):
            cv.px(bx + i, 48, (240, 90, 110))
            cv.px(bx + i + 1, 48, (250, 220, 80))
    cv.outline()
    return snowy_roof(cv) if snow else cv


def season_props():
    save = lambda c, n: c.img.save(os.path.join(OUT, n + ".png"))
    save(recolor(make_round_tree(11), LEAVES_AUTUMN), "tree_round_autumn")
    save(recolor(make_round_tree(23), LEAVES_RED), "tree_round2_autumn")
    save(recolor(make_fruit_tree(31), LEAVES_AUTUMN), "tree_fruit_autumn")
    save(recolor(make_bush(3), LEAVES_AUTUMN), "bush_autumn")
    save(recolor(make_bush(4, berries=True), LEAVES_RED), "bush_berry_autumn")
    save(recolor(make_round_tree(11), LEAVES_SNOW), "tree_round_winter")
    save(recolor(make_round_tree(23), LEAVES_SNOW), "tree_round2_winter")
    save(recolor(make_fruit_tree(31), LEAVES_SNOW), "tree_fruit_winter")
    save(recolor(make_pine(5), PINE_SNOW), "tree_pine_winter")
    save(recolor(make_bush(3), LEAVES_SNOW), "bush_winter")
    save(recolor(make_bush(4, berries=True), LEAVES_SNOW), "bush_berry_winter")
    houses = {
        "house_red": ((178, 74, 62), (150, 58, 50), (180, 50, 46), 1),
        "house_blue": ((112, 182, 190), (90, 152, 162), (70, 120, 190), 2),
        "house_tan": ((196, 156, 96), (168, 128, 76), (110, 70, 48), 3),
        "house_white": ((214, 200, 170), (186, 172, 142), (60, 120, 80), 4),
    }
    for name, args in houses.items():
        save(snowy_roof(make_house(*args)), name + "_winter")
    save(snowy_roof(make_shop()), "shop_winter")
    save(make_home(), "home")
    save(make_home(True), "home_winter")


# ---------------------------------------------------------------- house interiors

WOOD, WOOD_D, WOOD_L = (150, 100, 60), (112, 72, 44), (190, 140, 92)


def make_interior():
    save = lambda c, n: c.img.save(os.path.join(OUT, "in_" + n + ".png"))
    # floors (16x16)
    for name, base in (("floor", (176, 128, 84)), ("floor_home", (190, 142, 94))):
        cv = Canvas(16, 16)
        cv.rect(0, 0, 15, 15, base)
        for y in (3, 7, 11, 15):
            cv.rect(0, y, 15, y, darker(base, 0.82))
        for y, x in ((0, 5), (4, 11), (8, 2), (12, 9)):
            cv.rect(x, y, x, y + 2, darker(base, 0.85))
        cv.px(3, 1, lighter(base, 0.15))
        cv.px(12, 9, lighter(base, 0.15))
        save(cv, name)
    # walls (16x32): wallpaper + wooden trim; one sheet per wallpaper colour, frame 1 = window
    papers = {"a": ((206, 182, 140), (190, 164, 122)), "b": ((150, 178, 140), (134, 162, 124)),
              "c": ((150, 168, 196), (134, 152, 182)), "home": ((214, 160, 140), (198, 142, 124))}
    for name, (paper, stripe) in papers.items():
        sheet = Canvas(32, 32)
        for f in range(2):
            cv = Canvas(16, 32)
            cv.rect(0, 0, 15, 25, paper)
            for x in range(1, 16, 4):
                cv.rect(x, 0, x, 25, stripe)
            cv.rect(0, 0, 15, 1, darker(paper, 0.7))
            cv.rect(0, 26, 15, 28, WOOD)
            cv.rect(0, 26, 15, 26, WOOD_L)
            cv.rect(0, 29, 15, 31, darker(WOOD, 0.7))
            if f == 1:
                cv.rect(3, 6, 12, 18, (90, 60, 44))
                cv.rect(4, 7, 11, 17, (120, 170, 210))
                cv.rect(4, 12, 11, 12, (90, 60, 44))
                cv.rect(7, 7, 8, 17, (90, 60, 44))
                cv.rect(4, 7, 6, 7, (200, 230, 250))
                cv.rect(2, 19, 13, 19, WOOD_L)
            sheet.paste(cv, f * 16, 0)
        save(sheet, "wall_" + name)

    # bed 16x28
    for name, blanket in (("bed", (200, 70, 70)), ("bed_blue", (70, 110, 190))):
        cv = Canvas(16, 28)
        cv.rect(1, 1, 14, 6, WOOD)
        cv.rect(1, 1, 14, 1, WOOD_L)
        cv.rect(2, 6, 13, 24, (236, 232, 222))
        cv.rect(3, 7, 12, 10, (250, 250, 246))
        cv.rect(2, 11, 13, 24, blanket)
        cv.rect(2, 11, 13, 11, lighter(blanket, 0.3))
        cv.rect(12, 11, 13, 24, darker(blanket))
        for y in (15, 19):
            cv.rect(2, y, 13, y, darker(blanket, 0.85))
        cv.rect(1, 24, 14, 26, WOOD_D)
        cv.outline()
        save(cv, name)
    # table 28x18 and chair 10x14
    cv = Canvas(28, 18)
    cv.rect(1, 2, 26, 9, WOOD_L)
    cv.rect(1, 9, 26, 10, WOOD)
    cv.rect(1, 11, 26, 11, WOOD_D)
    for x in (2, 24):
        cv.rect(x, 11, x + 1, 16, WOOD_D)
    cv.rect(8, 4, 11, 6, (240, 240, 236))
    cv.rect(16, 3, 18, 6, (200, 80, 60))
    cv.outline()
    save(cv, "table")
    cv = Canvas(10, 14)
    cv.rect(1, 1, 8, 6, WOOD)
    cv.rect(1, 7, 8, 8, WOOD_L)
    cv.rect(1, 9, 2, 12, WOOD_D)
    cv.rect(7, 9, 8, 12, WOOD_D)
    cv.outline()
    save(cv, "chair")
    # cupboard 18x28 (closed / open)
    for opened in (False, True):
        cv = Canvas(18, 28)
        cv.rect(1, 1, 16, 26, WOOD)
        cv.rect(1, 1, 16, 2, WOOD_L)
        cv.rect(15, 1, 16, 26, WOOD_D)
        if opened:
            cv.rect(3, 4, 14, 23, (60, 40, 30))
            cv.rect(3, 13, 14, 13, WOOD_D)
            cv.rect(0, 4, 1, 23, WOOD_L)
            cv.rect(16, 4, 17, 23, WOOD_L)
        else:
            cv.rect(3, 4, 8, 23, WOOD_L)
            cv.rect(9, 4, 14, 23, WOOD_L)
            cv.rect(8, 4, 9, 23, WOOD_D)
            cv.px(7, 13, (240, 210, 110))
            cv.px(10, 13, (240, 210, 110))
        cv.rect(1, 24, 16, 26, WOOD_D)
        cv.outline()
        save(cv, "cupboard_open" if opened else "cupboard")
    # chest 18x14 (closed / open)
    for opened in (False, True):
        cv = Canvas(18, 16)
        top = 6 if not opened else 7
        cv.rect(1, top, 16, 14, WOOD)
        cv.rect(1, 14, 16, 14, WOOD_D)
        for x in (4, 12):
            cv.rect(x, top, x + 1, 14, (120, 124, 136))
        if opened:
            cv.rect(1, 1, 16, 5, WOOD_D)
            cv.rect(2, 6, 15, 7, (50, 34, 26))
        else:
            cv.rect(1, 3, 16, 6, WOOD_L)
            cv.rect(8, 7, 9, 9, (240, 210, 110))
        cv.outline()
        save(cv, "chest_open" if opened else "chest")
    # bookshelf 18x28 (full / searched)
    r = random.Random(5)
    for empty in (False, True):
        cv = Canvas(18, 28)
        cv.rect(1, 1, 16, 26, WOOD_D)
        cv.rect(2, 2, 15, 25, (70, 46, 32))
        for sy in (8, 15, 22):
            cv.rect(2, sy, 15, sy + 1, WOOD)
        for sy in (3, 10, 17):
            x = 3
            while x < 14:
                if empty and r.random() < 0.65:
                    x += 2
                    continue
                c = r.choice([(200, 60, 60), (60, 110, 190), (80, 160, 90), (220, 180, 60), (150, 90, 170)])
                hgt = r.randint(3, 4)
                cv.rect(x, sy + 4 - hgt + 1, x + 1, sy + 4, c)
                x += 2
        cv.outline()
        save(cv, "shelf_empty" if empty else "shelf")
    # fireplace 26x28
    cv = Canvas(26, 28)
    stone, stone_d = (150, 146, 150), (112, 108, 114)
    cv.rect(1, 3, 24, 26, stone)
    for y in range(5, 26, 4):
        cv.rect(1, y, 24, y, stone_d)
    cv.rect(0, 1, 25, 4, WOOD)
    cv.rect(0, 1, 25, 1, WOOD_L)
    cv.rect(6, 12, 19, 26, (40, 26, 22))
    for i, (fx, fh) in enumerate(((9, 7), (12, 9), (15, 6))):
        for y in range(26 - fh, 26):
            t = (y - (26 - fh)) / fh
            c = (255, 230, 120) if t > 0.6 else ((250, 160, 50) if t > 0.3 else (240, 90, 40))
            cv.rect(fx, y, fx + 1, y, c)
    cv.rect(7, 24, 18, 25, BARK)
    cv.outline()
    save(cv, "fireplace")
    # plant 12x18
    cv = Canvas(12, 18)
    cv.rect(3, 12, 8, 16, (180, 90, 60))
    cv.rect(3, 12, 8, 12, (210, 120, 80))
    blob(cv, [(6, 7, 4), (3, 9, 3), (9, 9, 3)], TREE, TREE_D, TREE_L, 3)
    cv.outline()
    save(cv, "plant")
    # rug 48x28
    cv = Canvas(48, 28)
    for y in range(28):
        for x in range(48):
            edge = x < 3 or y < 3 or x > 44 or y > 24
            c = (170, 60, 60) if not edge else (220, 190, 110)
            if not edge and (x + y) % 8 == 0:
                c = (200, 90, 80)
            cv.px(x, y, c, 235)
    save(cv, "rug")
    # door / exit mat 20x8
    cv = Canvas(20, 8)
    cv.rect(0, 0, 19, 7, (60, 40, 30))
    cv.rect(2, 2, 17, 7, (150, 120, 70))
    for x in range(3, 17, 2):
        cv.px(x, 4, (120, 92, 52))
    save(cv, "exit")
    # sparkle that marks something you can search
    cv = Canvas(7, 7)
    for (x, y) in ((3, 0), (3, 1), (3, 5), (3, 6), (0, 3), (1, 3), (5, 3), (6, 3)):
        cv.px(x, y, (255, 240, 140))
    cv.rect(2, 2, 4, 4, (255, 255, 220))
    save(cv, "sparkle")


# ---------------------------------------------------------------- the big manor house

def make_mansion(snow=False):
    """A big house with three floors (96x100): brick walls, two rows of windows, attic, chimneys."""
    w, h = 96, 100
    r = random.Random(12)
    cv = Canvas(w, h)
    brick, brick_d = (176, 96, 80), (148, 76, 64)
    stone, stone_d = (196, 190, 176), (160, 154, 142)
    thatch, thatch_d, thatch_l = (230, 180, 110), (204, 148, 86), (244, 204, 140)
    post_d = (80, 50, 34)
    wall_top, wall_bottom = 30, h - 4
    # walls with bricks
    cv.rect(4, wall_top, w - 5, wall_bottom, brick)
    for y in range(wall_top + 2, wall_bottom, 3):
        cv.rect(4, y, w - 5, y, brick_d)
        off = 0 if (y // 3) % 2 == 0 else 3
        for x in range(4 + off, w - 4, 6):
            cv.px(x, y + 1, brick_d)
    # stone band between the floors and stone corners
    for y in (wall_top + 1, wall_top + 32):
        cv.rect(4, y, w - 5, y + 2, stone)
        cv.rect(4, y + 2, w - 5, y + 2, stone_d)
    for x in (4, w - 9):
        cv.rect(x, wall_top, x + 4, wall_bottom, stone)
        for y in range(wall_top + 2, wall_bottom, 6):
            cv.rect(x, y, x + 4, y, stone_d)
    cv.rect(4, wall_bottom - 1, w - 5, wall_bottom, darker(brick, 0.7))

    def window(wx, wy, wh=11):
        cv.rect(wx, wy, wx + 9, wy + wh, (90, 60, 44))
        cv.rect(wx + 1, wy + 1, wx + 8, wy + wh - 1, (250, 222, 140))
        cv.rect(wx + 1, wy + wh // 2, wx + 8, wy + wh // 2, (90, 60, 44))
        cv.rect(wx + 4, wy + 1, wx + 5, wy + wh - 1, (90, 60, 44))
        cv.rect(wx + 1, wy + 1, wx + 3, wy + 1, (255, 246, 210))
        cv.rect(wx - 1, wy + wh + 1, wx + 10, wy + wh + 1, stone)
        # shutters
        cv.rect(wx - 3, wy, wx - 2, wy + wh, (70, 110, 80))
        cv.rect(wx + 11, wy, wx + 12, wy + wh, (70, 110, 80))

    # first floor windows
    for wx in (14, 34, 52, 72):
        window(wx, wall_top + 7)
    # ground floor windows
    for wx in (14, 72):
        window(wx, wall_top + 40, 13)
    # big double door with steps and a little roof
    dx = w // 2 - 8
    cv.rect(dx, wall_bottom - 20, dx + 15, wall_bottom, (110, 60, 40))
    cv.rect(dx + 7, wall_bottom - 19, dx + 8, wall_bottom, (80, 44, 30))
    cv.rect(dx, wall_bottom - 20, dx + 15, wall_bottom - 20, post_d)
    cv.px(dx + 5, wall_bottom - 9, (240, 210, 110))
    cv.px(dx + 10, wall_bottom - 9, (240, 210, 110))
    cv.rect(dx - 4, wall_bottom - 25, dx + 19, wall_bottom - 22, (200, 70, 60))
    cv.rect(dx - 4, wall_bottom - 22, dx + 19, wall_bottom - 22, (150, 50, 44))
    cv.rect(dx - 3, wall_bottom - 21, dx - 2, wall_bottom, stone)
    cv.rect(dx + 17, wall_bottom - 21, dx + 18, wall_bottom, stone)
    cv.rect(dx - 4, wall_bottom + 1, dx + 19, wall_bottom + 2, stone_d)
    # roof
    for y in range(4, wall_top + 2):
        t = (y - 4) / (wall_top - 2)
        inset = int(14 * (1 - t))
        x0, x1 = inset + 1, w - inset - 2
        for x in range(x0, x1 + 1):
            c = thatch
            if (x * 3 + y * 7 + r.randint(0, 3)) % 9 == 0:
                c = thatch_d
            elif (x + y) % 11 == 0:
                c = thatch_l
            if x > x1 - 3:
                c = thatch_d
            cv.px(x, y, c)
    cv.rect(1, wall_top - 1, w - 2, wall_top + 1, (222, 132, 92))
    cv.rect(1, wall_top + 1, w - 2, wall_top + 1, darker((222, 132, 92), 0.75))
    cv.rect(16, 4, w - 17, 5, thatch_l)
    # attic dormers (the third floor)
    for ax in (22, w // 2 - 6, w - 34):
        cv.rect(ax, 10, ax + 11, 21, thatch_d)
        cv.rect(ax + 2, 13, ax + 9, 20, (90, 60, 44))
        cv.rect(ax + 3, 14, ax + 8, 19, (250, 222, 140))
        cv.rect(ax + 5, 14, ax + 6, 19, (90, 60, 44))
        cv.rect(ax - 1, 9, ax + 12, 10, thatch_l)
    # chimneys
    for cx in (12, w - 18):
        cv.rect(cx, 0, cx + 5, 10, stone)
        cv.rect(cx, 0, cx + 5, 1, stone_d)
        cv.rect(cx + 4, 0, cx + 5, 10, stone_d)
    cv.outline()
    return snowy_roof(cv) if snow else cv


def make_manor_interior():
    save = lambda c, n: c.img.save(os.path.join(OUT, "in_" + n + ".png"))
    # stairs going up (against the back wall)
    cv = Canvas(24, 32)
    for i in range(7):
        y = 30 - i * 4
        cv.rect(2 + i, y - 3, 21 - i, y, (176, 128, 84) if i % 2 == 0 else (160, 114, 74))
        cv.rect(2 + i, y, 21 - i, y, (120, 82, 54))
    cv.rect(0, 2, 1, 31, WOOD_D)
    cv.rect(22, 2, 23, 31, WOOD_D)
    cv.rect(8, 0, 15, 3, (40, 26, 22))
    cv.outline()
    save(cv, "stairs_up")
    # opening in the floor with stairs going down + railing
    cv = Canvas(28, 22)
    cv.rect(2, 4, 25, 19, (40, 26, 22))
    for i in range(4):
        cv.rect(4 + i * 2, 6 + i * 3, 23 - i * 2, 7 + i * 3, (150, 104, 66))
    cv.rect(0, 2, 27, 3, WOOD)
    cv.rect(0, 2, 27, 2, WOOD_L)
    for x in range(1, 27, 4):
        cv.rect(x, 0, x, 3, WOOD_D)
    cv.rect(0, 2, 1, 20, WOOD)
    cv.rect(26, 2, 27, 20, WOOD)
    cv.outline()
    save(cv, "stairs_down")
    # attic: wooden walls and dusty floor
    sheet = Canvas(32, 32)
    for f in range(2):
        cv = Canvas(16, 32)
        cv.rect(0, 0, 15, 28, (120, 84, 56))
        for x in range(0, 16, 5):
            cv.rect(x, 0, x, 28, (96, 66, 44))
        cv.rect(0, 10, 15, 11, (90, 60, 40))
        cv.rect(0, 29, 15, 31, (70, 46, 32))
        if f == 1:
            cv.rect(4, 4, 11, 10, (60, 40, 30))
            cv.rect(5, 5, 10, 9, (110, 150, 190))
            cv.rect(7, 5, 8, 9, (60, 40, 30))
        sheet.paste(cv, f * 16, 0)
    save(sheet, "wall_attic")
    cv = Canvas(16, 16)
    cv.rect(0, 0, 15, 15, (150, 116, 84))
    for y in (3, 7, 11, 15):
        cv.rect(0, y, 15, y, (126, 96, 70))
    for (x, y) in ((3, 2), (11, 9), (6, 13)):
        cv.px(x, y, (176, 160, 140))
    save(cv, "floor_attic")
    # treasure chest (gold) closed / open
    for opened in (False, True):
        cv = Canvas(20, 18)
        gold, gold_d = (240, 200, 70), (190, 140, 40)
        top = 7 if not opened else 8
        cv.rect(1, top, 18, 16, (140, 70, 50))
        cv.rect(1, 16, 18, 16, (100, 50, 36))
        for x in (3, 9, 15):
            cv.rect(x, top, x + 1, 16, gold)
        if opened:
            cv.rect(1, 1, 18, 6, (110, 56, 40))
            cv.rect(2, 7, 17, 8, (60, 30, 24))
            for x in range(3, 17, 2):
                cv.px(x, 7, gold)
        else:
            cv.rect(1, 3, 18, 7, (170, 86, 60))
            cv.rect(1, 3, 18, 3, gold)
            cv.rect(8, 8, 11, 11, gold_d)
            cv.px(9, 9, (255, 240, 160))
        cv.outline()
        save(cv, "treasure_open" if opened else "treasure")
    # sofa 30x18 for the living room
    cv = Canvas(30, 18)
    cv.rect(1, 2, 28, 9, (120, 70, 110))
    cv.rect(1, 9, 28, 14, (150, 90, 140))
    cv.rect(1, 2, 3, 15, (110, 62, 100))
    cv.rect(26, 2, 28, 15, (110, 62, 100))
    cv.rect(4, 10, 14, 10, (176, 116, 166))
    cv.rect(15, 10, 25, 10, (176, 116, 166))
    cv.rect(2, 15, 3, 16, WOOD_D)
    cv.rect(26, 15, 27, 16, WOOD_D)
    cv.outline()
    save(cv, "sofa")
    # dusty boxes in the attic
    cv = Canvas(16, 16)
    cv.rect(1, 4, 14, 14, (180, 140, 90))
    cv.rect(1, 4, 14, 5, (204, 166, 112))
    cv.rect(7, 4, 8, 14, (150, 112, 70))
    cv.outline()
    save(cv, "box")


def main():
    os.makedirs(OUT, exist_ok=True)
    character_sheet("player", PLAYER)
    for name, cfg in ZOMBIES.items():
        character_sheet(name, cfg)
    for name, cfg in VILLAGERS_FOR_MENU.items():
        character_sheet(name, cfg)
    make_tiles()
    season_tiles()
    make_round_tree(11).img.save(os.path.join(OUT, "tree_round.png"))
    make_round_tree(23).img.save(os.path.join(OUT, "tree_round2.png"))
    make_fruit_tree(31).img.save(os.path.join(OUT, "tree_fruit.png"))
    make_pine(5).img.save(os.path.join(OUT, "tree_pine.png"))
    make_bush(3).img.save(os.path.join(OUT, "bush.png"))
    make_bush(4, berries=True).img.save(os.path.join(OUT, "bush_berry.png"))
    make_rock(1).img.save(os.path.join(OUT, "rock.png"))
    make_rock(2, big=True).img.save(os.path.join(OUT, "rock_big.png"))
    make_log().img.save(os.path.join(OUT, "log.png"))
    make_stump().img.save(os.path.join(OUT, "stump.png"))
    make_fence_h().img.save(os.path.join(OUT, "fence.png"))
    make_crate().img.save(os.path.join(OUT, "crate.png"))
    make_barrel().img.save(os.path.join(OUT, "barrel.png"))
    make_car().img.save(os.path.join(OUT, "car.png"))
    make_sign().img.save(os.path.join(OUT, "sign.png"))
    make_well().img.save(os.path.join(OUT, "well.png"))
    make_house((178, 74, 62), (150, 58, 50), (180, 50, 46), 1).img.save(os.path.join(OUT, "house_red.png"))
    make_house((112, 182, 190), (90, 152, 162), (70, 120, 190), 2).img.save(os.path.join(OUT, "house_blue.png"))
    make_house((196, 156, 96), (168, 128, 76), (110, 70, 48), 3).img.save(os.path.join(OUT, "house_tan.png"))
    make_barricade().img.save(os.path.join(OUT, "barricade.png"))
    make_stone_wall().img.save(os.path.join(OUT, "wall_stone.png"))
    make_spikes().img.save(os.path.join(OUT, "spikes.png"))
    base, gun = make_turret()
    base.img.save(os.path.join(OUT, "turret_base.png"))
    gun.img.save(os.path.join(OUT, "turret_gun.png"))
    make_campfire().img.save(os.path.join(OUT, "campfire.png"))
    make_house((214, 200, 170), (186, 172, 142), (60, 120, 80), 4).img.save(os.path.join(OUT, "house_white.png"))
    make_shop().img.save(os.path.join(OUT, "shop.png"))
    make_van(True).img.save(os.path.join(OUT, "van_broken.png"))
    make_van(False).img.save(os.path.join(OUT, "van.png"))
    make_weapons()
    make_smoke()
    make_dog_sheet()
    make_iron_barricade().img.save(os.path.join(OUT, "barricade_iron.png"))
    make_gate().img.save(os.path.join(OUT, "gate.png"))
    make_slime()
    season_props()
    make_interior()
    make_mansion().img.save(os.path.join(OUT, "mansion.png"))
    make_mansion(True).img.save(os.path.join(OUT, "mansion_winter.png"))
    make_manor_interior()
    make_items()
    make_fx()
    make_ui()
    print("sprites ok")


if __name__ == "__main__":
    main()
