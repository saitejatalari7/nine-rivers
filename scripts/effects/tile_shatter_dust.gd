class_name TileShatterDust
extends Node2D

## Multi-Stage Cinematic Ceramic Fracture & Billowing Dust Dissolution Effect
## Emits soft billowing dust clouds, tumbling ceramic shards, suit-themed stardust,
## and a 4-point celestial starburst flare with water ripple shockwaves.

@onready var dust_cloud: CPUParticles2D = $DustCloud
@onready var shards: CPUParticles2D = $Shards
@onready var embers: CPUParticles2D = $Embers

static var _cached_soft_tex: Texture2D = null
static var _fade_ramp: Gradient = null
static var _dust_scale_curve: Curve = null

static func _ensure_resources() -> void:
	if _cached_soft_tex == null:
		# Circular soft radial particle texture (no square edges)
		var grad := Gradient.new()
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.75), Color(1, 1, 1, 0)])
		grad.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
		var tex := GradientTexture2D.new()
		tex.gradient = grad
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(0.5, 0.0)
		tex.width = 32
		tex.height = 32
		_cached_soft_tex = tex

	if _fade_ramp == null:
		var ramp := Gradient.new()
		ramp.colors = PackedColorArray([
			Color(1, 1, 1, 0.0),
			Color(1, 1, 1, 0.95),
			Color(1, 1, 1, 0.65),
			Color(1, 1, 1, 0.0)
		])
		ramp.offsets = PackedFloat32Array([0.0, 0.12, 0.65, 1.0])
		_fade_ramp = ramp

	if _dust_scale_curve == null:
		var c := Curve.new()
		c.add_point(Vector2(0.0, 0.5))
		c.add_point(Vector2(0.25, 1.3))
		c.add_point(Vector2(1.0, 1.9))
		_dust_scale_curve = c

func _enter_tree() -> void:
	_ensure_resources()

func _ready() -> void:
	# Configure particle textures and ramps for soft volumetric smoke/dust
	if dust_cloud:
		dust_cloud.texture = _cached_soft_tex
		dust_cloud.color_ramp = _fade_ramp
		dust_cloud.scale_amount_curve = _dust_scale_curve
		dust_cloud.emitting = true
		
	if embers:
		embers.texture = _cached_soft_tex
		embers.color_ramp = _fade_ramp
		embers.emitting = true
		
	if shards:
		shards.emitting = true
		
	# Draw expanding shockwave ring and central celestial lens flare
	_spawn_shockwave_and_flare()
	
	# Clean up after all particles disperse
	get_tree().create_timer(1.0).timeout.connect(queue_free)

var is_glass_mode: bool = false
var is_glass: bool = false

func setup(accent_color: Color = Color("#f2c14e"), is_triple: bool = false, suit: String = "", p_is_glass: bool = false) -> void:
	_ensure_resources()
	if not is_inside_tree():
		await tree_entered
		
	is_glass_mode = p_is_glass
	is_glass = p_is_glass
	
	if p_is_glass:
		# ================= MODE B: BREAKING GLASS VFX =================
		# Crystalline glass shards, diamond specular glints, frost shockwave
		if shards:
			shards.amount = 36 if is_triple else 24
			shards.gravity = Vector2(0, 320)
			shards.initial_velocity_min = 160.0
			shards.initial_velocity_max = 340.0
			shards.angular_velocity_min = -720.0
			shards.angular_velocity_max = 720.0
			shards.scale_amount_min = 2.4
			shards.scale_amount_max = 6.4
			shards.color = Color(0.85, 0.95, 1.0, 0.95) # Icy diamond cyan
		if embers:
			embers.amount = 32
			embers.color = Color(0.70, 0.92, 1.0, 0.9)
			embers.initial_velocity_max = 180.0
		if dust_cloud:
			dust_cloud.amount = 26
			dust_cloud.color = Color(0.65, 0.88, 1.0, 0.45)
	else:
		# ================= MODE A: GOLDEN SAND CASCADE VFX =================
		# Dense shower of golden sand granules cascading downward under gravity
		var primary_gold := Color(0.98, 0.78, 0.22, 1.0) # 24k Molten Gold
		if accent_color != Color.WHITE and accent_color != Color("#f2c14e"):
			primary_gold = primary_gold.lerp(accent_color, 0.35)
			
		if shards:
			# Sand grains tumbling down with realistic physical sand gravity
			shards.amount = 72 if is_triple else 48
			shards.gravity = Vector2(0, 420)
			shards.initial_velocity_min = 35.0
			shards.initial_velocity_max = 135.0
			shards.angular_velocity_min = -180.0
			shards.angular_velocity_max = 180.0
			shards.scale_amount_min = 1.8
			shards.scale_amount_max = 3.6
			shards.color = primary_gold
			
		if embers:
			# Sparkling specular glints & golden sand flecks
			embers.amount = 38 if is_triple else 24
			embers.gravity = Vector2(0, -25)
			embers.initial_velocity_max = 110.0
			embers.color = Color(1.0, 0.94, 0.65, 0.95)
			
		if dust_cloud:
			# Soft golden sand powder mist wisp
			dust_cloud.amount = 38
			dust_cloud.color = Color(0.96, 0.86, 0.52, 0.55)

func _spawn_shockwave_and_flare() -> void:
	var fx := Node2D.new()
	add_child(fx)
	
	var tween := create_tween()
	tween.tween_method(func(_p: float):
		if is_instance_valid(fx):
			fx.queue_redraw()
	, 0.0, 1.0, 0.40).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	fx.draw.connect(func():
		var p := tween.get_total_elapsed_time() / 0.40 if tween and tween.is_valid() else 1.0
		var progress := clampf(p, 0.0, 1.0)
		
		var ring_col := Color(0.65, 0.90, 1.0) if is_glass_mode else Color(0.98, 0.82, 0.35)
		var flare_col_base := Color(0.90, 0.97, 1.0) if is_glass_mode else Color(1.0, 0.96, 0.78)
		
		# 1. Expanding shockwave ring
		var r_outer: float = lerpf(14.0, 62.0, progress)
		var a_outer: float = lerpf(0.85, 0.0, progress)
		fx.draw_arc(Vector2.ZERO, r_outer, 0.0, TAU, 40, Color(ring_col.r, ring_col.g, ring_col.b, a_outer), 2.2, true)
		
		# 2. Inner sharp energy shockwave
		var r_inner: float = lerpf(8.0, 38.0, progress)
		var a_inner: float = lerpf(0.90, 0.0, progress * 1.25)
		if a_inner > 0.0:
			fx.draw_arc(Vector2.ZERO, r_inner, 0.0, TAU, 32, Color(1.0, 1.0, 1.0, a_inner), 1.6, true)
		
		# 3. 4-point Diamond Starburst Lens Flare (First 0.18s)
		if progress < 0.45:
			var flare_p := progress / 0.45
			var flare_alpha := (1.0 - flare_p) * 0.95
			var flare_len := lerpf(10.0, 48.0 if is_glass_mode else 38.0, sin(flare_p * PI * 0.5))
			var flare_thick := lerpf(3.2, 0.8, flare_p)
			var flare_col := Color(flare_col_base.r, flare_col_base.g, flare_col_base.b, flare_alpha)
			
			# Horizontal beam
			fx.draw_line(Vector2(-flare_len, 0), Vector2(flare_len, 0), flare_col, flare_thick, true)
			# Vertical beam
			fx.draw_line(Vector2(0, -flare_len * 0.8), Vector2(0, flare_len * 0.8), flare_col, flare_thick, true)
			# Central radiant core
			fx.draw_circle(Vector2.ZERO, lerpf(5.5, 1.5, flare_p), Color(1.0, 1.0, 1.0, flare_alpha))
	)
	tween.tween_callback(fx.queue_free)
