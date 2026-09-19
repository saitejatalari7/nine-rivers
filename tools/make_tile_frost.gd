extends SceneTree

## Generates a frosted-white tile body to sit against the existing warm-grey one.
##
## The shipped bodies read grey rather than ivory once the bevel lighting is on
## them: the key light lifts the whole face toward white and takes the warmth
## out of a colour that was only just warm to begin with. Rather than fight
## that, this leans into it - a cool near-white porcelain with frost grain,
## which is a colour that survives being lit.
##
## Silhouette matches make_tile_normal.gd exactly, because the two are sampled
## as one surface and a mismatch shows up as a lit halo outside the tile.
##
## Run: godot --headless --script tools/make_tile_frost.gd

const W := 256
const H := 336
const CORNER := 22.0
const OUT := "res://assets/tiles/tile_frost.png"

const TOP := Color(0.988, 0.992, 1.0)
const BOT := Color(0.886, 0.910, 0.937)
## Fine grain, the frozen-surface texture. Kept small: at the ~74px a tile
## occupies this is sub-pixel, and its job is to stop the face reading as flat
## vector fill rather than to be seen as noise.
const GRAIN := 0.022
## Broad cloudy patches, the part that actually reads as frost at tile size.
const CLOUD := 0.045


func _init() -> void:
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
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var d: float = _rounded_box(p, half - Vector2.ONE, CORNER)
			if d > 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue

			var t: float = float(y) / float(H - 1)
			var c: Color = TOP.lerp(BOT, t)

			c = _shift(c, cloud.get_noise_2d(x, y) * CLOUD)
			c = _shift(c, grain.get_noise_2d(x, y) * GRAIN)

			# Ice veins: the cellular ridges, kept faint and only brightening.
			var v: float = clampf(crystal.get_noise_2d(x, y), 0.0, 1.0)
			c = _shift(c, pow(v, 3.0) * 0.10)

			# The rim darkens slightly inward so the tile still has an outline
			# on a light background, where the bevel highlight alone would let
			# it dissolve into the felt.
			var inset: float = -d
			if inset < 6.0:
				c = _shift(c, -0.10 * (1.0 - inset / 6.0))

			# One pixel of anti-aliased alpha at the silhouette.
			var a: float = clampf(inset, 0.0, 1.0)
			img.set_pixel(x, y, Color(c.r, c.g, c.b, a))

	img.save_png(OUT)
	print("wrote %s (%dx%d)" % [OUT, W, H])
	quit(0)


func _shift(c: Color, amt: float) -> Color:
	return Color(
		clampf(c.r + amt, 0.0, 1.0),
		clampf(c.g + amt, 0.0, 1.0),
		clampf(c.b + amt, 0.0, 1.0), c.a)


func _rounded_box(p: Vector2, b: Vector2, r: float) -> float:
	var q: Vector2 = p.abs() - (b - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r
