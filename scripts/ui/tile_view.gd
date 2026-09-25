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
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

const TILE_W: float = 64.0
const TILE_H: float = 84.0
const DEPTH_3D: float = 4.0 # Physical 3D bottom extrusion matching HTML (4px)

# Luxury Ceramic & Imperial Enamel Palette (exact match to nine-rivers.html)
const COL_IVORY := Color("#fdf8ec")         # Milk-ivory ceramic face (--cream)
const COL_CREAM_TOP := Color("#fffdf6")     # Top face highlight
const COL_CREAM_BOT := Color("#f2e9d4")     # Bottom face tone (--cream-2)
const COL_BORDER := Color("#cdb98f")        # Fine ivory rim
const COL_DEEP := Color("#b79f74")          # Biscuit warm ceramic underside (--deep)

const COL_RED := Color("#b03225")           # Imperial cinnabar vermilion
const COL_GREEN := Color("#1b6d49")         # Jade emerald green
const COL_BLUE := Color("#28527a")          # Porcelain cobalt blue
const COL_INK := Color("#232b26")           # Deep calligraphy ink
const COL_GOLD := Color("#f2c14e")          # 24k Imperial Gold
const COL_GOLD_BRIGHT := Color("#fff2b8")   # Luminous gold rim
const COL_GOLD_DARK := Color("#c2902c")     # Chased gold shadow
const DOTCOL: Array[Color] = [COL_BLUE, COL_RED, COL_GREEN]

var theme_override: String = ""

## Draw the Blender-rendered tile body instead of flat StyleBoxFlat slabs.
## Kept as a switch so the two can be compared on a real device: the whole
## point of the art pass is a judgement that can only be made on a phone.
const USE_RENDERED_BODY: bool = true

const BODY_TEX_DIR := "res://assets/tiles/"
const BODY_TEX_FILES: Dictionary = {
	# Frosted white, not the original warm body: dark inks on near-white took
	# this theme from failing every legibility check to passing every one.
	"classic_jade": "tile_frost.png",
	# Dark antique bronze. The mid-gold body put pale ink on a pale-ish face and
	# merged every tile with its neighbour on a full board; the same inks read as
	# gilding against bronze.
	"theme_imperial_gold": "tile_gold.png",
	"theme_obsidian_ink": "tile_obsidian_ink.png",
	"theme_cherry_blossom": "tile_cherry_blossom.png",
	# Earned only, never sold. Deep polished indigo, so the ink has to be pale -
	# the same inversion Imperial Gold went through in reverse.
	"theme_indigo": "tile_indigo.png",
}

## theme_id -> Texture2D, or null when the file is missing. Cached across every
## tile: there are up to 144 on screen and they share four textures.
static var _body_tex_cache: Dictionary = {}

## Test-only: suppresses the suit artwork so a probe can diff a drawn tile
## against a bare body and isolate the ink. Never set outside scripts/tests.
static var debug_skip_artwork: bool = false

## How much a blocked tile darkens. Multiplying toward black is right only
## while the ink is lighter than the face: on a dark-ink theme it drags the
## face down toward the ink and costs the contrast that made the ink readable.
## Imperial Gold went to 2.63 against a 3.0 floor at the shared 0.86.
const BLOCKED_TINT: Dictionary = {
	"theme_imperial_gold": Color(0.90, 0.89, 0.85, 1.0),
	"theme_indigo": Color(0.72, 0.74, 0.80, 1.0),
}
const BLOCKED_TINT_DEFAULT := Color(0.86, 0.86, 0.84, 1.0)

static var _normal_tex: Texture2D = null

## Pairs the body art with the shared bevel normal map. The silhouette is the
## same for every theme, so one normal map serves all four.
static func _get_normal_tex() -> Texture2D:
	if _normal_tex == null and ResourceLoader.exists(BODY_TEX_DIR + "tile_normal.png"):
		_normal_tex = load(BODY_TEX_DIR + "tile_normal.png")
	return _normal_tex


static func get_body_texture(theme_id: String) -> Texture2D:
	if _body_tex_cache.has(theme_id):
		return _body_tex_cache[theme_id]
	var tex: Texture2D = null
	var fname: String = String(BODY_TEX_FILES.get(theme_id, ""))
	if not fname.is_empty():
		var path := BODY_TEX_DIR + fname
		if ResourceLoader.exists(path):
			tex = load(path) as Texture2D
	var nrm: Texture2D = _get_normal_tex()
	if tex != null and nrm != null:
		# CanvasTexture is what carries a normal map into 2D drawing; a plain
		# Texture2D is lit as though it were flat however many lights are up.
		var ct := CanvasTexture.new()
		ct.diffuse_texture = tex
		ct.normal_texture = nrm
		var s: float = TileLighting.specular()
		ct.specular_color = Color(s, s * 0.98, s * 0.94)
		ct.specular_shininess = 0.35
		tex = ct
	_body_tex_cache[theme_id] = tex
	return tex

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
		# Dark ink on a bright gold face, the way a real gold-lacquer tile is cut.
		# The face had to be brightened to carry it: black on the old dark gold
		# measured 2.8, below the 3.0 floor.
		return Color("#16100a")
	elif th == "theme_indigo":
		return Color("#f4e6bd") # Pale gold on deep glaze
	elif th == "theme_cherry_blossom":
		return Color("#1b1015")
	return COL_INK

static func create_preview_tile(suit: String, rank: int, theme_id: String = "", scale_factor: float = 1.0) -> TileView:
	var tile := RiverTile.new(0, 0, 0, suit, rank)
	var view := TileView.new()
	view.theme_override = theme_id
	view.setup(tile, true)
	view.update_theme_style()
	view.custom_minimum_size = Vector2(TILE_W * scale_factor, TILE_H * scale_factor)
	view.size = view.custom_minimum_size
	# _draw works in fixed TILE_W x TILE_H units, so a bigger box on its own just
	# left a small tile floating in it. The node has to be scaled, from its top
	# left, so the drawing grows with the box a container lays out.
	view.pivot_offset = Vector2.ZERO
	view.scale = Vector2(scale_factor, scale_factor)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view

static func get_col_red(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#ff4757") # Radiant neon vermilion for dark basalt
	elif th == "theme_imperial_gold":
		return Color("#7a1410") # Deep cinnabar lacquer
	elif th == "theme_indigo":
		return Color("#ffab96") # Pale coral
	elif th == "theme_cherry_blossom":
		return Color("#6d1029") # Sakura rose cinnabar, cut deeper for a pale face
	var mode: String = SettingsManager.color_blind_mode
	if mode in ["deuteranopia", "protanopia"]:
		return Color("#b83a2e")
	return COL_RED

static func get_col_green(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#00d2d3") # Radiant electric turquoise
	elif th == "theme_imperial_gold":
		return Color("#10402a") # Deep malachite
	elif th == "theme_indigo":
		return Color("#a8e0bd") # Pale celadon
	elif th == "theme_cherry_blossom":
		return Color("#1d3a17") # Tender spring tea bud green
	var mode: String = SettingsManager.color_blind_mode
	if mode in ["deuteranopia", "protanopia"]:
		return Color("#006e6e")
	return COL_GREEN

static func get_col_blue(theme_id: String = "") -> Color:
	var th: String = theme_id
	if th.is_empty():
		th = MonetizationManager.get_active_theme() if Engine.has_singleton("MonetizationManager") or is_instance_valid(MonetizationManager) else "classic_jade"
	if th == "theme_obsidian_ink":
		return Color("#54a0ff") # Radiant sapphire cyan
	elif th == "theme_imperial_gold":
		return Color("#14243f") # Deep cobalt
	elif th == "theme_indigo":
		return Color("#bcd4ff") # Pale porcelain sky
	elif th == "theme_cherry_blossom":
		return Color("#2b2470") # Soft wisteria iris
	var mode: String = SettingsManager.color_blind_mode
	if mode == "tritanopia":
		return Color("#593570")
	return COL_BLUE

const CN_NUMS: Array[String] = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
const WINDS: Array[String] = ["東", "南", "西", "北"]
const FLOWERS: Array[String] = ["梅", "蘭", "菊", "竹"]
const SEASONS: Array[String] = ["春", "夏", "秋", "冬"]

# Canonical Mahjong Coordinate Map (viewBox 0 0 100 132)
#
# Positions were spread and the radii enlarged so a face fills roughly three
# quarters of its tile rather than half. The old table left 2-dot spanning 29%
# of the width and bamboo 2 spanning 13%, which is what "the symbols are tiny"
# was pointing at. Each radius is the largest that keeps neighbouring circles
# from touching at that rank's spacing.
const DOTS: Dictionary = {
	1: [[50.0, 66.0]],
	2: [[50.0, 38.0], [50.0, 94.0]],
	3: [[29.0, 33.0], [50.0, 66.0], [71.0, 99.0]],
	4: [[30.0, 37.0], [70.0, 37.0], [30.0, 95.0], [70.0, 95.0]],
	5: [[30.0, 34.0], [70.0, 34.0], [50.0, 66.0], [30.0, 98.0], [70.0, 98.0]],
	6: [[30.0, 30.0], [70.0, 30.0], [30.0, 66.0], [70.0, 66.0], [30.0, 102.0], [70.0, 102.0]],
	7: [[23.0, 24.0], [50.0, 24.0], [77.0, 24.0], [30.0, 66.0], [70.0, 66.0], [30.0, 106.0], [70.0, 106.0]],
	8: [[30.0, 25.0], [70.0, 25.0], [30.0, 52.0], [70.0, 52.0], [30.0, 79.0], [70.0, 79.0], [30.0, 106.0], [70.0, 106.0]],
	9: [[24.0, 30.0], [50.0, 30.0], [76.0, 30.0], [24.0, 66.0], [50.0, 66.0], [76.0, 66.0], [24.0, 102.0], [50.0, 102.0], [76.0, 102.0]]
}

## Circle radius per rank, in the same viewBox units. Split out of DOTS because
## the old third element doubled as bamboo's "this is the big stalk" flag, so a
## radius could not be given to any other rank without turning its bamboo into
## a full-height pill.
const DOT_R: Dictionary = {
	1: 30.0, 2: 24.0, 3: 18.0, 4: 18.0, 5: 17.0,
	6: 17.0, 7: 12.5, 8: 12.5, 9: 12.5,
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

## Tweened by hand, so each one repaints when it changes. A tween only writes
## the property; without a setter the body layer kept whatever it was drawn
## with when the tween started, which is how a lifted tile ended up separated
## from its own slab.
var anim_lift: float = 0.0:
	set(v):
		if is_equal_approx(anim_lift, v):
			return
		anim_lift = v
		_redraw_all()
var anim_shake: float = 0.0:
	set(v):
		if is_equal_approx(anim_shake, v):
			return
		anim_shake = v
		_redraw_all()
var anim_wild_pulse: float = 0.0
var anim_hover: float = 0.0:
	set(v):
		if is_equal_approx(anim_hover, v):
			return
		anim_hover = v
		_redraw_all()
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

## The bundled subset, not the device's font.
##
## This asked Android for PingFang SC, YaHei, Heiti and friends, with the
## bundled face attached only as a fallback - so the tile artwork was drawn by
## whatever the phone happened to ship. The same tile looked different on a
## Samsung, a Xiaomi and a Pixel, and on a device carrying no CJK font at all it
## would have been boxes. The UI text never did this; only the tiles deferred.
const TILE_FONT_PATH := "res://assets/fonts/NineRiversTileSC.ttf"

static func get_cjk_font() -> Font:
	if cjk_font == null:
		# Noto Sans SC Bold, subset to the 27 characters a tile face can carry:
		# 8 KB against the 8.5 MB it was cut from. The bundled NotoSerifSC was
		# tried first and measured badly - its hairline horizontals anti-alias
		# away at 64px, taking the legibility check from 0 failures to 51, and
		# emboldening it synthetically only got back to 6.
		var base = load(TILE_FONT_PATH) if ResourceLoader.exists(TILE_FONT_PATH) else null
		if base is Font:
			cjk_font = base
		else:
			# Only if the bundled face is missing from the build, which would be a
			# packaging fault rather than a device one.
			var sf := SystemFont.new()
			sf.font_names = PackedStringArray(["Noto Sans CJK SC", "sans-serif"])
			sf.font_weight = 700
			cjk_font = sf
	return cjk_font

func _init() -> void:
	custom_minimum_size = Vector2(TILE_W, TILE_H)
	# The face and its overlays opt out of lighting entirely. Only the body,
	# which carries the normal map, is a lit surface.
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	_body_layer = BodyLayer.new()
	_body_layer.view = self
	_body_layer.show_behind_parent = true
	_body_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body_layer.size = Vector2(TILE_W, TILE_H)
	add_child(_body_layer)
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
	_redraw_all()

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
		_redraw_all()

func _on_mouse_exited() -> void:
	if not is_selected and not is_dissolving:
		var tween := create_tween()
		tween.tween_property(self, "anim_hover", 0.0, 0.12).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_redraw_all()

func setup(data: RiverTile, free_status: bool) -> void:
	tile_data = data
	is_free = free_status
	is_dissolving = false
	_redraw_all()

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

## A picked-up tile draws over its neighbours; without this the lift disappears
## behind whatever is stacked in front of it.
const SELECT_Z_BOOST: int = 400
## Gold, at 4px. It went black and 5px to be more visible; the black ring read
## as a hole punched in the board and the extra weight made it heavier still.
## The lift, the scale and the shadow are what sell selection now, so the ring
## can go back to being a rim rather than a frame.
const SELECT_BORDER_W: int = 4
const SELECT_SCALE: float = 1.08

func set_selected(sel: bool) -> void:
	if is_selected == sel:
		return
	is_selected = sel
	# Lift, grow, and rise above the neighbours. On a dark felt the cast shadow
	# alone cannot carry height - there is nothing for it to darken - so the
	# scale is what makes a picked-up tile read as picked up.
	z_index += SELECT_Z_BOOST if sel else -SELECT_Z_BOOST
	var tween := create_tween()
	if sel:
		tween.tween_property(self, "anim_lift", -13.0, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "scale", Vector2(SELECT_SCALE, SELECT_SCALE), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		tween.tween_property(self, "anim_lift", 0.0, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_redraw_all()

func set_free_status(free_val: bool) -> void:
	if is_free != free_val:
		is_free = free_val
		_redraw_all()

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
		_redraw_all()

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
	_redraw_all()

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
	# The body layer takes the dissolve shader too, or the tile face burns away
	# while the slab underneath it stays whole.
	if is_instance_valid(_body_layer):
		_body_layer.material = mat
	
	var tween := create_tween()
	# Step 1: 0.06s Anticipation scale pop & radiant gold flash
	tween.tween_property(self, "scale", Vector2(1.12, 1.12), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "modulate", Color(1.8, 1.7, 1.3, 1.0), 0.06)
	
	# Step 2: Incense smoke vaporization & upward levitation
	tween.chain().tween_property(self, "modulate", Color.WHITE, 0.12)
	tween.parallel().tween_method(func(val: float):
		if is_instance_valid(mat):
			mat.set_shader_parameter("dissolve_amount", val)
		_redraw_all()
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
		_redraw_all()
		
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

## The tile body, drawn into its own CanvasItem so that lights reach it and
## nothing else.
##
## 2D lights in Godot apply per CanvasItem, not per draw call, so while the
## body and the artwork shared one node every glyph was being lit too. With an
## additive key light that washed the pale inks straight out - Imperial Gold's
## dots, which are near-white by design since the legibility pass, went to flat
## white and lost their colour. A printed glyph should not catch light anyway;
## the ceramic under it should.
class BodyLayer extends Control:
	var view = null

	func _draw() -> void:
		if view != null:
			view._draw_body(self)


var _body_layer: BodyLayer = null


## Redraws the body alongside the face. Every queue_redraw() in this file goes
## through here, because the body now lives in a child that does not repaint
## just because its parent did.
func _redraw_all() -> void:
	queue_redraw()
	if is_instance_valid(_body_layer):
		_body_layer.queue_redraw()


## Test-only draw counters. Selection now repaints a tile on every frame it
## moves, which it did not before, so how far that spreads is worth being able
## to measure rather than reason about.
static var debug_body_draws: int = 0
static var debug_face_draws: int = 0

func _draw_body(ci: CanvasItem) -> void:
	debug_body_draws += 1
	if not tile_data:
		return
	if tile_data.is_removed and not is_dissolving:
		return

	var z: int = tile_data.z
	var offset_y: float = anim_lift + anim_hover
	var offset_x: float = anim_shake

	if not is_dissolving:
		# The shadow stays on the table while the tile rises. It used to carry
		# offset_y like everything else, so a selected tile and its shadow moved
		# together and the lift read as nothing at all - which is why selection
		# was hard to see. A shadow that stays put, spreads and softens is what
		# actually sells height.
		var lift: float = maxf(0.0, -(anim_lift + anim_hover))
		var shadow_y: float = 3.5 + z * 3.0 + lift * 0.30
		var shadow_alpha: float = clampf(0.36 + z * 0.06 - lift * 0.013, 0.14, 0.65)
		var spread: float = lift * 0.26
		sb_shadow.bg_color = Color(0.01, 0.04, 0.03, shadow_alpha)
		sb_shadow.set_corner_radius_all(int(9.0 + lift * 0.5))
		var shadow_rect := Rect2(offset_x - spread, shadow_y,
			TILE_W + spread * 2.0, TILE_H - DEPTH_3D)
		ci.draw_style_box(sb_shadow, shadow_rect)

	var face_rect := Rect2(offset_x, offset_y, TILE_W, TILE_H - DEPTH_3D)
	var cur_th: String = get_effective_theme()
	var body_tex: Texture2D = get_body_texture(cur_th) if USE_RENDERED_BODY else null

	if body_tex != null:
		# The rendered sprite is a COMPLETE tile body seen face-on, so it
		# replaces the extrusion slab and the face slab together. It is drawn
		# into the full TILE_W x TILE_H rect rather than face_rect: the art is
		# 64:84 and face_rect is 64:80, so face_rect alone would squash it.
		var body_rect := Rect2(offset_x, offset_y, TILE_W, TILE_H)
		var tint: Color = Color.WHITE if (is_free or is_revealed or is_dissolving) else BLOCKED_TINT.get(cur_th, BLOCKED_TINT_DEFAULT)
		ci.draw_texture_rect(body_tex, body_rect, false, tint)
	else:
		# Procedural fallback: original flat-slab path, used when the rendered
		# art is missing or USE_RENDERED_BODY is off.
		sb_extrusion.bg_color = get_theme_back_base(cur_th)
		sb_extrusion.border_color = get_theme_back_edge(cur_th)
		var ext_rect := Rect2(offset_x, offset_y + DEPTH_3D, TILE_W, TILE_H - DEPTH_3D)
		ci.draw_style_box(sb_extrusion, ext_rect)

		sb_base.bg_color = get_theme_face_color(is_free or is_revealed, cur_th)
		sb_base.border_color = get_theme_border_color(is_free or is_revealed, cur_th)
		ci.draw_style_box(sb_base, face_rect)

		if is_free or is_revealed or is_dissolving:
			ci.draw_line(face_rect.position + Vector2(6, 1.5), face_rect.position + Vector2(TILE_W - 6, 1.5), Color(1, 1, 1, 0.85), 1.2, true)

		if cur_th == "theme_imperial_gold":
			_draw_imperial_gold_framing(face_rect)
		elif cur_th == "theme_obsidian_ink":
			_draw_obsidian_ink_framing(face_rect)
		elif cur_th == "theme_cherry_blossom":
			_draw_cherry_blossom_framing(face_rect)


func _draw() -> void:
	debug_face_draws += 1
	if not tile_data:
		return
	# CRITICAL FIX: If tile is marked removed by match logic, KEEP DRAWING if is_dissolving is true!
	if tile_data.is_removed and not is_dissolving:
		return

	var offset_y: float = anim_lift + anim_hover
	var offset_x: float = anim_shake
	var face_rect := Rect2(offset_x, offset_y, TILE_W, TILE_H - DEPTH_3D)
	var cur_th: String = get_effective_theme()

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
		sel_sb.set_border_width_all(SELECT_BORDER_W)
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
	
	# 7. Canonical artwork, veiled by fog when the tile is still blocked.
	# The face is drawn FIRST and the mist laid over it, rather than the mist
	# replacing it. That is what lets the artwork ghost through as a shape
	# while the rank stays unreadable.
	if not debug_skip_artwork:
		draw_canonical_face(face_rect)
	if StageModifiers.is_fog_active() and not is_free and not is_revealed:
		_draw_fog_shroud(face_rect)
	
	# 8. Frost Encasement
	if tile_data.is_frozen:
		_draw_frost_encasement(face_rect)
	
	# 9. Atmospheric Depth Wash for Blocked Tiles (matching HTML .tile.blocked::after)
	if not is_free and not is_revealed and not StageModifiers.is_fog_active() and not is_dissolving:
		_draw_atmospheric_blocked_tint(face_rect)

func _draw_atmospheric_blocked_tint(face_r: Rect2) -> void:
	# Soft warm translucent shadow wash (preserves beautiful ivory porcelain look)
	var blocked_wash := Color(0.12, 0.14, 0.12, 0.10)
	draw_rect(face_r, blocked_wash, true)
	var top_shadow := Rect2(face_r.position, Vector2(face_r.size.x, face_r.size.y * 0.40))
	draw_rect(top_shadow, Color(0.06, 0.08, 0.07, 0.06), true)

func _draw_fog_shroud(face_r: Rect2) -> void:
	# Softened. At alpha 0.92 the mist was near-opaque, so on a 144-tile board
	# roughly a hundred tiles became identical blank rectangles at once - the
	# board stopped reading as a board. Fog is meant to hide a tile's IDENTITY,
	# not erase the tile.
	#
	# Now the mist is translucent enough that the artwork ghosts through as a
	# shape, and a faint wash of the suit's colour bleeds in. The player can see
	# something is there and roughly what family it belongs to, but not the
	# rank - so the tactical concealment survives while the board stays legible.
	var mist_col := Color(0.86, 0.91, 0.93, 0.80)
	var mist_rect := Rect2(face_r.position + Vector2(2, 2), face_r.size - Vector2(4, 4))
	draw_rect(mist_rect, mist_col, true)

	var hint := get_accent_color()
	draw_rect(mist_rect, Color(hint.r, hint.g, hint.b, 0.10), true)
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
			draw_canonical_glyph(face_r, w_str, get_col_ink(th), 48)
		"dragon":
			match tile_data.rank:
				1: draw_canonical_glyph(face_r, "中", get_col_red(th), 48)
				2: draw_canonical_glyph(face_r, "發", get_col_green(th), 48)
				3: draw_white_dragon_frame(face_r)
		"flower":
			var f_str := FLOWERS[tile_data.rank - 1] if tile_data.rank <= FLOWERS.size() else "花"
			draw_canonical_glyph(face_r, f_str, get_col_green(th), 42)
		"season":
			var s_str := SEASONS[tile_data.rank - 1] if tile_data.rank <= SEASONS.size() else "季"
			draw_canonical_glyph(face_r, s_str, get_col_blue(th), 42)

func draw_white_dragon_frame(face_r: Rect2) -> void:
	var th: String = get_effective_theme()
	var scale_x: float = face_r.size.x / 100.0
	var scale_y: float = face_r.size.y / 132.0
	var col := get_col_blue(th)
	if th == "theme_imperial_gold":
		col = get_col_ink(th) # pale lacquer, same as every other glyph on bronze
	elif th == "theme_obsidian_ink":
		col = Color("#38bdf8") # Radiant electric cyan frame
	elif th == "theme_cherry_blossom":
		col = Color("#cf3b5b") # Soft rose cinnabar frame
	
	# Outer rounded rectangle, widened from 64x82 so the white dragon reads at
	# the same size as the other two.
	# Outer rounded rectangle
	var sb_outer := StyleBoxFlat.new()
	sb_outer.draw_center = false
	sb_outer.border_color = col
	sb_outer.set_border_width_all(int(round(5.0 * (scale_x / 0.64))))
	sb_outer.set_corner_radius_all(int(round(7.0 * scale_x)))
	sb_outer.anti_aliasing = true
	sb_outer.anti_aliasing_size = 1.0
	var outer_r := Rect2(face_r.position.x + 12.0 * scale_x, face_r.position.y + 18.0 * scale_y, 76.0 * scale_x, 98.0 * scale_y)
	draw_style_box(sb_outer, outer_r)
	
	# Inner rounded rectangle (38x56, rx=5, stroke=3.4 in 100x132 viewBox)
	var sb_inner := StyleBoxFlat.new()
	sb_inner.draw_center = false
	sb_inner.border_color = col
	sb_inner.set_border_width_all(int(round(3.0 * (scale_x / 0.64))))
	sb_inner.set_corner_radius_all(int(round(5.0 * scale_x)))
	sb_inner.anti_aliasing = true
	sb_inner.anti_aliasing_size = 1.0
	var inner_r := Rect2(face_r.position.x + 27.0 * scale_x, face_r.position.y + 34.0 * scale_y, 46.0 * scale_x, 66.0 * scale_y)
	draw_style_box(sb_inner, inner_r)

func draw_canonical_characters(face_r: Rect2, rank: int) -> void:
	var th: String = get_effective_theme()
	var font := get_cjk_font()
	var num_str: String = CN_NUMS[rank] if rank < CN_NUMS.size() else str(rank)
	var cx: float = face_r.position.x + face_r.size.x * 0.5
	var cy: float = face_r.position.y + face_r.size.y * 0.5
	
	# 0.46/0.38 put the pair at 45% of the tile width. 0.58/0.52 is the largest
	# that still stacks inside the 80px face without the numeral clipping.
	var top_sz: int = int(face_r.size.x * 0.58)
	var bot_sz: int = int(face_r.size.x * 0.52)
	
	if th == "theme_imperial_gold":
		# Same trap as the dragons: the numeral was gilded #d49826 on a #8b6c26
		# gold face and 萬 was dark crimson on dark gold, both hardcoded past
		# the palette. Emboss kept, colours taken from the palette.
		var gold_ink: Color = get_col_ink(th)
		var gold_red: Color = get_col_red(th)
		# A light highlight, not a dark shadow. The ink is dark now, so darkening
		# it again was invisible; offsetting a pale gold underneath reads as a
		# stroke cut into the lacquer.
		var ink_sh := Color(1.0, 0.92, 0.70, 0.30)
		var red_sh := Color(1.0, 0.90, 0.66, 0.28)
		draw_string(font, Vector2(cx - top_sz * 0.5 + 1.0, cy - 0.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, ink_sh)
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 1.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, gold_ink)

		draw_string(font, Vector2(cx - bot_sz * 0.5 + 1.0, cy + bot_sz * 0.82 + 1.0), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, red_sh)
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.82), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, gold_red)
	elif th == "theme_obsidian_ink":
		# Luminescent white-jade glyph with electric cyan glow
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 1.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color(0, 0.85, 0.8, 0.35))
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 1.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, Color("#f0f4f8"))
		# 萬 in radiant neon vermilion
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.82), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, Color("#ff4757"))
	else:
		draw_string(font, Vector2(cx - top_sz * 0.5, cy - 1.0), num_str, HORIZONTAL_ALIGNMENT_CENTER, top_sz, top_sz, get_col_ink(th))
		draw_string(font, Vector2(cx - bot_sz * 0.5, cy + bot_sz * 0.82), "萬", HORIZONTAL_ALIGNMENT_CENTER, bot_sz, bot_sz, get_col_red(th))

func draw_canonical_glyph(face_r: Rect2, text: String, col: Color, font_size: int) -> void:
	var th: String = get_effective_theme()
	var font := get_cjk_font()
	var cx: float = face_r.position.x + face_r.size.x * 0.5
	var cy: float = face_r.position.y + face_r.size.y * 0.5
	
	if th == "theme_imperial_gold":
		# These two used to hardcode their own colours and ignore `col`, which
		# is why fixing the palette did nothing for the dragons: 發 was drawn
		# #d49826 on a #8b6c26 gold face - gold on gold, the exact bug this file
		# claims elsewhere to have fixed - and 中 was dark red on dark gold. The
		# emboss is worth keeping, so it is now built FROM the palette colour
		# rather than instead of it.
		if text == "發" or text == "中":
			var shadow := Color(1.0, 0.92, 0.70, 0.30)
			draw_string(font, Vector2(cx - font_size * 0.5 + 1.1, cy + font_size * 0.36 + 1.1), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, shadow)
			draw_string(font, Vector2(cx - font_size * 0.5, cy + font_size * 0.36), text, HORIZONTAL_ALIGNMENT_CENTER, font_size, font_size, col)
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
	var r_base: float = DOT_R.get(n, 12.5)
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
		var r_val: float = r_base * scale_x
		var col: Color = dot_colors[(i + n) % 3]
		var center := Vector2(cx, cy)

		draw_circle(center, r_val, col, true, -1.0, true)
		draw_circle(center, r_val * 0.42, core_col, true, -1.0, true)


## Pill sizes in viewBox units. Bamboo shares the dot positions, so a rank with
## few tokens is inherently a narrow column - 2-bamboo is two stalks one above
## the other on a real tile. Widening the pills is the only lever the shared
## arrangement leaves; the low ranks get the widest of them.
const BAM_BIG := Vector2(30.0, 66.0)
const BAM_SMALL := Vector2(22.0, 34.0)
const BAM_SMALL_SPARSE := Vector2(27.0, 38.0)
const BAM_PAIR := Vector2(46.0, 52.0)

## One bamboo is a sparrow, on every real set. It was a green capsule with a
## line across it - the least convincing face in the game, and the narrowest:
## 31%% of the tile width against a 63%% mean.
##
## Drawn from primitives rather than a glyph. No CJK character means a bird, and
## an imported drawing would be the only raster face in a vector set.
func draw_bamboo_bird(face_r: Rect2) -> void:
	var th: String = get_effective_theme()
	var g: Color = get_col_green(th)
	var r: Color = get_col_red(th)
	var sx: float = face_r.size.x / 100.0
	var sy: float = face_r.size.y / 132.0
	var o: Vector2 = face_r.position
	# Everything below is in the same 100x132 viewBox the dot table uses.
	var P := func(px: float, py: float) -> Vector2:
		return o + Vector2(px * sx, py * sy)

	# Tail: three feathers fanning back from the body. Drawn as quads rather than
	# slivers - at 64px a triangle two units wide at its base disappears.
	for f in [[8.0, 26.0], [0.0, 16.0], [-6.0, 4.0]]:
		var tip := Vector2(14.0 + f[1] * 0.35, 60.0 + f[0])
		draw_colored_polygon(PackedVector2Array([
			P.call(44.0, 62.0), P.call(44.0, 74.0),
			P.call(tip.x + 4.0, tip.y + 7.0), P.call(tip.x, tip.y)]), g)

	# Body, leaning forward over the perch.
	draw_colored_polygon(PackedVector2Array([
		P.call(66.0, 40.0), P.call(78.0, 56.0), P.call(72.0, 78.0),
		P.call(54.0, 88.0), P.call(42.0, 80.0), P.call(42.0, 60.0),
		P.call(52.0, 46.0)]), g)

	# Wing, laid over the body in the second ink so the bird reads at tile size.
	draw_colored_polygon(PackedVector2Array([
		P.call(60.0, 52.0), P.call(74.0, 62.0), P.call(64.0, 82.0),
		P.call(50.0, 78.0), P.call(48.0, 60.0)]), r)

	# Head and beak.
	draw_circle(P.call(66.0, 34.0), 13.0 * sx, g)
	draw_colored_polygon(PackedVector2Array([
		P.call(76.0, 29.0), P.call(94.0, 35.0), P.call(76.0, 41.0)]), r)
	# The eye is the face colour rather than white, so it stays an eye on a dark
	# theme instead of becoming a bright dot.
	draw_circle(P.call(68.0, 31.0), 3.0 * sx, get_theme_face_color(true, th))

	# Perch, with the stalk node every other bamboo rank carries.
	draw_line(P.call(12.0, 104.0), P.call(88.0, 104.0), g, 7.0 * sx, true)
	draw_line(P.call(50.0, 100.0), P.call(50.0, 108.0),
		get_theme_face_color(true, th), 3.0 * sx, true)
	# Legs.
	for lx in [56.0, 66.0]:
		draw_line(P.call(lx, 84.0), P.call(lx - 2.0, 101.0), r, 3.2 * sx, true)


func draw_canonical_bamboos(face_r: Rect2, n: int) -> void:
	if n == 1:
		draw_bamboo_bird(face_r)
		return
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

	# Two stalks on a whole tile can afford to be much bigger than six can. At
	# the shared sparse size 2-bam spanned 28%% of the tile, the narrowest face
	# left once the bird replaced 1-bam.
	var small: Vector2 = BAM_PAIR if n == 2 else (BAM_SMALL_SPARSE if n <= 3 else BAM_SMALL)
	for i in range(pts_list.size()):
		var p: Array = pts_list[i]
		var is_big: bool = n == 1
		var box: Vector2 = BAM_BIG if is_big else small
		var w: float = box.x * scale_x
		var h: float = box.y * scale_y
		var x: float = face_r.position.x + (p[0] - box.x * 0.5) * scale_x
		var y: float = face_r.position.y + (p[1] - box.y * 0.5) * scale_y
		var col: Color = r_col if (i % 3 == 1) else g_col

		var sb := _get_bamboo_stylebox(col, int(round(w * 0.5)))
		draw_style_box(sb, Rect2(x, y, w, h))

		var cy: float = face_r.position.y + p[1] * scale_y
		draw_line(Vector2(x + 1.2, cy), Vector2(x + w - 1.2, cy), cream_line_col, 2.4 * scale_x, true)
