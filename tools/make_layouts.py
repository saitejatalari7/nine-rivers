#!/usr/bin/env python3
"""Author board shapes and emit them as GDScript for LayoutData.

Constraints every shape must satisfy, enforced here rather than eyeballed:

  * Even tile count. deal_board splits the total into triples, wild pairs and
    normal pairs; an odd total leaves a tile with no partner.
  * At most MAX_COLS columns. Tile size on screen is bound by column count,
    not tile count - 9 columns gives 33.7dp, 15 gives 20.6dp. Capacity is
    bought with rows and layers instead.
  * Every tile on a layer above 0 rests on the layer below. Nothing floats.

Run:  py -3 tools/make_layouts.py > /tmp/layouts.txt
"""

MAX_COLS = 9
TIERS = [(48, 1), (72, 2), (96, 3), (120, 4), (10**9, 5)]


class Shape:
    def __init__(self, name, display, cols, rows):
        self.name = name
        self.display = display
        self.cols = cols
        self.rows = rows
        self.layers = []

    def layer(self):
        self.layers.append([[0] * self.cols for _ in range(self.rows)])
        return self

    def rect(self, c0, c1, r0, r1, z=-1):
        g = self.layers[z]
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                g[r][c] = 1
        return self

    def ring(self, c0, c1, r0, r1, z=-1):
        g = self.layers[z]
        for c in range(c0, c1 + 1):
            g[r0][c] = 1
            g[r1][c] = 1
        for r in range(r0, r1 + 1):
            g[r][c0] = 1
            g[r][c1] = 1
        return self

    def clear(self, c0, c1, r0, r1, z=-1):
        g = self.layers[z]
        for r in range(r0, r1 + 1):
            for c in range(c0, c1 + 1):
                g[r][c] = 0
        return self

    def diamond(self, cc, cr, rad, z=-1):
        g = self.layers[z]
        for r in range(self.rows):
            for c in range(self.cols):
                if abs(c - cc) + abs(r - cr) <= rad:
                    g[r][c] = 1
        return self

    def count(self):
        return sum(sum(row) for g in self.layers for row in g)

    def used_cols(self):
        cols = 0
        for g in self.layers:
            for row in g:
                for c, v in enumerate(row):
                    if v:
                        cols = max(cols, c + 1)
        return cols

    def floating(self):
        """Tiles on an upper layer with no support anywhere beneath them."""
        bad = []
        for z in range(1, len(self.layers)):
            below = self.layers[z - 1]
            for r, row in enumerate(self.layers[z]):
                for c, v in enumerate(row):
                    if not v:
                        continue
                    if not any(
                        below[rr][cc]
                        for rr in range(max(0, r - 1), min(self.rows, r + 2))
                        for cc in range(max(0, c - 1), min(self.cols, c + 2))
                    ):
                        bad.append((z, r, c))
        return bad

    def tier(self):
        n = self.count()
        for limit, t in TIERS:
            if n <= limit:
                return t
        return 5

    def emit(self):
        out = ['\t"%s": {' % self.name]
        out.append('\t\t"display": "%s",' % self.display)
        out.append('\t\t"layers": [')
        for g in self.layers:
            rows = ["".join("X" if v else "." for v in row) for row in g]
            while rows and rows[-1].strip(".") == "":
                rows.pop()
            out.append('\t\t\t"""\n%s\n""",' % "\n".join(rows))
        out.append("\t\t],")
        out.append("\t},")
        return "\n".join(out)


def build():
    s = []

    # ---- tier 1: opening shapes -------------------------------------------
    s.append(Shape("brook", "Spring Brook", 6, 6).layer().rect(0, 5, 0, 4)
             .layer().rect(1, 4, 1, 2))

    b = Shape("stair", "River Steps", 6, 6).layer()
    b.rect(0, 3, 0, 1).rect(1, 4, 2, 3).rect(2, 5, 4, 5)
    b.layer().rect(2, 3, 2, 3)
    s.append(b)

    s.append(Shape("well", "Stone Well", 7, 6).layer().ring(0, 6, 0, 5)
             .layer().rect(1, 5, 0, 0).rect(1, 5, 5, 5))

    s.append(Shape("twin", "Twin Pillars", 7, 6).layer()
             .rect(0, 2, 0, 5).rect(4, 6, 0, 5)
             .layer().rect(1, 1, 1, 4).rect(5, 5, 1, 4))

    s.append(Shape("crest", "Heron Crest", 7, 6).layer().diamond(3, 2, 3)
             .layer().rect(2, 4, 1, 2))

    s.append(Shape("ford", "Shallow Ford", 8, 5).layer().rect(0, 7, 0, 3)
             .layer().rect(2, 5, 1, 1))

    # ---- tier 2 ------------------------------------------------------------
    s.append(Shape("fan", "Paper Fan", 8, 6).layer().rect(0, 7, 0, 4)
             .layer().rect(1, 6, 1, 3))

    s.append(Shape("urn", "Jade Urn", 7, 8).layer()
             .rect(1, 5, 0, 1).rect(0, 6, 2, 5).rect(1, 5, 6, 7)
             .layer().rect(2, 4, 3, 4))

    s.append(Shape("cross", "River Cross", 9, 7).layer()
             .rect(3, 5, 0, 6).rect(0, 8, 2, 4)
             .layer().rect(2, 6, 2, 4))

    s.append(Shape("weir", "Moonlit Weir", 9, 6).layer()
             .rect(0, 8, 0, 3).rect(2, 6, 4, 5)
             .layer().rect(2, 6, 1, 2))

    s.append(Shape("lattice", "Bamboo Lattice", 8, 7).layer()
             .rect(0, 7, 0, 6).clear(1, 1, 1, 5).clear(3, 3, 1, 5)
             .clear(5, 5, 1, 5)
             .layer().rect(2, 6, 2, 4))

    # ---- tier 3 ------------------------------------------------------------
    s.append(Shape("pagoda_s", "Little Pagoda", 9, 7).layer().rect(0, 8, 0, 5)
             .layer().rect(1, 7, 1, 4)
             .layer().rect(3, 5, 2, 3))

    s.append(Shape("wall", "Frontier Wall", 9, 7).layer()
             .rect(0, 8, 0, 6).clear(4, 4, 3, 3)
             .layer().rect(1, 7, 1, 2).rect(1, 7, 4, 5))

    s.append(Shape("cascade", "Jade Cascade", 9, 9).layer()
             .rect(0, 8, 0, 3).rect(1, 7, 4, 6).rect(2, 6, 7, 8)
             .layer().rect(2, 6, 1, 3))

    s.append(Shape("vase", "Cinnabar Vase", 8, 9).layer()
             .rect(2, 5, 0, 1).rect(1, 6, 2, 3).rect(0, 7, 4, 8)
             .layer().rect(1, 6, 5, 7)
             .layer().rect(2, 5, 6, 6))

    s.append(Shape("dragonfly", "Dragonfly", 9, 8).layer()
             .rect(0, 8, 1, 2).rect(0, 8, 5, 6).rect(3, 5, 0, 7)
             .layer().rect(3, 5, 1, 6).rect(1, 7, 2, 2).rect(1, 7, 5, 5))

    # ---- tier 4 ------------------------------------------------------------
    s.append(Shape("fortress", "Stone Fortress", 9, 8).layer().rect(0, 8, 0, 7)
             .layer().rect(2, 6, 1, 6)
             .layer().rect(3, 5, 3, 4))

    s.append(Shape("temple", "River Temple", 9, 9).layer()
             .rect(1, 7, 0, 1).rect(0, 8, 2, 8)
             .layer().rect(2, 6, 3, 8)
             .layer().rect(3, 5, 4, 6))

    s.append(Shape("loom", "Weaver's Loom", 9, 9).layer()
             .rect(0, 8, 0, 8).clear(2, 2, 1, 7).clear(6, 6, 1, 7)
             .layer().rect(3, 5, 1, 8)
             .layer().rect(3, 5, 3, 5))

    s.append(Shape("gorge", "Jade Gorge", 9, 10).layer()
             .rect(0, 2, 0, 9).rect(6, 8, 0, 9).rect(3, 5, 3, 6)
             .layer().rect(0, 2, 1, 8).rect(6, 8, 1, 8))

    # ---- tier 5: the classic 144 ------------------------------------------
    s.append(Shape("koi_pool", "Koi Pool", 9, 10).layer().rect(0, 8, 0, 9)
             .layer().rect(1, 7, 1, 6)
             .layer().rect(3, 5, 3, 6))

    s.append(Shape("mountain", "Cloud Mountain", 9, 10).layer()
             .rect(0, 8, 0, 8).rect(1, 7, 9, 9)
             .layer().rect(1, 7, 1, 5)
             .layer().rect(2, 6, 2, 4)
             .layer().rect(3, 5, 3, 4))

    s.append(Shape("great_wall", "The Long Wall", 9, 11).layer()
             .rect(0, 8, 0, 10).clear(4, 4, 1, 9)
             .layer().rect(1, 3, 1, 8).rect(5, 7, 1, 8)
             .layer().rect(2, 2, 3, 5).rect(6, 6, 3, 5))
    return s


def main():
    shapes = build()
    ok = True
    report = []
    for sh in shapes:
        n = sh.count()
        cols = sh.used_cols()
        floats = sh.floating()
        issues = []
        if n % 2 != 0:
            issues.append("ODD(%d)" % n)
            ok = False
        if cols > MAX_COLS:
            issues.append("WIDE(%d)" % cols)
            ok = False
        if floats:
            issues.append("FLOAT(%d)" % len(floats))
            ok = False
        report.append("%-12s %3d tiles  %d cols  %d layers  tier %d  %s" % (
            sh.name, n, cols, len(sh.layers), sh.tier(), " ".join(issues)))

    import sys
    for line in report:
        print(line, file=sys.stderr)
    counts = {}
    for sh in shapes:
        counts[sh.tier()] = counts.get(sh.tier(), 0) + 1
    print("tier spread (new only): %s" % counts, file=sys.stderr)
    if not ok:
        print("FIX THE ISSUES ABOVE", file=sys.stderr)
        sys.exit(1)
    for sh in shapes:
        print(sh.emit())


if __name__ == "__main__":
    main()
