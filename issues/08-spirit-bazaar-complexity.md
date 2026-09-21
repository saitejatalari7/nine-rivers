# 08 — Spirit Bazaar is too complex

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
