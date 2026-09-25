class_name UITheme
extends RefCounted

## Nine Rivers — Luxury Zen Roguelite Design System & Theme Engine
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

# ================= TYPE SCALE =================
## Design-space px. canvas_items + "expand" is width-bound and Android pins
## width to ~360-412dp, so 3 design px = 1dp; divide by 3 for sp.
const FS_CAPTION: int = 36    # 12sp - units, counts, secondary metadata
const FS_BODY: int = 42       # 14sp - default body copy
const FS_BODY_LG: int = 48    # 16sp - primary row text and button labels
const FS_TITLE: int = 60      # 20sp - screen and section headers
const FS_DISPLAY: int = 84    # 28sp - hero numerals

## Minimum tappable size; Material and the Apple HIG both land on ~48dp.
const TOUCH_MIN: float = 144.0   # 48dp

# ================= FONTS =================
## Outfit.ttf is variable and defaults to Thin (100), so a weight must always
## be requested explicitly - 400 is as much an override as 700.
const W_REGULAR: int = 400
const W_MEDIUM: int = 500
const W_SEMIBOLD: int = 600
const W_BOLD: int = 700

static var _ui_font: Font = null
static var _ui_variations: Dictionary = {}
static var _wght_tag_cached: int = 0

static func _wght_tag() -> int:
	if _wght_tag_cached == 0:
		var ts := TextServerManager.get_primary_interface()
		# 0x77676874 is "wght" packed big-endian; only a fallback if the
		# interface is somehow unavailable.
		_wght_tag_cached = ts.name_to_tag("wght") if ts != null else 0x77676874
	return _wght_tag_cached
static var _cjk_font: Font = null
static var _title_font: Font = null
static var _glyph_font: Font = null

## Inline UI symbols are in none of the bundled faces; without this they fall
## through to whatever the device ships. Built by tools/make_ui_glyphs.py.
static func get_glyph_font() -> Font:
	if _glyph_font == null:
		if ResourceLoader.exists("res://assets/fonts/NineRiversGlyphs.ttf"):
			_glyph_font = load("res://assets/fonts/NineRiversGlyphs.ttf")
	return _glyph_font

## Chains the symbol and CJK faces behind `font` so a Latin label can render
## 玉 and ◈ from bundled fonts.
static func _with_fallbacks(font: Font, include_cjk: bool = true) -> Font:
	if font == null:
		return null
	var chain: Array[Font] = []
	var g := get_glyph_font()
	if g != null:
		chain.append(g)
	if include_cjk:
		var c := get_cjk_font()
		if c != null:
			chain.append(c)
	font.fallbacks = chain
	return font

static func get_ui_font() -> Font:
	if _ui_font == null:
		if ResourceLoader.exists("res://assets/fonts/Outfit.ttf"):
			_ui_font = _with_fallbacks(load("res://assets/fonts/Outfit.ttf"))
	return _ui_font

static func get_cjk_font() -> Font:
	if _cjk_font == null:
		if ResourceLoader.exists("res://assets/fonts/NotoSerifSC.ttf"):
			# include_cjk false: chaining the CJK face behind itself recurses.
			_cjk_font = _with_fallbacks(load("res://assets/fonts/NotoSerifSC.ttf"), false)
	return _cjk_font

static func get_title_font() -> Font:
	if _title_font == null:
		if ResourceLoader.exists("res://assets/fonts/MaShanZheng-Regular.ttf"):
			_title_font = _with_fallbacks(load("res://assets/fonts/MaShanZheng-Regular.ttf"))
		elif _cjk_font != null:
			_title_font = _cjk_font
	return _title_font

## A weighted, optionally letter-spaced instance of the UI face.
##   weight   - OpenType wght axis, 100-900
##   tracking - extra pixels between glyphs, for tracked uppercase labels
static func get_ui_variation(weight: int = W_REGULAR, tracking: int = 0) -> Font:
	var base := get_ui_font()
	if base == null:
		return null
	var key := "%d/%d" % [weight, tracking]
	if _ui_variations.has(key):
		return _ui_variations[key]
	var fv := FontVariation.new()
	fv.base_font = base
	# The key MUST be the numeric OpenType tag. A String key ("wght") is
	# accepted without error and then silently ignored, which is exactly how
	# this went unnoticed: spacing_glyph still applied, so the variation
	# looked live while the weight axis did nothing.
	fv.variation_opentype = { _wght_tag(): float(weight) }
	if tracking != 0:
		fv.spacing_glyph = tracking
	_ui_variations[key] = fv
	return fv

static func style_label(
	lbl: Label,
	font_type: String = "ui",
	size: int = 20,
	color: Color = IVORY_BASE,
	weight: int = W_REGULAR,
	tracking: int = 0
) -> void:
	var font: Font = null
	match font_type:
		"title":
			font = get_title_font()
		"cjk":
			font = get_cjk_font()
		_:
			font = get_ui_variation(weight, tracking)
	if font != null:
		lbl.add_theme_font_override("font", font)
	if size > 0:
		lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)

# ================= PRESS FEEDBACK =================
## Fires on button_down, not pressed, so feedback lands on touch not release.
static func add_press_feedback(btn: BaseButton) -> void:
	var cb := Callable(UITheme, "_on_press_feedback")
	if not btn.is_connected("button_down", cb):
		btn.button_down.connect(cb)

static func _on_press_feedback() -> void:
	if Engine.get_main_loop() == null:
		return
	AudioManager.play_ui_tap()

## Press wash for controls without a full stylebox set.
static func create_press_wash(corner_r: int = 5) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 1, 1, 0.12)
	sb.set_corner_radius_all(corner_r)
	sb.border_width_left = 3
	sb.border_color = GOLD_CORE
	sb.anti_aliasing = true
	return sb

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
	
	var font := get_ui_variation(W_SEMIBOLD)
	if font != null:
		btn.add_theme_font_override("font", font)
	
	add_press_feedback(btn)


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
	
	var font := get_ui_variation(W_SEMIBOLD)
	if font != null:
		btn.add_theme_font_override("font", font)
	
	add_press_feedback(btn)


# ================= SAFE AREA =================
## Top/bottom insets in viewport px. Android delivers insets after the first
## frame, so callers must re-apply on size_changed; the floors exist because a
## reported zero usually means "not delivered yet".
const SAFE_TOP_FLOOR: float = 72.0      # 24dp at the 1080-wide design scale
const SAFE_BOTTOM_FLOOR: float = 144.0  # 48dp - the gesture pill

static func get_safe_insets(viewport: Viewport) -> Vector2:
	if viewport == null:
		return Vector2(SAFE_TOP_FLOOR, SAFE_BOTTOM_FLOOR)
	var vp_size: Vector2 = viewport.get_visible_rect().size
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var screen_size := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var top := SAFE_TOP_FLOOR
	var bottom := SAFE_BOTTOM_FLOOR
	if screen_size.y > 0 and safe.size.y > 0 and vp_size.y > 0:
		# The viewport is a scaled copy of the screen; convert device pixels
		# into design pixels before using them as offsets.
		var k := vp_size.y / float(screen_size.y)
		top = maxf(top, float(safe.position.y) * k)
		bottom = maxf(bottom, float(screen_size.y - (safe.position.y + safe.size.y)) * k)
	return Vector2(top, bottom)
