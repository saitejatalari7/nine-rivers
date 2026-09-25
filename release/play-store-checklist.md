# Play Store release — Nine Rivers

Worked through in order. Tick as you go; most of these gate the next one.

Package name: `com.ninerivers.mahjong` — this is permanent. It cannot be
changed after the first upload, and it cannot be reused if the app is deleted.

---

## 0. Account

- [ ] Google Play Console account — one-off $25 (about ₹2,100)
- [ ] Identity verification (ID + address). Can take a few days, so start here
- [ ] Payments profile, for receiving money
- [ ] Bank account and tax details, needed before any paid item can sell

## 1. Create the app

- [ ] Play Console → **Create app**
- [ ] Name: Nine Rivers · Language: English (India) · Type: **Game** · **Free**
- [ ] "Free" is about the download price. In-app purchases are separate and
      still allowed. This choice is permanent

## 2. The forms Play requires before any release

These are the "App content" section. All of them block publishing.

- [ ] **Privacy policy** — a public URL. Needed even for an offline game
- [ ] **Data safety** — what leaves the device. Today: nothing. Answer it again
      if ads ship (see issues/04) because ads collect an advertising ID
- [ ] **Content rating** — a questionnaire. A mahjong game with no violence,
      no chat and no gambling rates lowest everywhere
- [ ] **Target audience** — choose 13+ or 18+. Anything under 13 pulls in
      Families policy and far stricter ad rules
- [ ] **Ads declaration** — "No" today. Must be updated if ads ship
- [ ] **Government apps / financial features / health** — all No

## 3. Store listing

- [ ] App icon, 512x512 PNG (three candidates rendered, one to pick)
- [ ] Feature graphic, 1024x500
- [ ] Phone screenshots, at least 2, 16:9 or 9:16
- [ ] Short description, 80 characters
- [ ] Full description, 4000 characters
- [ ] Category: Game → Puzzle or Board

## 4. In-app products

Create each with the ID EXACTLY as written — the app looks them up by these
strings, and a mismatch means the item silently cannot be bought.

| Product ID | Price | Type |
|---|---|---|
| `no_ads` | Rs199 | One-time |
| `pearls_small` | Rs49 | **Consumable** |
| `pearls_medium` | Rs149 | **Consumable** |
| `pearls_large` | Rs399 | **Consumable** |
| `theme_imperial_gold` | Rs99 | One-time |
| `theme_obsidian_ink` | Rs99 | One-time |
| `theme_cherry_blossom` | Rs99 | One-time |
| `bg_misty_spring` | Rs49 | One-time |
| `bg_sunset_haven` | Rs49 | One-time |

- [ ] All nine created and **Activated**
- [ ] `theme_indigo` NOT created — it is earned at stage 50, never sold

Consumable means it can be bought again (pearls). One-time means it is owned
forever (themes, no ads). Getting this wrong on the pearl packs means a player
can buy them once and never again.

## 5. First upload

- [ ] Issue 15 done, so the build is signed from outside the project
- [ ] Bump `version/code` in `export_presets.cfg` — currently 2, and every
      upload needs a higher number than the last
- [ ] `tools/build_android.sh aab`
- [ ] Upload to **Internal testing**, not production
- [ ] Add yourself as a tester and install through the Play link — billing only
      works for a build Play itself served

## 6. Test the purchases (issue 16)

This is the last release blocker, and it cannot be done from a PC.

- [ ] Add your account under **License testing** so purchases are free
- [ ] Buy one pearl pack — balance rises, and it can be bought again
- [ ] Buy one theme — it unlocks, and cannot be bought twice
- [ ] Buy `no_ads` — ads stop, 500 pearls granted
- [ ] Restore Purchases on a fresh install returns the one-time items
- [ ] Kill the app mid-purchase and reopen — no double grant, no lost money

## 7. Release

- [ ] Internal testing first, then closed, then production
- [ ] First production review takes days, sometimes longer for a new account
- [ ] Rollout at a small percentage, not 100%
