class_name UITheme
extends RefCounted

## Nine Rivers (九河) — Luxury Zen Roguelite Design System & Theme Engine
## Provides mastercrafted StyleBoxFlat definitions, palette tokens, and UI decorators.

# ================= PALETTE CONSTANTS =================
# Jade Baize & Obsidian Lacquer
const JADE_DARK := Color("#061c16")      # Deep river table felt
const JADE_MID := Color("#0b2920")       # Panel lacquer background
const JADE_LIGHT := Color("#164a3b")     # Border accent / surface
const JADE_GLOW := Color("#2ec492")      # Energy / hint glow

# Molten Gold Leaf
const GOLD_CORE := Color("#f5ba31")      # 24k Imperial Gold
const GOLD_BRIGHT := Color("#fff0a8")    # Specular rim highlight
const GOLD_DARK := Color("#9e6d19")      # Chased gold shadow
const GOLD_MUTED := Color("#c9a85c")     # Elegant hairline border

# Ivory Ceramic
const IVORY_BASE := Color("#faf7f0")     # Milk-ivory face
const IVORY_SHADOW := Color("#ede4d2")   # Subtle face shade
const IVORY_MUTED := Color("#cfc5b0")    # Secondary text

# Cinnabar & Accent Enamels
const RED_CINNABAR := Color("#c53026")   # Traditional Chinese vermilion
const BLUE_COBALT := Color("#1d537a")    # Traditional cobalt blue
const INK_BLACK := Color("#0d1411")      # Deepest lacquer/ink
const CARD_BG := Color(0.043, 0.118, 0.098, 0.96) # Frosted card background

# ================= FONTS =================
static var _ui_font: Font = null
static var _cjk_font: Font = null
static var _title_font: Font = null

static func get_ui_font() -> Font:
	if _ui_font == null:
		if ResourceLoader.exists("res://assets/fonts/Outfit.ttf"):
			_ui_font = load("res://assets/fonts/Outfit.ttf")
	return _ui_font

static func get_cjk_font() -> Font:
	if _cjk_font == null:
		if ResourceLoader.exists("res://assets/fonts/NotoSerifSC.ttf"):
			_cjk_font = load("res://assets/fonts/NotoSerifSC.ttf")
	return _cjk_font

static func get_title_font() -> Font:
	if _title_font == null:
		if ResourceLoader.exists("res://assets/fonts/MaShanZheng-Regular.ttf"):
			_title_font = load("res://assets/fonts/MaShanZheng-Regular.ttf")
		elif _cjk_font != null:
			_title_font = _cjk_font
	return _title_font

static func style_label(
	lbl: Label,
	font_type: String = "ui",
	size: int = 20,
	color: Color = IVORY_BASE
) -> void:
	var font: Font = null
	match font_type:
		"title":
			font = get_title_font()
		"cjk":
			font = get_cjk_font()
		_:
			font = get_ui_font()
	if font != null:
		lbl.add_theme_font_override("font", font)
	if size > 0:
		lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

# ================= STYLEBOX BUILDERS =================

static func create_panel_box(
	bg: Color = CARD_BG,
	border: Color = GOLD_MUTED,
	border_w: int = 1,
	corner_r: int = 14,
	shadow_a: float = 0.45
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(corner_r)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.2
	if shadow_a > 0.0:
		sb.shadow_color = Color(0, 0, 0, shadow_a)
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0, 4)
	return sb

static func create_button_box(
	state: String, # "normal", "hover", "pressed", "disabled"
	corner_r: int = 12,
	is_gold: bool = false
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(corner_r)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.2
	
	match state:
		"normal":
			if is_gold:
				sb.bg_color = Color("#241c08")
				sb.border_color = GOLD_CORE
				sb.set_border_width_all(2)
			else:
				sb.bg_color = Color("#0c231c")
				sb.border_color = GOLD_MUTED
				sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.35)
			sb.shadow_size = 4
			sb.shadow_offset = Vector2(0, 2)
			
		"hover":
			if is_gold:
				sb.bg_color = Color("#382b0c")
				sb.border_color = GOLD_BRIGHT
				sb.set_border_width_all(2)
			else:
				sb.bg_color = Color("#14352b")
				sb.border_color = GOLD_CORE
				sb.set_border_width_all(2)
			sb.shadow_color = Color(GOLD_CORE.r, GOLD_CORE.g, GOLD_CORE.b, 0.25)
			sb.shadow_size = 6
			sb.shadow_offset = Vector2(0, 2)
			
		"pressed":
			sb.bg_color = Color("#071712")
			sb.border_color = GOLD_DARK
			sb.set_border_width_all(1)
			sb.shadow_color = Color(0, 0, 0, 0.15)
			sb.shadow_size = 1
			sb.shadow_offset = Vector2(0, 1)
			
		"disabled":
			sb.bg_color = Color(0.08, 0.12, 0.10, 0.6)
			sb.border_color = Color(0.3, 0.38, 0.34, 0.4)
			sb.set_border_width_all(1)
			sb.shadow_size = 0
			
	return sb

static func create_talisman_circle_box(
	state: String,
	border_col: Color = GOLD_MUTED
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(99) # Circular
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.4
	
	match state:
		"normal":
			sb.bg_color = Color("#0b211a")
			sb.border_color = border_col
			sb.set_border_width_all(2)
			sb.shadow_color = Color(0, 0, 0, 0.4)
			sb.shadow_size = 5
			sb.shadow_offset = Vector2(0, 3)
		"hover":
			sb.bg_color = Color("#14362b")
			sb.border_color = GOLD_BRIGHT
			sb.set_border_width_all(2)
			sb.shadow_color = Color(GOLD_CORE.r, GOLD_CORE.g, GOLD_CORE.b, 0.35)
			sb.shadow_size = 8
			sb.shadow_offset = Vector2(0, 3)
		"pressed":
			sb.bg_color = Color("#061611")
			sb.border_color = GOLD_DARK
			sb.set_border_width_all(2)
			sb.shadow_size = 1
		"disabled":
			sb.bg_color = Color(0.06, 0.10, 0.08, 0.5)
			sb.border_color = Color(0.3, 0.38, 0.34, 0.35)
			sb.set_border_width_all(1)
			sb.shadow_size = 0
			
	return sb

static func style_button(
	btn: Button,
	is_gold: bool = false,
	corner_r: int = 12
) -> void:
	btn.add_theme_stylebox_override("normal", create_button_box("normal", corner_r, is_gold))
	btn.add_theme_stylebox_override("hover", create_button_box("hover", corner_r, is_gold))
	btn.add_theme_stylebox_override("pressed", create_button_box("pressed", corner_r, is_gold))
	btn.add_theme_stylebox_override("disabled", create_button_box("disabled", corner_r, is_gold))
	btn.add_theme_stylebox_override("focus", create_button_box("hover", corner_r, is_gold))
	
	btn.add_theme_color_override("font_color", IVORY_BASE)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", GOLD_CORE)
	btn.add_theme_color_override("font_disabled_color", Color(0.48, 0.58, 0.54, 0.6))
	
	var font := get_ui_font()
	if font != null:
		btn.add_theme_font_override("font", font)
	
	# Connect micro-animations for hover & press
	if not btn.is_connected("mouse_entered", Callable(UITheme, "_on_button_hover")):
		btn.mouse_entered.connect(Callable(UITheme, "_on_button_hover").bind(btn))
		btn.mouse_exited.connect(Callable(UITheme, "_on_button_unhover").bind(btn))

static func style_circular_button(
	btn: Button,
	border_col: Color = GOLD_MUTED
) -> void:
	btn.add_theme_stylebox_override("normal", create_talisman_circle_box("normal", border_col))
	btn.add_theme_stylebox_override("hover", create_talisman_circle_box("hover", border_col))
	btn.add_theme_stylebox_override("pressed", create_talisman_circle_box("pressed", border_col))
	btn.add_theme_stylebox_override("disabled", create_talisman_circle_box("disabled", border_col))
	btn.add_theme_stylebox_override("focus", create_talisman_circle_box("hover", border_col))
	
	btn.add_theme_color_override("font_color", GOLD_CORE)
	btn.add_theme_color_override("font_hover_color", GOLD_BRIGHT)
	btn.add_theme_color_override("font_pressed_color", GOLD_DARK)
	btn.add_theme_color_override("font_disabled_color", Color(0.4, 0.5, 0.46, 0.5))
	
	var font := get_ui_font()
	if font != null:
		btn.add_theme_font_override("font", font)
	
	if not btn.is_connected("mouse_entered", Callable(UITheme, "_on_button_hover")):
		btn.mouse_entered.connect(Callable(UITheme, "_on_button_hover").bind(btn))
		btn.mouse_exited.connect(Callable(UITheme, "_on_button_unhover").bind(btn))

static func _on_button_hover(btn: Button) -> void:
	if btn.disabled:
		return
	btn.pivot_offset = btn.size * 0.5
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2(1.035, 1.035), 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

static func _on_button_unhover(btn: Button) -> void:
	var tween := btn.create_tween()
	tween.tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
