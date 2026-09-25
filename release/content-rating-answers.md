# IARC content rating questionnaire - answer sheet

For Nine Rivers, `com.ninerivers.mahjong`.

The questionnaire is filled in once in the Play Console and issues ratings for every board at
once (IARC, ESRB, PEGI, USK, ClassInd, ACB and, relevant here, the Indian market through the
generic IARC rating). Answer it from the shipped build, not from intent: a wrong answer here is
grounds for removal, and the form is re-answerable at any time if the game changes.

---

## Category selection

**Choose: Game.** Not "Reference, News or Educational", not "Utility, Productivity,
Communication or Other". Nine Rivers is a game, and picking a non-game category to get a
shorter form is a misrepresentation.

**Email for the rating certificate:** `<CONTACT EMAIL>`

---

## Violence

| Question | Answer | Why |
|---|---|---|
| Does the app contain violence of any kind? | **No** | Tiles are matched and removed. Nothing is struck, damaged or destroyed, and there are no characters to harm. |
| Realistic or cartoon violence against humans or animals? | **No** | The only living things depicted are koi swimming in a pond. They cannot be interacted with, harmed or removed. |
| Blood, gore, mutilation, dismemberment? | **No** | None present. |
| Depictions of death, injury or torture? | **No** | None present. |
| Violence against vulnerable or defenceless characters? | **No** | No characters at all. |
| Weapons? | **No** | None depicted. |

---

## Sexuality and nudity

| Question | Answer | Why |
|---|---|---|
| Nudity, partial nudity or revealing clothing? | **No** | No human figures are depicted anywhere in the game. |
| Sexual behaviour, references or innuendo? | **No** | None. |
| Sexual violence? | **No** | None. |
| Erotic or sexual imagery in the artwork or store assets? | **No** | Artwork is tiles, water, koi and plants. |

---

## Language

| Question | Answer | Why |
|---|---|---|
| Profanity or crude humour? | **No** | The complete UI text is menus, stage names, settings labels and short results messages. There is no dialogue, no user text and no voice acting. |
| Discriminatory language or hate speech? | **No** | None. |

---

## Controlled substances

| Question | Answer | Why |
|---|---|---|
| Use or reference to alcohol, tobacco or drugs? | **No** | None appear or are mentioned. |
| Illegal drug use? | **No** | None. |

---

## Gambling and simulated gambling

This is the section most likely to be answered wrongly for a mahjong game, so the reasoning is
spelled out.

| Question | Answer | Why |
|---|---|---|
| Does the app allow players to gamble with real money or real-world value? | **No** | There is no wagering mechanic of any kind and nothing of value can be won. |
| Does the app simulate gambling, or teach or depict gambling? | **No** | See the note below. |
| Casino games (slots, roulette, poker, bingo, card games played for stakes)? | **No** | Nine Rivers is mahjong *solitaire*: a single-player tile-matching puzzle. It is not the four-player betting game, has no opponents, no hands, no betting and no pot. |
| Is there a loot box, gacha or other randomised reward purchase? | **No** | Every purchase has a fixed, stated outcome: a named tile set, a named background, ad removal, or an exact number of Spirit Pearls. Nothing paid for is randomised. |
| Do players bet or wager in-game currency? | **No** | See the note below. |
| Can in-game currency be cashed out, traded or transferred? | **No** | Spirit Pearls are spendable only inside the game, only on cosmetics, and cannot be sold, gifted, transferred or converted back to money. |

### Note on Spirit Pearls - the point to be clear about

Spirit Pearls are **bought or earned, then spent**. They are never wagered and never won.

- Earned by clearing stages, at a fixed 20 pearls per star. Not a random drop.
- Bought in fixed quantities for a fixed price (500, 2,500 or 7,500 pearls).
- Spent at a fixed, displayed price on a named cosmetic item.

There is no mechanic anywhere in the game where a player stakes pearls on an uncertain outcome
and gets more or fewer back. No wheel, no chest, no draw, no doubling, no risk-it-all round.
That absence is what makes the simulated-gambling answers No, and it is worth stating plainly
if a rating body queries the mahjong name.

The timed mode is capped at three runs a day and the daily puzzle at one. Neither is a stake:
running out means waiting until tomorrow, not losing anything.

---

## Miscellaneous

| Question | Answer | Why |
|---|---|---|
| Does the app contain in-app purchases? | **Yes** | Nine items, Rs 49 to Rs 399, all optional and all cosmetic apart from the Remove Ads upgrade. This must be declared; leaving it off is a rating violation even though the purchases are harmless. |
| Does the app share the user's location with other users? | **No** | Location is never read. |
| Does the app allow users to interact or exchange content with each other? | **No** | The game is entirely single-player. The daily puzzle is the same board for everyone, but there is no chat, no messaging, no user content, no friends list and no leaderboard in this build. |
| Does the app allow users to share their personal information with third parties? | **No** | There is nothing to share and no field to enter it in. |
| Does the app contain user-generated content? | **No** | Nothing is authored by players. |
| Does the app display advertising? | **No, for this release.** See below. | No ad SDK is bundled in the submitted build. |
| Is the app a web browser or search engine? | **No** | |
| Does the app contain fear or horror themes? | **No** | The whole design intent is the opposite. |
| Does the app contain crude humour or bodily functions? | **No** | |
| Digital purchases of physical goods? | **No** | |

---

## Expected outcome

All content answers being No, with in-app purchases declared, the questionnaire should return
the lowest rating each board offers - ESRB Everyone, PEGI 3, IARC 3+ - with an "In-app
purchases" interactive-element notice attached. That notice is normal and appears on the store
listing as "In-app purchases".

Note the mismatch with the privacy policy's 13+ statement: that is a data and audience
decision, not a content rating. A 3+ content rating and a stated target audience of 13 and over
are consistent, and the Play Console target-audience question is where 13+ is recorded.

---

## What to re-answer when ads ship

The questionnaire must be re-submitted, in the same release as the AdMob SDK:

1. **"Does the app display advertising?" becomes Yes.**
2. Follow-up questions will ask whether advertising is targeted or personalised, and whether ad
   content is moderated. With AdMob and Google's default ad content filters, the answers are
   that advertising is served by a third-party network with Google's content rating filters
   applied.
3. Set the AdMob ad content rating filter to match the game's rating (G) so that adult or
   gambling ad creatives cannot be served into a 3+ rated game. Leaving the filter open is how
   a family-friendly puzzle game ends up showing real-money gambling ads, which would
   contradict every answer in the gambling section above.

Re-submitting the questionnaire may change the rating. Do it before the release rolls out, not
after.
