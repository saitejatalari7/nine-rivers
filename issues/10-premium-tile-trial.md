# 10 — Premium tile trial after a streak

**Blocks release: no. Proposed by the owner. Recommended as post-launch.**

Owner's proposal: after a few days of play, give a short trial of a premium tile
theme so the player can see what they are buying.

An earned taste reads as a reward; the same tiles behind a price read as a wall.
This is a well-established pattern in casual games and is the strongest of the
monetisation ideas raised so far.

## Why it is not a two-day change

Themes are currently binary — `is_theme_unlocked()` returns true or false, with
ownership recorded in the economy dictionary. A time-limited trial needs an
expiry concept that does not exist, which means:

- new save state, which must satisfy the signing rules from
  [05](05-t02-checksum-forgeable.md)
- a decision about what happens to an equipped theme when the trial lapses
  mid-session
- a clock the player cannot trivially move forward

Shipping new save state days before release is how progress gets corrupted.
Better as the first post-launch update, once real players exist.

Files: `scripts/autoload/monetization_manager.gd` (`is_theme_unlocked`,
`equip_theme`), `scripts/autoload/save_manager.gd`
