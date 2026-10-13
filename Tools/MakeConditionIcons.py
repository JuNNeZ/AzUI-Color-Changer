"""Draws the rule condition icons the art pack had no picture for, and the speaker
glyphs on a rule's row (run from the addon folder).

    python Tools/MakeConditionIcons.py

Same rules as the pack's own condition icons (Tools/AssetBrief): 64x64, white on
transparent so the window tints them, read at 20x20, so bold shapes and strokes of
about 6 px at 64. Drawn at 512 and scaled down for smooth edges. The PNG masters go to
Tools/AssetBrief/source/, the TGAs to Media/StudioPack/ (icons) and Media/Studio/
(glyphs). Requires Pillow.
"""
import math
import os

from PIL import Image, ImageDraw

S = 512           # drawing size
U = S / 64.0      # one pixel of the 64 px icon
STROKE = 6 * U    # the pack's line weight
PACK = os.path.join("Media", "StudioPack")
GLYPHS = os.path.join("Media", "Studio")
MASTERS = os.path.join("Tools", "AssetBrief", "source")


def new():
    return Image.new("L", (S, S), 0)


def p(x, y):
    return (x * U, y * U)


def pts(points):
    return [p(x, y) for x, y in points]


def disc(d, x, y, r, fill=255):
    d.ellipse([(x - r) * U, (y - r) * U, (x + r) * U, (y + r) * U], fill=fill)


def ring(d, x, y, r, width=6, fill=255):
    d.ellipse([(x - r) * U, (y - r) * U, (x + r) * U, (y + r) * U], outline=fill, width=int(width * U))


def line(d, points, width=6, fill=255):
    d.line(pts(points), fill=fill, width=int(width * U), joint="curve")
    for x, y in (points[0], points[-1]):
        disc(d, x, y, width / 2, fill)


def write_tga(mask, path, size):
    mask = mask.resize((size, size), Image.LANCZOS)
    img = Image.new("RGBA", (size, size), (255, 255, 255, 0))
    img.putalpha(mask)
    img.save(path)
    return img


# --- the icons ---------------------------------------------------------------------

def role_tank(d):
    shield = [(32, 6), (52, 12), (51, 34), (44, 47), (32, 58), (20, 47), (13, 34), (12, 12)]
    d.polygon(pts(shield), fill=255)
    inner = [(32, 13), (45, 17), (44.5, 33), (39.5, 42.5), (32, 50), (24.5, 42.5), (19.5, 33), (19, 17)]
    d.polygon(pts(inner), fill=0)
    d.polygon(pts([(29, 14), (35, 14), (35, 48), (32, 50.5), (29, 48)]), fill=255)


def role_healer(d):
    ring(d, 32, 32, 25, 6)
    for box in ([27, 15, 37, 49], [15, 27, 49, 37]):
        d.rounded_rectangle([v * U for v in box], radius=2 * U, fill=255)


def role_damager(d):
    d.polygon(pts([(32, 3), (40, 12), (40, 39), (24, 39), (24, 12)]), fill=255)  # blade
    d.polygon(pts([(32, 11), (34, 14), (34, 35), (30, 35), (30, 14)]), fill=0)  # fuller
    d.rounded_rectangle([13 * U, 39 * U, 51 * U, 46 * U], radius=3.5 * U, fill=255)  # guard
    d.rectangle([28.5 * U, 46 * U, 35.5 * U, 54 * U], fill=255)  # grip
    disc(d, 32, 56.5, 5.5)  # pommel


def group(d):
    for x in (14, 50):
        disc(d, x, 22, 7)
        d.pieslice([(x - 13) * U, 31 * U, (x + 13) * U, 57 * U], 180, 360, fill=255)
    for x in (14, 50):  # a gap around the one in front
        disc(d, 32, 25, 12, fill=0)
        d.pieslice([16 * U, 34 * U, 48 * U, 66 * U], 180, 360, fill=0)
    disc(d, 32, 25, 9)
    d.pieslice([19 * U, 37 * U, 45 * U, 63 * U], 180, 360, fill=255)
    d.rectangle([0, 50 * U, S, S], fill=0)


def pet(d):
    d.ellipse([18 * U, 32 * U, 46 * U, 56 * U], fill=255)  # pad
    for x, y, r in ((14, 26, 6), (25, 15, 6.5), (39, 15, 6.5), (50, 26, 6)):
        disc(d, x, y, r)


def zone(d):
    d.pieslice([12 * U, 6 * U, 52 * U, 46 * U], 140, 400, fill=255)
    d.polygon(pts([(14.7, 38.9), (32, 59), (49.3, 38.9), (32, 26)]), fill=255)
    disc(d, 32, 26, 8, fill=0)


def mythicplus(d):
    ring(d, 18, 32, 11, 7)  # the key's bow
    d.rectangle([28 * U, 28.5 * U, 58 * U, 35.5 * U], fill=255)  # shaft
    d.rectangle([44 * U, 35 * U, 50 * U, 45 * U], fill=255)  # teeth
    d.rectangle([52 * U, 35 * U, 58 * U, 42 * U], fill=255)
    d.polygon(pts([(18, 25), (25, 32), (18, 39), (11, 32)]), fill=255)  # the keystone gem


def delve(d):
    ring(d, 32, 9, 5, 4)  # handle
    d.polygon(pts([(20, 20), (44, 20), (40, 14), (24, 14)]), fill=255)  # cap
    d.rounded_rectangle([18 * U, 20 * U, 46 * U, 50 * U], radius=4 * U, fill=255)  # body
    d.rounded_rectangle([24 * U, 25 * U, 40 * U, 45 * U], radius=3 * U, fill=0)  # glass
    d.polygon(pts([(32, 27), (37, 36), (34.5, 42), (29.5, 42), (27, 36)]), fill=255)  # flame
    d.rounded_rectangle([14 * U, 50 * U, 50 * U, 57 * U], radius=2 * U, fill=255)  # base


def bezier(a, b, c, steps=24):
    out = []
    for i in range(steps + 1):
        t = i / steps
        out.append(((1 - t) ** 2 * a[0] + 2 * (1 - t) * t * b[0] + t * t * c[0],
                    (1 - t) ** 2 * a[1] + 2 * (1 - t) * t * b[1] + t * t * c[1]))
    return out


def flying(d):
    # a raised wing: a curved leading edge from the shoulder to the tip, and three
    # long flight feathers stepping back underneath it
    edge = bezier((3, 58), (6, 10), (61, 3))
    feathers = [(61, 3), (55, 22), (61, 23), (49, 37), (55, 39), (41, 50), (46, 53), (26, 61), (3, 58)]
    d.polygon(pts(edge + feathers[1:]), fill=255)
    # the gaps between the feathers, and the line of the coverts
    for a, b in (((55, 22), (31, 31)), ((49, 37), (26, 42)), ((41, 50), (19, 51))):
        line(d, [a, b], 2.4, fill=0)
    line(d, bezier((11, 46), (16, 22), (42, 13), 12), 2.4, fill=0)


def warmode(d):
    d.rounded_rectangle([12 * U, 6 * U, 18 * U, 58 * U], radius=3 * U, fill=255)  # pole
    disc(d, 15, 6, 4)
    d.polygon(pts([(18, 10), (54, 10), (46, 22), (54, 34), (18, 34)]), fill=255)  # pennant
    # a sword on the banner, cut out
    d.polygon(pts([(26, 22), (40, 19.5), (42, 22), (40, 24.5)]), fill=0)
    d.rectangle([24 * U, 17 * U, 26.5 * U, 27 * U], fill=0)


def vehicle(d):
    ring(d, 32, 32, 23, 6)
    disc(d, 32, 32, 7)
    for i in range(6):
        a = math.radians(i * 60)
        line(d, [(32 + 7 * math.cos(a), 32 + 7 * math.sin(a)), (32 + 21 * math.cos(a), 32 + 21 * math.sin(a))], 5)


def time_of_day(d):
    # a sun setting behind the horizon, a crescent moon above
    d.pieslice([12 * U, 30 * U, 44 * U, 62 * U], 180, 360, fill=255)
    for a in (180, 220, 270, 320, 360):
        r = math.radians(a)
        line(d, [(28 + 21 * math.cos(r), 46 + 21 * math.sin(r)), (28 + 27 * math.cos(r), 46 + 27 * math.sin(r))], 4.5)
    d.rounded_rectangle([4 * U, 48 * U, 60 * U, 54 * U], radius=3 * U, fill=255)
    disc(d, 48, 14, 10)
    disc(d, 53, 10, 9, fill=0)


def threat(d):
    ring(d, 32, 32, 20, 6)
    disc(d, 32, 32, 6)
    for a, b in (((32, 3), (32, 15)), ((32, 49), (32, 61)), ((3, 32), (15, 32)), ((49, 32), (61, 32))):
        line(d, [a, b], 6)


def casting(d):
    def star(x, y, r, w):
        d.polygon(pts([(x, y - r), (x + w, y - w), (x + r, y), (x + w, y + w),
                       (x, y + r), (x - w, y + w), (x - r, y), (x - w, y - w)]), fill=255)
    star(27, 36, 22, 5)
    star(50, 14, 10, 2.6)
    star(52, 48, 6, 1.8)


def aura(d):
    ring(d, 32, 32, 25, 6)
    d.polygon(pts([(32, 14), (46, 30), (37, 30), (37, 48), (27, 48), (27, 30), (18, 30)]), fill=255)


ICONS = {
    "role-tank": role_tank, "role-healer": role_healer, "role-damager": role_damager,
    "group": group, "pet": pet, "zone": zone, "mythicplus": mythicplus, "delve": delve,
    "flying": flying, "warmode": warmode, "vehicle": vehicle, "time": time_of_day,
    "threat": threat, "casting": casting, "aura": aura,
}


# --- the speaker glyphs (32 px, like Media/Studio's other glyphs) ----------------

def speaker(d, loud):
    g = S / 32.0
    d.polygon([(5 * g, 12 * g), (10 * g, 12 * g), (17 * g, 6 * g), (17 * g, 26 * g), (10 * g, 20 * g), (5 * g, 20 * g)], fill=255)
    w = int(2.4 * g)
    if loud:
        d.arc([14 * g, 10 * g, 26 * g, 22 * g], -55, 55, fill=255, width=w)
        d.arc([14 * g, 5 * g, 31 * g, 27 * g], -55, 55, fill=255, width=w)
    else:
        d.line([(21 * g, 12 * g), (29 * g, 20 * g)], fill=255, width=w)
        d.line([(29 * g, 12 * g), (21 * g, 20 * g)], fill=255, width=w)


def main():
    os.makedirs(MASTERS, exist_ok=True)
    for name, draw in ICONS.items():
        mask = new()
        draw(ImageDraw.Draw(mask))
        img = write_tga(mask, os.path.join(PACK, "condition-" + name + ".tga"), 64)
        img.resize((256, 256), Image.LANCZOS).save(os.path.join(MASTERS, "condition-" + name + ".png"))
    for name, loud in (("speaker", True), ("speaker-mute", False)):
        mask = new()
        speaker(ImageDraw.Draw(mask), loud)
        write_tga(mask, os.path.join(GLYPHS, "glyph-" + name + ".tga"), 32)
    print("drew", len(ICONS), "condition icons and 2 glyphs")


if __name__ == "__main__":
    main()
