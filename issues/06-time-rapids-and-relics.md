# 06 — Time Rapids and the relic draft

**Status:** RESOLVED
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** 2026-09-23

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

---

## Resolution — 2026-09-23

Owner's decision: keep Time Rapids, remove the relics. "simple is better
according to me."

The relic system is gone entirely — `boon_pool.gd` deleted, the draft screen
removed, and all 17 relics with it. A cleared Rapids stage now shows a brief
"Stage N cleared" toast and deals the next board, with nothing to choose.

Removed with it: `active_relics`, `has_relic()`, `acquire_relic()`,
`relic_acquired`, `porcelain_guard_active`, the HUD relics bar, and every relic
branch in scoring, Flow, time, props and jade. Fourteen behaviours that used to
depend on which relics a player held now simply always apply.

Flow is the plain rule again: first match sets Flow 1, a matching suit advances
it by one, a misplay steps it down, repeated misplays reach zero. Lotus
Blessing, Spring Breeze and Porcelain Guard used to mask all of that, and
test_runner tested the masked version — its relic suites are replaced with one
that tests the plain rule.

`score_mult` stays at 1.0 now that Sharper Eye is gone, which also removes one
of the three invisible multipliers noted in [07](07-scoring-system.md).

Three things surfaced while doing it, none of them in the original report:

- Removing the Tide Surge branch orphaned an `else`, and main.gd stopped
  parsing. Every symbol in it went missing and four audits reported nonsense
  before the cause was found. Worth remembering that a GDScript parse failure
  presents as "function does not exist", not as a parse error, at the call site.
- `ui_nav_audit` starts a mode by calling `_start_run_mode()` directly, but the
  buttons that start a mode also close the menu. A stale modal was left up and
  read as the screen state for the whole flow. Calm hid this because its clear
  screen replaced the modal; Rapids, with no clear screen any more, exposed it.
- The splash tween called `_return_home()` on a delay with no check that the
  splash was still up, so a stale callback could haul the player back to the
  main menu. Guarded.

Not done here: the 3-runs-a-day cap is [09](09-daily-and-rapids-caps.md) and
still open.

test_runner 32/32, nav audit passes, bot 25/25, layout 0, rapids clock 9/9,
hardening 16/16, frost, hud_input, ads, daily all 0.
