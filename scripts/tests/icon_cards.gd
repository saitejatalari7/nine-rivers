extends Node2D

## Three app-icon options, drawn from the game's own tiles. No Chinese
## characters: the current icon carries 九川, and the tile faces that are pure
## geometry - dots, bamboo, the sparrow - say "mahjong" without a word in them.
##
## Nine dots also says nine without spelling it.
##
## Run: godot --path . --rendering-driver opengl3 res://scenes/icon_cards.tscn

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")

## Drawn in the project's 1080-wide design space and resampled down. The window
## renders smaller than the design resolution, so cropping 512 raw pixels took
## a corner of the artwork rather than the artwork.
const SIZE: int = 900
const OUT: int = 512
const POND_DEEP := Color("#06251c")
const POND_MID := Color("#0d4a35")
const GOLD := Color(0.96, 0.78, 0.35)

var _ripples: Array = []


func _ready() -> void:
	await get_tree().process_frame
	await _variant("icon_a_bird", [["bam", 1]], [0.0], 8.0)
	await _variant("icon_b_fan", [["dot", 9], ["bam", 1], ["dot", 1]], [-14.0, 0.0, 14.0], 5.2)
	await _variant("icon_c_nine", [["dot", 9]], [-8.0], 8.0)
	get_tree().quit(0)


func _variant(name: String, faces: Array, angles: Array, scale: float) -> void:
	for c in get_children():
		if c is Control:
			c.queue_free()
	await get_tree().process_frame

	var tw: float = 64.0 * scale
	var th: float = 84.0 * scale
	var spread: float = tw * 0.62
	for i in range(faces.size()):
		var holder := Control.new()
		holder.position = Vector2(
			SIZE * 0.5 - tw * 0.5 + (float(i) - (faces.size() - 1) * 0.5) * spread,
			SIZE * 0.5 - th * 0.5)
		holder.rotation = deg_to_rad(float(angles[i]))
		holder.pivot_offset = Vector2(tw * 0.5, th * 0.5)
		add_child(holder)
		var v = TileViewScene.instantiate()
		holder.add_child(v)
		v.setup(RiverTile.new(0, 0, 0, String(faces[i][0]), int(faces[i][1])), true)
		v.pivot_offset = Vector2.ZERO
		v.scale = Vector2(scale, scale)

	queue_redraw()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var f: float = float(img.get_width()) / 1080.0
	var side: int = int(round(SIZE * f))
	img = img.get_region(Rect2i(0, 0, side, side))
	img.resize(OUT, OUT, Image.INTERPOLATE_LANCZOS)
	var p := "res://assets/branding/screens/real_game/%s.png" % name
	img.save_png(ProjectSettings.globalize_path(p))
	print("  " + p)


## Pond, behind the tiles: a deep green field with the gold ripple the game
## draws whenever a tile is matched.
func _draw() -> void:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	draw_rect(Rect2(0, 0, SIZE, SIZE), POND_DEEP)
	for i in range(26):
		var t: float = float(i) / 25.0
		draw_circle(c + Vector2(0, SIZE * 0.06), SIZE * (0.62 - t * 0.5),
			POND_MID.lerp(POND_DEEP, t) * Color(1, 1, 1, 0.5), true)
	for r in [0.30, 0.40, 0.49]:
		draw_arc(c + Vector2(SIZE * 0.04, SIZE * 0.10), SIZE * r, 0.0, TAU, 96,
			Color(GOLD.r, GOLD.g, GOLD.b, 0.22), 3.0, true)
