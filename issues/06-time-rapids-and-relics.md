# 06 — Time Rapids and the relic draft

**Blocks release: no. Design decision, undecided.**

Owner's words after playing: "nobody knows about that pop up and its purpose.
its too much, no one wants that", and "why so complex. this is to be a simple
mind relaxing game."

## What it is

Time Rapids is an endless timed run. After every cleared board an unskippable
screen offers 3 relics drawn from 17; one must be taken and it lasts for the
run. The only other button is Abandon Run. Standard roguelite structure.

The 17 relics group as: more time (Deep Breath, Long Draw, Steady Hand), more
score (Sharper Eye, Jade Kiln), Flow manipulation (Lotus Blessing, Spring
Breeze, River Dragon, Porcelain Guard, Tide Caller), and more props (Two
Shuffles, Three Hints, Golden Net, Dragon Bell, Tide Surge, Phoenix Feather,
Jade Whisper).

## Why it is not landing

- Unskippable, and nothing explains that relics are permanent for the run or
  that they stack.
- The tutorial covers tiles, matching and Flow, then stops.
- Wording leans on unexplained systems: "Flow ×7", "Banded triples",
  "River Jade for the Koi Sanctuary".
- A roguelite build system asks for exactly the engagement a relaxing game is
  trying not to demand.

Three clock bugs were fixed in `f9bed21` — the clock froze from stage 2 and
matches added time with the clock stopped — so several relics were modifying a
timer that was not running.

## Options

- **Cut Rapids and the relics together.** Fastest, and leaves Calm plus Daily,
  which is a coherent game.
- **Cap Rapids at 3 runs a day.** Owner's own suggestion. At three short runs
  there is nothing for a build system to build across, so relics still go.
- **Leave it.** Costs nothing now; the confusion persists.

Rapids saves no best score and no best stage, and Calm ignores the timer
entirely, so changes here cannot touch the 350-level campaign or existing saves.

Report: `audit/time_rapids_report.html`
Files: `scripts/core/boon_pool.gd`, `scripts/ui/modal_controller.gd` (boon_draft),
`scripts/autoload/game_manager.gd`, `scripts/main.gd`
