extends RefCounted

## The two 2D lights that make the tile bevel visible.
##
## NOT USED BY THE GAME. The board never attached these lights (add_child ran
## while the scene was still being built and failed), every look was tuned
## without them, and a side-by-side in September 2026 showed they only dimmed
## the faces slightly. Kept for the light_tune and title_cards harnesses;
## tile_view still reads specular() for the normal-mapped body texture.
##
## The bevel used to be painted into the body PNG and was, in practice, absent:
## a soft gradient about two source pixels wide, which at the ~74px a tile
## occupies on a phone is under one pixel. Lighting a normal map instead gives
## the rim real shading, and it moves when a tile lifts or is selected rather
## than staying a fixed picture.
##
## Two lights, not one. 2D lights in Godot are additive over the sprite, so a
## single light can only brighten - the far rim would stay exactly as flat as
## before. The second light subtracts from the opposite direction, which is
## what produces the dark edge that reads as thickness.
##
## LIGHT_HEIGHT is the setting that matters most and the least obvious. It is
## how far off the canvas the light sits. High, and the light points straight
## down: the flat face takes almost all of it and washes out while the rim
## barely changes, which is what the first attempt did to Imperial Gold - the
## dots went pure white. Low, and the light grazes: a face whose normal points
## straight at the viewer receives little, and only the tilted rim pixels light
## up. Grazing is what is wanted here, because the bevel is the subject.
##
## Defined here rather than in board.tscn so the offscreen render harnesses can
## light a tile the same way the game does, instead of previewing a tile that
## no light ever reaches.

## Up and to the left, matching the highlight direction in the body art.
const KEY_ANGLE_DEG: float = 125.0
const KEY_ENERGY: float = 0.70
const KEY_COLOR := Color(1.0, 0.97, 0.9)
const FILL_ENERGY: float = 0.45
const FILL_COLOR := Color(0.58, 0.62, 0.74)
const LIGHT_HEIGHT: float = 0.10
## Kept low. A bright specular on a ceramic tile reads as wet plastic, and it
## was the second half of the Imperial Gold blowout.
const SPECULAR: float = 0.22


static func key_energy() -> float:
	return _env("TUNE_KEY", KEY_ENERGY)


static func fill_energy() -> float:
	return _env("TUNE_FILL", FILL_ENERGY)


static func light_height() -> float:
	return _env("TUNE_HEIGHT", LIGHT_HEIGHT)


static func specular() -> float:
	return _env("TUNE_SPEC", SPECULAR)


## Tuning override, read only when the variable is set. Nothing in the shipped
## game sets these; they exist so light_tune.gd can sweep a value without a
## source edit and a reimport between every frame.
static func _env(name: String, fallback: float) -> float:
	var v: String = OS.get_environment(name)
	return float(v) if v.is_valid_float() else fallback


static func attach(parent: Node) -> void:
	parent.add_child(_make("TileKeyLight", KEY_ANGLE_DEG, key_energy(), KEY_COLOR,
		Light2D.BLEND_MODE_ADD))
	parent.add_child(_make("TileFillLight", KEY_ANGLE_DEG + 180.0, fill_energy(), FILL_COLOR,
		Light2D.BLEND_MODE_SUB))


static func _make(n: String, angle_deg: float, energy: float, col: Color, blend: int) -> DirectionalLight2D:
	var l := DirectionalLight2D.new()
	l.name = n
	l.rotation_degrees = angle_deg
	l.energy = energy
	l.color = col
	l.blend_mode = blend
	l.height = light_height()
	l.shadow_enabled = false
	return l
