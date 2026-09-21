# 09 — Daily and Rapids play caps

**Status:** PENDING — awaiting owner decision
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-21
**Resolved:** —

**Blocks release: no. Proposed by the owner, not specced.**

Owner's proposal: Time Rapids limited to 3 runs a day; Daily Tide once a day,
and on finishing, tell the player to come back tomorrow.

## The shape it creates

    Calm          uncapped, 350 levels
    Daily Tide    once a day
    Time Rapids   3 a day

One endless mode for players who want to keep going, two ritual modes that run
out. Currently all three are unlimited, so none of them feels like an occasion.

This also settles [06](06-time-rapids-and-relics.md): at three short runs a day
there is nothing for a run-long build system to build across.

## Implementation notes

- Reuse the existing UTC date key that `record_daily_play()` already uses rather
  than inventing a second scheme. `scripts/autoload/save_manager.gd:519`.
- A device clock change can still game any local cap. Acceptable here; worth
  knowing.
- New counters are new save state and must pass the signing rules from
  [05](05-t02-checksum-forgeable.md).

## Risk

A player who finishes their runs and wants more may churn. Calm being uncapped
is the release valve, so the "come back tomorrow" screen has to lead back into
Calm rather than dead-end.

Files: `scripts/autoload/save_manager.gd`, `scripts/main.gd`,
`scripts/ui/modal_controller.gd`
