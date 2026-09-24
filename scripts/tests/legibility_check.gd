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
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
	"theme_indigo",
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
## Per-channel sum that counts a pixel as touched by the artwork.
const INK_DIFF: float = 0.06

var _fails: int = 0
var _worst: float = 999.0
var _worst_label: String = ""
var _restore_mode: String = ""

func _exit_tree() -> void:
	if not _restore_mode.is_empty():
		SettingsManager.color_blind_mode = _restore_mode


func _ready() -> void:
	await get_tree().process_frame
	# Kept on the node, not in a local: this setting is PERSISTED, and a run that
	# is interrupted part-way used to leave the profile in whatever mode it had
	# reached. That is how a set of theme screenshots came to be judged in
	# tritanopia without anyone noticing the blues had gone purple.
	_restore_mode = SettingsManager.color_blind_mode
	for mode in ["none", "protanopia", "deuteranopia"]:
		SettingsManager.color_blind_mode = mode
		print("")
		print("colour mode: %s" % mode)
		print("theme                 state    suit    contrast")
		for theme in THEMES:
			for free in [true, false]:
				for probe in PROBES:
					await _measure(theme, free, probe, mode)
	SettingsManager.color_blind_mode = _restore_mode
	_restore_mode = ""

	print("")
	print("worst anywhere: %.2f:1  (%s)" % [_worst, _worst_label])
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


## Renders a real TileView offscreen and reads the pixels back, which is the
## only way to include the body texture, the blocked tint and the atmospheric
## wash that the draw path layers on top.
##
## Each tile is rendered twice, with and without the suit artwork, so ink and
## face are separated by differencing rather than by guessing at percentiles.
## The percentile version worked only while the glyph was a small part of the
## box: when the glyphs were enlarged the median moved onto the ink and the
## measured ratio fell, reporting a regression in colours that had not changed.
func _measure(theme: String, free: bool, probe: Dictionary, mode: String) -> void:
	var with_art: Image = await _render(theme, free, probe, false)
	var without: Image = await _render(theme, free, probe, true)
	if DUMP_TILES and mode == "none":
		with_art.save_png("res://assets/branding/screens/real_game/tile_%s_%s_%s.png" % [
			theme, "free" if free else "blk", probe["suit"]])

	var c := _ink_and_face(with_art, without)
	if c.x < 0.0:
		print("%-20s %-8s %-6s   (no ink)" % [theme, "free" if free else "blocked", probe["suit"]])
		return
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


func _render(theme: String, free: bool, probe: Dictionary, skip_art: bool) -> Image:
	var vp := SubViewport.new()
	vp.size = Vector2i(72, 92)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	# Without this the harness measured an unlit tile while the game shipped a
	# lit one, so every number was for a face darker than the real thing - and
	# sweeping the light settings changed nothing, which is what gave it away.
	TileLighting.attach(vp)

	TileView.debug_skip_artwork = skip_art
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
	vp.queue_free()
	TileView.debug_skip_artwork = false
	return img


## Ink is every pixel the artwork changed; face is every pixel it did not. Both
## are taken as medians, so anti-aliased edge pixels - which sit between the two
## colours and belong to neither - do not drag either number.
##
## Returns (-1, -1) when the artwork changed nothing, which is a broken draw
## path rather than a passing tile and is reported as such.
func _ink_and_face(with_art: Image, without: Image) -> Vector2:
	var ink: Array[float] = []
	var face: Array[float] = []
	for y in range(6, 86):
		for x in range(6, 66):
			var a: Color = with_art.get_pixel(x, y)
			var b: Color = without.get_pixel(x, y)
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if d > INK_DIFF:
				ink.append(_lum(a))
			else:
				face.append(_lum(a))
	if ink.is_empty() or face.is_empty():
		return Vector2(-1.0, -1.0)
	ink.sort()
	face.sort()
	if OS.get_environment("LEG_DEBUG") != "":
		print("      ink n=%d med=%.3f p10=%.3f p90=%.3f | face n=%d med=%.3f" % [
			ink.size(), ink[ink.size() / 2], ink[int(ink.size() * 0.1)], ink[int(ink.size() * 0.9)],
			face.size(), face[face.size() / 2]])
	return Vector2(ink[ink.size() / 2], face[face.size() / 2])


func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]


func _contrast(la: float, lb: float) -> float:
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
