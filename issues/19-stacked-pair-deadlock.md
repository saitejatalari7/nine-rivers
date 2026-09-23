# 19 — Same-type tiles dealt in one column

**Status:** RESOLVED — 2026-09-23
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-23

A tester reached stage 2 with two tiles left, one sitting directly on the
other. He could not match them, pressed Shuffle, and nothing happened.

## Why it was fatal

Two slots in one column are never free at the same time — the lower is always
covered by the upper. So a pair of the same type seated that way cannot be
matched once the other copies of that type are gone.

Tiles never move during play. That makes this the entire cause rather than one
of several: the only way a board ends with two stacked tiles that ought to
match is if they were dealt that way.

Shuffle could not help either, and not because shuffle was weak. With two tiles
left in one column, every permutation of two stacked slots is still two stacked
slots. The geometry was the problem, not the arrangement.

## Cause

`deal_board` assigns a type to each peel group by popping from a pool that
reuses types — there are 34 types and up to about 70 sets, so two different
sets routinely share a match key. Nothing stopped one of them being seated
directly above the other.

`peel_dynamic` itself is innocent: it only ever picks slots that are free at the
same moment, so it cannot place one set stacked on itself. The collision is
always between two different sets that happen to share a type.

Measured before the fix: **61 occurrences across the 350 stages**, first at
stage 25, plus one in 60 daily seeds.

## Fix

Types are swapped between whole sets until no two vertically adjacent tiles
share a match key. Swapping is safe because solvability comes from the peel
ORDER, which is about slots — any assignment of types to those groups is
equally solvable. Confirmed by the campaign validator: 350 levels, 0 replay
failures, 0 shuffle fallbacks.

`stack_trap_test` checks all 350 stages and 60 daily seeds. Removing the repair
makes it report 61 and 1; restoring it returns both to zero.

## Also changed, though no longer the cure

Shuffle used to permute slot positions at random and return true whatever came
out — it could leave no legal move at all, and it consumed a charge either way.
It now re-deals the remaining tiles along a fresh peel order, so the result is
provably solvable, and it refuses rather than charging when the remaining slots
admit no solvable order.

Its first version grouped tiles by `set_id`, which failed every single time: a
match pairs tiles by match key, not by the set they were dealt in, so two tiles
of one type from different sets get matched together and leave an orphan in
each. A probe reading "group of 1, 600 times" is what surfaced it. Grouping is
by match key now.

Files: `scripts/core/board_generator.gd`, `scripts/core/board_controller.gd`,
`scripts/main.gd`
