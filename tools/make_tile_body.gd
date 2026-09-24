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
## Measured range of the cellular field the crackle veins are cut from.
const CRACKLE_MIN := -0.985
const CRACKLE_SPAN := 0.841

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
	# Celadon crackle porcelain - Ru ware. Earned only, never sold, so it has to
	# look like the reward it is rather than a fifth colourway. The crackle is a
	# cellular field used as dark veins instead of the bright ones frost uses.
	"celadon": {
		"out": "tile_celadon.png",
		"top": Color(0.780, 0.855, 0.806),
		"bot": Color(0.612, 0.706, 0.662),
		"grain": 0.014, "cloud": 0.028,
		"rim": -0.07, "rim_px": 9.0,
		"patina": Color(-0.010, 0.006, 0.004),
		"crystal": 0.0,
	},
	# Bright gold lacquer carrying dark ink. Which way round the face and the ink
	# sit drives everything else: dark ink needs a bright face, so the rim has to
	# DARKEN to keep one tile off its neighbour on a full board, where a dark face
	# wanted a brightened rim instead.
	# Deep indigo lacquer. Distinct from all four shipping themes at a glance:
	# Jade is white, Gold is warm yellow, Obsidian is near-black, Cherry is pink.
	# Nothing in the set owns blue.
	"indigo": {
		"out": "tile_indigo.png",
		"top": Color(0.208, 0.259, 0.435),
		"bot": Color(0.075, 0.098, 0.192),
		# Barely any grain: polished glaze is smooth, and grain reads as unfired
		# clay. The look comes from the sheen sweep and the rim instead.
		"grain": 0.006, "cloud": 0.020,
		"rim": 0.26, "rim_px": 6.0,
		"patina": Color(-0.004, 0.002, 0.014),
		"crystal": 0.0,
		"sheen": 0.26, "sheen_width": 0.20,
		"sparkle": 0.55,
	},
	# Blush porcelain under a rose rim. The old body was a dusty pink face inside
	# a dark red frame, with mid-tone ink on top: the same hue at the same value
	# three times over, which is why this was the only theme failing legibility.
	# The frame is what the theme is recognised by, so it moves INTO the rim
	# rather than being dropped, and the face goes near-white to carry dark ink.
	"blossom": {
		"out": "tile_cherry_blossom.png",
		# A real blush face, not white. Dark ink only needs the face to stay light,
		# not colourless - at 11.96:1 there was room to put the pink back and still
		# sit far above the 3.0 floor.
		"top": Color(0.976, 0.878, 0.898),
		"bot": Color(0.925, 0.792, 0.824),
		"grain": 0.012, "cloud": 0.026,
		# The rim tints rather than shifts value: a darker blush is still blush,
		# where the rose frame has to be a different colour to read as one.
		# Wide and mostly solid: at 256px source drawn into 64px the rim is scaled
		# down four times over, so a narrow band that looked like a frame in the
		# texture was two pale pixels on the board and the theme read as Jade.
		"rim": 0.0, "rim_px": 26.0,
		"rim_col": Color(0.812, 0.376, 0.459), "rim_mix": 1.0, "rim_hard": 0.55,
		"patina": Color(0.004, -0.002, 0.000),
		"crystal": 0.0,
		"sheen": 0.05, "sheen_width": 0.30,
	},
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

	var crackle_noise := FastNoiseLite.new()
	crackle_noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	crackle_noise.frequency = float(s.get("crackle_freq", 0.075))
	crackle_noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	crackle_noise.cellular_jitter = 0.75
	crackle_noise.seed = 9137

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

			var ck: float = float(s.get("crackle", 0.0))
			if ck > 0.0:
				# Ridges of the cellular field, not its cells: a thin dark line
				# where two cells meet is what a crackle glaze actually is.
				# Measured, not assumed: with RETURN_DISTANCE2_SUB this field runs
				# about -0.985 to -0.144 and the cell BOUNDARIES sit at the
				# minimum, not at zero. Taking abs() put the veins exactly where
				# they were not, which is why two attempts produced a blank tile.
				var sharp: float = float(s.get("crackle_sharp", 7.0))
				var t_edge: float = (crackle_noise.get_noise_2d(x, y) - CRACKLE_MIN) / CRACKLE_SPAN
				var edge: float = 1.0 - clampf(t_edge * sharp, 0.0, 1.0)
				c = _shift(c, -pow(edge, 0.85) * ck)
			var cr: float = float(s["crystal"])
			if cr > 0.0:
				var v: float = clampf(crystal.get_noise_2d(x, y), 0.0, 1.0)
				c = _shift(c, pow(v, 3.0) * cr)

			# A broad diagonal band of light across the face. This is what reads as
			# polish - a glazed surface returns a wide soft highlight, where a matte
			# one returns none. Baked in rather than lit, so it survives the tile
			# being drawn at any angle on any board.
			var sh: float = float(s.get("sheen", 0.0))
			if sh > 0.0:
				var u: float = (float(x) / float(W) + float(y) / float(H)) * 0.5
				var band: float = exp(-pow((u - 0.34) / float(s.get("sheen_width", 0.3)), 2.0))
				c = _shift(c, band * sh)

			# Sparse crystal specks. Kept rare and tiny: enough to catch the eye
			# when a tile moves, not enough to read as glitter.
			var sp: float = float(s.get("sparkle", 0.0))
			if sp > 0.0:
				var g: float = grain.get_noise_2d(x * 3.7 + 500.0, y * 3.7 - 220.0)
				if g > 0.74:
					c = _shift(c, (g - 0.74) * sp * 9.0)

			var inset: float = -d
			var rim_px: float = float(s["rim_px"])
			if inset < rim_px:
				var edge_t: float = 1.0 - inset / rim_px
				c = _shift(c, float(s["rim"]) * edge_t)
				if s.has("rim_col"):
					var rc: Color = s["rim_col"]
					var hard: float = float(s.get("rim_hard", 0.0))
					var m: float = edge_t if hard <= 0.0 else clampf(edge_t / (1.0 - hard), 0.0, 1.0)
					c = c.lerp(rc, pow(m, 1.15) * float(s.get("rim_mix", 1.0)))

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
