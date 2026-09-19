extends Node

## Renders every tile face in every theme to one PNG, so the artwork can be
## judged by eye instead of only by the contrast numbers.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]
const SCALE: int = 3
const PAD: int = 6
const OUT: String = "res://sheet.png"

var _rows: Array[Dictionary] = []


func _ready() -> void:
	await get_tree().process_frame
	for r in range(1, 10):
		_rows.append({"suit": "char", "rank": r})
	for r in range(1, 10):
		_rows.append({"suit": "dot", "rank": r})
	for r in range(1, 10):
		_rows.append({"suit": "bam", "rank": r})
	for r in range(1, 5):
		_rows.append({"suit": "wind", "rank": r})
	for r in range(1, 4):
		_rows.append({"suit": "dragon", "rank": r})
	_rows.append({"suit": "flower", "rank": 1})
	_rows.append({"suit": "season", "rank": 1})

	var tw: int = int(TileView.TILE_W) * SCALE
	var th: int = int(TileView.TILE_H) * SCALE
	var cols: int = _rows.size()
	var sheet := Image.create(
		cols * (tw + PAD) + PAD,
		THEMES.size() * 2 * (th + PAD) + PAD,
		false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.08, 0.09, 0.10, 1.0))

	var row: int = 0
	for theme in THEMES:
		for free in [true, false]:
			for i in _rows.size():
				var img: Image = await _render(theme, free, _rows[i], tw, th)
				img.convert(Image.FORMAT_RGBA8)
				sheet.blit_rect(img, Rect2i(0, 0, tw, th),
					Vector2i(PAD + i * (tw + PAD), PAD + row * (th + PAD)))
			row += 1
		print("rendered %s" % theme)

	sheet.save_png(OUT)
	print("wrote %s  (%dx%d)" % [OUT, sheet.get_width(), sheet.get_height()])
	get_tree().quit(0)


func _render(theme: String, free: bool, probe: Dictionary, tw: int, th: int) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(tw, th)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	TileLighting.attach(vp)
	var holder := Control.new()
	holder.scale = Vector2(SCALE, SCALE)
	vp.add_child(holder)
	var view = TileViewScene.instantiate()
	holder.add_child(view)
	var t := RiverTile.new()
	t.suit = probe["suit"]
	t.rank = probe["rank"]
	view.theme_override = theme
	view.setup(t, free)
	if view.has_method("update_theme_style"):
		view.update_theme_style()
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	return img
