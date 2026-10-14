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
- **Daily Puzzle is a stopwatch**, no longer a second countdown mode, with a
  **worldwide leaderboard** on Google Play Games ranked by fastest finish.
  Only the daily is ranked, because everyone plays the same board that day.
- **Tiles never under the timer.** The board is framed between the top panel,
  the timer strip and the bottom buttons, measured on screen. The bottom
  buttons are one slim row at the bottom edge; the top bar is slimmer and
  shows stage and score only.
- **Leaving the app pauses the game**, so a call cannot cost clock time.
- **Steady loading screen.** The engine splash and the loading screen now
  frame the art the same way (no jump), and the loading bar can be seen.
- **Optional video for one more shuffle** when out of shuffles (not in the
  Daily Puzzle), within the existing four-a-day video limit.

### Build 13 (1.0.1) - 2026-10-11

Build 12 never reached the closed testers: Android vitals showed native
crashes on builds 10 and 11, and a tester (Nikki) crashed during onboarding on
a fresh install. Symbolised with Godot 4.6.2's published release symbols:

- **Crash during play (54 events, 6 users, Android 14-16 on Vivo, iQOO and
  Samsung).** The generated ambient loop read one sample past its buffer at
  each loop point; on these phones that memory is guarded. Fixed, with a test
  that fails on the old value.
- **Crash on exit (2 issues).** An ad-consent callback outlived its script at
  shutdown. Callbacks handed to the ad plugin are now plain methods and are
  released once ads start.
- Confirmed fixed on the tester's phone via internal testing before the
  closed-track release.

### Build 14 (1.0.14) - 2026-10-14

From this build every upload has its own version name, so a tester's Play
Store page shows which build they have (builds 10-13 all read 1.0.1).

- **Smoother play.** A tester reported, and the developer saw, a stuck
  feeling when tiles clear. Measured: after every match every tile on the
  board redrew (a 35 ms frame on a desktop), and the music built new notes
  on the main thread (166 ms each). Both fixed; the worst frame after a
  match went from 23-39 ms to 17-21 ms (16.7 ms is a smooth 60 fps).
  Level starts no longer stall: the next level is dealt in the background.
- **500 levels** (from 350) with **51 new board shapes** - nature, zodiac,
  geometric and island shapes drawn for the 8-column board, every one
  proven clearable.
- **Koi Rescue** every fifth level from 10: free three koi pairs to win the
  level at once; the last sleeps until half the board is cleared.
  **Quick Combo** on every board for fast matches.
- **More variety:** Timed Mode deals new shapes every game (it used to repeat
  the same three); the Daily Puzzle never repeats a shape within 42 days.
- Sharper tile characters when pinch-zoomed; long messages wrap on screen.
- Readable crash reports: native debug symbols uploaded with the build.
- Play's two advisories (edge-to-edge APIs, orientation) come from the engine's
  immersive mode and the portrait-only design; noted, not blocking.

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
| 2026-10-07 | Developer | Top bar busy (tiles, sets) | Stage and score only, slimmer | 12 |
| 2026-10-10 | Developer | Daily and Timed both count down | Daily is a stopwatch, ranked by time | 12 |
| 2026-10-10 | Developer | Loading screen jumps; bar invisible | Matched framing; visible bar | 12 |
| 2026-10-11 | Nikki + Android vitals | Crash in onboarding / during play | Audio loop bound fixed | 13 |
| 2026-10-11 | Android vitals | Crash on closing the app | Ad callbacks released | 13 |
| 2026-10-12 | Developer | Wanted rewards from clearing, not power buttons | Koi Rescue, Quick Combo | 14 |
| 2026-10-13 | Developer | Same layouts in Timed and Daily | Random Timed shapes; Daily 42-day cycle | 14 |
| 2026-10-13 | Developer | Wants 500 levels | 51 new shapes, 500 levels | 14 |
| 2026-10-14 | Tester + developer | Stutter when tiles clear | Redraw and audio fixes | 14 |

## Pre-launch report

(to be filled from Play Console > Test and release > Pre-launch report)
