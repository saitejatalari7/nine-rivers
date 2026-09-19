extends SceneTree

## Generates the tile body's normal map analytically instead of baking one.
##
## The shape is known exactly - a rounded rectangle with a bevelled rim - so
## solving for the normal gives a cleaner result than rendering one out of
## Blender and re-sampling it, and it costs nothing to regenerate when the
## bevel width changes.
##
## Run: godot --headless --script tools/make_tile_normal.gd

const W := 256
const H := 336
## Matches the silhouette of assets/tiles/tile_*.png.
const CORNER := 22.0
## How far in from the edge the bevel runs, in source pixels.
const BEVEL := _envf("GEN_BEVEL", 22.0)
## Tilt at the outermost pixel of the rim. Below about 60 the bevel reads as a
## soft gradient rather than an edge; at 90 the rim pixels face fully sideways
## and go black under any light.
const MAX_TILT := _envf("GEN_TILT", 66.0)
const OUT := "res://assets/tiles/tile_normal.png"


static func _envf(name: String, fallback: float) -> float:
	var v: String = OS.get_environment(name)
	return float(v) if v.is_valid_float() else fallback


func _init() -> void:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var half := Vector2(W * 0.5, H * 0.5)
	for y in H:
		for x in W:
			var p := Vector2(x + 0.5, y + 0.5) - half
			var d: float = _rounded_box(p, half - Vector2.ONE, CORNER)
			var inset: float = -d
			var n: Vector3
			if inset >= BEVEL:
				n = Vector3(0.0, 0.0, 1.0)
			else:
				var t: float = clampf(inset / BEVEL, 0.0, 1.0)
				# Quarter-round rather than linear: a flat chamfer puts a hard
				# crease where the rim meets the face and catches the light as
				# a line instead of a curve.
				var ang: float = deg_to_rad(MAX_TILT) * cos(t * PI * 0.5)
				var g: Vector2 = _grad(p, half - Vector2.ONE, CORNER)
				n = Vector3(g.x * sin(ang), g.y * sin(ang), cos(ang)).normalized()
			# Green is flipped: Godot samples 2D normal maps with +Y downward,
			# so an unflipped map lights the bottom rim as though it were the top.
			img.set_pixel(x, y, Color(
				n.x * 0.5 + 0.5,
				-n.y * 0.5 + 0.5,
				n.z * 0.5 + 0.5, 1.0))
	img.save_png(OUT)
	print("wrote %s (%dx%d)" % [OUT, W, H])
	quit(0)


func _rounded_box(p: Vector2, b: Vector2, r: float) -> float:
	var q: Vector2 = p.abs() - (b - Vector2(r, r))
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length() + minf(maxf(q.x, q.y), 0.0) - r


## Outward gradient of the distance field, by central difference.
func _grad(p: Vector2, b: Vector2, r: float) -> Vector2:
	const E := 1.0
	var gx: float = _rounded_box(p + Vector2(E, 0), b, r) - _rounded_box(p - Vector2(E, 0), b, r)
	var gy: float = _rounded_box(p + Vector2(0, E), b, r) - _rounded_box(p - Vector2(0, E), b, r)
	var g := Vector2(gx, gy)
	return g.normalized() if g.length() > 0.0001 else Vector2.ZERO
