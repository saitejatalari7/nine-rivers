#!/usr/bin/env python3
"""Build assets/fonts/NineRiversGlyphs.ttf.

None of the three bundled faces (Outfit, Noto Serif SC, Ma Shan Zheng) contain
the symbols the interface uses inline in text - checked against the ORIGINAL,
un-subset files, so this is not something subsetting caused. Without them the
text server falls through to whatever the device happens to have, so a star or
a menu bar is drawn differently on a Pixel, a Samsung and a Xiaomi, which
undoes the point of having cut the emoji out in the first place.

These are drawn as geometry rather than shipped as a third-party font so the
weights and proportions can be matched to Outfit, and so there is no extra
licence to carry.

Run:  py -3 tools/make_ui_glyphs.py
"""

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen

UPEM = 1000
CAP = 700.0          # Outfit's cap height, so symbols sit on the same line
STROKE = 88.0        # matches Outfit Medium's stem weight closely enough


def rect(pen, x0, y0, x1, y1):
    """An axis-aligned filled box, wound clockwise (TrueType outer contour)."""
    pen.moveTo((x0, y0))
    pen.lineTo((x0, y1))
    pen.lineTo((x1, y1))
    pen.lineTo((x1, y0))
    pen.closePath()


def poly(pen, pts):
    pen.moveTo(pts[0])
    for p in pts[1:]:
        pen.lineTo(p)
    pen.closePath()


def diamond(cx, cy, rx, ry, reverse=False):
    pts = [(cx, cy + ry), (cx + rx, cy), (cx, cy - ry), (cx - rx, cy)]
    return list(reversed(pts)) if reverse else pts


def draw_diamond_inset(pen):
    """U+25C8 WHITE DIAMOND CONTAINING BLACK SMALL DIAMOND - the Spirit Pearl."""
    cx, cy, rx, ry = 340.0, CAP * 0.5, 300.0, 350.0
    poly(pen, diamond(cx, cy, rx, ry))                       # outer edge
    t = 92.0
    poly(pen, diamond(cx, cy, rx - t, ry - t, reverse=True))  # hollow it out
    poly(pen, diamond(cx, cy, rx * 0.38, ry * 0.38))          # the pearl itself


def draw_trigram(pen):
    """U+2630 TRIGRAM FOR HEAVEN - the menu control."""
    x0, x1 = 40.0, 640.0
    bar = 92.0
    gap = (CAP - 3 * bar) / 2.0
    for i in range(3):
        y = i * (bar + gap)
        rect(pen, x0, y, x1, y + bar)


def draw_multiply_x(pen):
    """U+2715 MULTIPLICATION X - the close control."""
    x0, x1 = 60.0, 620.0
    y0, y1 = 20.0, CAP - 20.0
    h = STROKE * 0.72
    poly(pen, [(x0, y0 + h), (x0 + h, y0), (x1, y1 - h), (x1 - h, y1)])
    poly(pen, [(x1 - h, y0), (x1, y0 + h), (x0 + h, y1), (x0, y1 - h)])


def draw_parallelogram(pen):
    """U+25B0 BLACK PARALLELOGRAM - one segment of the Flow meter."""
    slant = 90.0
    y0, y1 = 90.0, CAP - 90.0
    poly(pen, [(40.0 + slant, y0), (600.0 + slant, y0), (600.0, y1), (40.0, y1)])


def circle(pen, cx, cy, r, segments=8):
    """A filled disc approximated with quadratic segments (TrueType has no
    cubics), wound clockwise."""
    import math
    step = 2.0 * math.pi / segments
    k = r / math.cos(step / 2.0)   # controls sit on the circumscribed circle
    pts = [(cx + r * math.cos(-i * step), cy + r * math.sin(-i * step))
           for i in range(segments)]
    pen.moveTo(pts[0])
    for i in range(segments):
        a_mid = -(i + 0.5) * step
        pen.qCurveTo((cx + k * math.cos(a_mid), cy + k * math.sin(a_mid)),
                     pts[(i + 1) % segments])
    pen.closePath()


def draw_bullet(pen):
    """U+2022 BULLET. Not used in the interface today, but Outfit has it and
    the two CJK faces do not, so covering it keeps all three chains equal."""
    circle(pen, 160.0, CAP * 0.42, 108.0)


# U+20B9 INDIAN RUPEE SIGN is deliberately NOT drawn here.
#
# A first attempt was made and rendered: at display size it read as the postal
# mark U+3012, not as a rupee. That is worse than falling through to the
# system, because a wrong currency symbol is obvious to the people who use it
# every day, and India is the primary market.
#
# The system font is the right source for it in any case:
#   * Android has shipped a correct U+20B9 since 4.2, far below our min SDK.
#   * Play returns price strings already formatted for the buyer's locale, in
#     whatever currency that is, so no bundled font could ever cover them all.
# For a currency symbol, being correct beats being identical across devices -
# which is the opposite of the trade-off for the decorative symbols above.

GLYPHS = [
    ("uni25C8", 0x25C8, draw_diamond_inset, 700),
    ("uni2630", 0x2630, draw_trigram, 700),
    ("uni2715", 0x2715, draw_multiply_x, 690),
    ("uni25B0", 0x25B0, draw_parallelogram, 730),
    ("uni2022", 0x2022, draw_bullet, 320),
]


def build(path="assets/fonts/NineRiversGlyphs.ttf"):
    order = [".notdef"] + [n for n, _, _, _ in GLYPHS]
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(order)
    fb.setupCharacterMap({cp: name for name, cp, _, _ in GLYPHS})

    glyf = {".notdef": TTGlyphPen(None).glyph()}
    metrics = {".notdef": (600, 0)}
    for name, _cp, draw, adv in GLYPHS:
        pen = TTGlyphPen(None)
        draw(pen)
        glyf[name] = pen.glyph()
        metrics[name] = (adv, 0)

    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=800, descent=-200)
    fb.setupNameTable({
        "familyName": "Nine Rivers Glyphs",
        "styleName": "Regular",
        "psName": "NineRiversGlyphs-Regular",
        "version": "1.0",
        "copyright": "Nine Rivers - interface symbols drawn for this project.",
    })
    fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800,
                usWinDescent=200, sCapHeight=int(CAP))
    fb.setupPost()
    fb.save(path)
    print("wrote %s (%d glyphs)" % (path, len(GLYPHS)))


if __name__ == "__main__":
    build()
