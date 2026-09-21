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
