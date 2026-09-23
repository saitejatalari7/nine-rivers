# 22 — Pause control is a hamburger, not a pause symbol

**Status:** PENDING — not scheduled
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no.** Small, safe, cosmetic.

Owner: give a pause symbol instead of the three lines while playing.

## What happens now

`scenes/ui/hud.tscn` sets the button's `text = "☰"`. Three stacked bars is the
web convention for "open a navigation drawer". The button opens the pause menu,
which stops the clock in Rapids and Daily, so the glyph promises the wrong
thing.

## What to do

Swap the glyph for a pause mark. The tile glyph audit already flagged that this
button draws in the device font (issue 13), so it is worth picking a mark the
fallback fonts all carry, or drawing two bars in the scene rather than relying
on a codepoint:

- `❚❚` and `⏸` both render, but `⏸` is an emoji-range codepoint on some Android
  builds and may come back coloured or missing.
- Two `ColorRect` bars inside the button is the only option with no font risk.

Files: `scenes/ui/hud.tscn` (the button node above `TimerWrap`),
`scripts/ui/hud_controller.gd`
