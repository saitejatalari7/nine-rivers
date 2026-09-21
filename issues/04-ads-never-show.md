# 04 — Ads never show at all

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
