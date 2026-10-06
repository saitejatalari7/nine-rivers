# Closed test log - Nine Rivers: Mahjong

Kept during the closed test so the production-access form can be answered with
specifics: what testers reported, what changed, and which build changed it.

## Setup

- **Track:** Closed testing - Alpha, 178 countries.
- **Testers:** Testers Community (paid service, 25 testers, Google Group
  `testers-community@googlegroups.com`), plus the developer on internal testing.
- **Feedback channels:** the Play testing feedback channel
  (saiteja.talari@gmail.com), the service's tester reports, and direct
  testing by the developer and a second tester (Nikki) on their own phones.
- **Opt-in reached 12:** 2026-10-04. Fourteen days ends about 2026-10-18.

## Builds

### Build 10 (1.0.1) - start of the closed test, 2026-10-03

Bigger tiles (board fills the screen, about 10% larger); a fair clock per
Timed Mode stage sized to the board, with Fog and Rush compensated; blocked
Imperial Gold tiles dulled with grey symbols after a tester kept tapping them;
soft gold halo for selection on the gold set; loading screen; lower heat (frame
cap, cached audio); Shop-only rewarded video; recorded ambience per background.

### Build 11 (1.0.1) - 2026-10-05

- **Tiles 12% bigger again.** Every board capped at 8 columns (median tile
  5.0 -> 5.6 mm, smallest 4.8 -> 5.3 mm). Reason: tile size was the most
  repeated comment, from the developer and from older players.
- **Cloud save.** Google Play Games Services set up (saved games); a Cloud
  Save switch in Settings and a one-time offer after the tutorial, so progress
  survives a new phone or a reinstall.
- **Daily limits enforced.** Timed Mode's three runs and the Daily Puzzle could
  be replayed without limit from the pause menu's Restart Board. Restart now
  counts as a new attempt; the Daily Puzzle allows three tries a day.

### Build 12 (1.0.1) - 2026-10-06

- **A Timed Mode game is three stages.** It rolled on to stage 4, 5... until
  the clock ran out; clearing the third stage now wins the game. Menu wording
  is "3 games a day" for both Timed Mode and the Daily Puzzle.
- **Worldwide Daily Puzzle leaderboard** on Google Play Games. Only the daily
  is ranked, because everyone plays the same board that day.
- **Tiles never under the timer.** The board is framed between the top panel,
  the timer strip and the bottom buttons, measured on screen. The bottom
  buttons are one slim row at the bottom edge, giving the space to the tiles.

## Tester feedback received

| Date | From | Feedback | Action | Build |
|---|---|---|---|---|
| 2026-09-29 | Nikki | Blocked gold tiles look tappable in runs | Dulled, grey symbols | 10 |
| 2026-09-29 | Developer | Timed Mode stages 2-3 impossible | Per-stage clock | 10 |
| 2026-09-28 | Developer | Phone gets hot after 10 minutes | Frame cap, audio caching | 10 |
| 2026-10-05 | Developer | Tiles still small on phone | 8-column boards | 11 |
| 2026-10-05 | Developer | Played more than three daily games | Caps enforced | 11 |
| 2026-10-06 | Developer | Timed Mode reached stage 4 | Game ends after stage 3 | 12 |
| 2026-10-06 | Developer | Timer bar over the top tiles; bottom buttons bulky | Board framed below timer; slim bar | 12 |

## Pre-launch report

(to be filled from Play Console > Test and release > Pre-launch report)
