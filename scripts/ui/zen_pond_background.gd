class_name ZenPondBackground
extends CanvasLayer

## Nine Rivers (九河) — Living Zen Pond & River Parallax System
## Multi-layered parallax depth behind the stationary Mahjong board:
## 1. Deep Caustic Water Bed (0.05x Parallax)
## 2. Subterranean Swimming Koi Fish (0.22x Parallax)
## 3. Surface Floating Flora & Lotus Pads (0.50x Parallax)
## 4. Expanding Water Ripples Shockwaves (0.50x Parallax)
## 5. Foreground Spirit Fireflies & Air Motes (1.05x Parallax)
## Dynamic atmospheric evolution every 5 levels.

signal theme_changed(theme_data: Dictionary, new_level: int)

const KoiFishScript = preload("res://scripts/ui/koi_fish.gd")

const THEMES: Array[Dictionary] = [
	{
		"id": "emerald_pond",
		"name": "Emerald Serenity",
		"name_zh": "翠玉池",
		"felt_color": Color("#021711"),
		"secondary_color": Color("#053325"),
		"caustic_color": Color(0.06, 0.65, 0.48, 0.42),
		"gold_color": Color(0.96, 0.78, 0.28, 0.85),
		"speed": 0.8,
		"koi_species": ["kohaku", "sanke", "kohaku"],
		"flora_type": "lotus_pad",
		"mote_color": Color(0.96, 0.82, 0.35, 0.75),
		"ripple_color": Color(0.35, 0.92, 0.75)
	},
	{
		"id": "moonlit_river",
		"name": "Moonlit Twilight",
		"name_zh": "月华江",
		"felt_color": Color("#040d1e"),
		"secondary_color": Color("#0b1e42"),
		"caustic_color": Color(0.18, 0.45, 0.85, 0.45),
		"gold_color": Color(0.85, 0.92, 1.0, 0.85),
		"speed": 0.65,
		"koi_species": ["ogon", "shiro", "ogon"],
		"flora_type": "night_lily",
		"mote_color": Color(0.65, 0.85, 1.0, 0.8),
		"ripple_color": Color(0.45, 0.75, 1.0)
	},
	{
		"id": "autumn_stream",
		"name": "Autumn Maple Falls",
		"name_zh": "丹枫溪",
		"felt_color": Color("#1a0903"),
		"secondary_color": Color("#3a1506"),
		"caustic_color": Color(0.85, 0.35, 0.10, 0.45),
		"gold_color": Color(0.98, 0.70, 0.15, 0.9),
		"speed": 0.95,
		"koi_species": ["showa", "yamabuki", "showa"],
		"flora_type": "maple_leaf",
		"mote_color": Color(0.98, 0.58, 0.20, 0.75),
		"ripple_color": Color(0.95, 0.65, 0.35)
	},
	{
		"id": "misty_spring",
		"name": "Misty Mountain Spring",
		"name_zh": "清岚泉",
		"felt_color": Color("#05161b"),
		"secondary_color": Color("#0e323b"),
		"caustic_color": Color(0.20, 0.65, 0.72, 0.45),
		"gold_color": Color(0.95, 0.75, 0.82, 0.85),
		"speed": 0.7,
		"koi_species": ["asagi", "albino", "asagi"],
		"flora_type": "sakura_petal",
		"mote_color": Color(0.85, 0.75, 0.92, 0.7),
		"ripple_color": Color(0.40, 0.85, 0.88)
	},
	{
		"id": "sunset_haven",
		"name": "Sunset Lotus Haven",
		"name_zh": "夕霞泽",
		"felt_color": Color("#1a061d"),
		"secondary_color": Color("#3c0e44"),
		"caustic_color": Color(0.82, 0.25, 0.48, 0.45),
		"gold_color": Color(0.98, 0.68, 0.20, 0.9),
		"speed": 0.85,
		"koi_species": ["tancho", "hi_utsuri", "tancho"],
		"flora_type": "sunset_lotus",
		"mote_color": Color(0.98, 0.60, 0.35, 0.8),
		"ripple_color": Color(0.92, 0.45, 0.72)
	}
]

# Parallax Planes
var bg_color: ColorRect = null
var fish_container: Node2D = null
var flora_container: Node2D = null
var ripples_container: Node2D = null
var motes_container: Node2D = null

var current_level: int = 1
var current_theme_idx: int = -1
var active_theme: Dictionary = THEMES[0]

# Motion & Parallax variables
var current_parallax := Vector2.ZERO
var target_parallax := Vector2.ZERO
var sim_time: float = 0.0

# Flora items: Array of { pos, scale, rot, phase, type, blossom }
var flora_items: Array[Dictionary] = []

# Ripples: Array of { pos, r, max_r, a, speed }
var ripples: Array[Dictionary] = []
## Bounded so rapid tapping cannot pile up unbounded draw work.
const MAX_RIPPLES: int = 14

# Motes: Array of { pos, vel, size, phase }
var motes: Array[Dictionary] = []
const NUM_MOTES: int = 20

func _ready() -> void:
	layer = -10
	
	# Ensure container nodes exist if instantiated dynamically
	_ensure_containers()
	
	# Connect custom drawing callbacks
	flora_container.draw.connect(_on_flora_draw)
	ripples_container.draw.connect(_on_ripples_draw)
	motes_container.draw.connect(_on_motes_draw)
	
	# Initialize motes
	_init_motes()
	
	if is_instance_valid(MonetizationManager) and MonetizationManager.has_signal("background_theme_equipped"):
		MonetizationManager.background_theme_equipped.connect(_on_background_theme_equipped)
	
	# Apply initial theme
	var active_th := MonetizationManager.get_active_background_theme() if is_instance_valid(MonetizationManager) else "auto"
	if active_th != "auto":
		apply_theme_by_id(active_th, false)
	else:
		set_level(1, false)

func _ensure_containers() -> void:
	bg_color = get_node_or_null("BgColor")
	if not bg_color:
		bg_color = ColorRect.new()
		bg_color.name = "BgColor"
		bg_color.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg_color.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(bg_color)
		
	fish_container = get_node_or_null("FishContainer")
	if not fish_container:
		fish_container = Node2D.new()
		fish_container.name = "FishContainer"
		add_child(fish_container)
		
	flora_container = get_node_or_null("FloraContainer")
	if not flora_container:
		flora_container = Node2D.new()
		flora_container.name = "FloraContainer"
		add_child(flora_container)
		
	ripples_container = get_node_or_null("RipplesContainer")
	if not ripples_container:
		ripples_container = Node2D.new()
		ripples_container.name = "RipplesContainer"
		add_child(ripples_container)
		
	motes_container = get_node_or_null("MotesContainer")
	if not motes_container:
		motes_container = Node2D.new()
		motes_container.name = "MotesContainer"
		add_child(motes_container)

func _process(delta: float) -> void:
	sim_time += delta
	
	# 1. Update Parallax with Accelerometer & Autonomous Lissajous Drift
	_update_parallax(delta)
	
	# 2. Update Ripples
	_update_ripples(delta)
	
	# 3. Update Motes
	_update_motes(delta)
	
	# 4. Redraw containers
	flora_container.queue_redraw()
	ripples_container.queue_redraw()
	motes_container.queue_redraw()

func _update_parallax(delta: float) -> void:
	# Read phone tilt if available on mobile
	var accel := Input.get_accelerometer()
	var tilt := Vector2.ZERO
	if accel.length_squared() > 0.05:
		# In portrait mode: accel.x is roll (-9.8..9.8), accel.y is pitch (usually ~6.0 when tilted)
		tilt.x = clampf(-accel.x * 5.5, -45.0, 45.0)
		tilt.y = clampf((accel.y - 6.0) * 4.5, -35.0, 35.0)
		
	# Organic autonomous Zen breathing drift (active on desktop & flat mobile)
	var drift := Vector2(
		sin(sim_time * 0.35) * 16.0 + sin(sim_time * 0.18) * 8.0,
		cos(sim_time * 0.28) * 12.0 + cos(sim_time * 0.12) * 6.0
	)
	
	target_parallax = tilt + drift
	current_parallax = current_parallax.lerp(target_parallax, clampf(delta * 3.2, 0.0, 1.0))
	
	# Distribute 2.5D parallax offsets across depth planes
	if bg_color.material is ShaderMaterial:
		var mat: ShaderMaterial = bg_color.material as ShaderMaterial
		mat.set_shader_parameter("parallax_offset", current_parallax * 0.00018)
		
	fish_container.position = current_parallax * 0.22
	flora_container.position = current_parallax * 0.50
	ripples_container.position = current_parallax * 0.50
	motes_container.position = current_parallax * 1.05

func _update_ripples(delta: float) -> void:
	var remaining: Array[Dictionary] = []
	for r in ripples:
		r["r"] += delta * r["speed"]
		var life_ratio: float = 1.0 - (r["r"] / r["max_r"])
		r["a"] = maxf(0.0, life_ratio * 0.85)
		if r["a"] > 0.01 and r["r"] < r["max_r"]:
			remaining.append(r)
	ripples = remaining

func _update_motes(delta: float) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1080, 2400)
		
	for m in motes:
		m["pos"] += m["vel"] * delta
		m["pos"].x += sin(sim_time * 1.4 + m["phase"]) * 14.0 * delta
		
		# Wrap around screen edges
		if m["pos"].y < -40.0:
			m["pos"].y = vp_size.y + randf_range(10.0, 60.0)
			m["pos"].x = randf_range(20.0, vp_size.x - 20.0)
		if m["pos"].x < -40.0:
			m["pos"].x = vp_size.x + 20.0
		elif m["pos"].x > vp_size.x + 40.0:
			m["pos"].x = -20.0

func _init_motes() -> void:
	motes.clear()
	var vp_size := Vector2(1080, 2400)
	for _i in range(NUM_MOTES):
		motes.append({
			"pos": Vector2(randf_range(20, vp_size.x - 20), randf_range(0, vp_size.y)),
			"vel": Vector2(randf_range(-6, 6), -randf_range(18, 45)), # slow upward drift
			"size": randf_range(2.8, 6.0),
			"phase": randf() * TAU
		})

func _on_background_theme_equipped(theme_id: String) -> void:
	if theme_id == "auto":
		set_level(current_level, true)
	else:
		apply_theme_by_id(theme_id, true)

func apply_theme_by_id(theme_id: String, animate: bool = true) -> void:
	for idx in range(THEMES.size()):
		if THEMES[idx]["id"] == theme_id:
			var theme_data: Dictionary = THEMES[idx]
			var theme_changed_flag: bool = (idx != current_theme_idx)
			current_theme_idx = idx
			active_theme = theme_data
			_apply_theme(theme_data, animate)
			if theme_changed_flag:
				theme_changed.emit(theme_data, current_level)
			return

## Calculate theme based on 5-level bracket
func get_theme_for_level(level: int) -> Dictionary:
	var safe_level: int = maxi(1, level)
	var theme_idx: int = int((safe_level - 1) / 5) % THEMES.size()
	return THEMES[theme_idx]

## Public API to update level and trigger dynamic theme transitions
func set_level(level: int, animate: bool = true) -> void:
	current_level = level
	var active_th := MonetizationManager.get_active_background_theme() if is_instance_valid(MonetizationManager) else "auto"
	if active_th != "auto":
		apply_theme_by_id(active_th, animate)
		return
		
	var new_theme_idx: int = int((maxi(1, level) - 1) / 5) % THEMES.size()
	var theme_data: Dictionary = THEMES[new_theme_idx]
	
	var theme_changed_flag: bool = (new_theme_idx != current_theme_idx)
	current_theme_idx = new_theme_idx
	active_theme = theme_data
	
	_apply_theme(theme_data, animate)
	
	if theme_changed_flag:
		theme_changed.emit(theme_data, level)

func _apply_theme(theme_data: Dictionary, animate: bool) -> void:
	# 1. Shader Colors
	if bg_color and bg_color.material is ShaderMaterial:
		var mat: ShaderMaterial = bg_color.material as ShaderMaterial
		if animate:
			var tween := create_tween().set_parallel(true)
			tween.tween_property(mat, "shader_parameter/felt_color", theme_data.felt_color, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "shader_parameter/secondary_color", theme_data.secondary_color, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "shader_parameter/caustic_color", theme_data.caustic_color, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "shader_parameter/gold_color", theme_data.gold_color, 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(mat, "shader_parameter/speed", theme_data.speed, 1.4)
		else:
			mat.set_shader_parameter("felt_color", theme_data.felt_color)
			mat.set_shader_parameter("secondary_color", theme_data.secondary_color)
			mat.set_shader_parameter("caustic_color", theme_data.caustic_color)
			mat.set_shader_parameter("gold_color", theme_data.gold_color)
			mat.set_shader_parameter("speed", theme_data.speed)
			
	# 2. Spawn / Update Koi Fish
	_refresh_koi(theme_data)
	
	# 3. Spawn / Update Flora
	_setup_flora(theme_data)

func _refresh_koi(theme_data: Dictionary) -> void:
	# Clear old fish
	for c in fish_container.get_children():
		c.queue_free()
		
	var species_list: Array = theme_data.get("koi_species", ["kohaku", "sanke"])
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1080, 2400)
		
	var pond_rect := Rect2(40, 80, vp_size.x - 80, vp_size.y - 160)
	
	# Spawn 3 fish with distributed starting positions (some in upper void, some in lower void)
	var spawn_y_positions := [320.0, vp_size.y - 380.0, vp_size.y * 0.5]
	for i in range(species_list.size()):
		var koi := Node2D.new()
		koi.set_script(KoiFishScript)
		fish_container.add_child(koi)
		
		var spawn_pos := Vector2(
			randf_range(120, vp_size.x - 120),
			spawn_y_positions[i % spawn_y_positions.size()] + randf_range(-100, 100)
		)
		koi.setup(species_list[i], spawn_pos)
		koi.set_pond_bounds(pond_rect)

func _setup_flora(theme_data: Dictionary) -> void:
	flora_items.clear()
	var vp_size := get_viewport().get_visible_rect().size
	if vp_size.x <= 0:
		vp_size = Vector2(1080, 2400)
		
	var flora_type: String = theme_data.get("flora_type", "lotus_pad")
	
	# Strategic placement in the tall 20:9 voids (top 150-450px and bottom 1500-2200px)
	# Board sits around y=600..1400, so top and bottom voids frame it gorgeously!
	var base_positions := [
		# Upper void
		Vector2(160, 240), Vector2(890, 280), Vector2(480, 360), Vector2(920, 460),
		# Left/Right edges
		Vector2(90, 860), Vector2(980, 1140),
		# Lower void
		Vector2(180, 1600), Vector2(880, 1680), Vector2(420, 1840), Vector2(780, 2040), Vector2(240, 2180)
	]
	
	for i in range(base_positions.size()):
		var base_p: Vector2 = base_positions[i]
		flora_items.append({
			"pos": base_p + Vector2(randf_range(-25, 25), randf_range(-25, 25)),
			"scale": randf_range(0.85, 1.25),
			"rot": randf() * TAU,
			"phase": randf() * TAU,
			"type": flora_type,
			"blossom": (i % 3 == 0) # 1 in 3 has a blossom
		})

## Create expanding water ripple (e.g. on tile match or water tap)
## attract: whether the koi should drift toward the disturbance. True for real
## events like a match; false for ordinary taps, or every touch would send the
## whole pond darting about and the effect would stop meaning anything.
func add_ripple(screen_pos: Vector2, strength: float = 1.0, attract: bool = true) -> void:
	# Cap concurrent ripples. A player drumming on the screen would otherwise
	# pile up unbounded draw work on exactly the budget hardware we target.
	if ripples.size() >= MAX_RIPPLES:
		ripples.remove_at(0)

	ripples.append({
		"pos": screen_pos,
		"r": 10.0 * strength,
		"max_r": 130.0 * strength,
		"a": 0.85 * strength,
		"speed": 105.0
	})

	if not attract:
		return
	# Attract fish toward ripple
	for f in fish_container.get_children():
		if f.has_method("attract_to") and randf() < 0.7:
			f.attract_to(screen_pos)

## Flow level / Overdrive hook
func set_flow_level(flow: int, is_overdrive: bool) -> void:
	if bg_color and bg_color.material is ShaderMaterial:
		var mat: ShaderMaterial = bg_color.material as ShaderMaterial
		mat.set_shader_parameter("flow_level", float(flow))
		mat.set_shader_parameter("overdrive", 1.0 if is_overdrive else 0.0)

# --- CUSTOM DRAWING IMPLEMENTATIONS ---

func _on_flora_draw() -> void:
	for item in flora_items:
		var phase: float = item["phase"]
		var rot: float = item["rot"] + sin(sim_time * 0.65 + phase) * 0.12
		var bob: Vector2 = Vector2(
			cos(sim_time * 0.45 + phase) * 7.0,
			sin(sim_time * 0.60 + phase) * 9.0
		)
		var p: Vector2 = item["pos"] + bob
		var s: float = item["scale"]
		var ftype: String = item["type"]
		
		# Draw soft water shadow first
		var shadow_col := Color(0.01, 0.03, 0.02, 0.28)
		flora_container.draw_circle(p + Vector2(10, 14), 38.0 * s, shadow_col)
		
		match ftype:
			"lotus_pad":
				_draw_lotus_pad(p, s, rot, item["blossom"])
			"night_lily":
				_draw_night_lily(p, s, rot, item["blossom"])
			"maple_leaf":
				_draw_maple_leaf(p, s, rot)
			"sakura_petal":
				_draw_sakura_petal(p, s, rot)
			"sunset_lotus":
				_draw_sunset_lotus(p, s, rot, item["blossom"])
			_:
				_draw_lotus_pad(p, s, rot, item["blossom"])

func _draw_lotus_pad(p: Vector2, s: float, rot: float, has_blossom: bool) -> void:
	# Outer darker rim
	var rim_col := Color("#0e4d37")
	flora_container.draw_circle(p, 36.0 * s, rim_col)
	# Inner vibrant emerald pad
	var pad_col := Color("#176b4d")
	flora_container.draw_circle(p, 33.0 * s, pad_col)
	# Pad notch wedge (pie cutout)
	var notch_dir := Vector2.RIGHT.rotated(rot)
	var notch_p1 := p + notch_dir.rotated(0.35) * 36.0 * s
	var notch_p2 := p + notch_dir.rotated(-0.35) * 36.0 * s
	var notch_poly := PackedVector2Array([p, notch_p1, notch_p2])
	flora_container.draw_colored_polygon(notch_poly, Color("#031913", 0.95))
	
	# Delicate leaf vein lines
	var vein_col := Color(0.22, 0.65, 0.48, 0.45)
	for a in [0.8, 1.6, 2.4, 3.2, 4.0, 4.8]:
		var dir := Vector2.RIGHT.rotated(rot + a)
		flora_container.draw_line(p, p + dir * 30.0 * s, vein_col, 1.2 * s)
		
	# Floating white/pink lotus blossom
	if has_blossom:
		var blossom_p := p + Vector2.RIGHT.rotated(rot + 2.2) * 14.0 * s
		flora_container.draw_circle(blossom_p, 12.0 * s, Color("#ffffff"))
		flora_container.draw_circle(blossom_p, 9.5 * s, Color("#f9b4cc"))
		flora_container.draw_circle(blossom_p, 4.0 * s, Color("#ffd447"))

func _draw_night_lily(p: Vector2, s: float, rot: float, has_blossom: bool) -> void:
	# Deep midnight indigo pad
	flora_container.draw_circle(p, 35.0 * s, Color("#13274e"))
	flora_container.draw_circle(p, 32.0 * s, Color("#1c386d"))
	# Notch
	var notch_dir := Vector2.RIGHT.rotated(rot)
	var notch_poly := PackedVector2Array([p, p + notch_dir.rotated(0.3) * 35.0 * s, p + notch_dir.rotated(-0.3) * 35.0 * s])
	flora_container.draw_colored_polygon(notch_poly, Color("#040d1e", 0.95))
	# Bioluminescent starlight blossom
	if has_blossom:
		var bp := p + Vector2.RIGHT.rotated(rot + 1.8) * 12.0 * s
		flora_container.draw_circle(bp, 16.0 * s, Color(0.35, 0.65, 1.0, 0.35)) # Soft blue glow
		flora_container.draw_circle(bp, 11.0 * s, Color("#eef5ff"))
		flora_container.draw_circle(bp, 7.5 * s, Color("#7eb9ff"))
		flora_container.draw_circle(bp, 3.5 * s, Color("#ffffff"))

func _draw_maple_leaf(p: Vector2, s: float, rot: float) -> void:
	# Japanese Momiji 5-lobed maple leaf
	var col_leaf := Color("#bf2c15")
	var col_accent := Color("#d65a1e")
	var stem_dir := Vector2.RIGHT.rotated(rot)
	
	# Stem
	flora_container.draw_line(p - stem_dir * 18.0 * s, p, Color("#6d1d0f"), 2.2 * s)
	
	# 5 lobes
	var angles := [-1.1, -0.55, 0.0, 0.55, 1.1]
	var lobe_lens := [22.0, 30.0, 35.0, 30.0, 22.0]
	for idx in range(angles.size()):
		var a: float = rot + angles[idx]
		var len_l: float = lobe_lens[idx] * s
		var tip := p + Vector2.RIGHT.rotated(a) * len_l
		var left_side := p + Vector2.RIGHT.rotated(a - 0.22) * (len_l * 0.6)
		var right_side := p + Vector2.RIGHT.rotated(a + 0.22) * (len_l * 0.6)
		flora_container.draw_colored_polygon(PackedVector2Array([p, left_side, tip, right_side]), col_leaf)
	
	# Center vein highlight
	flora_container.draw_circle(p, 4.0 * s, col_accent)

func _draw_sakura_petal(p: Vector2, s: float, rot: float) -> void:
	# Floating cherry blossom petals
	var petal_col := Color(0.98, 0.78, 0.85, 0.92)
	var rim_col := Color(0.92, 0.55, 0.68, 0.85)
	
	for off_a in [0.0, 1.25, 2.5]:
		var dir := Vector2.RIGHT.rotated(rot + off_a)
		var pp := p + dir * 16.0 * s
		var tip := pp + dir * 14.0 * s
		var p_left := pp + dir.rotated(-0.5) * 8.0 * s
		var p_right := pp + dir.rotated(0.5) * 8.0 * s
		flora_container.draw_colored_polygon(PackedVector2Array([pp, p_left, tip, p_right]), petal_col)
		flora_container.draw_arc(pp, 5.0 * s, 0.0, TAU, 12, rim_col, 1.2 * s)

func _draw_sunset_lotus(p: Vector2, s: float, rot: float, has_blossom: bool) -> void:
	# Dusk plum/violet pad
	flora_container.draw_circle(p, 35.0 * s, Color("#3a1344"))
	flora_container.draw_circle(p, 32.0 * s, Color("#551d63"))
	# Notch
	var notch_dir := Vector2.RIGHT.rotated(rot)
	var notch_poly := PackedVector2Array([p, p + notch_dir.rotated(0.3) * 35.0 * s, p + notch_dir.rotated(-0.3) * 35.0 * s])
	flora_container.draw_colored_polygon(notch_poly, Color("#1a061d", 0.95))
	
	if has_blossom:
		var bp := p + Vector2.RIGHT.rotated(rot + 1.5) * 12.0 * s
		flora_container.draw_circle(bp, 14.0 * s, Color(0.95, 0.35, 0.55, 0.4)) # Crimson glow
		flora_container.draw_circle(bp, 11.0 * s, Color("#f75c88"))
		flora_container.draw_circle(bp, 7.0 * s, Color("#ffa4c0"))
		flora_container.draw_circle(bp, 3.5 * s, Color("#ffe066"))

func _on_ripples_draw() -> void:
	var rip_col: Color = active_theme.get("ripple_color", Color(0.4, 0.9, 0.8))
	for r in ripples:
		var col := Color(rip_col.r, rip_col.g, rip_col.b, r["a"])
		ripples_container.draw_arc(r["pos"], r["r"], 0.0, TAU, 32, col, 2.4)
		if r["r"] > 14.0:
			var inner_col := Color(col.r, col.g, col.b, r["a"] * 0.45)
			ripples_container.draw_arc(r["pos"], r["r"] * 0.65, 0.0, TAU, 24, inner_col, 1.6)

func _on_motes_draw() -> void:
	var base_col: Color = active_theme.get("mote_color", Color(0.96, 0.82, 0.35, 0.75))
	for m in motes:
		var alpha_pulse := (sin(sim_time * 2.8 + m["phase"]) * 0.35 + 0.65) * base_col.a
		var c := Color(base_col.r, base_col.g, base_col.b, alpha_pulse)
		
		# Outer soft halo
		var halo_c := Color(c.r, c.g, c.b, alpha_pulse * 0.30)
		motes_container.draw_circle(m["pos"], m["size"] * 2.2, halo_c)
		# Core glow
		motes_container.draw_circle(m["pos"], m["size"], c)
		# Bright center pinpoint
		motes_container.draw_circle(m["pos"], m["size"] * 0.45, Color(1.0, 1.0, 1.0, alpha_pulse * 0.85))
