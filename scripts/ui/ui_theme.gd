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

# ================= TYPE SCALE =================
## Sizes are in the 1080-wide DESIGN space, not device pixels.
##
## The stretch mode is canvas_items with aspect "expand", which is WIDTH-bound:
## the 1080 design width is mapped onto the device width whatever the height.
## Android pins usable width to roughly 360-412dp across nearly every phone in
## the market, so 1080 design px lands on ~360dp - i.e. 3 design px per dp, and
## a design size divided by 3 gives you sp. This is a property of the stretch
## mode, not of screen density: a 1080p phone and a 1440p phone both land here.
##
## Below FS_CAPTION, text stops being reliably readable at arm's length, and
## Android accessibility guidance treats 12sp as the floor for any text a user
## has to act on.
const FS_CAPTION: int = 36    # 12sp - units, counts, secondary metadata
const FS_BODY: int = 42       # 14sp - default body copy
const FS_BODY_LG: int = 48    # 16sp - primary row text and button labels
const FS_TITLE: int = 60      # 20sp - screen and section headers
const FS_DISPLAY: int = 84    # 28sp - hero numerals

## Minimum size for anything tappable. Both Material and the Apple HIG land on
## the same ~48dp / 9mm figure, which is the width of an adult fingertip's
## contact patch; below it, miss rates climb sharply.
const TOUCH_MIN: float = 144.0   # 48dp

# ================= FONTS =================
## Weights we actually use. Outfit.ttf is a VARIABLE font whose default
## instance is Thin (wght 100) - so every label in the game was rendering in
## hairline Thin, which is most of why small text read as unreadable and why
## the build never matched the design mockups. Asking for a weight explicitly
## is not optional here; 400 is as much an override as 700 is.
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
	
	var font := get_ui_variation(W_SEMIBOLD)
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

# ================= SAFE AREA =================
## Top and bottom insets in VIEWPORT pixels, for notches, status bars and
## gesture pills.
##
## Two things make this harder than it looks:
##
## 1. targetSdk 35 forces edge-to-edge on Android 15, so the window extends
##    behind both system bars. Content that used a small fixed inset now sits
##    underneath them.
## 2. Android delivers insets via onApplyWindowInsets AFTER the first frame,
##    so querying during _ready() usually reports the full screen and yields
##    zero inset. Callers must re-apply on size_changed as well.
##
## A floor is applied because a reported inset of zero is more often "not
## delivered yet" than "genuinely no inset". Reserving space that turns out to
## be unnecessary costs a little layout; not reserving it puts the UI under the
## status bar.
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
