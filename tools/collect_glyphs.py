import os, sys
root = "."
SKIP = {".godot", ".git", "android", "build", "addons", "audit"}
EXT = (".gd", ".tscn", ".cfg", ".godot", ".html", ".md", ".json")
chars, files = set(), 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in SKIP and not d.startswith(".")]
    for fn in filenames:
        if not fn.endswith(EXT):
            continue
        try:
            t = open(os.path.join(dirpath, fn), encoding="utf-8").read()
        except Exception:
            continue
        files += 1
        chars.update(ch for ch in t if ord(ch) > 0x7F)
for c in range(0x20, 0x7F):
    chars.add(chr(c))
# Punctuation and symbols the UI may compose at runtime.
for c in "·—–…“”‘’×÷°±≤≥→←↑↓★☆◈✕☰▰、。，！？：；（）《》「」　":
    chars.add(c)
# Every CJK numeral / suit glyph the tile renderer can produce, defensively.
for c in "一二三四五六七八九十百千萬万东南西北中發白梅蘭菊竹春夏秋冬红中发白":
    chars.add(c)
cjk = sorted(c for c in chars if 0x2E80 <= ord(c) <= 0x9FFF)
out = "".join(sorted(chars))
open(sys.argv[1], "w", encoding="utf-8").write(out)
print("files scanned:", files)
print("total unique glyphs:", len(chars))
print("CJK glyphs:", len(cjk))
print("CJK set:", "".join(cjk))
