# 18 — First-run onboarding

**Status:** RESOLVED — 2026-09-23
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-23

Owner: a player who installs the game should be taught how to play it before
anything else.

## What was there

Three paragraphs behind a Next button:

> "A tile is FREE if its left or right edge is unobstructed, and no tile rests
> directly upon it. Free tiles gleam with ceramic light; blocked tiles softly
> slumber in shade."

Nobody reads that. It never asked the player to do anything, so someone could
click through all three panels and still not know what a free tile is. It was
also untestable - there was no behaviour to assert.

## What it is now

Four beats, each completed by an action on the real board. Nothing advances on
a button.

| Beat | Asks | Completed by |
|------|------|--------------|
| 1 | Tap these two tiles to match them | matching the pointed-at pair |
| 2 | Tap the tile with something on top | tapping it and feeling it refuse |
| 3 | Match another pair | any legal match |
| 4 | That is all of it. Clear the board | immediately; control is handed back |

`board.tutorial_focus` limits which tiles answer a tap while a beat is up. A
first-timer who wanders off ends up somewhere the script cannot follow, and the
lesson breaks rather than the player learning anything. It is empty at every
other moment in the game.

Beat 2 needed a new `blocked_tap` signal: nothing is matched when a covered tile
is tapped, so `move_completed` never fires and there was no way to know the
player had tried.

Skip is always present and sits inside the instruction card. Anchored top-right
it landed on top of the TILES and SETS readout - caught from a screenshot, not
from a test.

## The one that would have taught a lie

Beat 1 says "two tiles with the same face", and it was pointing at a flower
beside a character. Flowers and seasons are wild here and match anything, and
`get_legal_sets()[0]` happily returned one. It now prefers a genuinely identical
non-wild pair and only falls back if the board offers none. Verified by printing
the focused tiles: two `char` rank 9, both non-wild.

A beat that cannot find what it needs is skipped rather than left hanging - a
board with no covered tile is unusual but possible, and being stuck on step two
of a tutorial is the worst outcome available.

`onboarding_test` drives it: that a new player sees it, that it points at a real
pair, that a tile outside the lesson does not respond, that matching advances
without any button, that it can be finished, that finishing releases the board,
and that it is not shown twice.

Files: `scripts/ui/tutorial_controller.gd`, `scripts/core/board_controller.gd`
