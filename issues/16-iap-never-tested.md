# 16 — IAP flow never tested end to end

**Status:** RESOLVED — 2026-09-26
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-26

**Blocks release: probably, if paid items ship on day one.**

No purchase has ever been completed against real Google Play Billing. The code
path has only run in the simulated branch.

`buy_product()` at `scripts/autoload/monetization_manager.gd:552` is written
correctly as far as can be judged by reading: it fails closed on a mobile
release build when billing is unavailable (line 572), rather than granting the
item for free. But "reads correctly" is not "works".

Untested: the billing singleton connecting at all, a real purchase completing,
`restore_purchases()`, and what happens to a purchase interrupted mid-flow.

Requires a real device, a Play Console entry, and configured products. Cannot be
verified from a development machine.

Related: [03](03-rewarded-ads-grant-without-ad.md) shows the same class of
fallback *without* the guard, on the ads path.

Files: `scripts/autoload/monetization_manager.gd:552-620`


## Resolution — 2026-09-26

Tested on a real phone through the Internal testing track with license
testing (test card, no charge):

- `pearls_small` bought: Play confirmed, 500 pearls granted, purchase consumed.
- `theme_imperial_gold` bought with money: set unlocked and equipped.
- Uninstall and reinstall: Imperial Gold restored as owned from Play.

Testing exposed that the purchase code targeted the v2 plugin API while the
shipped plugin is v3 (no initPlugin, wrong purchase() arity, product details
never queried, `sku` instead of `product_ids`). Fixed in c68eced by moving to
the plugin's BillingClient wrapper. All 9 products are active in Play Console.
