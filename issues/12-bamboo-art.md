# 12 — Bamboo 1 and 2 are drawn as plain pills

**Status:** DEFERRED — owner chose to leave
**Raised:** 2026-09-21
**Last reviewed:** 2026-09-21
**Resolved:** —

**Blocks release: no — known art gap.**

Measured by `scenes/glyph_metrics.tscn`: bamboo rank 1 spans 31.3% of the tile
width and rank 2 spans 28.1%, against a 63.5% mean across all faces. They are
the narrowest art in the game.

They are also the least convincing: a rounded capsule with a line across it is
not a bamboo stalk, and rank 1 on a real mahjong tile is a bird.

## Why they are narrow

Bamboo shares the dot position table, so a low rank is inherently a narrow
vertical column — 2-bamboo is two stalks stacked, which is authentic. Widening
the pills is the only lever the shared arrangement leaves, and that was already
done: `BAM_SMALL_SPARSE` is wider than `BAM_SMALL` for ranks 1-3.

Beyond that this needs drawn art rather than geometry, which is the same pass as
baking the tile faces in Blender.

Files: `scripts/ui/tile_view.gd` (`draw_canonical_bamboos`, `BAM_*`)
