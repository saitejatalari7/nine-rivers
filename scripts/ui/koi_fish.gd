class_name KoiFish
extends Node2D

var species: String = "kohaku"
var swim_speed: float = 65.0
var turn_speed: float = 2.2

var target_pos: Vector2 = Vector2.ZERO
var wander_timer: float = 0.0
var pond_bounds := Rect2(60, 160, 960, 1500)

var tail_wag_phase: float = 0.0

# Colors based on species
var col_body := Color(0.96, 0.95, 0.92)
var col_markings := Color(0.85, 0.22, 0.15)
var col_accent := Color(0.12, 0.12, 0.12)
var has_black_spots: bool = false
var is_gold_dragon: bool = false

func setup(koi_species: String, start_pos: Vector2) -> void:
	species = koi_species
	position = start_pos
	rotation = randf() * TAU
	swim_speed = 50.0 + randf() * 30.0
	
	match species:
		"sanke":
			col_body = Color(0.96, 0.95, 0.92)
			col_markings = Color(0.85, 0.22, 0.15)
			has_black_spots = true
		"showa":
			col_body = Color(0.15, 0.15, 0.15)
			col_markings = Color(0.85, 0.25, 0.12)
			col_accent = Color(0.95, 0.95, 0.92)
		"dragon_koi":
			col_body = Color(0.95, 0.78, 0.32)
			col_markings = Color(1.0, 0.92, 0.55)
			is_gold_dragon = true
		"ogon":
			col_body = Color(0.92, 0.94, 0.96)
			col_markings = Color(0.78, 0.85, 0.92)
			col_accent = Color(1.0, 1.0, 1.0)
		"shiro":
			col_body = Color(0.14, 0.15, 0.18)
			col_markings = Color(0.92, 0.94, 0.96)
			col_accent = Color(0.80, 0.88, 0.95)
		"yamabuki":
			col_body = Color(0.94, 0.75, 0.18)
			col_markings = Color(1.0, 0.88, 0.38)
			col_accent = Color(1.0, 0.98, 0.92)
		"asagi":
			col_body = Color(0.48, 0.60, 0.68)
			col_markings = Color(0.88, 0.38, 0.22)
			col_accent = Color(0.35, 0.45, 0.52)
		"albino":
			col_body = Color(0.98, 0.97, 0.96)
			col_markings = Color(1.0, 0.85, 0.88)
			col_accent = Color(0.92, 0.30, 0.35)
		"tancho":
			col_body = Color(0.98, 0.97, 0.95)
			col_markings = Color(0.90, 0.18, 0.12)
			col_accent = Color(0.98, 0.97, 0.95)
		"hi_utsuri":
			col_body = Color(0.12, 0.12, 0.12)
			col_markings = Color(0.92, 0.26, 0.14)
			col_accent = Color(0.98, 0.40, 0.20)
		_: # kohaku
			col_body = Color(0.97, 0.96, 0.93)
			col_markings = Color(0.88, 0.22, 0.15)

func _process(delta: float) -> void:
	wander_timer -= delta
	if wander_timer <= 0.0:
		_pick_new_wander_target()
		wander_timer = 3.0 + randf() * 4.0
		
	# Smoothly steer toward target
	var to_target := target_pos - position
	if to_target.length_squared() > 400.0:
		var target_angle := to_target.angle()
		rotation = lerp_angle(rotation, target_angle, turn_speed * delta)
		
	# Move forward in facing direction
	var forward := Vector2.RIGHT.rotated(rotation)
	position += forward * swim_speed * delta
	
	# Clamp inside pond bounds
	position.x = clampf(position.x, pond_bounds.position.x, pond_bounds.end.x)
	position.y = clampf(position.y, pond_bounds.position.y, pond_bounds.end.y)
	
	tail_wag_phase += delta * (swim_speed * 0.12)
	queue_redraw()

func set_pond_bounds(new_bounds: Rect2) -> void:
	pond_bounds = new_bounds
	_pick_new_wander_target()

func attract_to(pos: Vector2) -> void:
	target_pos = pos
	wander_timer = 6.0

func _pick_new_wander_target() -> void:
	target_pos = Vector2(
		pond_bounds.position.x + randf() * pond_bounds.size.x,
		pond_bounds.position.y + randf() * pond_bounds.size.y
	)

func _draw() -> void:
	var tail_sin := sin(tail_wag_phase) * 12.0
	
	# Subterranean water shadow (depth illusion)
	var shadow_offset := Vector2(10, 14)
	var shadow_col := Color(0.01, 0.04, 0.03, 0.22)
	draw_set_transform(shadow_offset, 0.0, Vector2(1.05, 1.05))
	draw_circle(Vector2(-10, 0), 22.0, shadow_col)
	draw_circle(Vector2(-28 + tail_sin * 0.4, 0), 14.0, shadow_col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	
	# Pectoral fins
	var fin_col := Color(col_body.r, col_body.g, col_body.b, 0.65)
	var left_fin := [Vector2(-4, -8), Vector2(-16, -24), Vector2(6, -12)]
	var right_fin := [Vector2(-4, 8), Vector2(-16, 24), Vector2(6, 12)]
	draw_colored_polygon(left_fin, fin_col)
	draw_colored_polygon(right_fin, fin_col)
	
	# Main Body (Torpedo curve)
	var body_points := PackedVector2Array([
		Vector2(24, 0),    # Snout
		Vector2(16, -11),  # Head left
		Vector2(-4, -14),  # Midbody left
		Vector2(-24, -9),  # Taper left
		Vector2(-40 + tail_sin * 0.3, -4), # Rear
		Vector2(-52 + tail_sin, 0),         # Tail root
		Vector2(-40 + tail_sin * 0.3, 4),  # Rear
		Vector2(-24, 9),   # Taper right
		Vector2(-4, 14),   # Midbody right
		Vector2(16, 11),   # Head right
	])
	draw_colored_polygon(body_points, col_body)
	
	# Markings
	draw_circle(Vector2(6, -2), 8.0, col_markings)
	draw_circle(Vector2(-14, 2), 9.0, col_markings)
	draw_circle(Vector2(-32 + tail_sin * 0.2, 0), 6.0, col_markings)
	
	if has_black_spots:
		draw_circle(Vector2(10, 4), 4.0, col_accent)
		draw_circle(Vector2(-10, -5), 5.0, col_accent)
		
	# Caudal / Tail Fin
	var tail_root := Vector2(-50 + tail_sin, 0)
	var tail_fin := PackedVector2Array([
		tail_root,
		tail_root + Vector2(-22 + tail_sin * 0.4, -16),
		tail_root + Vector2(-30 + tail_sin * 0.6, 0),
		tail_root + Vector2(-22 + tail_sin * 0.4, 16)
	])
	draw_colored_polygon(tail_fin, fin_col)
	
	# Cute dark eyes
	draw_circle(Vector2(18, -7), 2.2, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(18, 7), 2.2, Color(0.1, 0.1, 0.1))
