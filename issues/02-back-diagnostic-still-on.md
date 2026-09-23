# 02 — BACK_DIAGNOSTIC still enabled

**Status:** PENDING — blocks release
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-23
**Resolved:** —

**Blocks release: yes.** Deliberate, temporary.

`const BACK_DIAGNOSTIC: bool = true` at `scripts/main.gd:176` draws a debug
banner over the HUD and every modal on each back press, and prints to stdout.

It exists to diagnose [01](01-back-button.md) and must be `false` before any
store build. It is a one-line change; the risk is only that it is forgotten.

Worth considering: a check that fails the build, or an export-time assert, so
this cannot ship on by accident.

Files: `scripts/main.gd:176`
