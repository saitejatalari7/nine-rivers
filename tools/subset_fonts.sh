#!/usr/bin/env bash
# Regenerate the subset CJK fonts.
#
# NotoSerifSC (24MB) and MaShanZheng (5.6MB) ship the full CJK repertoire -
# tens of thousands of glyphs. Nine Rivers uses about 140. Shipping the full
# fonts added ~30MB to the APK, which matters a great deal in the Indian
# market where install size drives conversion.
#
# Requires: py -m pip install --user fonttools brotli
# Originals live in assets/fonts/original/ (gitignored).
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=$(mktemp -d)
py tools/collect_glyphs.py "$OUT/glyphs.txt"

for F in NotoSerifSC MaShanZheng-Regular; do
  py -m fontTools.subset "assets/fonts/original/$F.ttf" \
     --text-file="$OUT/glyphs.txt" \
     --output-file="assets/fonts/$F.ttf" \
     --layout-features='*' --glyph-names --symbol-cmap --legacy-cmap \
     --notdef-glyph --notdef-outline --recommended-glyphs \
     --name-IDs='*' --name-legacy --name-languages='*'
  echo "$F -> $(du -h "assets/fonts/$F.ttf" | cut -f1)"
done

# Fail loudly if subsetting dropped a glyph the source actually had.
PYTHONIOENCODING=utf-8 py - "$OUT/glyphs.txt" <<'PY'
import io, sys
from fontTools.ttLib import TTFont
want = set(io.open(sys.argv[1], encoding="utf-8").read())
def cov(p):
    ft = TTFont(p); s = set()
    for t in ft["cmap"].tables:
        s.update(chr(c) for c in t.cmap.keys())
    return s
bad = False
for f in ("NotoSerifSC", "MaShanZheng-Regular"):
    lost = (want & cov(f"assets/fonts/original/{f}.ttf")) - cov(f"assets/fonts/{f}.ttf")
    if lost:
        bad = True
        print(f"FAIL {f}: subsetting dropped {len(lost)} glyphs the source had")
print("OK - no glyphs lost by subsetting" if not bad else "")
sys.exit(1 if bad else 0)
PY
