# 21 — Remove the Chinese text from the menus

**Status:** RESOLVED — 2026-09-23
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-23, `10b11e4`

Owner: remove all Chinese words from the menus, including the red seal glyph
discussed earlier.

**Not to be implemented yet — to be discussed first.**

## Where it appears

- Every modal header carries a Chinese subtitle: "清 · Stage 12",
  "灵气集市 · Tiles, ponds & offerings", "潮 · Cleared"
- `_add_seal_header` draws a red cinnabar seal containing a CJK glyph. It was
  moved off the close-button corner in `8d64c8b` but is still there
- Theme names are stored as "Classic Jade (羊脂白玉)" and split into a Latin
  title and a Chinese subline
- Row glyphs used as icons throughout: 牌 池 鯉 宝 供 設 急 潮 市 復 戻 写 珠 購
- Chapter names carry a Chinese pair, e.g. "The Spring Brooks" / "春溪"

## Worth considering

The tile faces are Chinese characters and must stay — that is mahjong. The
question is only the chrome around them.

- The row glyphs double as icons. Removing them leaves every row with no visual
  anchor unless something replaces them, and the Bazaar and Settings lists lean
  on them heavily.
- The seal is decoration with no function. It is the easiest to remove and the
  one already causing confusion.
- The chapter names are flavour rather than navigation.

Worth settling what the goal is: a game that reads as English, or one that reads
as uncluttered. Those point at different amounts of removal — the first takes
the glyphs too and needs icon replacements, the second may only need the
subtitles and the seal gone.

Files: `scripts/ui/modal_controller.gd` — `_add_seal_header`,
`TILE_THEME_DETAILS`, `TILE_THEME_GLYPHS`, `BG_THEME_GLYPHS`, most `show_*`
builders; `scripts/core/stage_plan.gd` — `CHAPTER_NAMES`
