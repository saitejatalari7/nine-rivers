# Production access application - answers

Drafted from `closed-test-log.md`. Paste each answer into the matching field of
Play Console > Dashboard > Apply for production. Edit anything that does not
match what you saw.

## Part 1 - About your closed test

**How did you recruit users for your closed test?**

Through a tester community group (a Google Group of Android testers who try
new apps), plus friends who installed the game from the internal and closed
testing links. Twelve or more testers stayed opted in for the full 14 days.

**How easy was it to recruit testers?**

Neither easy nor difficult (choose the option that matches your experience).

**Describe the engagement you received from testers during your closed test.**

Testers played the campaign, the Daily Puzzle and Timed Mode on a range of
phones (Samsung, Vivo, iQOO and others, Android 14 to 16). A friend tested
the later builds on their own phone from a fresh install, including the
tutorial.
Android vitals reported real-device crashes from tester sessions, which led to
two crash fixes. Over the test we shipped five updates (builds 10 to 14).

**Provide a summary of the feedback you received from testers and how you collected it.**

Feedback came through direct messages from testers, our own play on several
phones, and Android vitals in Play Console. The main points were: tiles were
too small on phones; blocked gold tiles looked tappable; Timed Mode was too
hard in later stages; the daily limits could be played around; the game
crashed during the tutorial on some phones; there was a slight stutter when
tiles cleared; and Timed Mode and the Daily Puzzle repeated the same board
shapes.

## Part 2 - About your app or game

**Who is the intended audience of your app or game?**

Adults and teens (13+) who enjoy calm puzzle games, especially mahjong
solitaire players. The game is relaxing rather than competitive, with an
optional Daily Puzzle leaderboard for players who like a daily challenge.

**Describe how your app or game provides value to users.**

Nine Rivers is a calm mahjong solitaire game: 500 hand-made stages across ten
chapters, a Daily Puzzle that everyone plays on the same board, and a short
Timed Mode. Every board is generated to be solvable, so players are never stuck
on an impossible deal. It has a soothing pond setting with recorded nature
sounds, cloud save through Google Play Games, and works fully offline. Ads
never appear during play; videos are optional and only shown when the player
asks.

**How many installs do you expect your app or game to have in its first year?**

Choose the range you honestly expect (for a first game with no marketing,
"1,000 - 10,000" is a reasonable choice).

## Part 3 - Your production readiness

**What changes did you make to your app based on what you learned during your closed test?**

- Made tiles larger (boards capped at 8 columns) after testers said they
  were too small.
- Greyed out blocked gold tiles so they no longer look tappable.
- Gave each Timed Mode stage a fair clock sized to its board, and limited a
  Timed game to three stages.
- Enforced the three-games-a-day limits that could be bypassed with Restart.
- Fixed a crash on some Android 14-16 phones (an audio bug found through
  Android vitals) and a crash when closing the app.
- Removed a stutter when tiles clear and when a level starts.
- Added many more board shapes (500 levels in all) so Timed Mode and the
  Daily Puzzle no longer repeat the same boards.
- Improved the tutorial ending and the loading screen.

**How did you decide that your app or game is ready for production?**

Both crash types reported in Android vitals were fixed in build 13 and the
fix was confirmed on the affected tester's phone; no new crash types have
been reported since. Every one of
the 500 levels is checked by automated tests to deal a solvable board and fit
the screen, and the app passes our full test suite. Testers completed the
tutorial, campaign, Daily Puzzle and Timed Mode on several devices, and the
issues they raised were fixed in the updates listed above.
