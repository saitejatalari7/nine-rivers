# 25 — Menu names are too clever

**Status:** RESOLVED — 2026-09-23
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-23, `10b11e4`

**Blocks release: no.** Text only, but it touches nearly every screen.

Owner, agreeing with a feeling he has had for a while: the names in the menus
are too smart. They should be plain words. Needs a review pass, not a guess.

**Not to be implemented yet — to be agreed first.**

## The current names

Themed, and in several places the theme is the only clue to what the button
does:

| Now | What it actually is |
|-----|---------------------|
| Spirit Bazaar | the shop |
| Pearl Treasury | buy currency |
| Daily Offerings | today's deals |
| Daily Meditations | the daily puzzle |
| Timed Rapids | timed mode |
| River Stages / Stages Map | level select |
| Tile Sets / Pond Backdrops | tile skins / backgrounds |
| Serenity Blessing, Meditation Blessing | daily reward |
| Peak Flow | best combo |
| River Streak | days played in a row |
| Set out from the source | start a new game |
| Carry on downriver | continue |
| Back to the board | resume |
| Run Concluded | you lost |

Related, and probably the same pass: issue 21, removing the Chinese words and
the cinnabar seal from the menus.

## Worth deciding first

- How far to go. "Shop" and "Buy Pearls" are unmistakable and flat; a middle
  setting keeps the river names for the *places* and makes the *buttons* plain.
- The river naming is the only theming left once the Chinese goes (issue 21).
  Stripping both leaves a generic mahjong app.
- A recommendation: keep the river word where it names a mode a player returns
  to and will learn — Timed Rapids, Daily Meditation — and make every action
  button say the action. "Set out from the source" becomes "New Game".
- Store listing and screenshots use some of these names.

Files: `scripts/ui/modal_controller.gd` (most of them),
`scripts/ui/hud_controller.gd`, `scenes/ui/*.tscn`
