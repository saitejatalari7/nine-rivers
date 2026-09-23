# 17 — Invisible percentage bonuses

**Status:** PARTIALLY RESOLVED — 2026-09-23
**Raised:** 2026-09-23
**Last reviewed:** 2026-09-23
**Resolved:** —

Owner, on the koi blessings: "i dont want people to think something of 5%. no
one cares."

The same shape appeared in several places: a permanent bonus of a few per cent,
applied to a number the player cannot see, described in language that does not
say what it does.

## Removed — 2026-09-23

The Koi Blessings shop and all four koi:

| Koi | Cost | Did |
|-----|------|-----|
| Taisho Sanke | 200 玉 | +5% River Jade |
| Showa Sanshoku | 400 玉 | Misplay cost 1 Flow instead of 2 |
| Platinum Ogon | 750 玉 | +10% score in Calm |
| Golden Dragon Koi | 1,500 玉 | Overdrive at Flow ×6 instead of ×7 |

Plus four pond ornaments, which had no gameplay effect and were not read by the
pond background either.

Overdrive and the misplay drop are now plain constants — `OVERDRIVE_FLOW` and
`MISPLAY_FLOW_DROP` in `game_manager.gd`.

## Still present: tile mastery

`record_tile_mastery()` counts how often each of the 34 tile types has been
cleared and awards a level. That level feeds
`mastery_mult = 1.0 + (mastery_level * 0.05)` at `game_manager.gd:219`, so a
player who has cleared a lot of one tile scores more for it.

It is shown **nowhere**. No screen, no toast, no counter. It is the last of the
three invisible multipliers noted in [07](07-scoring-system.md) — `score_mult`
went with the relics, `ogon_mult` went with the koi.

Options: surface it so it means something, or remove it and make matches worth
the same every time. Removing it would also make the scoring formula
`base x Flow x Rush`, which is explainable in one line.

## Also dead, found while looking

`streak_shields` is only ever *spent*, at `save_manager.gd:536`, to save a
broken daily streak. Nothing anywhere grants one, so the branch can never run.
See [09](09-daily-and-rapids-caps.md) for the daily-streak discussion.

`daily_streak` itself is incremented and displayed, and does nothing else.

Files: `scripts/autoload/game_manager.gd:219`,
`scripts/autoload/save_manager.gd:536,545`
