class_name SanctuaryView
extends Control

## Nine Rivers (九河) — Ethereal Zen Koi Sanctuary
## Shimmering water caustics, floating lotus pads, fluid koi schools, and artisan garden shop.

signal back_requested()

const KoiFishScript = preload("res://scripts/ui/koi_fish.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")
const ModalController = preload("res://scripts/ui/modal_controller.gd")

@onready var pond_area: Control = $PondArea
@onready var fish_container: Node2D = $PondArea/FishContainer
@onready var ripples_container: Node2D = $PondArea/RipplesContainer
@onready var lbl_jade: Label = $TopBar/JadeBalance
@onready var shop_panel: PanelContainer = $ShopDrawer
@onready var shop_list: VBoxContainer = $ShopDrawer/Body/Scroll/ShopList

var ripples: Array[Dictionary] = [] # pos, radius, alpha
var lotus_pads: Array[Vector2] = [
	Vector2(180, 420), Vector2(880, 680), Vector2(240, 1180), Vector2(840, 1340), Vector2(480, 880)
]

func _ready() -> void:
	_apply_luxury_styling()
	_apply_safe_area()
	get_tree().get_root().size_changed.connect(_apply_safe_area)

	$TopBar/BtnBack.pressed.connect(func(): back_requested.emit())
	$BottomBar/BtnShop.pressed.connect(_toggle_shop)
	$ShopDrawer/Body/DrawerHead/BtnCloseShop.pressed.connect(func(): shop_panel.visible = false)
	shop_panel.visible = false
	ripples_container.draw.connect(_on_ripples_draw)

	refresh_sanctuary()

## The pond is full-bleed, so the bar that sits over it has to be pushed clear of
## the status bar and the gesture pill by hand.
func _apply_safe_area() -> void:
	var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
	var top: float = maxf(insets.x, UITheme.SAFE_TOP_FLOOR) + 24.0
	var bottom: float = maxf(insets.y, UITheme.SAFE_BOTTOM_FLOOR)

	var bar: Control = $TopBar
	bar.offset_top = top
	bar.offset_bottom = top + UITheme.TOUCH_MIN

	var title: Control = $TitleBlock
	title.offset_top = bar.offset_bottom + 24.0
	title.offset_bottom = title.offset_top + 116.0

	var bottom_bar: Control = $BottomBar
	bottom_bar.offset_bottom = -bottom
	bottom_bar.offset_top = bottom_bar.offset_bottom - 160.0

	shop_panel.offset_bottom = bottom_bar.offset_top - 20.0
	shop_panel.offset_top = minf(shop_panel.offset_bottom - 640.0,
		-(size.y - title.offset_bottom - 24.0))

func _apply_luxury_styling() -> void:
	UITheme.style_button($TopBar/BtnBack, false, 14)
	$TopBar/BtnBack.add_theme_font_size_override("font_size", UITheme.FS_BODY_LG)
	UITheme.style_button($BottomBar/BtnShop, true, 16)
	$BottomBar/BtnShop.add_theme_font_size_override("font_size", UITheme.FS_BODY_LG)

	var close_btn: Button = $ShopDrawer/Body/DrawerHead/BtnCloseShop
	UITheme.style_circular_button(close_btn, UITheme.GOLD_CORE)
	close_btn.add_theme_font_size_override("font_size", UITheme.FS_TITLE)

	UITheme.style_label(lbl_jade, "ui", UITheme.FS_BODY_LG, UITheme.GOLD_CORE,
		UITheme.W_SEMIBOLD)
	UITheme.style_label($TitleBlock/Title, "ui", UITheme.FS_TITLE, UITheme.GOLD_CORE,
		UITheme.W_SEMIBOLD, 1)
	UITheme.style_label($ShopDrawer/Body/DrawerHead/DrawerTitle, "ui",
		UITheme.FS_TITLE, UITheme.GOLD_CORE, UITheme.W_SEMIBOLD, 1)

	# One cinnabar seal, exactly as every other screen header carries.
	var seal: PanelContainer = $TitleBlock/Seal
	var sb_seal := StyleBoxFlat.new()
	sb_seal.bg_color = UITheme.RED_CINNABAR
	sb_seal.set_corner_radius_all(4)
	sb_seal.content_margin_left = 12
	sb_seal.content_margin_right = 12
	sb_seal.content_margin_top = 6
	sb_seal.content_margin_bottom = 8
	seal.add_theme_stylebox_override("panel", sb_seal)
	UITheme.style_label($TitleBlock/Seal/SealGlyph, "cjk", 44, Color("#fff4ef"))

	var sb_shop := UITheme.create_panel_box(Color(0.035, 0.105, 0.085, 0.93),
		UITheme.GOLD_MUTED, 0, 18, 0.55)
	sb_shop.border_width_top = 1
	sb_shop.content_margin_left = 28
	sb_shop.content_margin_right = 28
	sb_shop.content_margin_top = 24
	sb_shop.content_margin_bottom = 24
	shop_panel.add_theme_stylebox_override("panel", sb_shop)

## Returns true if it actually closed something, so the back gesture can stop
## there instead of leaving the Sanctuary.
func close_shop_drawer() -> bool:
	if is_instance_valid(shop_panel) and shop_panel.visible:
		shop_panel.visible = false
		return true
	return false


func refresh_sanctuary() -> void:
	# Not saved state: leaving it open meant a player who opened the shop once
	# never saw the pond again.
	shop_panel.visible = false
	lbl_jade.text = "%d 玉" % SaveManager.get_jade()
	
	# Spawn all unlocked Koi fish
	for c in fish_container.get_children():
		c.queue_free()
		
	var unlocked_koi: Array = SaveManager.sanctuary.get("koi_unlocked", ["kohaku"])
	var pond_center := size * 0.5
	if pond_center == Vector2.ZERO:
		pond_center = Vector2(540, 960)
	
	for i in range(unlocked_koi.size()):
		var species: String = unlocked_koi[i]
		var koi := Node2D.new()
		koi.set_script(KoiFishScript)
		fish_container.add_child(koi)
		var rand_offset := Vector2(randf_range(-250, 250), randf_range(-400, 400))
		koi.setup(species, pond_center + rand_offset)
		
	_populate_shop()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_create_ripple(event.position)
		AudioManager.play_water_drop()
		# Attract fish toward tap
		for f in fish_container.get_children():
			if f.has_method("attract_to"):
				f.attract_to(event.position)

func _create_ripple(pos: Vector2) -> void:
	ripples.append({"pos": pos, "r": 6.0, "a": 0.85})

func _process(delta: float) -> void:
	var remaining_ripples: Array[Dictionary] = []
	for r in ripples:
		r["r"] += delta * 85.0
		r["a"] -= delta * 0.85
		if r["a"] > 0.0:
			remaining_ripples.append(r)
	ripples = remaining_ripples
	ripples_container.queue_redraw()

func _on_ripples_draw() -> void:
	# 1. Draw Stepping Stones if unlocked
	if SanctuaryManager.is_decoration_unlocked("stepping_stones"):
		var stone_coords := [Vector2(320, 680), Vector2(440, 710), Vector2(560, 740), Vector2(680, 770)]
		for sc in stone_coords:
			ripples_container.draw_circle(sc, 26.0, Color(0.24, 0.32, 0.28, 0.95))
			ripples_container.draw_circle(sc, 22.0, Color(0.38, 0.48, 0.42, 0.95))
			ripples_container.draw_circle(sc + Vector2(-3, -3), 14.0, Color(0.48, 0.60, 0.52, 0.9))
			# Soft moss tint
			ripples_container.draw_circle(sc + Vector2(4, 4), 8.0, Color(0.18, 0.52, 0.28, 0.6))
	
	# 2. Draw Stone Lanterns if unlocked
	if SanctuaryManager.is_decoration_unlocked("stone_lantern"):
		var lantern_coords := [Vector2(140, 340), Vector2(940, 340)]
		for lc in lantern_coords:
			# Warm candlelight glow halo
			ripples_container.draw_circle(lc, 52.0, Color(1.0, 0.85, 0.45, 0.15))
			ripples_container.draw_circle(lc, 32.0, Color(1.0, 0.88, 0.52, 0.28))
			# Stone pagoda base and cap
			ripples_container.draw_rect(Rect2(lc.x - 14, lc.y - 8, 28, 24), Color(0.32, 0.36, 0.34, 0.95), true)
			ripples_container.draw_rect(Rect2(lc.x - 18, lc.y - 18, 36, 10), Color(0.25, 0.28, 0.26, 0.95), true)
			# Burning candle core
			ripples_container.draw_circle(lc + Vector2(0, 4), 6.0, Color(1.0, 0.94, 0.72, 0.95))
	
	# 3. Draw Bamboo Water Fountain if unlocked
	if SanctuaryManager.is_decoration_unlocked("bamboo_fountain"):
		var fc := Vector2(160, 200)
		# Stone basin
		ripples_container.draw_circle(fc, 30.0, Color(0.26, 0.30, 0.28, 0.95))
		ripples_container.draw_circle(fc, 22.0, Color(0.12, 0.38, 0.32, 0.95))
		# Bamboo spout
		ripples_container.draw_line(fc + Vector2(-36, -30), fc + Vector2(4, 2), Color(0.22, 0.58, 0.36, 0.95), 8.0, true)
		ripples_container.draw_circle(fc + Vector2(2, 2), 4.0, Color(0.65, 0.95, 0.88, 0.9))

	# 4. Draw floating lotus lily pads
	var all_pads := lotus_pads.duplicate()
	if SanctuaryManager.is_decoration_unlocked("pink_lotus"):
		all_pads.append_array([Vector2(360, 360), Vector2(720, 1100), Vector2(520, 1420)])
		
	for lp in all_pads:
		# Lily pad green disk with notch
		ripples_container.draw_circle(lp, 32.0, Color(0.12, 0.45, 0.32, 0.75))
		ripples_container.draw_circle(lp, 28.0, Color(0.16, 0.55, 0.38, 0.85))
		# Lotus blossom at center
		ripples_container.draw_circle(lp, 9.0, Color(0.96, 0.65, 0.78, 0.95))
		ripples_container.draw_circle(lp, 4.5, Color(1.0, 0.92, 0.45, 1.0))
	
	# 5. Draw dynamic water ripples
	for r in ripples:
		var col := Color(0.42, 0.88, 0.78, r["a"])
		ripples_container.draw_arc(r["pos"], r["r"], 0.0, TAU, 36, col, 2.2)
		ripples_container.draw_arc(r["pos"], maxf(1.0, r["r"] * 0.65), 0.0, TAU, 28, Color(col.r, col.g, col.b, r["a"] * 0.45), 1.6)

func _toggle_shop() -> void:
	shop_panel.visible = not shop_panel.visible
	if shop_panel.visible:
		_populate_shop()

func _populate_shop() -> void:
	for c in shop_list.get_children():
		c.queue_free()
		
	var user_jade: int = SaveManager.get_jade()

	_add_section("Sacred Koi Fish")
	for item in SanctuaryManager.KOI_SHOP:
		shop_list.add_child(_build_shop_card(item, true, user_jade))

	_add_section("Zen Garden Elements")
	for item in SanctuaryManager.DECORATIONS:
		shop_list.add_child(_build_shop_card(item, false, user_jade))

func _add_section(text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	UITheme.style_label(l, "ui", UITheme.FS_CAPTION, UITheme.IVORY_MUTED,
		UITheme.W_MEDIUM, 2)
	shop_list.add_child(l)

## A shop line is a face-up tile, the same object the rest of the game is built
## from, rather than a bordered card with a small button bolted to one end.
func _build_shop_card(item: Dictionary, is_koi: bool, user_jade: int) -> PanelContainer:
	var is_owned: bool = SanctuaryManager.is_koi_unlocked(item["id"]) if is_koi \
		else SanctuaryManager.is_decoration_unlocked(item["id"])
	var affordable: bool = user_jade >= int(item["cost"])

	# A PanelContainer rather than a styled Button: descriptions here run to two
	# lines, and a Button's height comes from its own text, so wrapped rows were
	# cut off at the tile's lip.
	var card := PanelContainer.new()
	# +32 for the tile stylebox margins, which the inner Button does not get.
	card.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN + 32.0)
	card.add_theme_stylebox_override("panel", ModalController._make_tile_box())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)

	var g := Label.new()
	g.text = "鯉" if is_koi else "庭"
	g.custom_minimum_size = Vector2(68, 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(g, "cjk", 56,
		ModalController.GLYPH_JADE if is_koi else ModalController.GLYPH_GOLD)
	row.add_child(g)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var title := Label.new()
	title.text = item["name"]
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(title, "ui", UITheme.FS_BODY_LG, ModalController.TILE_INK,
		UITheme.W_SEMIBOLD)
	col.add_child(title)

	var desc := Label.new()
	desc.text = item["desc"]
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(desc, "ui", UITheme.FS_CAPTION, ModalController.TILE_SUBINK)
	col.add_child(desc)

	var price := Label.new()
	price.text = "Owned" if is_owned else "%d 玉" % int(item["cost"])
	price.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var price_col: Color = ModalController.TILE_META
	if not is_owned:
		price_col = ModalController.GLYPH_JADE if affordable else ModalController.TILE_META
	UITheme.style_label(price, "ui", UITheme.FS_CAPTION, price_col, UITheme.W_SEMIBOLD)
	row.add_child(price)

	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_ALL
	var clear := StyleBoxEmpty.new()
	for state in ["normal", "hover", "focus", "disabled"]:
		btn.add_theme_stylebox_override(state, clear)
	var ink := StyleBoxFlat.new()
	ink.bg_color = Color(0, 0, 0, 0.10)
	ink.set_corner_radius_all(9)
	btn.add_theme_stylebox_override("pressed", ink)
	card.add_child(btn)
	UITheme.add_press_feedback(btn)

	# A tile you cannot pay for is dimmed rather than live-but-inert: a control
	# that accepts a press and then does nothing reads as a broken screen.
	if is_owned or not affordable:
		btn.disabled = true
		card.modulate.a = 0.62 if is_owned else 0.78
	else:
		var item_id: String = item["id"]
		btn.pressed.connect(func():
			var success: bool = SanctuaryManager.unlock_koi(item_id) if is_koi \
				else SanctuaryManager.unlock_decoration(item_id)
			if success:
				AudioManager.play_win()
				refresh_sanctuary()
		)
	return card
