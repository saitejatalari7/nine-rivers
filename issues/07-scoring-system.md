# 07 — Nobody understands the scoring system

**Blocks release: no. Design decision, owner still deciding.**

Owner: "noboday understood the storing system."

`register_match()` at `scripts/autoload/game_manager.gd:186` computes:

    base (100, or 250 for a triple)
      x Flow multiplier (1-6)
      x permanent score_mult
      x Rush (2x in timed modes)
      x Ogon koi (1.1x if that koi is unlocked)
      x mastery (1 + 0.05 per mastery level)
      + 500 for a glass tile

Six multipliers. Three of them — permanent, Ogon, mastery — are invisible
during play, so the same match can score differently with no visible reason.
Jade Kiln also triples the base for banded triples.

There is no in-game explanation anywhere. The tutorial does not cover it.

## Options

- **Explain it.** A breakdown on the clear screen, using the existing
  `_add_sheet_row` helper. Flow stays the only live multiplier during play.
- **Simplify it.** Fold the invisible multipliers into something visible, or
  drop them. Changes balance across 350 levels.
- **Leave it.** Valid for this release; the score is decoration for most players.

Files: `scripts/autoload/game_manager.gd:186-231`
