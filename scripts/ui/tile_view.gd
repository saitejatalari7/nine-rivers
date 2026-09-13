class_name TileView
extends Control

## Nine Rivers (九河) — Tactile 2.5D Physical Ceramic Tile View
## Dual-layer bamboo/ivory construction, dynamic contact & ambient occlusion shadows,
## authentic engraved vector artwork, and cinematic "Turn to Dust" dissolution FX.

signal tile_clicked(view: TileView)
signal tile_long_pressed(view: TileView)

const RiverTile = preload("res://scripts/core/river_tile.gd")
const DissolveShader = preload("res://assets/shaders/tile_dissolve.gdshader")
const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")

const TILE_W: float = 64.0
const TILE_H: float = 84.0
const DEPTH_3D: float = 4.0 # Physical 3D bottom extrusion matching HTML (4px)

# Luxury Ceramic & Imperial Enamel Palette (exact match to nine-rivers.html)
const COL_IVORY := Color("#fdf8ec")         # Milk-ivory ceramic face (--cream)
const COL_CREAM_TOP := Color("#fffdf6")     # Top face highlight
const COL_CREAM_BOT := Color("#f2e9d4")     # Bottom face tone (--cream-2)
const COL_BORDER := Color("#cdb98f")        # Fine ivory rim
const COL_DEEP := Color("#b79f74")          # Biscuit warm ceramic underside (--deep)

const COL_RED := Color("#c0392b")           # Imperial cinnabar vermilion
const COL_GREEN := Color("#1f7a52")         # Jade emerald green
const COL_BLUE := Color("#28527a")          # Porcelain cobalt blue
const COL_INK := Color("#232b26")           # Deep calligraphy ink
const COL_GOLD := Color("#f2c14e")          # 24k Imperial Gold
const COL_GOLD_BRIGHT := Color("#fff2b8")   # Luminous gold rim
const COL_GOLD_DARK := Color("#c2902c")     # Chased gold shadow
const DOTCOL: Array[Color] = [COL_BLUE, COL_RED, COL_GREEN]

var theme_override: String = ""

func get_effective_theme() -> String:
	if not theme_override.is_empty():
		return theme_override
	return MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"

static func get_theme_face_color(free: bool, theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	match th:
		"theme_imperial_gold":
			return Color("#fffbee") if free else Color("#f4e8c8")
		"theme_obsidian_ink":
			return Color("#1e2226") if free else Color("#14181b")
		"theme_cherry_blossom":
			return Color("#fdf7f8") if free else Color("#f2e4e7")
		_: # classic_jade
			return COL_IVORY if free else Color("#f4ece0")

static func get_theme_border_color(free: bool, theme_id: String = "") -> Color:
	if SettingsManager.high_contrast_borders:
		return Color(0.95, 0.95, 0.95, 1.0) if free else Color(0.55, 0.55, 0.55, 1.0)
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	match th:
		"theme_imperial_gold":
			return Color("#d4af37") if free else Color("#9a8235")
		"theme_obsidian_ink":
			return Color("#4a5568") if free else Color("#2d333b")
		"theme_cherry_blossom":
			return Color("#d89da4") if free else Color("#9c6d74")
		_:
			return COL_BORDER if free else Color("#baa885")

static func get_theme_back_base(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	match th:
		"theme_imperial_gold":
			return Color("#4a1210") # Imperial crimson lacquer back
		"theme_obsidian_ink":
			return Color("#0d0f12") # Basalt black back
		"theme_cherry_blossom":
			return Color("#421d28") # Dark plum rosewood back
		_:
			return COL_DEEP # Biscuit warm ceramic underside (#b79f74) from nine-rivers.html

static func get_theme_back_edge(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	match th:
		"theme_imperial_gold":
			return Color("#8c2320")
		"theme_obsidian_ink":
			return Color("#2d3748")
		"theme_cherry_blossom":
			return Color("#693040")
		_:
			return Color("#a48c62")

static func get_col_ink(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#f0f4f8") # White jade calligraphy on dark basalt
	elif th == "theme_imperial_gold":
		return Color("#2a1608") # Deep sepia lacquer ink
	elif th == "theme_cherry_blossom":
		return Color("#2e181f")
	return COL_INK

static func create_preview_tile(suit: String, rank: int, theme_id: String = "", scale_factor: float = 1.0) -> TileView:
	var tile := RiverTile.new(0, 0, 0, suit, rank)
	var view := TileView.new()
	view.theme_override = theme_id
	view.setup(tile, true)
	view.update_theme_style()
	view.custom_minimum_size = Vector2(TILE_W * scale_factor, TILE_H * scale_factor)
	view.size = view.custom_minimum_size
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func get_col_red(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#ff4757") # Radiant neon vermilion for dark basalt
	elif th == "theme_imperial_gold":
		return Color("#b22222") # Imperial royal crimson
	elif th == "theme_cherry_blossom":
		return Color("#cf3b5b") # Sakura rose cinnabar
	var mode: String = SettingsManager.color_blind_mode
	if mode in ["deuteranopia", "protanopia"]:
		return Color("#e04a3f")
	return COL_RED

static func get_col_green(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#00d2d3") # Radiant electric turquoise
	elif th == "theme_imperial_gold":
		return Color("#c69214") # Gilded antique bronze-gold
	elif th == "theme_cherry_blossom":
		return Color("#38a169") # Tender spring tea bud green
	var mode: String = SettingsManager.color_blind_mode
	if mode in ["deuteranopia", "protanopia"]:
		return Color("#008a8a")
	return COL_GREEN

static func get_col_blue(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#54a0ff") # Radiant sapphire cyan
	elif th == "theme_imperial_gold":
		return Color("#b8860b") # Chased goldenrod
	elif th == "theme_cherry_blossom":
		return Color("#6c5ce7") # Soft wisteria iris
	var mode: String = SettingsManager.color_blind_mode
	if mode == "tritanopia":
		return Color("#593570")
	return COL_BLUE

const CN_NUMS: Array[String] = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
const WINDS: Array[String] = ["東", "南", "西", "北"]
const FLOWERS: Array[String] = ["梅", "蘭", "菊", "竹"]
const SEASONS: Array[String] = ["春", "夏", "秋", "冬"]

# Canonical Mahjong Coordinate Map (viewBox 0 0 100 132)
const DOTS: Dictionary = {
	1: [[50.0, 66.0, 24.0]],
	2: [[50.0, 40.0], [50.0, 92.0]],
	3: [[30.0, 34.0], [50.0, 66.0], [70.0, 98.0]],
	4: [[32.0, 40.0], [68.0, 40.0], [32.0, 92.0], [68.0, 92.0]],
	5: [[32.0, 38.0], [68.0, 38.0], [50.0, 66.0], [32.0, 94.0], [68.0, 94.0]],
	6: [[32.0, 32.0], [68.0, 32.0], [32.0, 66.0], [68.0, 66.0], [32.0, 100.0], [68.0, 100.0]],
	7: [[30.0, 26.0], [50.0, 26.0], [70.0, 26.0], [32.0, 68.0], [68.0, 68.0], [32.0, 102.0], [68.0, 102.0]],
	8: [[32.0, 24.0], [68.0, 24.0], [32.0, 52.0], [68.0, 52.0], [32.0, 80.0], [68.0, 80.0], [32.0, 108.0], [68.0, 108.0]],
	9: [[26.0, 32.0], [50.0, 32.0], [74.0, 32.0], [26.0, 66.0], [50.0, 66.0], [74.0, 66.0], [26.0, 100.0], [50.0, 100.0], [74.0, 100.0]]
}

var tile_data: RiverTile
var is_free: bool = false
var is_selected: bool = false
var is_hinted: bool = false
var is_revealed: bool = false
var is_dissolving: bool = false # Crucial: enables full draw during Turn to Dust animation!

var press_start_time: float = 0.0
var press_start_pos: Vector2 = Vector2.ZERO
var is_pressing: bool = false
var long_press_threshold: float = 0.42
var long_press_fired: bool = false

var anim_lift: float = 0.0
var anim_shake: float = 0.0
var anim_wild_pulse: float = 0.0
var anim_hover: float = 0.0
var _hint_tween: Tween = null
var _reveal_tween: Tween = null

# StyleBoxes for pixel-crisp rounded ceramic slabs & shadows
var sb_base: StyleBoxFlat
var sb_extrusion: StyleBoxFlat
var sb_shadow: StyleBoxFlat
var sb_ambient_shadow: StyleBoxFlat

static var _bamboo_sb_cache: Dictionary = {}

static func _get_bamboo_stylebox(col: Color, radius: int) -> StyleBoxFlat:
	var key: int = (col.to_rgba32() & 0xFFFFFFFF) ^ (radius << 16)
	if not _bamboo_sb_cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(radius)
		sb.anti_aliasing = true
		sb.anti_aliasing_size = 1.0
		_bamboo_sb_cache[key] = sb
	return _bamboo_sb_cache[key]

static var cjk_font: Font = null

static func get_cjk_font() -> Font:
	if cjk_font == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray([
			"PingFang SC", "Microsoft YaHei", "Hiragino Sans GB",
			"Noto Sans CJK SC", "Noto Sans SC", "Heiti SC",
			"SimHei", "Segoe UI", "sans-serif"
		])
		sf.font_weight = 600
		sf.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		sf.oversampling = 2.0
		if ResourceLoader.exists("res://assets/fonts/NotoSerifSC.ttf"):
			var fb = load("res://assets/fonts/NotoSerifSC.ttf")
			if fb is Font:
				sf.fallbacks.append(fb)
		cjk_font = sf
	return cjk_font

func _init() -> void:
	custom_minimum_size = Vector2(TILE_W, TILE_H)
	size = custom_minimum_size
	pivot_offset = Vector2(TILE_W * 0.5, TILE_H * 0.5)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_init_styleboxes()
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

func _ready() -> void:
	if not Engine.is_editor_hint():
		if is_instance_valid(MonetizationManager) and MonetizationManager.has_signal("theme_equipped"):
			MonetizationManager.theme_equipped.connect(_on_theme_equipped)
		if is_instance_valid(SettingsManager) and SettingsManager.has_signal("setting_changed"):
			SettingsManager.setting_changed.connect(_on_setting_changed)

func _on_theme_equipped(_theme_id: String) -> void:
	update_theme_style()

func _on_setting_changed(setting_name: String, _val: Variant) -> void:
	if setting_name in ["high_contrast_borders", "color_blind_mode"]:
		update_theme_style()

func update_theme_style() -> void:
	_init_styleboxes()
	queue_redraw()

func _init_styleboxes() -> void:
	# 1. 3D Biscuit / Lacquer Underside Slab (exact match to HTML --deep #b79f74)
	sb_extrusion = StyleBoxFlat.new()
	sb_extrusion.bg_color = get_theme_back_base(get_effective_theme())
	sb_extrusion.border_color = get_theme_back_edge(get_effective_theme())
	sb_extrusion.set_corner_radius_all(8)
	sb_extrusion.anti_aliasing = true
	sb_extrusion.anti_aliasing_size = 1.0
	
	# 2. Top Ceramic Face Slab
	sb_base = StyleBoxFlat.new()
	sb_base.bg_color = get_theme_face_color(is_free or is_revealed, get_effective_theme())
	sb_base.border_color = get_theme_border_color(is_free or is_revealed, get_effective_theme())
	sb_base.set_border_width_all(1)
	sb_base.set_corner_radius_all(8)
	sb_base.anti_aliasing = true
	sb_base.anti_aliasing_size = 1.0
	
	# 3. Contact Drop Shadow
	sb_shadow = StyleBoxFlat.new()
	sb_shadow.bg_color = Color(0.01, 0.04, 0.03, 0.42)
	sb_shadow.set_corner_radius_all(9)
	sb_shadow.anti_aliasing = true
	sb_shadow.anti_aliasing_size = 2.2
	
	# 4. Ambient Occlusion Blur Shadow
	sb_ambient_shadow = StyleBoxFlat.new()
	sb_ambient_shadow.bg_color = Color(0, 0, 0, 0.18)
	sb_ambient_shadow.set_corner_radius_all(12)
	sb_ambient_shadow.anti_aliasing = true
	sb_ambient_shadow.anti_aliasing_size = 3.5

func _on_mouse_entered() -> void:
	if is_free and not is_selected and not is_dissolving:
		var tween := create_tween()
		tween.tween_property(self, "anim_hover", -3.5, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()

func _on_mouse_exited() -> void:
	if not is_selected and not is_dissolving:
		var tween := create_tween()
		tween.tween_property(self, "anim_hover", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		queue_redraw()

func setup(data: RiverTile, free_status: bool) -> void:
	tile_data = data
	is_free = free_status
	is_dissolving = false
	queue_redraw()

func get_accent_color() -> Color:
	if not tile_data:
		return COL_GOLD
	if tile_data.is_wild() or tile_data.is_open:
		return COL_GOLD
	match tile_data.suit:
		"bam":
			return COL_GREEN
		"char":
			return COL_RED
		"dot":
			return COL_BLUE
		"dragon":
			return COL_RED if tile_data.rank == 1 else (COL_GREEN if tile_data.rank == 2 else COL_BLUE)
		_:
			return COL_GOLD

func set_selected(sel: bool) -> void:
	if is_selected == sel:
		return
	is_selected = sel
	var tween := create_tween()
	if sel:
		tween.tween_property(self, "anim_lift", -8.5, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "anim_lift", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func set_free_status(free_val: bool) -> void:
	if is_free != free_val:
		is_free = free_val
		queue_redraw()

func _exit_tree() -> void:
	if is_instance_valid(_hint_tween):
		_hint_tween.kill()
		_hint_tween = null
	if is_instance_valid(_reveal_tween):
		_reveal_tween.kill()
		_reveal_tween = null

func set_hint(val: bool) -> void:
	if not val and is_instance_valid(_hint_tween) and _hint_tween.is_valid():
		_hint_tween.kill()
		_hint_tween = null
	if is_hinted != val:
		is_hinted = val
		queue_redraw()

func flash_hint(duration: float = 2.5) -> void:
	set_hint(true)
	if is_instance_valid(_hint_tween) and _hint_tween.is_valid():
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_interval(duration)
	_hint_tween.tween_callback(func(): set_hint(false))

func set_revealed(val: bool) -> void:
	if not val and is_instance_valid(_reveal_tween) and _reveal_tween.is_valid():
		_reveal_tween.kill()
		_reveal_tween = null
	if is_revealed == val:
		return
	is_revealed = val
	var tween := create_tween()
	if val:
		tween.tween_property(self, "anim_lift", -5.5, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "anim_lift", 0.0, 0.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	queue_redraw()

func flash_revealed(duration: float = 4.0) -> void:
	set_revealed(true)
	if is_instance_valid(_reveal_tween) and _reveal_tween.is_valid():
		_reveal_tween.kill()
	_reveal_tween = create_tween()
	_reveal_tween.tween_interval(duration)
	_reveal_tween.tween_callback(func(): set_revealed(false))

func play_wrong_shake() -> void:
	var tween := create_tween()
	tween.tween_property(self, "anim_shake", 7.0, 0.05)
	tween.tween_property(self, "anim_shake", -7.0, 0.05)
	tween.tween_property(self, "anim_shake", 4.0, 0.05)
	tween.tween_property(self, "anim_shake", 0.0, 0.05)

func play_clear_animation() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_dissolving = true
	z_index += 300 # Bring dissolving tile above all others during disintegration
	
	# Instantiate runtime Voronoi burning ember dissolve shader
	var mat := ShaderMaterial.new()
	mat.shader = DissolveShader
	mat.set_shader_parameter("dissolve_amount", 0.0)
	mat.set_shader_parameter("edge_thickness", 0.14)
	if tile_data and tile_data.is_glass:
		mat.set_shader_parameter("edge_color", Color(0.70, 0.92, 1.0, 1.0)) # Icy diamond cyan
		mat.set_shader_parameter("ember_color", Color(1.0, 1.0, 1.0, 1.0))
		mat.set_shader_parameter("burn_color", Color(0.35, 0.70, 0.95, 1.0))
	else:
		mat.set_shader_parameter("edge_color", Color(0.98, 0.78, 0.22, 1.0)) # 24k Golden Sand
		mat.set_shader_parameter("ember_color", Color(1.0, 0.95, 0.65, 1.0))
		mat.set_shader_parameter("burn_color", Color(0.85, 0.45, 0.10, 1.0))
	mat.set_shader_parameter("ash_drift", 36.0)
	mat.set_shader_parameter("tile_size", size if size.x > 0 else Vector2(64.0, 84.0))
	material = mat
	
	var tween := create_tween()
	# Step 1: 0.06s Anticipation scale pop & radiant gold flash
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(1.8, 1.7, 1.3, 1.0), 0.06)
	
	# Step 2: Incense smoke vaporization & upward levitation
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_method(func(val: float):
		if is_instance_valid(mat):
			mat.set_shader_parameter("dissolve_amount", val)
		queue_redraw()
	, 0.0, 1.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(self, "position:y", position.y - 18.0, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "scale", Vector2(0.90, 0.90), 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	
	tween.chain().tween_callback(queue_free)

func play_strand_ripple() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

func _process(delta: float) -> void:
	if tile_data and tile_data.is_open:
		anim_wild_pulse += delta * 4.8
		queue_redraw()
		
	if is_pressing and not long_press_fired:
		if (Time.get_ticks_msec() / 1000.0) - press_start_time >= long_press_threshold:
			long_press_fired = true
			tile_long_pressed.emit(self)

func _gui_input(event: InputEvent) -> void:
	if is_dissolving:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				is_pressing = true
				long_press_fired = false
				press_start_time = Time.get_ticks_msec() / 1000.0
				press_start_pos = mb.position
			else:
				is_pressing = false
				var drag_dist: float = mb.position.distance_to(press_start_pos)
				if not long_press_fired and drag_dist < 36.0:
					tile_clicked.emit(self)
				long_press_fired = false

func _draw() -> void:
	if not tile_data:
		return
	# CRITICAL FIX: If tile is marked removed by match logic, KEEP DRAWING if is_dissolving is true!
	if tile_data.is_removed and not is_dissolving:
		return
		
	var z: int = tile_data.z
	var offset_y: float = anim_lift + anim_hover
	var offset_x: float = anim_shake
	
	# 1. Physical Drop Shadows with progressive Z-depth (matching HTML data-z rules)
	if not is_dissolving:
		var shadow_y: float = 3.5 + z * 3.0
		var shadow_alpha: float = clampf(0.36 + z * 0.06, 0.36, 0.65)
		sb_shadow.bg_color = Color(0.01, 0.04, 0.03, shadow_alpha)
		var shadow_rect := Rect2(offset_x, offset_y + shadow_y, TILE_W, TILE_H - DEPTH_3D)
		draw_style_box(sb_shadow, shadow_rect)
	
	# 2. 3D Depth Underside Slab (matching HTML 0 4px 0 0 var(--deep))
	sb_extrusion.bg_color = get_theme_back_base(get_effective_theme())
	sb_extrusion.border_color = get_theme_back_edge(get_effective_theme())
	var ext_rect := Rect2(offset_x, offset_y + DEPTH_3D, TILE_W, TILE_H - DEPTH_3D)
	draw_style_box(sb_extrusion, ext_rect)
	
	# 3. Top Ceramic Face Slab (cream face + 1px border)
	var face_rect := Rect2(offset_x, offset_y, TILE_W, TILE_H - DEPTH_3D)
	sb_base.bg_color = get_theme_face_color(is_free or is_revealed, get_effective_theme())
	sb_base.border_color = get_theme_border_color(is_free or is_revealed, get_effective_theme())
	draw_style_box(sb_base, face_rect)
	
	# Top inset specular highlight line: inset 0 2px 0 rgba(255,255,255,.95)
	if is_free or is_revealed or is_dissolving:
		draw_line(face_rect.position + Vector2(6, 1.5), face_rect.position + Vector2(TILE_W - 6, 1.5), Color(1, 1, 1, 0.85), 1.2, true)
	
	# 3.5 Theme-Specific Artisan Ornamentation & Face Framing
	var cur_th: String = get_effective_theme()
	if cur_th == "theme_imperial_gold":
		_draw_imperial_gold_framing(face_rect)
	elif cur_th == "theme_obsidian_ink":
		_draw_obsidian_ink_framing(face_rect)
	elif cur_th == "theme_cherry_blossom":
		_draw_cherry_blossom_framing(face_rect)
	
	# 4. Triple Set 24k Gold Band (Bottom Bezel)
	if tile_data.size == 3:
		var band_h: float = 6.0
		var band_rect := Rect2(face_rect.position.x + 1.0, face_rect.position.y + face_rect.size.y - band_h - 1.0, TILE_W - 2.0, band_h)
		draw_rect(band_rect, COL_GOLD, true)
		draw_line(band_rect.position, band_rect.position + Vector2(band_rect.size.x, 0), Color(1, 0.95, 0.7, 0.9), 1.0, true)
		draw_line(band_rect.position + Vector2(0, band_h), band_rect.position + Vector2(band_rect.size.x, band_h), COL_GOLD_DARK, 1.0, true)
	
	# 5. Wild / Stranded Luminous Gem (elegant diamond star crest)
	if tile_data.is_wild():
		var center_pt := face_rect.position + Vector2(TILE_W - 9.0, 9.0)
		var glow_a: float = 0.70 + 0.30 * sin(anim_wild_pulse)
		# Outer soft gold halo
		draw_circle(center_pt, 6.0, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, glow_a * 0.45), true, -1.0, true)
		# 4-point Diamond jewel
		var pts := PackedVector2Array([
			center_pt + Vector2(0, -5.0),
			center_pt + Vector2(5.0, 0),
			center_pt + Vector2(0, 5.0),
			center_pt + Vector2(-5.0, 0)
		])
		draw_colored_polygon(pts, Color(COL_GOLD.r, COL_GOLD.g, COL_GOLD.b, glow_a))
		draw_circle(center_pt, 1.8, Color.WHITE, true, -1.0, true)
	
	# 5.5 Special Crystal Glass Tile Treatment (Prismatic Reflection & Diamond Crest)
	if tile_data.is_glass:
		# Prismatic ice-cyan glass border
		var glass_sb := StyleBoxFlat.new()
		glass_sb.draw_center = false
		glass_sb.border_color = Color(0.62, 0.88, 1.0, 0.85)
		glass_sb.set_border_width_all(2)
		glass_sb.set_corner_radius_all(8)
		glass_sb.anti_aliasing = true
		draw_style_box(glass_sb, face_rect)
		
		# Diagonal specular glass reflection beams
		var glint_col := Color(1.0, 1.0, 1.0, 0.45)
		draw_line(face_rect.position + Vector2(4, 22), face_rect.position + Vector2(24, 2), glint_col, 2.0, true)
		draw_line(face_rect.position + Vector2(TILE_W - 24, TILE_H - DEPTH_3D - 2), face_rect.position + Vector2(TILE_W - 4, TILE_H - DEPTH_3D - 22), glint_col, 1.5, true)
		
		# Delicate 4-point Diamond Crystal crest in top-left
		var crystal_pt := face_rect.position + Vector2(9.0, 9.0)
		var c_pts := PackedVector2Array([
			crystal_pt + Vector2(0, -4.5),
			crystal_pt + Vector2(4.5, 0),
			crystal_pt + Vector2(0, 4.5),
			crystal_pt + Vector2(-4.5, 0)
		])
		draw_colored_polygon(c_pts, Color(0.75, 0.92, 1.0, 0.95))
		draw_circle(crystal_pt, 1.5, Color.WHITE, true, -1.0, true)
	
	# 6. Selection, Reveal & Hint Overlays (matching HTML .tile.sel / .tile.hint)
	if is_selected:
		var sel_sb := StyleBoxFlat.new()
		sel_sb.draw_center = false
		sel_sb.border_color = COL_GOLD
		sel_sb.set_border_width_all(3)
		sel_sb.set_corner_radius_all(8)
		sel_sb.anti_aliasing = true
		draw_style_box(sel_sb, face_rect)
	elif is_revealed:
		var rev_sb := StyleBoxFlat.new()
		rev_sb.draw_center = false
		rev_sb.border_color = Color("#f6d860")
		rev_sb.set_border_width_all(2)
		rev_sb.set_corner_radius_all(8)
		rev_sb.anti_aliasing = true
		draw_style_box(rev_sb, face_rect)
	elif is_hinted:
		var hint_sb := StyleBoxFlat.new()
		hint_sb.draw_center = false
		hint_sb.border_color = Color("#4ce0a6")
		hint_sb.set_border_width_all(3)
		hint_sb.set_corner_radius_all(8)
		hint_sb.anti_aliasing = true
		draw_style_box(hint_sb, face_rect)
	
	# 7. Clean Canonical Artwork or Fog Shroud
	if StageModifiers.is_fog_active() and not is_free and not is_revealed:
		_draw_fog_shroud(face_rect)
	else:
		draw_canonical_face(face_rect)
	
	# 8. Frost Encasement
	if tile_data.is_frozen:
		_draw_frost_encasement(face_rect)
	
	# 9. Atmospheric Depth Wash for Blocked Tiles (matching HTML .tile.blocked::after)
	if not is_free and not is_revealed and not StageModifiers.is_fog_active() and not is_dissolving:
		_draw_atmospheric_blocked_tint(face_rect)

func _draw_atmospheric_blocked_tint(face_r: Rect2) -> void:
	# Soft warm translucent shadow wash (preserves beautiful ivory porcelain look)
	var blocked_wash := Color(0.12, 0.14, 0.12, 0.22)
	draw_rect(face_r, blocked_wash, true)
	var top_shadow := Rect2(face_r.position, Vector2(face_r.size.x, face_r.size.y * 0.40))
	draw_rect(top_shadow, Color(0.06, 0.08, 0.07, 0.10), true)

func _draw_fog_shroud(face_r: Rect2) -> void:
	var mist_col := Color(0.86, 0.91, 0.93, 0.92)
	var mist_rect := Rect2(face_r.position + Vector2(2, 2), face_r.size - Vector2(4, 4))
	draw_rect(mist_rect, mist_col, true)
	var line_col := Color(0.68, 0.77, 0.82, 0.45)
	for y_pos in range(int(mist_rect.position.y) + 8, int(mist_rect.position.y + mist_rect.size.y) - 6, 8):
		draw_line(Vector2(mist_rect.position.x + 6, y_pos), Vector2(mist_rect.position.x + mist_rect.size.x - 6, y_pos), line_col, 1.2)
	draw_canonical_glyph(face_r, "云", Color(0.45, 0.60, 0.65, 0.7), 24)

func _draw_frost_encasement(face_r: Rect2) -> void:
	var frost_rim := Color(0.65, 0.88, 1.0, 0.95)
	var frost_glaze := Color(0.70, 0.88, 1.0, 0.38)
	draw_rect(face_r.grow(1.0), frost_rim, false, 2.2)
	draw_rect(face_r, frost_glaze, true)
	var c := face_r.position + face_r.size * 0.5
	draw_line(face_r.position + Vector2(6, 6), c + Vector2(-4, -4), frost_rim, 1.5)
	draw_line(c + Vector2(-4, -4), c + Vector2(8, 2), frost_rim, 1.5)
	draw_line(c + Vector2(8, 2), face_r.position + face_r.size - Vector2(6, 6), frost_rim, 1.5)
	draw_circle(face_r.position + Vector2(face_r.size.x - 8, 8), 3.0, Color.WHITE, true)

# ================= THEME ARTISAN FRAMING & ORNAMENTATION =================
func _draw_imperial_gold_framing(face_r: Rect2) -> void:
	var frame_r := Rect2(face_r.position + Vector2(2.5, 2.5), face_r.size - Vector2(5.0, 5.0))
	# 1. 24k Gold leaf inner border
	draw_rect(frame_r, Color(0.85, 0.68, 0.22, 0.65), false, 1.0)
	
	# 2. Regal Gilded Filigree L-Brackets at 4 corners
	var fg_col := Color(0.95, 0.78, 0.25, 0.95)
	var fl: float = 5.0
	# Top-Left
	draw_line(frame_r.position + Vector2(1, 0), frame_r.position + Vector2(1, fl), fg_col, 1.4)
	draw_line(frame_r.position + Vector2(0, 1), frame_r.position + Vector2(fl, 1), fg_col, 1.4)
	# Top-Right
	var tr := frame_r.position + Vector2(frame_r.size.x, 0)
	draw_line(tr + Vector2(-1, 0), tr + Vector2(-1, fl), fg_col, 1.4)
	draw_line(tr + Vector2(0, 1), tr + Vector2(-fl, 1), fg_col, 1.4)
	# Bottom-Left
	var bl := frame_r.position + Vector2(0, frame_r.size.y)
	draw_line(bl + Vector2(1, 0), bl + Vector2(1, -fl), fg_col, 1.4)
	draw_line(bl + Vector2(0, -1), bl + Vector2(fl, -1), fg_col, 1.4)
	# Bottom-Right
	var br := frame_r.position + frame_r.size
	draw_line(br + Vector2(-1, 0), br + Vector2(-1, -fl), fg_col, 1.4)
	draw_line(br + Vector2(0, -1), br + Vector2(-fl, -1), fg_col, 1.4)

func _draw_obsidian_ink_framing(face_r: Rect2) -> void:
	var inner_r := Rect2(face_r.position + Vector2(2.0, 2.0), face_r.size - Vector2(4.0, 4.0))
	# Sleek slate chamfer
	draw_rect(inner_r, Color(0.28, 0.35, 0.44, 0.40), false, 1.0)
	# Subtle moonlit basalt reflection glint
	draw_line(inner_r.position + Vector2(4, 1), inner_r.position + Vector2(inner_r.size.x - 4, 1), Color(0.55, 0.75, 0.92, 0.35), 1.0)

func _draw_cherry_blossom_framing(face_r: Rect2) -> void:
	var frame_r := Rect2(face_r.position + Vector2(2.5, 2.5), face_r.size - Vector2(5.0, 5.0))
	# Rose-gold hairline border
	draw_rect(frame_r, Color(0.85, 0.55, 0.62, 0.45), false, 1.0)
	# Subtle sakura petal motifs in top-left and bottom-right corners
	var petal_col := Color(0.95, 0.65, 0.75, 0.75)
	var tl_pos := frame_r.position + Vector2(4, 4)
	draw_circle(tl_pos, 1.6, petal_col)
	draw_circle(tl_pos + Vector2(2, 2), 1.2, petal_col)
	var br_pos := frame_r.position + frame_r.size - Vector2(4, 4)
	draw_circle(br_pos, 1.6, petal_col)
	draw_circle(br_pos - Vector2(2, 2), 1.2, petal_col)

# ================= CANONICAL ARTWORK (EXACT MATCH TO NINE-RIVERS.HTML) =================
func draw_canonical_face(face_r: Rect2) -> void:
	var th: String = get_effective_theme()
	match tile_data.suit:
		"dot":
			draw_canonical_dots(face_r, tile_data.rank)
		"bam":
			draw_canonical_bamboos(face_r, tile_data.rank)
		"char":
			draw_canonical_characters(face_r, tile_data.rank)
		"wind":
			var w_str := WINDS[tile_data.rank - 1] if tile_data.rank <= WINDS.size() else "東"
			draw_canonical_glyph(face_r, w_str, get_col_ink(th), 38)
		"dragon":
			match tile_data.rank:
				1: draw_canonical_glyph(face_r, "中", get_col_red(th), 38)
				2: draw_canonical_glyph(face_r, "發", get_col_green(th), 38)
				3: draw_white_dragon_frame(face_r)
		"flower":
			var f_str := FLOWERS[tile_data.rank - 1] if tile_data.rank <= FLOWERS.size() else "花"
			draw_canonical_glyph(face_r, f_str, get_col_green(th), 30)
		"season":
			var s_str := SEASONS[tile_data.rank - 1] if tile_data.rank <= SEASONS.size() else "季"
			draw_canonical_glyph(face_r, s_str, get_col_blue(th), 30)

func draw_white_dragon_frame(face_r: Rect2) -> void:
	var th: String = get_effective_theme()
	var scale_x: float = face_r.size.x / 100.0
	var scale_y: float = face_r.size.y / 132.0
	var col := get_col_blue(th)
	if th == "theme_imperial_gold":
		col = Color("#d49826") # 24k Gold frame
	elif th == "theme_obsidian_ink":
		col = Color("#38bdf8") # Radiant electric cyan frame
	elif th == "theme_cherry_blossom":
		col = Color("#cf3b5b") # Soft rose cinnabar frame
	
	# Outer rounded rectangle (64x82, rx=7, stroke=7 in 100x132 viewBox)
	var sb_outer := StyleBoxFlat.new()
	sb_outer.draw_center = false
	sb_outer.border_color = col
	sb_outer.set_border_width_all(int(round(4.0 * (scale_x / 0.64))))
	sb_outer.set_corner_radius_all(int(round(7.0 * scale_x)))
	sb_outer.anti_aliasing = true
	sb_outer.anti_aliasing_size = 1.0
	var outer_r := Rect2(face_r.position.x + 18.0 * scale_x, face_r.position.y + 26.0 * scale_y, 64.0 * scale_x, 82.0 * scale_y)
	draw_style_box(sb_outer, outer_r)
	
	# Inner rounded rectangle (38x56, rx=5, stroke=3.4 in 100x132 viewBox)
	var sb_inner := StyleBoxFlat.new()
	sb_inner.draw_center = false
	sb_inner.border_color = col
	sb_inner.set_border_width_all(int(round(2.0 * (scale_x / 0.64))))
	sb_inner.set_corner_radius_all(int(round(5.0 * scale_x)))
	sb_inner.anti_aliasing = true
	sb_inner.anti_aliasing_size = 1.0
	var inner_r := Rect2(face_r.position.x + 31.0 * scale_x, face_r.position.y + 39.0 * scale_y, 38.0 * scale_x, 56.0 * scale_y)
	draw_style_box(sb_inner, inner_r)

func draw_canonical_characters(face_r: Rect2, rank: int) -> void:
	var th: String = get_effective_theme()
	var font := get_cjk_font()
	var num_str: String = CN_NUMS[rank] if rank < CN_NUMS.size() else str(rank)
	var cx: float = face_r.position.x + face_r.size.x * 0.5
	var cy: float = face_r.position.y + face_r.size.y * 0.5
	
	var top_sz: int = int(face_r.size.x * 0.46) # ~29px
	var bot_sz: int = int(face_r.size.x * 0.38) # ~24px
	
	if th == "theme_imperial_gold":
		# 24k Gilded gold engraving with warm chased depth
		draw_string(font, Vector2(cx - top_sz * 0.5 + 1.0, cy - 2.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color("#6d460e"))
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 3.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color("#d49826"))
		draw_string(font, Vector2(cx - top_sz * 0.5 - 0.5, cy - 3.5), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color(1.0, 0.95, 0.70, 0.45))
		
		# 萬 in royal crimson lacquer
		draw_string(font, Vector2(cx - bot_sz * 0.5 + 1.0, cy + bot_sz * 0.95 + 1.0), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, Color("#4a0e12"))
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.95), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, Color("#b22222"))
	elif th == "theme_obsidian_ink":
		# Luminescent white-jade glyph with electric cyan glow
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 3.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color(0, 0.85, 0.8, 0.35))
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 3.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color("#f0f4f8"))
		# 萬 in radiant neon vermilion
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.95), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, Color("#ff4757"))
	else:
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 3.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, get_col_ink(th))
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.95), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, get_col_red(th))

func draw_canonical_glyph(face_r: Rect2, text: String, col: Color, font_size: int) -> void:
	var th: String = get_effective_theme()
	var font := get_cjk_font()
	var cx: float = face_r.position.x + face_r.size.x * 0.5
	var cy: float = face_r.position.y + face_r.size.y * 0.5
	
	if th == "theme_imperial_gold":
		if text == "發":
			# Gilded 24k Gold Prosperity character
			draw_string(font, Vector2(cx - font_size * 0.5 + 1.2, cy + font_size * 0.36 + 1.2), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color("#6d460e"))
			draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color("#d49826"))
			draw_string(font, Vector2(cx - font_size * 0.5 - 0.5, cy + font_size * 0.36 - 0.5), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color(1.0, 0.95, 0.70, 0.55))
			return
		elif text == "中":
			draw_string(font, Vector2(cx - font_size * 0.5 + 1.0, cy + font_size * 0.36 + 1.0), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color("#4a0e12"))
			draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color("#b22222"))
			return
	elif th == "theme_obsidian_ink":
		# Soft glowing halo on dark volcanic stone
		draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, Color(col.r, col.g, col.b, 0.35))
		draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, col)
		return
		
	draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, col)

func draw_canonical_dots(face_r: Rect2, n: int) -> void:
	var th: String = get_effective_theme()
	var pts_list: Array = DOTS.get(n, [])
	var default_r: float = 9.5 if n >= 8 else (10.5 if n == 9 else 12.5)
	var scale_x: float = face_r.size.x / 100.0
	var scale_y: float = face_r.size.y / 132.0
	var dot_colors: Array[Color] = [get_col_blue(th), get_col_red(th), get_col_green(th)]
	var core_col := get_theme_face_color(true, th)
	if th == "theme_obsidian_ink":
		core_col = Color("#0f1317")
	elif th == "theme_imperial_gold":
		core_col = Color("#fff9e8")
	
	for i in range(pts_list.size()):
		var p: Array = pts_list[i]
		var cx: float = face_r.position.x + p[0] * scale_x
		var cy: float = face_r.position.y + p[1] * scale_y
		var r_val: float = (p[2] if p.size() > 2 else default_r) * scale_x
		var col: Color = dot_colors[(i + n) % 3]
		var center := Vector2(cx, cy)
		
		# 1. Outer colored enameled circle
		draw_circle(center, r_val, col, true, -1.0, true)
		# 2. Inner circle core
		draw_circle(center, r_val * 0.42, core_col, true, -1.0, true)

func draw_canonical_bamboos(face_r: Rect2, n: int) -> void:
	var th: String = get_effective_theme()
	var pts_list: Array = DOTS.get(n, [])
	var scale_x: float = face_r.size.x / 100.0
	var scale_y: float = face_r.size.y / 132.0
	var g_col := get_col_green(th)
	var r_col := get_col_red(th)
	var cream_line_col := get_theme_face_color(true, th)
	if th == "theme_obsidian_ink":
		cream_line_col = Color("#f0f4f8")
	elif th == "theme_imperial_gold":
		cream_line_col = Color("#fff8e1")
	
	for i in range(pts_list.size()):
		var p: Array = pts_list[i]
		var is_big: bool = p.size() > 2
		var w: float = (17.0 if is_big else 12.0) * scale_x
		var h: float = (48.0 if is_big else 27.0) * scale_y
		var x: float = face_r.position.x + (p[0] - (17.0 if is_big else 12.0) * 0.5) * scale_x
		var y: float = face_r.position.y + (p[1] - (48.0 if is_big else 27.0) * 0.5) * scale_y
		var col: Color = r_col if (i % 3 == 1) else g_col
		
		# Rounded pill capsule
		var sb := _get_bamboo_stylebox(col, int(round(w * 0.5)))
		draw_style_box(sb, Rect2(x, y, w, h))
		
		# Crisp dividing line across the middle
		var cy: float = face_r.position.y + p[1] * scale_y
		draw_line(Vector2(x + 1.2, cy), Vector2(x + w - 1.2, cy), cream_line_col, 2.0 * scale_x, true)


