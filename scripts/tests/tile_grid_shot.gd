extends Node

## One image per theme: every face, wrapped into a grid rather than a single
## 7000px strip, so it can actually be looked at.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
	"theme_cherry_blossom", "theme_indigo",
]
const SCALE: int = 3
const PAD: int = 8
const COLS: int = 10
const BG := Color("#0d2a21")

var _faces: Array[Dictionary] = []

func _ready() -> void:
	await get_tree().process_frame
	for r in range(1, 10):
		_faces.append({"suit": "char", "rank": r})
	for r in range(1, 10):
		_faces.append({"suit": "dot", "rank": r})
	for r in range(1, 10):
		_faces.append({"suit": "bam", "rank": r})
	for r in range(1, 5):
		_faces.append({"suit": "wind", "rank": r})
	for r in range(1, 4):
		_faces.append({"suit": "dragon", "rank": r})
	for r in range(1, 5):
		_faces.append({"suit": "flower", "rank": r})
	for r in range(1, 5):
		_faces.append({"suit": "season", "rank": r})

	var tw: int = int(TileView.TILE_W) * SCALE
	var th: int = int(TileView.TILE_H) * SCALE
	var rows: int = int(ceil(float(_faces.size()) / float(COLS)))

	for theme in THEMES:
		var sheet := Image.create(COLS * (tw + PAD) + PAD, rows * (th + PAD) + PAD,
			false, Image.FORMAT_RGBA8)
		sheet.fill(BG)
		for i in range(_faces.size()):
			var f: Dictionary = _faces[i]
			var holder := Node2D.new()
			holder.scale = Vector2(SCALE, SCALE)
			add_child(holder)
			var v = TileViewScene.instantiate()
			holder.add_child(v)
			v.theme_override = theme
			v.setup(RiverTile.new(0, 0, 0, String(f["suit"]), int(f["rank"])), true)
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var shot: Image = get_viewport().get_texture().get_image()
			var src := Rect2i(0, 0, tw, th)
			var dst := Vector2i(PAD + (i % COLS) * (tw + PAD), PAD + (i / COLS) * (th + PAD))
			sheet.blit_rect(shot, src, dst)
			holder.queue_free()
		var p := "res://assets/branding/screens/real_game/tiles_%s.png" % theme
		sheet.save_png(ProjectSettings.globalize_path(p))
		print("  " + p)
	get_tree().quit(0)
