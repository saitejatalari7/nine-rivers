# 20 — Selecting a tile is not visible enough

**Status:** PENDING — awaiting design discussion
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** —

Owner, long-standing wish: the select effect is not visible enough that
something is selected. Wants a shadow, or the tile moving up a little, or
whatever the industry convention is.

**Not to be implemented yet — to be discussed first.**

## What happens now

`TileView.set_selected()` lifts the tile 8.5px with a BACK ease and draws a 3px
gold border. On a 64x84 tile that is a small move and a thin line, and the gold
sits against a face that is already warm on three of the four themes.

The shadow does not change when a tile lifts. `_draw_body` offsets the shadow by
`3.5 + z * 3.0`, which depends on the stack layer and not on the lift, so a
selected tile rises while its shadow stays put. That is most of why the lift
does not read.

## Worth considering

- A cast shadow that grows and softens as the tile lifts. This is what actually
  sells height, and it is currently the missing half.
- A larger lift, a slight scale-up, or both.
- Dimming the rest of the board briefly.
- A distinct held-press state, separate from a completed selection.
- Sound already plays on select; only the visual lags.

Convention in tile-matching games is lift plus shadow plus a small scale, not a
border. A border reads as "highlighted"; a lift with a shadow reads as
"picked up".

Files: `scripts/ui/tile_view.gd` — `set_selected()`, the `is_selected` branch of
`_draw()`, and the shadow in `_draw_body()`
