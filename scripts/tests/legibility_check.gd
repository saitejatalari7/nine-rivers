extends Node

## Measures symbol-against-face contrast for every theme, including under the
## fog modifier. The gold-on-gold bug shipped because the art was reviewed as
## isolated PNGs, where there is no fog, no stacking and no blocked tiles.
##
## WCAG puts 3:1 as the floor for large text and graphical objects. Tile
## symbols are strokes at ~30dp, so 3:1 is the right bar and 4.5:1 is
## comfortable.

const TileView = preload("res://scripts/ui/tile_view.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]
const FLOOR: float = 3.0

func _ready() -> void:
	var fails := 0
	print("theme                 state   ink    red   green   blue")
	for th in THEMES:
		for state in ["free", "blocked", "fogged"]:
			var face: Color = TileView.get_theme_face_color(state == "free", th)
			if state == "fogged":
				face = _over(Color(0.86, 0.91, 0.93, 0.80), face)
			var vals: Array[float] = []
			for col in [TileView.get_col_ink(th), TileView.get_col_red(th),
					TileView.get_col_green(th), TileView.get_col_blue(th)]:
				var c: Color = col
				if state == "fogged":
					c = _over(Color(0.86, 0.91, 0.93, 0.80), c)
				vals.append(_contrast(c, face))
			# Fog exists to conceal blocked tiles, so low contrast there is the
			# feature working. Only free and blocked tiles must stay readable.
			var flag := ""
			if state != "fogged":
				for v in vals:
					if v < FLOOR:
						flag = "  BELOW %.1f:1" % FLOOR
						fails += 1
						break
				if flag.is_empty():
					for v in vals:
						if v < 4.5:
							flag = "  marginal (<4.5:1)"
							break
			print("%-20s %-8s %5.2f  %5.2f  %5.2f  %5.2f%s" % [
				th, state, vals[0], vals[1], vals[2], vals[3], flag])
	print("")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _over(top: Color, bottom: Color) -> Color:
	return Color(
		top.r * top.a + bottom.r * (1.0 - top.a),
		top.g * top.a + bottom.g * (1.0 - top.a),
		top.b * top.a + bottom.b * (1.0 - top.a), 1.0)

func _lum(c: Color) -> float:
	var ch: Array[float] = []
	for v in [c.r, c.g, c.b]:
		ch.append(v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4))
	return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]

func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)
