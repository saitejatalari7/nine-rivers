# 23 — Closing the game loses the board in progress

**Status:** PENDING — not scheduled
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no, but it is the largest of the three new items.**

Owner: closing the game and opening it again should continue from where they
left off.

## What happens now

`SaveManager` persists progression only — level reached, stars, pearls, themes,
settings — and flushes it on `NOTIFICATION_WM_CLOSE_REQUEST`,
`APPLICATION_PAUSED` and `FOCUS_OUT` (`save_manager.gd:88`). No board state is
written anywhere. Reopening deals a fresh board for the stage.

On Android this is worse than it sounds: the OS kills a backgrounded app
without warning, so a player who takes a phone call mid-board loses it.

## What it needs

A board snapshot, written on the same notifications that already flush the
save, and offered as "Continue" on launch:

- Per-tile `x/y/z`, type, `set_id`, `is_removed`, and the frost/ice state.
- The undo stack, or the decision to drop it on resume.
- `GameManager.snapshot_state()` already returns score, flow, time left and
  misplays — that half exists.
- Current mode and stage number; a Rapids run in progress also has a run clock
  and a daily has its seed.
- Whether a Rapids run resumed from disk still counts against the daily cap
  (issue 09) — otherwise closing the app is a free retry.

Not a small change, and the cap interaction needs a decision before it is
built.

Files: `scripts/autoload/save_manager.gd`, `scripts/autoload/game_manager.gd`,
`scripts/core/board_controller.gd`, `scripts/main.gd`
