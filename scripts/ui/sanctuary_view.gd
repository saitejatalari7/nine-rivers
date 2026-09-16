class_name SanctuaryView
extends Control

## Nine Rivers (九河) — Ethereal Zen Koi Sanctuary
## Shimmering water caustics, floating lotus pads, fluid koi schools, and artisan garden shop.

signal back_requested()

const KoiFishScript = preload("res://scripts/ui/koi_fish.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

@onready var pond_area: Control = $PondArea
@onready var fish_container: Node2D = $PondArea/FishContainer
@onready var ripples_container: Node2D = $PondArea/RipplesContainer
@onready var lbl_jade: Label = $TopBar/JadeBalance
@onready var shop_panel: PanelContainer = $ShopDrawer
@onready var shop_list: VBoxContainer = $ShopDrawer/Scroll/ShopList

var ripples: Array[Dictionary] = [] # pos, radius, alpha
var lotus_pads: Array[Vector2] = [
	Vector2(180, 420), Vector2(880, 680), Vector2(240, 1180), Vector2(840, 1340), Vector2(480, 880)
]

func _ready() -> void:
	_apply_luxury_styling()
	
	$TopBar/BtnBack.pressed.connect(func(): back_requested.emit())
	$BottomBar/BtnShop.pressed.connect(_toggle_shop)
	$ShopDrawer/BtnCloseShop.pressed.connect(func(): shop_panel.visible = false)
	shop_panel.visible = false
	ripples_container.draw.connect(_on_ripples_draw)
	
	refresh_sanctuary()

func _apply_luxury_styling() -> void:
	UITheme.style_button($TopBar/BtnBack, false, 12)
	UITheme.style_button($BottomBar/BtnShop, true, 16)
	UITheme.style_circular_button($ShopDrawer/BtnCloseShop, UITheme.GOLD_CORE)
	
	var sb_shop := UITheme.create_panel_box(Color("#071d16"), UITheme.GOLD_MUTED, 2, 18, 0.6)
	shop_panel.add_theme_stylebox_override("panel", sb_shop)

func refresh_sanctuary() -> void:
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
	
	# 1. Section: Sacred Koi Fish
	var header_koi := Label.new()
	header_koi.text = "SACRED KOI FISH"
	header_koi.add_theme_font_size_override("font_size", 18)
	header_koi.add_theme_color_override("font_color", UITheme.GOLD_CORE)
	shop_list.add_child(header_koi)
	
	for item in SanctuaryManager.KOI_SHOP:
		var card := _build_shop_card(item, true, user_jade)
		shop_list.add_child(card)
		
	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 14)
	shop_list.add_child(sep)
	
	# 2. Section: Zen Garden Elements
	var header_dec := Label.new()
	header_dec.text = "ZEN GARDEN ELEMENTS"
	header_dec.add_theme_font_size_override("font_size", 18)
	header_dec.add_theme_color_override("font_color", UITheme.GOLD_CORE)
	shop_list.add_child(header_dec)
	
	for item in SanctuaryManager.DECORATIONS:
		var card := _build_shop_card(item, false, user_jade)
		shop_list.add_child(card)

func _build_shop_card(item: Dictionary, is_koi: bool, user_jade: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 80)
	var sb_item := UITheme.create_panel_box(Color("#0c251d"), UITheme.GOLD_MUTED, 1, 12, 0.25)
	card.add_theme_stylebox_override("panel", sb_item)
	
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	
	var info_box := VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var title := Label.new()
	title.text = item["name"]
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", UITheme.GOLD_BRIGHT)
	
	var desc := Label.new()
	desc.text = item["desc"]
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", UITheme.IVORY_MUTED)
	
	info_box.add_child(title)
	info_box.add_child(desc)
	box.add_child(info_box)
	
	var is_owned: bool = SanctuaryManager.is_koi_unlocked(item["id"]) if is_koi else SanctuaryManager.is_decoration_unlocked(item["id"])
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 56)
	UITheme.style_button(btn, not is_owned and user_jade >= item["cost"], 12)
	btn.add_theme_font_size_override("font_size", 18)
	
	if is_owned:
		btn.text = "Owned"
		btn.disabled = true
	else:
		btn.text = "%d 玉" % item["cost"]
		btn.disabled = user_jade < item["cost"]
		var item_id: String = item["id"]
		btn.pressed.connect(func():
			var success: bool = SanctuaryManager.unlock_koi(item_id) if is_koi else SanctuaryManager.unlock_decoration(item_id)
			if success:
				AudioManager.play_win()
				refresh_sanctuary()
		)
	box.add_child(btn)
	card.add_child(box)
	return card
