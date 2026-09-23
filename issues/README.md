# Open issues — Nine Rivers

**All issues below are PENDING unless marked otherwise.**

Raised: 2026-09-21
Last reviewed: 2026-09-23
Against commit: 10b11e4

Every issue file carries its own Status, Raised, Last reviewed and Resolved
line. When one is closed, set Resolved to the date and the commit that did it,
change Status to RESOLVED, and move its row to the table at the bottom.

## Blocks release

| # | Item | Status |
|---|------|--------|
| [01](01-back-button.md) | Android back button does nothing on device | PENDING |
| [16](16-iap-never-tested.md) | IAP flow never tested end to end | PENDING — if paid items ship day one |

## Awaiting a decision, not defects

| # | Item | Status |
|---|------|--------|
| [08](08-spirit-bazaar-complexity.md) | Spirit Bazaar too complex | PENDING — owner |
| [09](09-daily-and-rapids-caps.md) | Daily and Rapids play caps | PENDING — owner |
| [10](10-premium-tile-trial.md) | Premium tile trial after a streak | PENDING — owner |
| [20](20-selection-feedback.md) | Selecting a tile is not visible enough | PENDING — discuss |

## Known, not blocking

| # | Item | Status |
|---|------|--------|
| [04](04-ads-never-show.md) | Ads never show at all | PENDING |
| [05](05-t02-checksum-forgeable.md) | Save checksum forgeable | ACCEPTED — will not fix |
| [11](11-cherry-blossom-legibility.md) | Cherry Blossom fails legibility | DEFERRED |
| [12](12-bamboo-art.md) | Bamboo 1 and 2 drawn as plain pills | DEFERRED |
| [13](13-tile-glyph-system-font.md) | Tile glyphs use the device font | PENDING |
| [14](14-cloud-save-branch-unmerged.md) | feat/cloud-save-pgs unmerged | PENDING |
| [15](15-keystore-password-plaintext.md) | Keystore password in plaintext | PENDING |
| [23](23-no-resume-after-close.md) | Closing the game loses the board in progress | PENDING |

## Resolved

| # | Item | Resolved | Commit |
|---|------|----------|--------|
| [03](03-rewarded-ads-grant-without-ad.md) | Rewarded ads pay out with no ad shown | 2026-09-21, extended 09-23 | `0397c28`, `c3a69c7` |
| [06](06-time-rapids-and-relics.md) | Time Rapids and the relic draft | 2026-09-23 | `405b5d6` |
| [07](07-scoring-system.md) | Scoring system not understood | 2026-09-23 | `405b5d6`, `8123c89`, `d397347` |
| [17](17-invisible-bonuses.md) | Invisible percentage bonuses | 2026-09-23 | `8123c89`, `d397347` |
| [18](18-onboarding.md) | First-run onboarding | 2026-09-23 | see git log |
| [19](19-stacked-pair-deadlock.md) | Same-type tiles dealt in one column | 2026-09-23 | see git log |
| [02](02-back-diagnostic-still-on.md) | BACK_DIAGNOSTIC still enabled | 2026-09-23 | `10b11e4` |
| [21](21-remove-chinese-from-menus.md) | Remove the Chinese text from menus | 2026-09-23 | `10b11e4` |
| [22](22-pause-icon.md) | Pause control is a hamburger | 2026-09-23 | `10b11e4` |
| [24](24-timer-bar-starts-half-full.md) | Time bar starts about half full | 2026-09-23 | `10b11e4` |
| [25](25-menu-wording-too-clever.md) | Menu names are too clever | 2026-09-23 | `10b11e4` |

---

## Fixed earlier on 2026-09-21, before this register existed

Recorded so the register is not mistaken for the whole history.

| Item | Commit |
|------|--------|
| HUD controls swallowing taps across the top of every board | `a98f85e` |
| Frost ice not cracking when its blockers cleared | `a98f85e` |
| Tile lights freed by clear_board, so bevel lighting never ran | `9d7306f` |
| Shuffle melting Frost ice | `9d7306f` |
| Settings → Back abandoning the board | `0c3c5f8` |
| Layout audit measuring a card mid-animation | `c991b01` |
| Daily Tide blessing paid for drawing a screen, not clearing the daily | `2c3799d` |
| Time Rapids clock frozen from stage 2 | `f9bed21` |
| Save integrity T03, T04, T08 | `49070b6` |
| Cinnabar seal occupying the close-button slot | `8d64c8b` |
| Boot splash re-encode, 816 KB | `adef556` |
