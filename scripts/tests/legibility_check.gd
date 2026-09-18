extends Node

## Measures symbol-against-face contrast on the pixels the game actually draws.
##
## The previous version compared get_theme_face_color() against the glyph
## colours and reported every theme comfortably clear. It was measuring a
## colour the renderer had stopped using: TileView._draw has taken the
## USE_RENDERED_BODY path since the Blender art pass, so the face comes from
## assets/tiles/tile_<theme>.png and get_theme_face_color() survives only as a
## fallback. The check could not fail for the right reason, and it rated the
## worst theme in the game as the best one.
##
## It also read colour_blind_mode out of whatever was in the local save, so its
## numbers changed depending on the machine. Every mode is now iterated
## explicitly and the setting is restored afterwards.
##
## WCAG puts 3:1 as the floor for graphical objects and 4.5:1 as comfortable.
## Fog is not measured: concealing blocked tiles is what fog is for.
##
## Read the numbers as conservative. Thin anti-aliased strokes - a dot ring, a
## character numeral - put partly-blended pixels at the extremes, so the
## measured ratio sits below what the pure colours compute to: Classic Jade's
## green ring reads 2.13 here against 3.09 for #1b6d49 on #bcb5a2. It errs
## toward flagging, which is the right direction for a legibility check, but a
## flag just above the floor deserves a look rather than a panic.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]
## One tile of each suit, so every glyph colour the theme uses gets sampled.
const PROBES: Array[Dictionary] = [
	{"suit": "char", "rank": 1}, {"suit": "bam", "rank": 2},
	{"suit": "dot", "rank": 3}, {"suit": "dragon", "rank": 1},
]
const FLOOR: float = 3.0
const COMFORTABLE: float = 4.5
## Writes each probed tile to disk so the numbers can be checked against eyes.
const DUMP_TILES: bool = false

var _fails: int = 0
var _worst: float = 999.0
var _worst_label: String = ""


func _ready() -> void:
	await get_tree().process_frame
	var restore: String = SettingsManager.color_blind_mode
	for mode in ["none", "protanopia", "deuteranopia"]:
		SettingsManager.color_blind_mode = mode
		print("")
		print("colour mode: %s" % mode)
		print("theme                 state    suit    contrast")
		for theme in THEMES:
			for free in [true, false]:
				for probe in PROBES:
					await _measure(theme, free, probe, mode)
	SettingsManager.color_blind_mode = restore

	print("")
	print("worst anywhere: %.2f:1  (%s)" % [_worst, _worst_label])
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Renders a real TileView offscreen and reads the pixels back, which is the
## only way to include the body texture, the blocked tint and the atmospheric
## wash that the draw path layers on top.
func _measure(theme: String, free: bool, probe: Dictionary, mode: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(72, 92)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var view = TileViewScene.instantiate()
	vp.add_child(view)
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
	if DUMP_TILES and mode == "none":
		img.save_png("res://assets/branding/screens/real_game/tile_%s_%s_%s.png" % [
			theme, "free" if free else "blk", probe["suit"]])
	vp.queue_free()

	var c := _ink_and_face(img)
	var ratio: float = _contrast(c.x, c.y)
	var flag := ""
	if ratio < FLOOR:
		flag = "  BELOW %.1f" % FLOOR
		_fails += 1
	elif ratio < COMFORTABLE:
		flag = "  marginal"
	if ratio < _worst:
		_worst = ratio
		_worst_label = "%s %s %s / %s" % [theme, "free" if free else "blocked", probe["suit"], mode]
	print("%-20s %-8s %-6s %7.2f%s" % [
		theme, "free" if free else "blocked", probe["suit"], ratio, flag])


## Separates ink from face inside the glyph box.
##
## The face is the median: it is most of the box whatever the glyph is. The ink
## is whichever extreme lies further from it, because a theme may print dark
## glyphs on a light tile or light glyphs on a dark one, and assuming the first
## reports a pale glyph as invisible.
##
## The extremes are the 2nd and 98th percentiles, not the 5th and 92nd. Thin
## strokes - a character numeral, a dragon glyph - cover only a few per cent of
## the box, so a 5% tail sampled face against face and returned the same number
## no matter how the ink colour changed.
func _ink_and_face(img: Image) -> Vector2:
	var lums: Array[float] = []
	for y in range(28, 64):
		for x in range(16, 56):
			lums.append(_lum(img.get_pixel(x, y)))
	if lums.is_empty():
		return Vector2(0.0, 1.0)
	lums.sort()
	var face: float = lums[int(lums.size() * 0.5)]
	var dark: float = lums[int(lums.size() * 0.02)]
	var light: float = lums[mini(lums.size() - 1, int(lums.size() * 0.98))]
	var ink: float = dark if (face - dark) >= (light - face) else light
	return Vector2(ink, face)


func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _contrast(la: float, lb: float) -> float:
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
