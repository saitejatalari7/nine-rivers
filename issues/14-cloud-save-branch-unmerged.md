# 14 — feat/cloud-save-pgs is unmerged

**Status:** PENDING — not scheduled
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-21
**Resolved:** —

**Blocks release: no.**

Two commits on `feat/cloud-save-pgs` add Play Games Services cloud save for
progress and pearls, wire its UI, fix save migration and update the privacy
policy.

Measured from the merge base: **73 files changed, 2,864 insertions, 30
deletions.** It adds work.

An earlier report claimed merging it would revert ~12,600 lines. That was
measured in the wrong direction — `main` has moved a long way since the merge
base at `69fabcb` (2026-09-15), so a reversed diff shows large deletions. It
would need a merge, not a revert.

Worth checking before merging: it also fixes T08 save migration, which was
independently fixed on main in `49070b6`, so that part will conflict.

Also note that PGS is Android-only and would need replacing for iOS — see
`audit/ios_testing_report.html`.
