extends Node

## Measures how much of a tile face the suit artwork actually covers.
##
## The complaint this answers is "the symbols are tiny": competitor tiles fill
## roughly 70% of the face width, and eyeballing our own art was not going to
## settle whether we do. Each tile is rendered twice - once normally, once with
## TileView.debug_skip_artwork - and the two images are differenced, so what is
## measured is the ink alone rather than the ink plus whatever the body texture
## and the bevel happen to contribute.
##
## Rendered at RENDER_SCALE so the bounding box is not quantised to the 64x84
## shipping grid. Coverage is the share of face PIXELS the ink touches, which is
## a stroke-weight measure; span is the bounding box, which is a size measure.
## A glyph can score a wide span and thin coverage - that is exactly the
## hairline-serif failure mode - so both are printed.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")

const RENDER_SCALE: int = 4
const DIFF_THRESHOLD: float = 0.06

const PROBES: Array[Dictionary] = [
	{"suit": "char", "rank": 1}, {"suit": "char", "rank": 5}, {"suit": "char", "rank": 9},
	{"suit": "dot", "rank": 1}, {"suit": "dot", "rank": 2}, {"suit": "dot", "rank": 3},
	{"suit": "dot", "rank": 5}, {"suit": "dot", "rank": 9},
	{"suit": "bam", "rank": 1}, {"suit": "bam", "rank": 2}, {"suit": "bam", "rank": 6},
	{"suit": "wind", "rank": 1}, {"suit": "wind", "rank": 3},
	{"suit": "dragon", "rank": 1}, {"suit": "dragon", "rank": 2}, {"suit": "dragon", "rank": 3},
	{"suit": "flower", "rank": 1}, {"suit": "season", "rank": 1},
]

const THEME: String = "classic_jade"

var _w_sum: float = 0.0
var _h_sum: float = 0.0
var _c_sum: float = 0.0
var _n: int = 0
var _min_w: float = 999.0
var _min_label: String = ""


func _ready() -> void:
	await get_tree().process_frame
	print("")
	print("glyph coverage on %s, tile %dx%d" % [THEME, TileView.TILE_W, TileView.TILE_H])
	print("suit    rank   width%   height%   ink%")
	for probe in PROBES:
		await _measure(probe)
	print("")
	print("mean    width %.1f%%   height %.1f%%   ink %.1f%%" % [
		_w_sum / _n, _h_sum / _n, _c_sum / _n])
	print("narrowest: %s at %.1f%% width" % [_min_label, _min_w])
	get_tree().quit(0)


func _measure(probe: Dictionary) -> void:
	var with_art: Image = await _render(probe, false)
	var without: Image = await _render(probe, true)

	var w: int = with_art.get_width()
	var h: int = with_art.get_height()
	var min_x: int = w
	var max_x: int = -1
	var min_y: int = h
	var max_y: int = -1
	var ink: int = 0
	for y in h:
		for x in w:
			var a: Color = with_art.get_pixel(x, y)
			var b: Color = without.get_pixel(x, y)
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if d > DIFF_THRESHOLD:
				ink += 1
				min_x = mini(min_x, x)
				max_x = maxi(max_x, x)
				min_y = mini(min_y, y)
				max_y = maxi(max_y, y)
	if max_x < 0:
		print("%-7s %-5d   (no ink detected)" % [probe["suit"], probe["rank"]])
		return

	var wp: float = 100.0 * float(max_x - min_x + 1) / float(w)
	var hp: float = 100.0 * float(max_y - min_y + 1) / float(h)
	var cp: float = 100.0 * float(ink) / float(w * h)
	_w_sum += wp
	_h_sum += hp
	_c_sum += cp
	_n += 1
	if wp < _min_w:
		_min_w = wp
		_min_label = "%s %d" % [probe["suit"], probe["rank"]]
	print("%-7s %-5d %7.1f %9.1f %6.1f" % [probe["suit"], probe["rank"], wp, hp, cp])


func _render(probe: Dictionary, skip_art: bool) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(int(TileView.TILE_W) * RENDER_SCALE, int(TileView.TILE_H) * RENDER_SCALE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var holder := Control.new()
	holder.scale = Vector2(RENDER_SCALE, RENDER_SCALE)
	vp.add_child(holder)

	TileView.debug_skip_artwork = skip_art
	var view = TileViewScene.instantiate()
	holder.add_child(view)
	var t := RiverTile.new()
	t.suit = probe["suit"]
	t.rank = probe["rank"]
	view.theme_override = THEME
	view.setup(t, true)
	if view.has_method("update_theme_style"):
		view.update_theme_style()

	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	vp.queue_free()
	TileView.debug_skip_artwork = false
	return img
