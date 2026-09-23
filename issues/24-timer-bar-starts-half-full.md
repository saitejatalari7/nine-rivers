# 24 — The time bar starts about half full

**Status:** PENDING — not scheduled
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no.** Cosmetic, but it reads as a bug to a player.

Owner: the timer bar starts from the middle. Remove the bar if the animation
cannot run from a full bar.

## Why it does that

The bar is `time_left / max_time`, and the two numbers were never meant to
match:

- Rapids starts `time_left = 100.0`, `max_time = 180.0` — **56% full on the
  first frame** (`game_manager.gd:96`).
- Daily sets `max_time = time_left + 60.0`, so it opens around 63–81% full
  (`apply_daily_time`).
- Calm hides the bar entirely, so this is a Rapids and Daily problem only.

`max_time` is a *ceiling*, not an allotment. Matches add seconds and the bar has
to show that headroom, so it can never open full as written.

## The options

1. **Start full, cap gains at the start value.** The bar reads correctly; time
   gained near full is partly wasted, which players of this genre expect.
2. **Start full, let the bar overfill visibly** — a second fill colour past
   100%. Honest, but more work and more to explain.
3. **Drop the bar, keep the clock text.** The digits already say everything the
   bar does, and the owner explicitly offered this.

Option 1 is the smallest change and the one to recommend: one line in each of
`start_timed_run`, `start_daily_tide` and `apply_daily_time`, and a clamp where
matches add time.

Files: `scripts/autoload/game_manager.gd` (`DEFAULT_MAX_TIME`,
`start_timed_run`, `start_daily_tide`, `apply_daily_time`, the `time_left +
bonus` clamp), `scripts/ui/hud_controller.gd:276`
