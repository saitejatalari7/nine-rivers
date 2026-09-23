# 09 — Daily and Rapids play caps

**Status:** PENDING — awaiting owner decision
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
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

---

## Resolution — 2026-09-23

    Calm          uncapped, 350 levels
    Daily Tide    one board a day
    Time Rapids   three runs a day

Both counters key off the UTC date the daily already used, so there is one
scheme rather than two. Only a LATER date resets them: winding the device clock
backwards and forwards cannot refill the runs, which is the trap the rewarded-ad
counter had and which is now tested for.

The menu rows carry their own state - "3 left" or "Spent", "Ready" or "Done" -
and go quiet when there is nothing to start, rather than letting a player begin
a run that is refused a moment later. The cap is also enforced where the run
actually starts, because the signal can arrive from a stale screen.

Calm is deliberately untouched. It is the release valve: when both timed modes
are spent there is still 350 levels of somewhere to go, and without that a cap
is just a locked door.

`play_caps_test` covers the count, exhaustion, the backwards clock, a genuine
new day, and that Calm has no counter of its own.

`ui_nav_audit` starts several timed runs in one pass and began failing the
Daily flow, because the second start was refused. It clears the counters
between flows now - it is an audit of navigation, and the caps have their own
test.

Not done: nothing yet tells the player *when* the runs come back. "Back
tomorrow" is true but vague, and a countdown or a reset time would be kinder.
