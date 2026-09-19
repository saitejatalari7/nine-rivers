extends SceneTree

## Generates a tile body texture procedurally.
##
## The Blender bake gave a clean silhouette and almost nothing else - the
## bodies are flat cards whose whole surface sits in one narrow value band. On
## a 144-tile board that is the defect that matters: adjacent tiles share a
## value, so they merge into one mass and you cannot see where one ends and the
## next begins. Generating instead of baking makes the value range an argument
## rather than something to re-render for.
##
## Silhouette matches make_tile_normal.gd exactly, because the two are sampled
## as one surface and a mismatch shows as a lit halo outside the tile.
##
## Run: STYLE=frost godot --headless --script tools/make_tile_body.gd
##      STYLE=bronze godot --headless --script tools/make_tile_body.gd

const W := 256
const H := 336
const CORNER := 22.0

## top, bottom, grain, cloud, rim shift, rim depth, patina tint
const STYLES := {
	"frost": {
		"out": "tile_frost.png",
		"top": Color(0.988, 0.992, 1.0),
		"bot": Color(0.886, 0.910, 0.937),
		"grain": 0.022, "cloud": 0.045,
		"rim": -0.10, "rim_px": 6.0,
		"patina": Color(0.0, 0.0, 0.0),
		"crystal": 0.10,
	},
	# Bright gold lacquer carrying dark ink. Which way round the face and the
	# ink sit is a real choice and it drives everything else: dark ink needs a
	# bright face, so the rim has to DARKEN to keep one tile off its neighbour
	# on a full board, where a dark face wanted a brightened rim instead.
	"gold": {
		"out": "tile_gold.png",
		# Hue matters more than brightness here. At R/G 1.47 this read as dark
		# chocolate however it was lit; green is lifted until the ratio is nearer
		# 1.28, which puts the hue around 45 rather than 33 degrees. The wide
		# top-to-bottom range is the sheen - a narrow range reads as painted card
		# whatever the hue.
		"top": Color(0.865, 0.706, 0.300),
		"bot": Color(0.632, 0.492, 0.166),
		"grain": 0.016, "cloud": 0.022,
		"rim": -0.26, "rim_px": 7.0,
		# Warm drift, not verdigris. The first attempt tinted the low-frequency
		# field green and the result read as corroded brass rather than bronze.
		"patina": Color(0.016, 0.004, -0.012),
		"crystal": 0.0,
	},
}


func _init() -> void:
	var name: String = OS.get_environment("STYLE")
	if not STYLES.has(name):
		push_error("STYLE must be one of: " + ", ".join(STYLES.keys()))
		quit(1)
		return
	var s: Dictionary = STYLES[name]

	var grain := FastNoiseLite.new()
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain.frequency = 0.28
	grain.seed = 20260919

	var cloud := FastNoiseLite.new()
	cloud.noise_type = FastNoiseLite.TYPE_SIMPLEX
	cloud.frequency = 0.016
	cloud.seed = 771

	var crystal := FastNoiseLite.new()
	crystal.noise_type = FastNoiseLite.TYPE_CELLULAR
	crystal.frequency = 0.045
	crystal.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	crystal.seed = 4242

	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half := Vector2(W * 0.5, H * 0.5)
	var top: Color = s["top"]
	var bot: Color = s["bot"]
	var patina: Color = s["patina"]
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var d: float = _rounded_box(p, half - Vector2.ONE, CORNER)
			if d > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var t: float = float(y) / float(H - 1)
			var c: Color = top.lerp(bot, t)

			var cl: float = cloud.get_noise_2d(x, y)
			c = _shift(c, cl * float(s["cloud"]))
			# Patina rides the same low-frequency field, so the mottling and
			# the colour drift belong to one another instead of fighting.
			c = Color(
				clampf(c.r + patina.r * cl, 0.0, 1.0),
				clampf(c.g + patina.g * cl, 0.0, 1.0),
				clampf(c.b + patina.b * cl, 0.0, 1.0), c.a)
			c = _shift(c, grain.get_noise_2d(x, y) * float(s["grain"]))

			var cr: float = float(s["crystal"])
			if cr > 0.0:
				var v: float = clampf(crystal.get_noise_2d(x, y), 0.0, 1.0)
				c = _shift(c, pow(v, 3.0) * cr)

			var inset: float = -d
			var rim_px: float = float(s["rim_px"])
			if inset < rim_px:
				c = _shift(c, float(s["rim"]) * (1.0 - inset / rim_px))

			img.set_pixel(x, y, Color(c.r, c.g, c.b, clampf(inset, 0.0, 1.0)))

	var path := "res://assets/tiles/" + String(s["out"])
	img.save_png(path)
	print("wrote %s (%dx%d)" % [path, W, H])
	quit(0)


func _shift(c: Color, amt: float) -> Color:
	return Color(
		clampf(c.r + amt, 0.0, 1.0),
		clampf(c.g + amt, 0.0, 1.0),
		clampf(c.b + amt, 0.0, 1.0), c.a)


func _rounded_box(p: Vector2, b: Vector2, r: float) -> float:
	var q: Vector2 = p.abs() - (b - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
