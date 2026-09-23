# 04 — Ads never show at all

**Status:** PENDING — not scheduled
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: no** — revenue is zero either way. But zero is the current state.

`admob_plugin.zip` sits unextracted at the repo root. There is no
`android/plugins/` directory and no plugin entry in `export_presets.cfg`, so no
ad SDK ships. `monetization_manager.gd:369` checks
`Engine.has_singleton("GodotAdMob")`, finds nothing, and falls through silently.

## Installing the plugin would not fix it

The bundled zip is Poing AdMob 4.1.0, which registers five separate singletons
— `PoingGodotAdMob` (`initialize`, `set_app_muted`), `PoingGodotAdMobRewardedAd`
(`load`, `show`, signal `on_rewarded_ad_user_earned_reward`),
`PoingGodotAdMobInterstitialAd`, `PoingGodotAdMobAdView`.

`monetization_manager.gd` calls `show_rewarded_video()`, `show_interstitial()`,
`show_banner()`, `hide_banner()`. **None of these exist on any of those
singletons**, and the reward signal is connected to the wrong one. Every
`has_method()` guard would fail and the code would keep granting rewards with no
ad — which is [03](03-rewarded-ads-grant-without-ad.md).

The integration is written against the Godot 3.x-era "GodotAdMob" plugin.

## Also missing

- Any `initialize()` call
- Ad unit IDs
- The AdMob App ID `meta-data` in the manifest — the SDK crashes on init without it
- `com.google.android.gms:play-services-ads` dependency
- The zip is Android payload only: no `plugin.cfg`, no `addons/admob/` GDScript
  API. It is an incomplete download.

This is a rewrite against a current plugin, not a configuration fix.

Files: `scripts/autoload/monetization_manager.gd:369`, `admob_plugin.zip`

---

## Partial — 2026-09-23: the showing policy

The owner asked for ads from day one, but nothing until three levels are played
and sensible rules after that. The policy half is done and tested; it will
govern ads the moment ads exist.

| Rule | Value |
|------|-------|
| Nothing before | stage 4 — three levels played untroubled, and long enough for onboarding to finish |
| Stages between ads | 3 |
| Minimum gap | 4 minutes |
| Quiet after any purchase | 15 minutes |
| A player who bought no-ads | never |

## The bug underneath it

The spacing existed already but lived entirely in memory and timed from
`Time.get_ticks_msec()`, which restarts with the app. Closing and reopening
cleared the frequency cap, so a player who relaunched between levels would have
seen an ad every single time. Both counters are persisted now and timed from
Unix time.

A clock wound backwards leaves a timestamp in the future, which `now - then`
reports as negative, i.e. recent. That is checked first and reported as
`clock_moved`, so it reads as quiet rather than as licence.

`interstitial_block_reason()` returns *why*, not just yes or no. "No ad
appeared" is true for six different reasons and they are not interchangeable - a
test asserting only the boolean passes just as happily when the wrong rule
fired. That is exactly what caught the post-purchase window blocking
test_runner's capper suite: an earlier suite buys something, so the capper was
being asked about a player who had paid seconds ago.

## Still outstanding

Everything in the original report. No ad SDK ships, the bundled plugin exposes a
different API from the one the code calls, and there are no ad unit IDs, no
`initialize()` call, and no AdMob App ID in the manifest. That work needs an
AdMob account and a device.
