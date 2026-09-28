"""Caps every ASCII board layout at N rows, trimming top and bottom evenly.

The column cap (narrow_layouts.py) only helps boards whose size on screen is
bound by width. On a phone, a board twelve rows tall is bound by height, so
narrowing it changed nothing; this is the other half.

The parser in board_generator.positions_from_ascii skips blank lines and
numbers each layer's rows from zero, so row r of every layer is the r-th
non-blank line of its block. Trimming therefore drops the first `top` and the
last `bottom` such lines from every layer, measured against the layout's full
height, not the layer's own.

Tiles in dropped rows are dropped, not re-homed, and an odd board loses one
more tile from its top layer so it still deals in pairs.

Run: py tools/cap_rows.py --cap=10 [--dry-run]
"""
import io, re, sys

SRC = "scripts/core/layout_data.gd"
DRY = "--dry-run" in sys.argv
CAP = int(next((a.split("=")[1] for a in sys.argv if a.startswith("--cap=")), "10"))

text = io.open(SRC, encoding="utf-8", newline="").read()

entry_re = re.compile(r'(\t"(?P<name>[a-z_0-9]+)": \{)(?P<body>.*?)(\n\t\},)', re.S)
block_re = re.compile(r'"""(?P<block>.*?)"""', re.S)
extras_re = re.compile(r'"extras": \[(.*)\]')
triple_re = re.compile(r"\[(-?\d+), (-?\d+), (-?\d+)\]")
TILE_FREE = "., " + chr(13)

report, dropped_total, layouts = [], 0, 0


def rows_of(block):
    return [l for l in block.split(chr(10)) if l.strip(chr(13)).strip()]


def count_tiles(body):
    n = 0
    for b in block_re.findall(body):
        n += sum(1 for line in rows_of(b) for c in line if c not in TILE_FREE)
    m = extras_re.search(body)
    if m:
        n += len(triple_re.findall(m.group(1)))
    return n


def drop_one(body):
    blocks = list(block_re.finditer(body))
    for bm in reversed(blocks):
        block = bm.group("block")
        idx = max((block.rfind(ch) for ch in set(block) if ch not in TILE_FREE + chr(10)),
                  default=-1)
        if idx < 0:
            continue
        new = block[:idx] + "." + block[idx + 1:]
        return body[:bm.start()] + '"""' + new + '"""' + body[bm.end():], 1
    return body, 0


def fix_entry(m):
    global dropped_total, layouts
    body = m.group("body")
    blocks = block_re.findall(body)
    if not blocks:
        return m.group(0)
    height = max(len(rows_of(b)) for b in blocks)
    em = extras_re.search(body)
    if em:
        for x, y, z in triple_re.findall(em.group(1)):
            height = max(height, int(y) // 2 + 1)
    if height <= CAP:
        return m.group(0)
    extra = height - CAP
    top = extra // 2
    bottom = extra - top
    keep_last = height - bottom  # exclusive

    dropped = 0

    def one(bm):
        nonlocal dropped
        rows = rows_of(bm.group("block"))
        kept = rows[top:keep_last]
        for gone in rows[:top] + rows[keep_last:]:
            dropped += sum(1 for c in gone if c not in TILE_FREE)
        return '"""' + chr(10) + chr(10).join(kept) + chr(10) + '"""'

    body = block_re.sub(one, body)

    def extras(e):
        nonlocal dropped
        kept = []
        for x, y, z in triple_re.findall(e.group(1)):
            row = int(y) / 2.0
            if row < top or row > keep_last - 1:
                dropped += 1
                continue
            kept.append("[%s, %d, %s]" % (x, int(y) - top * 2, z))
        return '"extras": [%s]' % ", ".join(kept)

    body = extras_re.sub(extras, body)

    if count_tiles(body) % 2 == 1:
        body, removed = drop_one(body)
        dropped += removed

    layouts += 1
    dropped_total += dropped
    report.append((m.group("name"), height, CAP, dropped))
    return m.group(1) + body + m.group(4)


out = entry_re.sub(fix_entry, text)

report.sort(key=lambda r: -r[3])
print("layouts capped at %d rows: %d" % (CAP, layouts))
print("tiles dropped:    %d" % dropped_total)
print("")
for name, h0, h1, d in report:
    print("  %-18s %2d -> %2d rows, -%d tiles" % (name, h0, h1, d))

if not DRY:
    io.open(SRC, "w", encoding="utf-8", newline="").write(out)
    print("")
    print("written: %s" % SRC)
