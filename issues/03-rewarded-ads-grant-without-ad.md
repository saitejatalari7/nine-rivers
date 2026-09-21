# 03 — Rewarded ads pay out with no ad shown

**Status:** PENDING — blocks release
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-21
**Resolved:** —

**Blocks release: yes.** Needs a decision, then a small fix.

`show_rewarded_ad()` at `scripts/autoload/monetization_manager.gd:654` checks
for an ad plugin and, when there is none, falls through to `_grant_reward()` at
line 669. There is no ad plugin in the shipping build — see
[04](04-ads-never-show.md) — so every rewarded offer pays out immediately.

Cap is `MAX_DAILY_REWARDED_ADS = 4` at 60 pearls each: **240 free premium
pearls per day, no ad watched.** Pearls are a paid currency.

## Why this is an oversight rather than a choice

Purchases already have exactly the guard that ads lack.
`buy_product()` at line 572 refuses to fulfil on a mobile release build when
billing is unavailable — commented "never allow free fulfillment if billing
service failed to connect". The same reasoning was never applied to ads.

## Options

- Fail closed and hide the offer when no ad is available. Correct, but with ads
  dead it removes the Daily Meditations screen's only content.
- Keep granting until ads work. Devalues the pearl IAP.
- Fail closed and leave the screen showing "Complete · resets at dawn".

Probably wants deciding alongside [04](04-ads-never-show.md); they are the same
underlying problem.

Files: `scripts/autoload/monetization_manager.gd:654,669,572`

---

## Resolution — 2026-09-21

`show_rewarded_ad()` now refuses on a mobile release build when no ad network is
present, emitting `rewarded_ad_unavailable(placement)` instead of granting. The
editor and debug builds keep the simulated grant, which is where it is useful.

Two things came out of the fix that were not in the original report:

- The daily charge was consumed *before* the plugin check, so a refused offer
  still burned one of the four. Charges are now taken only when an ad is really
  shown, or a debug grant is really made.
- Daily Meditations showed its offers regardless. They are hidden when no ad is
  available, with "Unavailable · try again later" in their place, rather than
  leaving a button that silently does nothing.

`scripts/tests/rewarded_ad_test.tscn` covers it. The branch that matters is
mobile release, which a desktop run cannot reach, so
`MonetizationManager.debug_force_release_mobile` forces it rather than leaving
the important path untested. Verified by deleting the guard: 3 failures, and 0
with it restored.

Commit: see git log for `fix(ads)`.
