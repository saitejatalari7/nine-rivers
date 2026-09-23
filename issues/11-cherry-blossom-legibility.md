# 11 — Cherry Blossom fails legibility

**Status:** DEFERRED — owner chose to leave
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no — owner chose to leave it.**

`scenes/legibility_check.tscn` reports 12 failures, all Cherry Blossom, across
all three colour-blind modes. Worst is 2.03:1 on a blocked dragon against a
3.0 floor. Every other theme passes everywhere.

## Cause

Same fault the other themes had: mid-tone ink on a mid-tone body of the same
hue. The body is a dusty pink face inside a dark red frame; the inks are
`#2e181f`, `#8f2340`, `#2f5626`, `#453a9c`. Nothing has enough separation.

## The fix is known and was measured

Moving the body to an extreme fixes it, as it did for the other two. A blush
white body took the whole check to **0 failures** when trialled. That work was
reverted at the owner's request — the theme was not on the list and the trial
version lost the bold rose frame the theme is recognised by.

If revisited: keep the frame by moving it into the body's rim rather than
dropping it, and darken the inks.

Generator: `tools/make_tile_body.gd` already supports this — add a style entry.
Files: `scripts/ui/tile_view.gd` (`BODY_TEX_FILES`, `get_col_*`),
`assets/tiles/tile_cherry_blossom.png`
