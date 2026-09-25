"""Caps every ASCII board layout at twelve columns, six each side of centre.

Tile size on screen is bound by COLUMN COUNT, not tile count: fifteen columns
gives a 3.3mm tile on a 5.5in phone, twelve gives 4.8mm. Android asks for 9mm,
so this narrows the gap rather than closing it.

Only layouts WIDER than twelve are touched. The sixty-seven at eleven columns
already sit inside the cap and are left exactly as they are.

Tiles standing in the columns that go are dropped rather than re-homed. Moving
them somewhere else changes the shape, which is the thing being preserved, and
a shorter board is a fair price for a legible one.

Columns come off both sides evenly so the silhouette stays centred; an odd
number takes the extra from the right.

Layers inside one layout can be different widths, so every layer is padded to
the layout's own width before the outer columns come off - trimming each layer
by its own first and last character would cut different columns on each.

Run: py tools/narrow_layouts.py [--dry-run]
"""
import io, re, sys

SRC = "scripts/core/layout_data.gd"
DRY = "--dry-run" in sys.argv

text = io.open(SRC, encoding="utf-8", newline="").read()
nl = "\r\n" if "\r\n" in text else "\n"

# One entry per layout: "name": { ... },  up to the next top-level key.
entry_re = re.compile(r'(\t"(?P<name>[a-z_0-9]+)": \{)(?P<body>.*?)(\n\t\},)', re.S)
block_re = re.compile(r'"""(?P<block>.*?)"""', re.S)

report, dropped_total, layouts = [], 0, 0


CAP = 12


def trim_block(block, width, left, right):
    out, dropped = [], 0
    for line in block.split(chr(10)):
        stripped = line.strip(chr(13))
        if not stripped.strip():
            out.append(line)
            continue
        padded = stripped.ljust(width, ".")
        cut = padded[:left] + padded[width - right:]
        dropped += sum(1 for c in cut if c not in "., ")
        out.append(padded[left:width - right])
    return chr(10).join(out), dropped


def count_tiles(body):
    n = 0
    for b in block_re.findall(body):
        n += sum(1 for line in b.split(chr(10)) for c in line if c not in "., " + chr(13))
    m = re.search(r'"extras": \[(.*)\]', body)
    if m:
        n += len(re.findall(r"\[(-?\d+), (-?\d+), (-?\d+)\]", m.group(1)))
    return n


def drop_one(body):
    """Removes the last tile of the highest layer, so the board stays even."""
    blocks = list(block_re.finditer(body))
    for bm in reversed(blocks):
        block = bm.group("block")
        idx = max((block.rfind(ch) for ch in set(block) if ch not in "., " + chr(13) + chr(10)),
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
    width = max(
        (len(l.strip("\r")) for b in blocks for l in b.split("\n") if l.strip()),
        default=0)
    if width <= CAP:
        return m.group(0)
    extra = width - CAP
    left = extra // 2
    right = extra - left

    dropped = 0

    def one(bm):
        nonlocal dropped
        new, d = trim_block(bm.group("block"), width, left, right)
        dropped += d
        return '"""%s"""' % new

    body = block_re.sub(one, body)

    # "extras" are absolute half-grid coordinates, so they shift with the art.
    def extras(em):
        nonlocal dropped
        kept = []
        for x, y, z in re.findall(r"\[(-?\d+), (-?\d+), (-?\d+)\]", em.group(1)):
            xi = int(x)
            if xi < left * 2 or xi > (width - right - 1) * 2:
                dropped += 1
                continue
            kept.append("[%d, %s, %s]" % (xi - left * 2, y, z))
        return '"extras": [%s]' % ", ".join(kept)

    # Greedy, and NOT dotall: the list sits on one line and a lazy match
    # stopped at the first inner ']', leaving the rest of the entries
    # stranded outside the brackets and the file unparseable.
    body = re.sub(r'"extras": \[(.*)\]', extras, body)

    # Parity matters: tiles are dealt in pairs and triples, and a board with
    # an odd count sends the peel generator into its retry loop and out the
    # other side having failed. zodiac_wheel lost seven tiles, landed on 95,
    # and took 58 seconds to not deal. If the trim leaves an odd board, one
    # more tile comes off the top layer.
    kept = count_tiles(body)
    if kept % 2 == 1:
        body, removed = drop_one(body)
        dropped += removed

    layouts += 1
    dropped_total += dropped
    report.append((m.group("name"), width, width - extra, dropped))
    return m.group(1) + body + m.group(4)


out = entry_re.sub(fix_entry, text)

report.sort(key=lambda r: -r[3])
print("layouts capped at %d columns: %d" % (CAP, layouts))
print("tiles dropped:    %d" % dropped_total)
print("")
print("what changed:")
for name, w0, w1, d in report:
    print("  %-18s %2d -> %2d cols, -%d tiles" % (name, w0, w1, d))

if not DRY:
    io.open(SRC, "w", encoding="utf-8", newline="").write(out)
    print("")
    print("written: %s" % SRC)
