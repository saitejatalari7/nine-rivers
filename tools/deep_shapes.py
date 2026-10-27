"""Deep board shapes for levels 501+: narrow (at most 7 columns), 5-7 layers,
built from separate towers and pillars with gaps between them, so the sides
of a stack stay open and a player digs straight down rather than through a
wall.

Each shape is a height map: one row per board row, one digit per column, the
digit being how many tiles are stacked there (0 or '.' for none). Stacks are
solid by construction, so nothing can float.

Run: py tools/deep_shapes.py         -> checks every shape
     py tools/deep_shapes.py --emit  -> writes scripts/core/layout_data_deep.gd
"""
import sys

MAX_COLS = 7
MAX_ROWS = 10

S = {}


def shape(key, display, heights):
    rows = [r.strip() for r in heights.strip("\n").split("\n")]
    S[key] = (display, [[0 if ch == "." else int(ch) for ch in r] for r in rows])


# ---- band 5 (five layers)
shape("jade_pillars", "Jade Pillars", """
5.4.4.5
5.4.4.5
4.3.3.4
4.3.3.4
5.4.4.5
""")
shape("lantern_row", "Lantern Row", """
.3.3.3.
4.5.5.4
4.5.5.4
4.5.5.4
.3.3.3.
""")
shape("reed_bed", "Reed Bed", """
3.4.5.3
3.4.5.3
.4.5.3.
.4.5.3.
3.4.5.3
3.4.5.3
""")
shape("stone_steps", "Stone Steps", """
2.3.4.5
2.3.4.5
2.3.4.5
2.3.4.5
2.3.4.5
""")
shape("twin_lanterns", "Twin Lanterns", """
.34.43.
.45.54.
.55.55.
.45.54.
.34.43.
""")
shape("koi_gate", "Koi Gate", """
55...55
4.....4
4..2..4
4.333.4
4..3..4
4.....4
55...55
""")
shape("rice_terraces", "Rice Terraces", """
5.4.3.2
5.4.3.2
.......
2.3.4.5
2.3.4.5
2.3.4.5
""")
shape("drum_pavilion", "Drum Pavilion", """
..343..
.3.5.3.
.4.5.4.
.4.5.4.
.3.5.3.
..343..
""")
shape("bamboo_pillars", "Bamboo Pillars", """
4.5.4.5
4.5.4.5
5.4.5.4
5.4.5.4
""")
shape("market_stalls", "Market Stalls", """
45.54.4
45.54.4
.......
4.45.54
4.45.54
""")
shape("well_of_stars", "Well of Stars", """
5..4..5
.4...4.
..565..
.4...4.
5..4..5
""")
shape("ink_brushes", "Ink Brushes", """
5.5.5.5
4.4.4.4
3.3.3.3
3.3.3.3
2.2.2.2
""")
shape("moon_portal", "Moon Portal", """
.45554.
4.....4
5.....5
5.....5
4.....4
.45554.
""")

# ---- band 6 (six layers)
shape("twin_pagodas", "Twin Pagodas", """
45..54
67..76
67..76
45..54
""")
shape("stone_forest", "Stone Forest", """
..3.4..
4.3.4.3
4...4.3
4.6...5
..6.4.5
3.6.4..
3...4.3
3.3...3
""")
shape("karst_peaks", "Karst Peaks", """
3...4..
3.6.4.5
..6...5
4.6.3..
4...3.6
..5.3.6
""")
shape("crane_nests", "Crane Nests", """
6.....6
5.4.4.5
..5.5..
..5.5..
5.4.4.5
6.....6
""")
shape("bell_towers", "Bell Towers", """
.6...6.
.5.4.5.
.5.4.5.
.5.4.5.
.6...6.
""")
shape("dragon_spine", "Dragon Spine", """
3.....3
.4...4.
..565..
..565..
.4...4.
3.....3
""")
shape("three_peaks", "Three Peaks", """
4.6.4..
4.6.4..
..5.5.3
..5.5.3
3.4.6.4
3.4.6.4
""")
shape("lotus_towers", "Lotus Towers", """
.5.5.5.
4.6.6.4
4.6.6.4
.5.5.5.
""")
shape("monk_stairs", "Monk Stairs", """
6.5.4.3
6.5.4.3
.......
3.4.5.6
3.4.5.6
""")
shape("phoenix_wings", "Phoenix Wings", """
6.....6
.5...5.
..4.4..
...6...
..4.4..
.5...5.
6.....6
""")
shape("tea_houses", "Tea Houses", """
56.4.65
56.4.65
.......
4.565.4
4.565.4
""")
shape("waterfall_cliffs", "Waterfall Cliffs", """
6.....6
6.3.3.6
6.4.4.6
6.4.4.6
6.3.3.6
""")
shape("scholar_desks", "Scholar Desks", """
44.5.44
.......
.5.6.5.
.5.6.5.
.......
44.5.44
""")

# ---- band 7 (seven layers)
shape("stepped_cliffs", "Stepped Cliffs", """
2.33.55
2.34.56
2.44.67
2.43.66
2.33.55
""")
shape("sky_pagoda", "Sky Pagoda", """
..5.5..
.4.7.4.
.4.7.4.
.4.7.4.
..5.6..
""")
shape("heaven_pillars", "Heaven Pillars", """
7.5.5.7
7.4.4.7
6.4.4.6
6.5.5.6
""")
shape("jade_mountain", "Jade Mountain", """
..4.4..
.5.6.5.
4.6.7.5
.5.6.5.
..4.4..
""")
shape("dragon_towers", "Dragon Towers", """
7...7
6.4.6
6.4.6
7...7
""")
shape("cloud_ladders", "Cloud Ladders", """
7..4..3
6..5..4
5..6..5
4..5..6
3..4..7
""")
shape("emperor_gates", "Emperor Gates", """
77...77
6.....6
5..4..5
5..4..5
6.....6
77...77
""")
shape("celestial_spires", "Celestial Spires", """
.7.5.7.
.6.4.6.
.6.4.6.
.7.5.7.
""")
shape("thunder_peaks", "Thunder Peaks", """
7.4...7
..4.6..
5...6.5
5.3...5
..3.6..
7...6.7
""")
shape("nine_dragon_wall", "Nine Dragon Wall", """
7.6.5.7
.......
5.6.7.6
.......
7.5.6.7
""")
shape("immortal_isles", "Immortal Isles", """
56...65
67...76
.......
..676..
..566..
""")
shape("summit_shrine", "Summit Shrine", """
..7.7..
..5.5..
.4.6.4.
3.5.5.3
.4.6.4.
""")
shape("great_wall_towers", "Great Wall Towers", """
7.....7
6.4.4.6
6.4.4.6
6.4.4.6
7.....7
""")


def positions(hm):
    out = []
    for r, row in enumerate(hm):
        for c, h in enumerate(row):
            for z in range(h):
                out.append((c, r, z))
    return out


def layers_of(hm):
    depth = max(max(row) for row in hm)
    width = max(len(row) for row in hm)
    out = []
    for z in range(depth):
        out.append(["".join("X" if c < len(row) and row[c] > z else "." for c in range(width)) for row in hm])
    return out


def _grid(hm):
    w = max(len(r) for r in hm)
    return tuple(tuple(r + [0] * (w - len(r))) for r in hm)


def variants(key, hm):
    g = _grid(hm)
    seen = {}
    for suffix, grid in (("", g), ("@m", tuple(tuple(reversed(r)) for r in g)),
            ("@v", tuple(reversed(g))), ("@mv", tuple(tuple(reversed(r)) for r in reversed(g)))):
        if grid not in seen:
            seen[grid] = key + suffix
    return list(seen.values())


def _classic_names():
    import re
    with open("scripts/core/layout_data.gd") as f:
        return set(re.findall(r'^	"([a-z_]+)": \{', f.read(), re.M))


def check():
    bad = 0
    classic = _classic_names()
    for key, (display, hm) in S.items():
        problems = []
        pos = positions(hm)
        width = max(len(row) for row in hm)
        if width > MAX_COLS:
            problems.append("width %d" % width)
        if len(hm) > MAX_ROWS:
            problems.append("rows %d" % len(hm))
        if len(pos) % 2:
            problems.append("odd count %d" % len(pos))
        if key in classic:
            problems.append("name already used by a classic shape")
        depth = max(max(row) for row in hm)
        status = "OK " if not problems else "BAD"
        bad += 1 if problems else 0
        print("%s %-16s %3d tiles  %d layers  %d cols  %s" % (
            status, key, len(pos), depth, width, "; ".join(problems)))
    print("%d shapes, %d with problems" % (len(S), bad))
    return bad


def emit():
    lines = [
        "## Generated by tools/deep_shapes.py - edit the height maps there.",
        "## Deep shapes for levels 501+, kept apart from LayoutData so adding",
        "## them never reshuffles the shapes of levels 1-500.",
        "",
        "const LAYOUTS: Dictionary = {",
    ]
    for key, (display, hm) in S.items():
        lines.append('\t"%s": {' % key)
        lines.append('\t\t"display": "%s",' % display)
        lines.append('\t\t"depth": %d,' % max(max(row) for row in hm))
        lines.append('\t\t"layers": [')
        for rows in layers_of(hm):
            lines.append('\t\t\t"""')
            lines.extend(rows)
            lines.append('""",')
        lines.append("\t\t],")
        lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("## Every distinct way a shape can be dealt: as drawn, flipped left to right")
    lines.append("## (@m), upside down (@v) or both (@mv). Flips that come out identical are")
    lines.append("## left out, so no board appears twice under two names.")
    lines.append("const VARIANTS: Array[String] = [")
    for k, (d, hm) in S.items():
        for name in variants(k, hm):
            lines.append('	"%s",' % name)
    lines.append("]")
    with open("scripts/core/layout_data_deep.gd", "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("wrote scripts/core/layout_data_deep.gd (%d shapes)" % len(S))


if __name__ == "__main__":
    if check():
        sys.exit(1)
    if "--emit" in sys.argv:
        emit()
