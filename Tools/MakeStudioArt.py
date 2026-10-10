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

    print("wrote", len(os.listdir(OUT)), "files to", OUT)


if __name__ == "__main__":
    main()
