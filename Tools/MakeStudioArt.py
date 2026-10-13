"""Draws the AzUI Studio primitives into Media/Studio/ (run from the addon folder).

    python Tools/MakeStudioArt.py

Every file is white on transparent, so the addon tints it with the theme's colours.
Shapes are drawn at 4x and scaled down, which gives smooth edges. The rounded shapes
are meant for Texture:SetTextureSliceMargins: their corners keep their shape at any
size, and the middle stretches. Requires Pillow.
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join("Media", "Studio")
SS = 4  # supersampling


def canvas(w, h):
    return Image.new("L", (w * SS, h * SS), 0)


def save(mask, name, w, h):
    mask = mask.resize((w, h), Image.LANCZOS)
    img = Image.new("RGBA", (w, h), (255, 255, 255, 0))
    img.putalpha(mask)
    img.save(os.path.join(OUT, name + ".tga"))


def rounded(size, radius, inset=0.0):
    m = canvas(size, size)
    d = ImageDraw.Draw(m)
    i = inset * SS
    d.rounded_rectangle([i, i, size * SS - 1 - i, size * SS - 1 - i], radius=radius * SS, fill=255)
    return m


def rounded_edge(size, radius, width):
    outer = rounded(size, radius)
    inner = rounded(size, max(0, radius - width), inset=width)
    # where the inner shape is, nothing; elsewhere the outer shape
    return Image.composite(Image.new("L", outer.size, 0), outer, inner)


def circle(size, inset=0.0):
    m = canvas(size, size)
    d = ImageDraw.Draw(m)
    i = inset * SS
    d.ellipse([i, i, size * SS - 1 - i, size * SS - 1 - i], fill=255)
    return m


def ring(size, width):
    outer = circle(size)
    inner = circle(size, inset=width)
    return Image.composite(Image.new("L", outer.size, 0), outer, inner)


def glyph(name, draw):
    m = canvas(32, 32)
    draw(ImageDraw.Draw(m), SS)
    save(m, "glyph-" + name, 32, 32)


def main():
    os.makedirs(OUT, exist_ok=True)

    # Rounded fills and 1.25px edges, 64x64; slice margin = radius + 2
    for r in (3, 4, 6, 8, 9, 10, 12):
        save(rounded(64, r), "round%d-fill" % r, 64, 64)
        save(rounded_edge(64, r, 1.25), "round%d-edge" % r, 64, 64)
        save(rounded_edge(64, r, 2.0), "round%d-edge2" % r, 64, 64)
        # a keycap's face: the shape lifted 3px off its bottom edge, drawn over -fill
        # (tinted darker) so the strip left below it reads as the key's lip
        m = canvas(64, 64)
        ImageDraw.Draw(m).rounded_rectangle([0, 0, 64 * SS - 1, (64 - 3) * SS - 1], radius=r * SS, fill=255)
        save(m, "round%d-face" % r, 64, 64)

    # Circles: fill, thin ring (portraits), thick ring (thumbs)
    save(circle(64), "circle-fill", 64, 64)
    save(ring(64, 2.0), "circle-ring", 64, 64)
    save(ring(64, 5.0), "circle-ring-thick", 64, 64)

    # Soft drop shadow for the window and raised cards; slice margin 40
    m = canvas(128, 128)
    ImageDraw.Draw(m).rounded_rectangle([28 * SS, 28 * SS, 100 * SS, 100 * SS], radius=10 * SS, fill=150)
    m = m.filter(ImageFilter.GaussianBlur(10 * SS))
    save(m, "shadow", 128, 128)

    # Dashes for the "+ Save" tile, tiled along each side
    m = canvas(16, 4)
    ImageDraw.Draw(m).rectangle([0, 1 * SS, 8 * SS - 1, 3 * SS - 1], fill=255)
    save(m, "dash-h", 16, 4)
    m = canvas(4, 16)
    ImageDraw.Draw(m).rectangle([1 * SS, 0, 3 * SS - 1, 8 * SS - 1], fill=255)
    save(m, "dash-v", 4, 16)

    # Checkerboard behind alpha previews
    img = Image.new("RGBA", (16, 16), (255, 255, 255, 255))
    d = ImageDraw.Draw(img)
    for y in range(2):
        for x in range(2):
            if (x + y) % 2:
                d.rectangle([x * 8, y * 8, x * 8 + 7, y * 8 + 7], fill=(150, 150, 150, 255))
    img.save(os.path.join(OUT, "checker.tga"))

    def line(d, s, pts, w):
        d.line([(x * s, y * s) for x, y in pts], fill=255, width=int(w * s), joint="curve")
        for x, y in (pts[0], pts[-1]):
            r = w * s / 2
            d.ellipse([x * s - r, y * s - r, x * s + r, y * s + r], fill=255)

    glyph("cross", lambda d, s: (line(d, s, [(9, 9), (23, 23)], 2.6), line(d, s, [(23, 9), (9, 23)], 2.6)))
    glyph("check", lambda d, s: line(d, s, [(7, 16.5), (13, 22.5), (25, 10)], 2.8))
    glyph("chevron", lambda d, s: line(d, s, [(9, 12.5), (16, 19.5), (23, 12.5)], 2.6))
    glyph("plus", lambda d, s: (line(d, s, [(16, 8), (16, 24)], 2.6), line(d, s, [(8, 16), (24, 16)], 2.6)))
    glyph("search", lambda d, s: (d.ellipse([7 * s, 7 * s, 21 * s, 21 * s], outline=255, width=int(2.4 * s)),
                                  line(d, s, [(19.5, 19.5), (25, 25)], 2.8)))

    def grip(d, s):
        for x in (12, 20):
            for y in (9, 16, 23):
                d.ellipse([(x - 1.8) * s, (y - 1.8) * s, (x + 1.8) * s, (y + 1.8) * s], fill=255)
    glyph("grip", grip)

    def undo(d, s):
        d.arc([8 * s, 9 * s, 24 * s, 25 * s], start=200, end=90, fill=255, width=int(2.6 * s))
        d.polygon([(5 * s, 13 * s), (12 * s, 9 * s), (12 * s, 17 * s)], fill=255)
    glyph("undo", undo)

    # Page icons for the rail, 32x32 line drawings tinted like the glyphs above
    # (muted, gold when the page is selected), in the way AdvancedHotkeyOverlaySystem
    # draws its own. Strokes of 2.2px or more, so they hold at 18px on screen.
    def box(d, s, x0, y0, x1, y1, r, w=None):
        if w:
            d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], radius=r * s, outline=255, width=int(w * s))
        else:
            d.rounded_rectangle([x0 * s, y0 * s, x1 * s, y1 * s], radius=r * s, fill=255)

    def dot(d, s, x, y, r):
        d.ellipse([(x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s], fill=255)

    def heart(d, s, x0, y0, x1, y1, fill):
        r = (x1 - x0) / 4
        d.ellipse([x0 * s, y0 * s, (x0 + 2 * r) * s, (y0 + 2 * r) * s], fill=fill)
        d.ellipse([(x1 - 2 * r) * s, y0 * s, x1 * s, (y0 + 2 * r) * s], fill=fill)
        d.polygon([((x0 + r * .09) * s, (y0 + r * 1.46) * s), ((x1 - r * .09) * s, (y0 + r * 1.46) * s),
                   ((x0 + x1) / 2 * s, y1 * s)], fill=fill)

    def health(d, s):  # a heart, outlined: the whole shape, its inside cut out
        heart(d, s, 4, 5, 28, 27.5, 255)
        heart(d, s, 6.4, 7.4, 25.6, 23.8, 0)
    glyph("page-health", health)

    def rules(d, s):  # a list of rules, the first one on
        box(d, s, 4, 5, 11, 12, 2)
        line(d, s, [(15, 8.5), (28, 8.5)], 2.4)
        box(d, s, 4, 14.5, 11, 21.5, 2, 2)
        line(d, s, [(15, 18), (25, 18)], 2.4)
        box(d, s, 4, 24, 11, 31, 2, 2)
        line(d, s, [(15, 27.5), (27, 27.5)], 2.4)
    glyph("page-rules", rules)

    def pets(d, s):  # a paw print
        d.ellipse([9 * s, 15 * s, 23 * s, 27 * s], fill=255)
        for x, y in ((7, 12), (12.5, 7), (19.5, 7), (25, 12)):
            dot(d, s, x, y, 3)
    glyph("page-pets", pets)

    def families(d, s):  # four swatches: a colour for each family
        box(d, s, 4, 4, 14.5, 14.5, 3)
        box(d, s, 17.5, 4, 28, 14.5, 3, 2.2)
        box(d, s, 4, 17.5, 14.5, 28, 3, 2.2)
        box(d, s, 17.5, 17.5, 28, 28, 3)
    glyph("page-families", families)

    def bars(d, s):  # unit frames: a long bar, then two shorter ones under it
        box(d, s, 3, 5, 29, 12, 2)
        box(d, s, 3, 15, 22, 21, 2, 2.2)
        box(d, s, 3, 24, 16, 28, 1.5)
    glyph("page-bars", bars)

    def profiles(d, s):  # a person
        d.ellipse([11 * s, 4 * s, 21 * s, 14 * s], outline=255, width=int(2.4 * s))
        d.arc([5 * s, 17 * s, 27 * s, 39 * s], start=180, end=360, fill=255, width=int(2.4 * s))
    glyph("page-profiles", profiles)

    def share(d, s):  # three points joined
        line(d, s, [(23, 8), (9, 16), (23, 24)], 2.2)
        dot(d, s, 23, 8, 4)
        dot(d, s, 9, 16, 4)
        dot(d, s, 23, 24, 4)
    glyph("page-share", share)

    def window(d, s):  # sliders
        for x, knob in ((9, 12), (16, 20), (23, 14)):
            line(d, s, [(x, 6), (x, 26)], 1.6)
            dot(d, s, x, knob, 3)
    glyph("page-window", window)

    # Button icons: beside a button's text, or alone on a small button with a tooltip.
    def play(d, s):  # Try
        d.polygon([(10 * s, 6 * s), (25 * s, 16 * s), (10 * s, 26 * s)], fill=255)
    glyph("play", play)

    def pen(d, s):  # Rename
        line(d, s, [(8, 24), (23, 9)], 4.2)
        d.polygon([(4.5 * s, 27.5 * s), (5.6 * s, 22 * s), (10 * s, 26.4 * s)], fill=255)
        line(d, s, [(21, 7), (25, 11)], 2)
    glyph("pen", pen)

    def dice(d, s):  # Random Colour
        box(d, s, 4, 4, 28, 28, 5, 2.2)
        for x, y in ((10.5, 10.5), (16, 16), (21.5, 21.5), (21.5, 10.5), (10.5, 21.5)):
            dot(d, s, x, y, 2.1)
    glyph("dice", dice)

    def reload(d, s):  # Reload: a circle that comes round to an arrowhead
        d.arc([6 * s, 6 * s, 26 * s, 26 * s], start=-60, end=250, fill=255, width=int(2.6 * s))
        d.polygon([(19.5 * s, 2.5 * s), (27 * s, 8 * s), (19 * s, 12.5 * s)], fill=255)
    glyph("reload", reload)

    # Section icons, beside the headings inside a page, in the same hand.
    def shield(d, s, fill):
        pts = [(16, 3.5), (27, 7.5), (26, 17), (16, 28.5), (6, 17), (5, 7.5)]
        if fill:
            d.polygon([(x * s, y * s) for x, y in pts], fill=255)
        else:
            d.line([(x * s, y * s) for x, y in pts + [pts[0]]], fill=255, width=int(2.2 * s), joint="curve")

    def class_colours(d, s):  # a shield, split down the middle
        shield(d, s, False)
        line(d, s, [(16, 6), (16, 26)], 2.2)
    glyph("section-class", class_colours)

    def effect(d, s):  # a four-pointed spark and a small one
        def spark(cx, cy, r, w):
            d.polygon([(cx * s, (cy - r) * s), ((cx + w) * s, (cy - w) * s), ((cx + r) * s, cy * s), ((cx + w) * s, (cy + w) * s),
                       (cx * s, (cy + r) * s), ((cx - w) * s, (cy + w) * s), ((cx - r) * s, cy * s), ((cx - w) * s, (cy - w) * s)], fill=255)
        spark(13, 18, 10, 2.6)
        spark(24.5, 7.5, 5, 1.4)
    glyph("section-effect", effect)

    def presets(d, s):  # a bookmark
        d.line([(9 * s, 4 * s), (23 * s, 4 * s), (23 * s, 28 * s), (16 * s, 21.5 * s), (9 * s, 28 * s), (9 * s, 4 * s)],
               fill=255, width=int(2.2 * s), joint="curve")
    glyph("section-presets", presets)

    def packs(d, s):  # cards fanned out
        box(d, s, 11, 3, 27, 22, 3, 2.2)
        box(d, s, 5, 9, 21, 28, 3)
    glyph("section-packs", packs)

    def maintenance(d, s):  # a wrench
        d.ellipse([16 * s, 3 * s, 29 * s, 16 * s], outline=255, width=int(2.6 * s))
        d.rectangle([22 * s, 0, 32 * s, 9 * s], fill=0)
        line(d, s, [(18.5, 13.5), (6, 26)], 3.2)
    glyph("section-maintenance", maintenance)

    def power(d, s):  # a drop
        d.ellipse([7 * s, 12 * s, 25 * s, 30 * s], fill=255)
        d.polygon([(16 * s, 2 * s), (24.3 * s, 17 * s), (7.7 * s, 17 * s)], fill=255)
    glyph("section-power", power)

    def cast(d, s):  # an hourglass
        line(d, s, [(8, 4), (24, 4)], 2.4)
        line(d, s, [(8, 28), (24, 28)], 2.4)
        d.line([(10 * s, 4 * s), (22 * s, 28 * s)], fill=255, width=int(2.2 * s))
        d.line([(22 * s, 4 * s), (10 * s, 28 * s)], fill=255, width=int(2.2 * s))
        d.polygon([(12.5 * s, 25 * s), (19.5 * s, 25 * s), (16 * s, 19 * s)], fill=255)
    glyph("section-cast", cast)

    def class_power(d, s):  # combo points, three lit and one not
        for i, x in enumerate((5, 12, 19, 26)):
            if i < 3:
                dot(d, s, x, 16, 3.2)
            else:
                d.ellipse([(x - 3) * s, 13 * s, (x + 3) * s, 19 * s], outline=255, width=int(1.8 * s))
    glyph("section-classpower", class_power)

    def overlays(d, s):  # a bar, the heal past its end shown as a lighter outline
        box(d, s, 3, 10, 29, 22, 3, 2.2)
        box(d, s, 6, 13, 17, 19, 1)
        for x in (20, 24):
            line(d, s, [(x, 18.5), (x + 3, 13.5)], 1.8)
    glyph("section-overlays", overlays)

    def prd(d, s):  # bars under a head: the display under your character
        d.ellipse([12 * s, 2 * s, 20 * s, 10 * s], outline=255, width=int(2.2 * s))
        box(d, s, 5, 15, 27, 21, 2)
        box(d, s, 8, 24, 24, 28, 1.5, 1.6)
    glyph("section-prd", prd)

    def spec(d, s):  # a star in a ring
        d.ellipse([3 * s, 3 * s, 29 * s, 29 * s], outline=255, width=int(2.2 * s))
        pts = []
        for i in range(10):
            a = math.pi * (-.5 + i / 5)
            r = 8.5 if i % 2 == 0 else 3.6
            pts.append(((16 + r * math.cos(a)) * s, (16.8 + r * math.sin(a)) * s))
        d.polygon(pts, fill=255)
    glyph("section-spec", spec)

    def export(d, s):  # an arrow up out of a tray
        d.line([(5 * s, 17 * s), (5 * s, 27 * s), (27 * s, 27 * s), (27 * s, 17 * s)], fill=255, width=int(2.2 * s), joint="curve")
        line(d, s, [(16, 21), (16, 4)], 2.4)
        line(d, s, [(10, 10), (16, 4), (22, 10)], 2.4)
    glyph("section-export", export)

    def import_(d, s):  # an arrow down into a tray
        d.line([(5 * s, 17 * s), (5 * s, 27 * s), (27 * s, 27 * s), (27 * s, 17 * s)], fill=255, width=int(2.2 * s), joint="curve")
        line(d, s, [(16, 4), (16, 21)], 2.4)
        line(d, s, [(10, 15), (16, 21), (22, 15)], 2.4)
    glyph("section-import", import_)

    def chat(d, s):  # a speech bubble
        box(d, s, 3, 5, 29, 22, 5, 2.2)
        d.polygon([(8 * s, 20 * s), (15 * s, 20 * s), (8 * s, 28 * s)], fill=255)
        for x in (10, 16, 22):
            dot(d, s, x, 13.5, 1.8)
    glyph("section-chat", chat)

    def appearance(d, s):  # an eye: two arcs meeting at the corners, and the pupil
        d.arc([2 * s, 7 * s, 30 * s, 43 * s], start=212, end=328, fill=255, width=int(2.2 * s))
        d.arc([2 * s, -11 * s, 30 * s, 25 * s], start=32, end=148, fill=255, width=int(2.2 * s))
        dot(d, s, 16, 16, 4.2)
    glyph("section-appearance", appearance)

    def classic(d, s):  # a window
        box(d, s, 3, 5, 29, 27, 3, 2.2)
        line(d, s, [(4, 11), (28, 11)], 2.2)
        for x in (7, 11):
            dot(d, s, x, 8, 1.2)
    glyph("section-classic", classic)

    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
