extends Node

## Can one tile be told from the tile beside it, and from the tile under it?
##
## legibility_check measures ink against its own face and passes every theme.
## It cannot see the problem the dark themes actually have: two neighbouring
## near-black tiles on a near-black pond with no boundary between them, and a
## stacked tile indistinguishable from the one it sits on. The depth cue on the
## light themes is a dark drop shadow, which on a black tile is invisible.
##
## Two seams are sampled on a real board, artwork off so only the body counts:
##   side  - where two tiles on the same layer meet
##   layer - the left edge of a tile stacked on another
## Each is the contrast between the most extreme pixel within 2px of the seam
## and the median of the faces either side. 1.0 means the seam is invisible.

const RiverTile = preload("res://scripts/core/river_tile.gd")
const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
	"theme_cherry_blossom", "theme_indigo",
]
## Where the light themes sit - their weakest seam is Cherry Blossom's layer
## edge at 2.10 - rather than a published standard, because there is none for
## this. At 1.35 Indigo passed, and the owner had just reported it merging.
const FLOOR: float = 2.0

var _fails: int = 0
var main: Node2D
var board


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["unlocked_themes"] = THEMES.duplicate()
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	main.get_node("HUD").visible = false
	board = main.get_node("Board")
	board.visible = true
	TileView.debug_skip_artwork = true

	print("theme                  side seam   layer seam")
	for theme in THEMES:
		MonetizationManager.equip_theme(theme)
		await _measure(theme)
	TileView.debug_skip_artwork = false

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _measure(theme: String) -> void:
	# A at x=0 and B at x=2 touch side by side; C sits on A one layer up.
	board.restore_stage([
		{"x": 0, "y": 0, "z": 0, "suit": "dot", "rank": 1, "set_id": 1, "size": 2},
		{"x": 2, "y": 0, "z": 0, "suit": "dot", "rank": 2, "set_id": 2, "size": 2},
		{"x": 0, "y": 2, "z": 0, "suit": "dot", "rank": 3, "set_id": 3, "size": 2},
		{"x": 2, "y": 2, "z": 0, "suit": "dot", "rank": 4, "set_id": 4, "size": 2},
		{"x": 1, "y": 1, "z": 1, "suit": "dot", "rank": 5, "set_id": 5, "size": 2},
	])
	main.get_node("Camera2D").frame_board(board.board_bounds, get_viewport().get_visible_rect().size)
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var scale: float = float(img.get_width()) / get_viewport().get_visible_rect().size.x

	var a = _view_at(0, 2, 0)
	var b = _view_at(2, 2, 0)
	var c = _view_at(1, 1, 1)
	var side: float = _seam(img, scale, _screen_x(b, 0.0), _screen_y(b, 0.75), true)
	var layer: float = _seam(img, scale, _screen_x(c, 0.0), _screen_y(c, 0.5), true)

	var ok: bool = side >= FLOOR and layer >= FLOOR
	if not ok:
		_fails += 1
	print("%-22s %6.2f      %6.2f   %s" % [theme, side, layer, "" if ok else "BELOW %.2f" % FLOOR])


func _view_at(x: int, y: int, z: int):
	for t in board.get_active_tiles():
		if t.x == x and t.y == y and t.z == z:
			return board.tile_views.get(t)
	return null


func _screen_x(v, fx: float) -> float:
	return (v.get_global_transform_with_canvas() * Vector2(64.0 * fx, 0)).x


func _screen_y(v, fy: float) -> float:
	return (v.get_global_transform_with_canvas() * Vector2(0, 80.0 * fy)).y


## Contrast between the most extreme pixel within 2px of the seam and the median
## face luminance either side, 8 to 14px in.
func _seam(img: Image, scale: float, sx: float, sy: float, _vertical: bool) -> float:
	var y: int = clampi(int(sy * scale), 0, img.get_height() - 1)
	var cx: int = int(sx * scale)
	var faces: Array[float] = []
	for d in range(8, 15):
		faces.append(_lum(img, cx - d, y))
		faces.append(_lum(img, cx + d, y))
	faces.sort()
	var face: float = faces[faces.size() / 2]
	var extreme: float = face
	for d in range(-2, 3):
		var l: float = _lum(img, cx + d, y)
		if absf(l - face) > absf(extreme - face):
			extreme = l
	var hi: float = maxf(face, extreme)
	var lo: float = minf(face, extreme)
	return (hi + 0.05) / (lo + 0.05)


func _lum(img: Image, x: int, y: int) -> float:
	var c: Color = img.get_pixel(clampi(x, 0, img.get_width() - 1), clampi(y, 0, img.get_height() - 1))
	var f := func(v: float) -> float:
		return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * f.call(c.r) + 0.7152 * f.call(c.g) + 0.0722 * f.call(c.b)
