# 08 — Spirit Bazaar is too complex

**Status:** PENDING — awaiting owner decision
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no. Design decision, undecided.**

Owner: "noone understood sprite bazaar. its complex. that koi blessing pearl
tresures daily meditation, even i dont understand them well."

## The root problem: two currencies, nothing explains either

- **River Jade 玉** — earned by playing. 50 per star on a level clear, plus a
  per-board gain. Spends on Koi Blessings.
- **Spirit Pearls ◈** — bought with real money, or granted by rewarded ads.
  Spends on tile themes and pond backdrops.

Nothing in the game says which is which or where either comes from.

## The five sub-screens are organised by currency, not by intent

    Artisan Tile Sets     pearls
    Zen Pond Backdrops    pearls or jade
    Koi Blessings         jade
    Pearl Treasury        pearls (and IAP)
    Daily Meditations     free, via rewarded ads

"Koi Blessings" and "Pearl Treasury" feel like the same thing twice because the
split is by what they take, not by what the player wants.

## Options

- Rename in plain language and add one line per currency saying where it comes
  from. Cheapest, keeps the structure.
- Reorganise by intent: Tiles / Ponds / Blessings / Free.
- Collapse to one currency. The honest fix, but it touches IAP and the products
  table, so not a two-day change.

Note that Daily Meditations is currently free pearls with no ad —
see [03](03-rewarded-ads-grant-without-ad.md).

Files: `scripts/ui/modal_controller.gd:687` and the screens below it,
`scripts/autoload/monetization_manager.gd`, `scripts/core/sanctuary_manager.gd`

---

## Resolution — 2026-09-23

One currency. Spirit Pearls are all that remains; River Jade converts at three
to one on load, which is the rate the shop already implied - a background cost
1,500 jade or 500 pearls. The Koi Blessings screen went with
[17](17-invisible-bonuses.md), so the Bazaar is four rows rather than five and
no two of them take different money.

Earning moved across: 20 pearls per star, 50 for the first daily of the day, 2
for a wild tile. The HUD purse now follows a `pearls_changed` signal - it had
been written once when the HUD was built and never again, so pearls earned
mid-board did not appear until a restart.

Pricing was respread at the same time. At 1,500 flat and 60 pearls a
three-starred level, every paid set was owned by level 75 of 350 and the
currency was dead for the remaining 275:

| Set | Cost | Reached around |
|-----|------|----------------|
| Imperial Gold | 4,000 ◈ | level 67 |
| Obsidian Ink | 6,000 ◈ | level 100 |
| Cherry Blossom | 8,000 ◈ | level 134 |

All four by about level 342, so pearls stay worth something to the end.

Deep Indigo is new and is not for sale at any price. It unlocks by reaching
Calm stage 50 and is offered there - shown, not applied, because a set that
switches itself on is a surprise while one the player chooses is a reward. A
milestone reads as an achievement where a price reads as a chore.

What still is not addressed here: nothing explains what pearls are or where
they come from. One currency removes the confusion between two, but a first-time
player is still not told anything. Worth a line on the Bazaar screen.
