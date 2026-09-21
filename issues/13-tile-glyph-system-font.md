# 13 — Tile glyphs render in the device's font

**Blocks release: no. Worth knowing before release.**

`get_cjk_font()` at `scripts/ui/tile_view.gd:281` builds a `SystemFont` asking
for PingFang SC, Microsoft YaHei, Hiragino Sans GB, Noto Sans CJK SC and others,
with the bundled `NotoSerifSC.ttf` attached only as a *fallback*.

On Android the device supplies the face, so tile faces look different on a
Samsung, a Xiaomi and a Pixel. On a device with no CJK font they would render as
boxes.

Note the inconsistency: `ui_theme.gd:100` uses the bundled NotoSerifSC as the
*primary* for UI text. Only the tiles defer to the system.

## Why it has not been changed

The bundled font was checked and covers all 27 tile glyphs, so it could be
promoted to primary and rendering would become deterministic. But it is a serif
face at a single weight, and the tiles currently ask for weight 700 — part of
the legibility work in `a8f0cd0`. Switching would make the glyphs thinner and
give back some of that gain.

The real fix is bundling a bold sans CJK subset. Only ~27 glyphs are needed, so
a subset would be small; `NineRiversGlyphs.ttf` (1.3 KB) shows the pipeline
already exists.

Files: `scripts/ui/tile_view.gd:281`, `assets/fonts/`
