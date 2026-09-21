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

## Review follow-up — 2026-09-21

A review agent found that the first fix was correct at the entry point but that
its UI half over-fired, plus three adjacent holes. All addressed:

- **The offer gate was wrong.** The screen asked `is_rewarded_ad_available()`
  while `show_rewarded_ad()` refused only when that *and* `_is_release_mobile()`.
  So the editor and debug builds hid offers that would have granted normally,
  making the simulated grant unreachable from any UI. Both now ask
  `can_offer_rewarded_ad()`, so an offer appears exactly when taking it does
  something.
- **`_on_admob_reward_granted` bypassed the guard, the cap and the charge.**
  With no pending placement it fell to the catch-all arm of `_grant_reward` and
  paid 50 pearls; firing twice for one ad paid twice. It now returns unless a
  placement is pending, and the catch-all warns instead of paying.
- **`_check_daily_ad_reset` refilled on any date mismatch**, so winding the
  device clock back and forward refilled the four charges indefinitely. Only a
  later date refills now.
- **`is_rewarded_ad_available()` only recognised the Godot 3.x API name**, so it
  would have refused every offer while a working Poing plugin was installed.
  Both names are accepted.

Two the reviewer raised that were deliberately left:

- The real-ad path consumes a charge before showing, so an abandoned ad still
  burns one of four. That is standard practice and prevents farming by
  dismissal. The earlier commit message claiming charges are taken "only when
  an ad is really shown" was inaccurate for that path.
- Coverage: `ui_layout_audit` and `ui_nav_audit` now walk a one-row Daily
  Meditations on release-mobile settings, so their coverage of the two offer
  rows drops. Scores unchanged. Worth revisiting when ads actually work.
