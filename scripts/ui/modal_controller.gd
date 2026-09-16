class_name ModalController
extends CanvasLayer

## Nine Rivers (九河) — Imperial Modal & Relic Deck Controller
## Features lacquered scroll framing, golden crest headers, tarot-style relic cards, and responsive level grid.

signal start_calm_requested(level: int)
signal start_run_requested()
signal start_daily_requested()
signal open_sanctuary_requested()
signal restart_stage_requested()
signal next_stage_requested()
signal resume_game_requested()
signal return_home_requested()
signal replay_tutorial_requested()

const BoonPool = preload("res://scripts/core/boon_pool.gd")
const UITheme = preload("res://scripts/ui/ui_theme.gd")

const TILE_THEME_DETAILS: Dictionary = {
	"classic_jade": {
		"id": "classic_jade",
		"name": "Classic Jade (羊脂白玉)",
		"subtitle": "Timeless Chinese Ceramic Craftsmanship",
		"desc": "Fine milk-ivory ceramic tiles with hand-engraved cinnabar vermilion and emerald jade calligraphy on a warm biscuit terracotta underside.",
		"purpose": "Balanced natural contrast for both bright sunlight and dim rooms. High-clarity strokes prevent misreads during fast-paced clearing.",
		"tactile": "Smooth glazed ceramic texture with crisp, acoustic stone clacks. Clears fracture into delicate jade dust.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 2]]
	},
	"theme_imperial_gold": {
		"id": "theme_imperial_gold",
		"name": "Imperial Gold (皇家金叶)",
		"subtitle": "24-Karat Gold Leaf on Crimson Lacquer",
		"desc": "Opulent gilded face with delicate chased gold filigree on imperial crimson lacquer backing. Fits the grandeur of royal courts.",
		"purpose": "Maximum visual prominence. Gilded tile faces catch the light, making free playable tiles immediately distinct in dense 3D stacks.",
		"tactile": "Heavy lacquered clack. Every match disintegrates into a radiant shower of glittering 24k golden sand.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 2]]
	},
	"theme_obsidian_ink": {
		"id": "theme_obsidian_ink",
		"name": "Obsidian Ink (玄黑墨玉)",
		"subtitle": "Polished Basalt Stone & Luminous White Jade",
		"desc": "Carved from deep volcanic basalt stone with luminous white-jade glyphs and cinnabar seals on a dark basalt underside.",
		"purpose": "True OLED Dark Mode. Drastically minimizes screen glare and blue light emissions, preventing eye strain during evening play.",
		"tactile": "Deep, resonant mineral clatter. Matched pairs disperse into wisps of midnight basalt mist.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 1]]
	},
	"theme_cherry_blossom": {
		"id": "theme_cherry_blossom",
		"name": "Cherry Blossom (落樱白瓷)",
		"subtitle": "Rosewater Porcelain on Plum Rosewood",
		"desc": "Delicate blush porcelain tiles with cinnabar plum flower engravings resting on a dark plum rosewood foundation.",
		"purpose": "Tranquil sensory comfort. Soft pastel tones ease mental tension and facilitate long, uninterrupted zen flow states.",
		"tactile": "Gentle porcelain chime. Matched tiles dissolve gracefully into floating pink sakura petals.",
		"samples": [["flower", 1], ["char", 9], ["dragon", 3]]
	}
}

const BG_THEME_DETAILS: Dictionary = {
	"auto": {
		"id": "auto",
		"name": "Dynamic River Flow (九河漫流)",
		"subtitle": "Evolving Water Journey",
		"desc": "The living river continuously transforms its water currents, koi species, and floating flora every 5 stages as you progress.",
		"mood": "Adaptive & Ever-Changing · Shifts seamlessly through all 5 river realms.",
		"is_free": true,
		"koi": "Kohaku, Ogon, Showa, Asagi, Tancho",
		"flora": "Lotus, Night Lilies, Maple Leaves, Sakura",
		"theme_data": {
			"felt_color": Color("#021711"),
			"secondary_color": Color("#053325"),
			"caustic_color": Color(0.06, 0.65, 0.48, 0.42),
			"gold_color": Color(0.96, 0.78, 0.28, 0.85)
		}
	},
	"emerald_pond": {
		"id": "emerald_pond",
		"name": "Emerald Serenity (翠玉池)",
		"subtitle": "Classic Jade Green Sanctuary",
		"desc": "Deep emerald water with shimmering 24k gold caustics, floating sacred lotus pads, and playful Kohaku and Sanke koi.",
		"mood": "Daylight Clarity & Rejuvenation · The signature Nine Rivers sanctuary.",
		"is_free": true,
		"koi": "Kohaku & Sanke (Red & White / Tricolor)",
		"flora": "Floating Sacred Lotus Pads",
		"theme_data": {
			"felt_color": Color("#021711"),
			"secondary_color": Color("#053325"),
			"caustic_color": Color(0.06, 0.65, 0.48, 0.42),
			"gold_color": Color(0.96, 0.78, 0.28, 0.85)
		}
	},
	"moonlit_river": {
		"id": "moonlit_river",
		"name": "Moonlit Twilight (月华江)",
		"subtitle": "Midnight Indigo & Silver Moonbeams",
		"desc": "Deep indigo water reflecting tranquil silver moonlight, nocturnal water lilies, and luminous metallic Ogon and Shiro koi.",
		"mood": "Deep Restfulness & Night Mode · Perfectly dark backdrop for playing in bed.",
		"is_free": true,
		"koi": "Ogon & Shiro (Platinum Gold & Pure White)",
		"flora": "Night-Blooming Silver Lilies",
		"theme_data": {
			"felt_color": Color("#040d1e"),
			"secondary_color": Color("#0b1e42"),
			"caustic_color": Color(0.18, 0.45, 0.85, 0.45),
			"gold_color": Color(0.85, 0.92, 1.0, 0.85)
		}
	},
	"autumn_stream": {
		"id": "autumn_stream",
		"name": "Autumn Maple Falls (丹枫溪)",
		"subtitle": "Warm Amber Rust & Drifting Leaves",
		"desc": "Rich amber current with fiery copper caustics, drifting crimson maple leaves, and vibrant Showa tri-colored koi.",
		"mood": "Warmth, Nostalgia & Cozy Focus · Inviting earthy tones for prolonged contemplation.",
		"is_free": true,
		"koi": "Showa & Yamabuki (Black, Red & Golden Yellow)",
		"flora": "Crimson Autumn Maple Leaves",
		"theme_data": {
			"felt_color": Color("#1a0903"),
			"secondary_color": Color("#3a1506"),
			"caustic_color": Color(0.85, 0.35, 0.10, 0.45),
			"gold_color": Color(0.98, 0.70, 0.15, 0.9)
		}
	},
	"misty_spring": {
		"id": "misty_spring",
		"name": "Misty Mountain Spring (清岚泉)",
		"subtitle": "Cool Teal Mist & Sakura Petals",
		"desc": "Glacial teal waters veiled in mountain mist, drifting delicate sakura petals, and rare blue-scaled Asagi koi.",
		"mood": "Freshness & Mental Acuity · Cool tones that keep your mind sharp and refreshed.",
		"is_free": false,
		"koi": "Asagi & Albino (Indigo Backed & Ghost White)",
		"flora": "Drifting Pale Sakura Petals",
		"theme_data": {
			"felt_color": Color("#05161b"),
			"secondary_color": Color("#0e323b"),
			"caustic_color": Color(0.20, 0.65, 0.72, 0.45),
			"gold_color": Color(0.95, 0.75, 0.82, 0.85)
		}
	},
	"sunset_haven": {
		"id": "sunset_haven",
		"name": "Sunset Lotus Haven (夕霞泽)",
		"subtitle": "Royal Violet Dusk & Crimson Glow",
		"desc": "Twilight purple water bathed in the golden-rose glow of setting sun caustics, floating magenta blossoms, and Tancho koi.",
		"mood": "Aesthetic Splendor & Twilight Serenity · Rich sunset palette for evening unwinding.",
		"is_free": false,
		"koi": "Tancho & Hi Utsuri (Red-Crowned & Flame-Banded)",
		"flora": "Twilight Purple Lotus Blossoms",
		"theme_data": {
			"felt_color": Color("#1a061d"),
			"secondary_color": Color("#3c0e44"),
			"caustic_color": Color(0.82, 0.25, 0.48, 0.45),
			"gold_color": Color(0.98, 0.68, 0.20, 0.9)
		}
	}
}

@onready var backdrop: ColorRect = $Backdrop
@onready var card_container: VBoxContainer = $Center/Card/Content
@onready var card_panel: PanelContainer = $Center/Card

var _current_screen: String = "main"

func _ready() -> void:
	visible = false
	# Transparent card: the tiles ARE the interface, floating on the live pond.
	# A bordered box around them would be exactly the "boxes inside boxes" the
	# design brief set out to remove.
	var sb_card := StyleBoxFlat.new()
	sb_card.bg_color = Color(0.04, 0.12, 0.09, 0.0)
	sb_card.content_margin_left = 54
	sb_card.content_margin_right = 54
	sb_card.content_margin_top = 28
	sb_card.content_margin_bottom = 28
	card_panel.add_theme_stylebox_override("panel", sb_card)

func show_modal() -> void:
	visible = true
	card_panel.scale = Vector2(0.92, 0.92)
	card_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_panel, "modulate:a", 1.0, 0.16)

func hide_modal() -> void:
	var tween := create_tween()
	tween.tween_property(card_panel, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func(): visible = false)

func show_main_menu() -> void:
	_current_screen = "main"
	_clear_content()
	# The Rack floats directly on the water; the tiles supply their own opacity.
	_set_card_backing(false)

	# Authentic Calligraphic Main Title
	var title_brush := Label.new()
	title_brush.text = "九河"
	title_brush.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(title_brush, "title", 80, UITheme.GOLD_CORE)
	card_container.add_child(title_brush)
	
	_add_title("NINE RIVERS")
	_add_subtitle("Zen Roguelite Mahjong Solitaire")
	
	var cur_lvl: int = int(SaveManager.prog.get("level", 1))
	var streak: int = int(SaveManager.prog.get("daily_streak", 0))
	var jade: int = SaveManager.get_jade()
	var pearls: int = MonetizationManager.get_pearls()
	
	# One compact purse line instead of four stacked tallies. The old version
	# gave the eye four identical rows to read before reaching anything
	# actionable.
	var purse := Label.new()
	purse.text = "%d ◈   ·   %d 玉   ·   %d 日" % [pearls, jade, streak]
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(purse, "ui", 21, UITheme.GOLD_MUTED)
	card_container.add_child(purse)

	_add_hairline()

	# THE RACK. Carved glyphs rather than emoji: emoji are someone else's
	# artwork in someone else's style, and Samsung, Pixel and Xiaomi each draw
	# them differently, so an art-directed screen changes shape per device.
	_add_tile_row("河", UITheme.RED_CINNABAR, "Continue Journey",
		"Stage %d of 50" % cur_lvl, "", func():
			hide_modal()
			start_calm_requested.emit(cur_lvl)
	, true)

	_add_tile_row("図", Color("#1f7a52"), "Stages Map", "Chapters I – V",
		"%d/50" % cur_lvl, func(): show_level_select())

	_add_tile_row("急", UITheme.RED_CINNABAR, "Timed Rapids", "Roguelite run",
		"", func():
			hide_modal()
			start_run_requested.emit()
	)

	_add_tile_row("潮", Color("#28527a"), "The Daily Tide", "Global challenge",
		"", func():
			hide_modal()
			start_daily_requested.emit()
	)

	_add_tile_row("鯉", Color("#1f7a52"), "Koi Sanctuary", "Zen garden",
		"", func():
			hide_modal()
			open_sanctuary_requested.emit()
	)

	_add_tile_row("市", Color("#9e6d19"), "Spirit Bazaar", "Tiles & ponds",
		"%d ◈" % pearls, func(): show_bazaar_modal())

	_add_tile_row("設", Color("#6d6455"), "Settings", "Audio & accessibility",
		"", func(): show_settings_menu())

	show_modal()

func show_level_select() -> void:
	_current_screen = "level_select"
	_clear_content()
	
	var max_unlocked: int = int(SaveManager.prog.get("level", 1))
	var stars_data: Dictionary = SaveManager.prog.get("stars", {})
	var total_stars: int = 0
	for s_val in stars_data.values():
		total_stars += int(s_val)
		
	_add_title("River Stages (九河图)")
	_add_subtitle("Calm Journey · %d / 150 ★ Stars Gathered" % total_stars)
	
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	
	var chapters: Array[Dictionary] = [
		{"name": "Chapter I: The Spring Brooks", "sub": "春溪 · Stages 1 - 10", "start": 1, "end": 10},
		{"name": "Chapter II: The Bamboo Valley", "sub": "竹谷 · Stages 11 - 20", "start": 11, "end": 20},
		{"name": "Chapter III: The Golden Rapids", "sub": "金滩 · Stages 21 - 30", "start": 21, "end": 30},
		{"name": "Chapter IV: The Jade Gorges", "sub": "玉峡 · Stages 31 - 40", "start": 31, "end": 40},
		{"name": "Chapter V: The Dragon Sea", "sub": "龙海 · Stages 41 - 50", "start": 41, "end": 50}
	]
	
	for ch in chapters:
		var ch_box := VBoxContainer.new()
		ch_box.add_theme_constant_override("separation", 6)
		
		# Chapter Header Row
		var h_box := HBoxContainer.new()
		var ch_title := Label.new()
		ch_title.text = "%s (%s)" % [ch["name"], ch["sub"]]
		ch_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(ch_title, "ui", 18, UITheme.GOLD_CORE)
		h_box.add_child(ch_title)
		
		var ch_stars: int = 0
		for lvl in range(ch["start"], ch["end"] + 1):
			ch_stars += int(stars_data.get(str(lvl), 0))
		var stars_lbl := Label.new()
		stars_lbl.text = "%d/30 ★" % ch_stars
		UITheme.style_label(stars_lbl, "ui", 17, UITheme.GOLD_BRIGHT)
		h_box.add_child(stars_lbl)
		ch_box.add_child(h_box)
		
		# Chapter Grid
		var grid := GridContainer.new()
		grid.columns = 5
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		
		for lvl in range(ch["start"], ch["end"] + 1):
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(96, 68)
			if lvl <= max_unlocked:
				var s_count: int = int(stars_data.get(str(lvl), 0))
				var star_str := ""
				for s in range(3):
					star_str += "★" if s < s_count else "☆"
				btn.text = "%d\n%s" % [lvl, star_str]
				UITheme.style_button(btn, lvl == max_unlocked, 10)
				btn.add_theme_font_size_override("font_size", 18)
				btn.pressed.connect(func():
					hide_modal()
					start_calm_requested.emit(lvl)
				)
			else:
				btn.text = "%d\n🔒" % lvl
				btn.disabled = true
				UITheme.style_button(btn, false, 10)
				btn.add_theme_font_size_override("font_size", 18)
			grid.add_child(btn)
			
		ch_box.add_child(grid)
		vbox.add_child(ch_box)
		
	scroll.add_child(vbox)
	card_container.add_child(scroll)
	
	_add_button("← Back to Main Menu", func():
		show_main_menu()
	)
	show_modal()

func show_pause_menu() -> void:
	_current_screen = "pause"
	_clear_content()
	_add_title("Paused")
	_add_subtitle("Current Score: %d" % GameManager.score)
	
	_add_button("▶ Resume Game", func():
		hide_modal()
		resume_game_requested.emit()
	, true)
	_add_button("↺ Restart Board", func():
		hide_modal()
		restart_stage_requested.emit()
	)
	_add_button("⚙️ Settings", func():
		show_settings_menu()
	)
	_add_button("⛩️ Quit to Main Menu", func():
		return_home_requested.emit()
	)
	show_modal()

func show_level_clear(level: int, score: int, stars: int) -> void:
	_current_screen = "level_clear"
	_clear_content()
	_add_title("✨ Board Cleared! ✨")
	
	var star_lbl := Label.new()
	var star_str := ""
	for i in range(3):
		star_str += "★ " if i < stars else "☆ "
	star_lbl.text = star_str.strip_edges()
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(star_lbl, "ui", 48, UITheme.GOLD_BRIGHT)
	card_container.add_child(star_lbl)
	
	_add_tally("Final Score", str(score))
	_add_tally("River Jade Earned", "+%d 🪨" % (50 * stars))
	_add_tally("Peak Flow", "×%d" % GameManager.best_flow)
	
	_add_separator()
	
	_add_button("Next Level →", func():
		hide_modal()
		next_stage_requested.emit()
	, true)
	_add_button("↺ Replay Board", func():
		hide_modal()
		restart_stage_requested.emit()
	)
	_add_button("⛩️ Main Menu", func():
		return_home_requested.emit()
	)
	show_modal()

func show_daily_clear(score: int, best_flow: int, streak: int) -> void:
	_current_screen = "daily_clear"
	_clear_content()
	_add_title("🌊 The Daily Tide Cleared! 🌊")
	_add_subtitle("River Streak: %d Days 🔥" % streak)
	
	_add_tally("Final Score", str(score))
	_add_tally("Peak Flow Multiplier", "×%d" % best_flow)
	_add_tally("Daily Tide Blessing", "+150 🪨 River Jade")
	
	SaveManager.add_jade(150)
	
	_add_button("📋 Share Scorecard (Copy)", func():
		var flow_emojis := ""
		for i in range(mini(10, best_flow)):
			flow_emojis += "🌊"
		var share_text := "Nine Rivers (九河) — The Daily Tide 🌊\nStreak: %d Days 🔥\nFlow: %s (×%d)\nScore: %s\nStatus: Clean Clear ✨" % [
			streak, flow_emojis, best_flow, score
		]
		DisplayServer.clipboard_set(share_text)
	, true)
	
	_add_button("⛩️ Main Menu", func():
		return_home_requested.emit()
	)
	show_modal()

func show_boon_draft() -> void:
	_current_screen = "boon_draft"
	_clear_content()
	_add_title("⚡ Stage Cleared! ⚡")
	_add_subtitle("Draft 1 Relic to empower your run:")
	
	var drafts: Array[Dictionary] = BoonPool.get_draft_choices(3, GameManager.active_relics)
	for b in drafts:
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 88)
		var sb_relic := UITheme.create_panel_box(Color("#0d241d"), UITheme.GOLD_CORE, 1, 12, 0.3)
		card.add_theme_stylebox_override("panel", sb_relic)
		
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 4)
		
		var h_title := Label.new()
		h_title.text = "%s %s" % [b["icon"], b["name"]]
		UITheme.style_label(h_title, "ui", 20, UITheme.GOLD_BRIGHT)
		
		var l_desc := Label.new()
		l_desc.text = b["desc"]
		UITheme.style_label(l_desc, "ui", 16, UITheme.IVORY_MUTED)
		l_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
		vbox.add_child(h_title)
		vbox.add_child(l_desc)
		card.add_child(vbox)
		
		var relic_btn := Button.new()
		relic_btn.flat = true
		relic_btn.anchors_preset = Control.PRESET_FULL_RECT
		relic_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		relic_btn.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var b_copy := b
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				GameManager.acquire_relic(b_copy)
				hide_modal()
				next_stage_requested.emit()
		)
		
		card_container.add_child(card)
		
	show_modal()

func show_game_over(reason: String) -> void:
	_current_screen = "game_over"
	_clear_content()
	_add_title("Run Concluded")
	_add_subtitle(reason)
	
	_add_tally("Final Score", str(GameManager.score))
	_add_tally("Stages Cleared", str(GameManager.current_stage_no - 1))
	_add_tally("Peak Flow", "×%d" % GameManager.best_flow)
	
	_add_separator()
	
	_add_button("📋 Share Scorecard (Copy)", func():
		var share_text := "Nine Rivers 🌊\nFlow: ×%d\nScore: %s\nStages: %d" % [
			GameManager.best_flow, GameManager.score, GameManager.current_stage_no - 1
		]
		DisplayServer.clipboard_set(share_text)
	)
	_add_button("↺ Try Again", func():
		hide_modal()
		if GameManager.current_mode == GameManager.GameMode.DAILY:
			start_daily_requested.emit()
		else:
			start_run_requested.emit()
	, true)
	_add_button("⛩️ Main Menu", func():
		return_home_requested.emit()
	)
	show_modal()

func show_sanctuary_menu() -> void:
	_current_screen = "sanctuary"
	_clear_content()
	_add_title("Koi Sanctuary (鲤鱼潭)")
	_add_subtitle("River Jade Balance: %d 🪨" % SaveManager.get_jade())
	
	for k in SanctuaryManager.KOI_SHOP:
		var unlocked: bool = SanctuaryManager.is_koi_unlocked(k["id"])
		var txt := "%s (Owned)" % k["name"] if unlocked else "%s (%d Jade)" % [k["name"], k["cost"]]
		var koi_id: String = k["id"]
		_add_button(txt, func():
			if not unlocked:
				if SanctuaryManager.unlock_koi(koi_id):
					AudioManager.play_win()
					show_sanctuary_menu()
		, unlocked)
		
	_add_button("← Back to Menu", func():
		show_main_menu()
	)

func show_bazaar_modal() -> void:
	_current_screen = "bazaar"
	_clear_content()
	
	_add_title("Spirit Bazaar (灵气集市)")
	_add_subtitle("🦪 %d Spirit Pearls | 🪨 %d River Jade" % [MonetizationManager.get_pearls(), SaveManager.get_jade()])
	_add_separator()
	
	_add_button("🀄 Artisan Tile Sets (4 Collections · Live Previews)", func():
		show_tile_catalog_modal()
	, true)
	
	_add_button("🌊 Zen Pond Backdrops (3 Free · 5 Water Themes)", func():
		show_background_catalog_modal()
	)
	
	_add_button("🦪 Pearl Treasury & Serenity (Remove Ads)", func():
		show_treasury_modal()
	)
	
	_add_button("🏮 Daily Meditations (Free Blessings & Props)", func():
		show_daily_offerings_modal()
	)
	
	_add_separator()
	_add_button("↺ Restore Purchases", func():
		MonetizationManager.restore_purchases()
		show_bazaar_modal()
	)
	_add_button("← Back to Menu", func():
		show_main_menu()
	)
	show_modal()

func show_tile_catalog_modal() -> void:
	_current_screen = "tile_catalog"
	_clear_content()
	
	_add_title("Artisan Tile Sets (麻将牌套)")
	_add_subtitle("Handcrafted 2.5D Ceramic & Volcanic Stone Sets")
	
	var cur_theme := MonetizationManager.get_active_theme()
	for theme_key in ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]:
		var detail: Dictionary = TILE_THEME_DETAILS[theme_key]
		var is_active: bool = (cur_theme == theme_key)
		var is_unlocked: bool = MonetizationManager.is_theme_unlocked(theme_key)
		
		var tag := ""
		if is_active:
			tag = "[EQUIPPED]"
		elif is_unlocked:
			tag = "[OWNED]"
		else:
			tag = "[%s]" % MonetizationManager.get_formatted_price(theme_key)
			
		var label_str := "🀄 %s · %s" % [detail["name"], tag]
		var captured_key: String = theme_key
		_add_button(label_str, func():
			show_tile_detail_modal(captured_key)
		, is_active)
		
	_add_separator()
	_add_button("← Back to Bazaar", func():
		show_bazaar_modal()
	)
	show_modal()

func show_tile_detail_modal(theme_key: String) -> void:
	_current_screen = "tile_detail"
	_clear_content()
	
	var detail: Dictionary = TILE_THEME_DETAILS.get(theme_key, TILE_THEME_DETAILS["classic_jade"])
	_add_title(detail["name"])
	_add_subtitle(detail["subtitle"])
	
	# Live visual preview row with real physical tiles
	_add_tile_preview_row(detail["samples"], theme_key)
	
	_add_description(detail["desc"])
	_add_feature_row("🎯 Tactical Purpose", detail["purpose"])
	_add_feature_row("✨ Feel & Dissolution", detail["tactile"])
	
	_add_separator()
	
	var cur_theme := MonetizationManager.get_active_theme()
	var is_active: bool = (cur_theme == theme_key)
	var is_unlocked: bool = MonetizationManager.is_theme_unlocked(theme_key)
	
	if is_active:
		_add_tally("★ Current Status", "Equipped & In Play")
	elif is_unlocked:
		_add_button("✓ Equip This Tile Set", func():
			MonetizationManager.equip_theme(theme_key)
			AudioManager.play_win()
			show_tile_detail_modal(theme_key)
		, true)
	else:
		_add_button("🦪 Buy with 1,500 Spirit Pearls", func():
			if MonetizationManager.buy_with_pearls(theme_key, func(): show_tile_detail_modal(theme_key)):
				AudioManager.play_win()
				show_tile_detail_modal(theme_key)
			else:
				show_treasury_modal()
		, true)
		_add_button("💳 Unlock for %s (Play Store / UPI)" % MonetizationManager.get_formatted_price(theme_key), func():
			MonetizationManager.buy_product(theme_key, func(): show_tile_detail_modal(theme_key))
		)
		
	_add_button("← Back to Tile Sets", func():
		show_tile_catalog_modal()
	)
	show_modal()

func show_background_catalog_modal() -> void:
	_current_screen = "bg_catalog"
	_clear_content()
	
	_add_title("Zen Pond Backdrops (水榭背幕)")
	_add_subtitle("3 Free Environments · Living Shaders & Koi")
	
	var cur_bg := MonetizationManager.get_active_background_theme()
	for bg_id in ["auto", "emerald_pond", "moonlit_river", "autumn_stream", "misty_spring", "sunset_haven"]:
		var detail: Dictionary = BG_THEME_DETAILS[bg_id]
		var is_active: bool = (cur_bg == bg_id)
		var is_unlocked: bool = MonetizationManager.is_background_theme_unlocked(bg_id)
		
		var tag := ""
		if is_active:
			tag = "[ACTIVE]"
		elif bool(detail.get("is_free", false)):
			tag = "[FREE]"
		elif is_unlocked:
			tag = "[OWNED]"
		else:
			tag = "[1,500 🪨 / 500 🦪]"
			
		var label_str := "🌊 %s · %s" % [detail["name"], tag]
		var captured_id: String = bg_id
		_add_button(label_str, func():
			show_background_detail_modal(captured_id)
		, is_active)
		
	_add_separator()
	_add_button("← Back to Bazaar", func():
		show_bazaar_modal()
	)
	show_modal()

func show_background_detail_modal(theme_id: String) -> void:
	_current_screen = "bg_detail"
	_clear_content()
	
	var detail: Dictionary = BG_THEME_DETAILS.get(theme_id, BG_THEME_DETAILS["emerald_pond"])
	_add_title(detail["name"])
	_add_subtitle(detail["subtitle"])
	
	_add_palette_preview_card(detail["theme_data"])
	
	_add_description(detail["desc"])
	_add_feature_row("🌊 Water Atmosphere", detail["mood"])
	_add_feature_row("🐟 Living Koi Species", detail["koi"])
	_add_feature_row("🪷 Floating Aquatic Flora", detail["flora"])
	
	_add_separator()
	
	var cur_bg := MonetizationManager.get_active_background_theme()
	var is_active: bool = (cur_bg == theme_id)
	var is_unlocked: bool = MonetizationManager.is_background_theme_unlocked(theme_id)
	
	if is_active:
		_add_tally("★ Current Status", "Currently Flowing in Background")
	elif is_unlocked:
		_add_button("✓ Flow in This Pond (Equip)", func():
			MonetizationManager.equip_background_theme(theme_id)
			AudioManager.play_win()
			show_background_detail_modal(theme_id)
		, true)
	else:
		_add_button("🪨 Unlock with 1,500 River Jade", func():
			if MonetizationManager.buy_background_with_jade(theme_id):
				show_background_detail_modal(theme_id)
		, true)
		_add_button("🦪 Unlock with 500 Spirit Pearls", func():
			if MonetizationManager.buy_background_with_pearls(theme_id):
				show_background_detail_modal(theme_id)
			else:
				show_treasury_modal()
		)
		_add_button("💳 Unlock for %s (Play Store / UPI)" % MonetizationManager.get_formatted_price("bg_" + theme_id), func():
			MonetizationManager.buy_product("bg_" + theme_id, func(): show_background_detail_modal(theme_id))
		)
		
	_add_button("← Back to Pond Themes", func():
		show_background_catalog_modal()
	)
	show_modal()

func show_treasury_modal() -> void:
	_current_screen = "treasury"
	_clear_content()
	
	_add_title("Pearl Treasury & Serenity (宝库)")
	_add_subtitle("🦪 %d Spirit Pearls in Treasury" % MonetizationManager.get_pearls())
	
	if not MonetizationManager.is_no_ads():
		_add_button("🌸 Serenity Blessing (No-Ads + 500 🦪) — %s" % MonetizationManager.get_formatted_price("no_ads"), func():
			MonetizationManager.buy_product("no_ads", func(): show_treasury_modal())
		, true)
	else:
		_add_tally("✨ Serenity Status", "Permanent No-Ads Active (+Daily Prop)")
		
	_add_button("🦪 Pouch of 500 Pearls — %s" % MonetizationManager.get_formatted_price("pearls_small"), func():
		MonetizationManager.buy_product("pearls_small", func(): show_treasury_modal())
	)
	_add_button("🦪 Chest of 2,500 Pearls (+25%) — %s" % MonetizationManager.get_formatted_price("pearls_medium"), func():
		MonetizationManager.buy_product("pearls_medium", func(): show_treasury_modal())
	)
	_add_button("🦪 Dragon Hoard (7,500 Pearls +50%) — %s" % MonetizationManager.get_formatted_price("pearls_large"), func():
		MonetizationManager.buy_product("pearls_large", func(): show_treasury_modal())
	)
	
	_add_separator()
	_add_button("↺ Restore Purchases", func():
		MonetizationManager.restore_purchases()
		show_treasury_modal()
	)
	_add_button("← Back to Bazaar", func():
		show_bazaar_modal()
	)
	show_modal()

func show_daily_offerings_modal() -> void:
	_current_screen = "daily_offerings"
	_clear_content()
	
	_add_title("Daily Meditations (晨钟暮鼓)")
	_add_subtitle("Spiritual Blessings & Optional Offerings")
	
	var remaining_ads: int = MonetizationManager.get_remaining_rewarded_ads()
	if remaining_ads > 0:
		_add_button("🏮 Daily Meditation Blessing (+60 🦪 Free / Ad) [%d left]" % remaining_ads, func():
			MonetizationManager.show_rewarded_ad("daily_pearls", func(_t, _a):
				AudioManager.play_win()
				show_daily_offerings_modal()
			)
		, true)
		_add_button("🎋 Spirits' Prop Aid (+1 Hint & Shuffle / Ad)", func():
			MonetizationManager.show_rewarded_ad("props_refill", func(_t, _a):
				AudioManager.play_win()
				show_daily_offerings_modal()
			)
		)
	else:
		_add_tally("🏮 Daily Offerings", "Completed for today (resets at dawn)")
		
	_add_separator()
	_add_button("← Back to Bazaar", func():
		show_bazaar_modal()
	)
	show_modal()

func show_settings_menu() -> void:
	_current_screen = "settings"
	_clear_content()
	_add_seal_header("Settings", "設 · Audio & accessibility", "設")
	_add_hairline()

	# Carved glyphs, not emoji. 音 sound, 振 vibration, 動 motion, 眼 eye,
	# 界 boundary - each is the actual character for the thing it controls, so
	# the icon set is meaningful rather than decorative.
	var on_col := Color("#57bd92")
	var off_col := UITheme.IVORY_MUTED

	_add_toggle_row("音", "Ambient Music",
		"On" if SettingsManager.music_enabled else "Off", func():
			SettingsManager.toggle_setting("music")
			show_settings_menu()
	, on_col if SettingsManager.music_enabled else off_col)

	_add_toggle_row("響", "Tile ASMR Clacks",
		"On" if SettingsManager.sfx_enabled else "Off", func():
			SettingsManager.toggle_setting("sfx")
			show_settings_menu()
	, on_col if SettingsManager.sfx_enabled else off_col)

	_add_toggle_row("振", "Haptic Vibration",
		"On" if SettingsManager.haptics_enabled else "Off", func():
			SettingsManager.toggle_setting("haptics")
			show_settings_menu()
	, on_col if SettingsManager.haptics_enabled else off_col)

	_add_toggle_row("動", "Motion",
		SettingsManager.motion_mode.capitalize(), func():
			SettingsManager.toggle_setting("motion")
			show_settings_menu()
	)

	_add_toggle_row("眼", "Colour-Blind Mode",
		SettingsManager.color_blind_mode.capitalize(), func():
			SettingsManager.toggle_setting("color_blind_mode")
			show_settings_menu()
	)

	_add_toggle_row("界", "High Contrast Borders",
		"On" if SettingsManager.high_contrast_borders else "Off", func():
			SettingsManager.toggle_setting("high_contrast_borders")
			show_settings_menu()
	, on_col if SettingsManager.high_contrast_borders else off_col)

	# NOTE: the Cloud Save toggle lives on feat/cloud-save-pgs, where the
	# CloudSaveManager autoload exists. Referencing it here would not parse.
	
	_add_separator()
	_add_toggle_row("教", "Replay Tutorial", "›", func():
		hide_modal()
		replay_tutorial_requested.emit()
	)
	_add_toggle_row("約", "Privacy Policy", "›", func(): show_privacy_modal())
	_add_toggle_row("謝", "Credits", "›", func(): show_credits_modal())

	_add_separator()
	_add_button("Back", func():
		if GameManager.is_timer_active:
			show_pause_menu()
		else:
			show_main_menu()
	)
	show_modal()

func show_privacy_modal() -> void:
	_current_screen = "privacy"
	_clear_content()
	_add_title("Privacy Policy")
	_add_subtitle("Nine Rivers (九河)")
	
	_add_tally("Data Collection", "Zero Personal Data Collected")
	_add_tally("Save Storage", "100% Local Device Storage")
	_add_tally("In-App Purchases", "Secure Apple / Google Play")
	_add_tally("Family Safe", "COPPA & All-Ages Compliant")
	
	_add_separator()
	_add_button("← Back to Settings", func():
		show_settings_menu()
	)
	show_modal()

func show_credits_modal() -> void:
	_current_screen = "credits"
	_clear_content()
	_add_title("Nine Rivers (九河)")
	_add_subtitle("Credits & Acknowledgments")
	
	_add_tally("Game Design", "Nine Rivers Studio")
	_add_tally("Art Direction", "Imperial Ceramic & Ink Vector Engine")
	_add_tally("Typography", "Noto Serif CJK & Ma Shan Zheng")
	_add_tally("Audio Synthesis", "Procedural Guzheng & Acoustic Clacks")
	_add_tally("Engine", "Godot Engine 4.6")
	
	_add_separator()
	_add_button("← Back to Settings", func():
		show_settings_menu()
	)
	show_modal()

func handle_back_pressed() -> void:
	match _current_screen:
		"level_select", "sanctuary", "bazaar":
			show_main_menu()
		"tile_catalog", "bg_catalog", "treasury", "daily_offerings":
			show_bazaar_modal()
		"tile_detail":
			show_tile_catalog_modal()
		"bg_detail":
			show_background_catalog_modal()
		"settings":
			if GameManager.is_timer_active:
				show_pause_menu()
			else:
				show_main_menu()
		"privacy", "credits":
			show_settings_menu()
		"pause":
			hide_modal()
			resume_game_requested.emit()
		"level_clear", "daily_clear", "game_over":
			hide_modal()
			return_home_requested.emit()
		_:
			pass

# ================= HELPER BUILDERS =================
## The Rack needs no panel: the ivory tiles are opaque and carry themselves, so
## the pond shows between them. Text screens DO need one - koi swim straight
## through unbacked text and it becomes unreadable.
func _set_card_backing(frosted: bool) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.035, 0.105, 0.085, 0.93) if frosted else Color(0, 0, 0, 0.0)
	sb.set_corner_radius_all(18 if frosted else 0)
	sb.content_margin_left = 44 if frosted else 54
	sb.content_margin_right = 44 if frosted else 54
	sb.content_margin_top = 34 if frosted else 28
	sb.content_margin_bottom = 34 if frosted else 28
	if frosted:
		# One hairline at the top edge only, rather than a box around everything.
		sb.border_width_top = 1
		sb.border_color = Color(UITheme.GOLD_MUTED.r, UITheme.GOLD_MUTED.g, UITheme.GOLD_MUTED.b, 0.30)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 8)
	sb.anti_aliasing = true
	card_panel.add_theme_stylebox_override("panel", sb)

func _clear_content() -> void:
	# Default to frosted; show_main_menu() opts out for the Rack.
	_set_card_backing(true)
	for c in card_container.get_children():
		c.queue_free()

# ======================= THE RACK =======================
## Menu rows are mahjong tiles lying face-up on the water, not rounded
## rectangles with emoji. Ivory ceramic face, the warm biscuit underside showing
## as a lip along the bottom, a carved glyph where a suit symbol would sit.
## The point is that the interface is made of the same material as the game.

const TILE_IVORY := Color("#fdf8ec")
const TILE_IVORY_DIM := Color("#efe6d2")
const TILE_BISCUIT := Color("#b79f74")   # the tile's own 3D underside
const TILE_INK := Color("#232b26")
const TILE_SUBINK := Color("#6d6455")
const TILE_META := Color("#8a7f6b")
const RICE_PAPER := Color("#f0e6d2")
const PAPER_INK := Color("#2b2519")
const PAPER_RULE := Color(0.47, 0.39, 0.24, 0.22)

static func _make_tile_box(pressed: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = TILE_IVORY
	sb.set_corner_radius_all(9)
	# The bottom border IS the tile's extruded underside. This is what makes it
	# read as a physical object rather than a card.
	sb.border_width_bottom = 0 if pressed else 6
	sb.border_color = TILE_BISCUIT
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16 if not pressed else 20
	sb.content_margin_bottom = 16
	sb.shadow_color = Color(0, 0, 0, 0.42)
	sb.shadow_size = 0 if pressed else 7
	sb.shadow_offset = Vector2(0, 4)
	sb.anti_aliasing = true
	return sb

## One tile in the rack.
##   glyph   - a single carved character, standing in for a suit symbol
##   banded  - draws the gold band of a banded triple, which the player has
##             already been taught means "this one is worth more"
func _add_tile_row(glyph: String, glyph_col: Color, title: String, sub: String,
		meta: String, on_click: Callable, banded: bool = false) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 96)
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _make_tile_box())
	b.add_theme_stylebox_override("hover", _make_tile_box())
	b.add_theme_stylebox_override("focus", _make_tile_box())
	b.add_theme_stylebox_override("pressed", _make_tile_box(true))
	b.pressed.connect(on_click)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24; row.offset_right = -24
	# -12 at the bottom leaves the biscuit lip exposed; that lip is the whole
	# reason this reads as a tile rather than a list row.
	row.offset_top = 0; row.offset_bottom = -12
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var g := Label.new()
	g.text = glyph
	g.custom_minimum_size = Vector2(56, 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(g, "cjk", 46, glyph_col)
	row.add_child(g)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)

	var t := Label.new()
	t.text = title
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(t, "ui", 27, TILE_INK)
	col.add_child(t)

	if not sub.is_empty():
		var s := Label.new()
		s.text = sub
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.style_label(s, "ui", 17, TILE_SUBINK)
		col.add_child(s)

	if not meta.is_empty():
		var m := Label.new()
		m.text = meta
		m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.style_label(m, "ui", 19, TILE_META)
		row.add_child(m)

	if banded:
		# Gold band along the bottom bezel, same as a banded triple in play.
		var band := ColorRect.new()
		band.color = UITheme.GOLD_CORE
		band.custom_minimum_size = Vector2(0, 7)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		band.offset_left = 14; band.offset_right = -14
		band.offset_top = -19; band.offset_bottom = -12
		b.add_child(band)

	card_container.add_child(b)

## A hairline that fades at both ends, instead of another boxed border.
func _add_hairline() -> void:
	var g := GradientTexture2D.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([
		Color(UITheme.GOLD_MUTED.r, UITheme.GOLD_MUTED.g, UITheme.GOLD_MUTED.b, 0.0),
		Color(UITheme.GOLD_MUTED.r, UITheme.GOLD_MUTED.g, UITheme.GOLD_MUTED.b, 0.5),
		Color(UITheme.GOLD_MUTED.r, UITheme.GOLD_MUTED.g, UITheme.GOLD_MUTED.b, 0.0),
	])
	g.gradient = grad
	g.width = 256
	g.height = 1
	var tr := TextureRect.new()
	tr.texture = g
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.custom_minimum_size = Vector2(0, 1)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_container.add_child(tr)

## Header for a sub-screen: title, romanised subtitle, and ONE cinnabar seal.
## Cinnabar is the strongest colour available, so it is spent exactly once per
## screen rather than sprinkled around.
func _add_seal_header(title: String, sub: String, seal_glyph: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card_container.add_child(row)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var t := Label.new()
	t.text = title
	UITheme.style_label(t, "title", 40, UITheme.GOLD_CORE)
	col.add_child(t)

	if not sub.is_empty():
		var s := Label.new()
		s.text = sub
		UITheme.style_label(s, "ui", 19, UITheme.IVORY_MUTED)
		col.add_child(s)

	var seal := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.RED_CINNABAR
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 12; sb.content_margin_right = 12
	sb.content_margin_top = 6; sb.content_margin_bottom = 8
	seal.add_theme_stylebox_override("panel", sb)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seal)

	var sl := Label.new()
	sl.text = seal_glyph
	UITheme.style_label(sl, "cjk", 34, Color("#fff4ef"))
	seal.add_child(sl)

## A tappable settings line: carved glyph, label, current value. Hairline rule
## underneath instead of a box around it, so ten of these read as one list
## rather than ten separate objects.
func _add_toggle_row(glyph: String, label: String, value: String,
		on_click: Callable, value_col: Color = UITheme.GOLD_CORE) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 62)
	var flat := StyleBoxEmpty.new()
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(1, 1, 1, 0.045)
	hov.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("focus", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.pressed.connect(on_click)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8; row.offset_right = -8
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var g := Label.new()
	g.text = glyph
	g.custom_minimum_size = Vector2(40, 0)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(g, "cjk", 28, UITheme.GOLD_MUTED)
	row.add_child(g)

	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(l, "ui", 23, UITheme.IVORY_BASE)
	row.add_child(l)

	var v := Label.new()
	v.text = value
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(v, "ui", 22, value_col)
	row.add_child(v)

	card_container.add_child(b)
	_add_hairline()

## A key/value line on the rice-paper sheet: hairline rule, no boxes.
func _add_sheet_row(key: String, val: String, val_col: Color = UITheme.IVORY_BASE) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.custom_minimum_size = Vector2(0, 54)
	card_container.add_child(row)

	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UITheme.style_label(k, "ui", 22, UITheme.IVORY_MUTED)
	row.add_child(k)

	var v := Label.new()
	v.text = val
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(v, "ui", 23, val_col)
	row.add_child(v)

	_add_hairline()

func _add_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "title", 42, UITheme.GOLD_CORE)
	card_container.add_child(l)

func _add_subtitle(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", 23, UITheme.IVORY_MUTED)
	card_container.add_child(l)

func _add_description(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", 21, Color(0.85, 0.90, 0.88))
	card_container.add_child(l)

func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 14)
	card_container.add_child(sep)

func _add_tally(key: String, val: String) -> void:
	var box := HBoxContainer.new()
	var l_k := Label.new()
	l_k.text = key
	l_k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UITheme.style_label(l_k, "ui", 24, Color(0.72, 0.82, 0.77))
	
	var l_v := Label.new()
	l_v.text = val
	UITheme.style_label(l_v, "ui", 26, UITheme.GOLD_BRIGHT)
	
	box.add_child(l_k)
	box.add_child(l_v)
	card_container.add_child(box)

func _add_feature_row(key: String, val: String) -> void:
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 2)
	
	var l_k := Label.new()
	l_k.text = key
	UITheme.style_label(l_k, "ui", 22, UITheme.GOLD_CORE)
	
	var l_v := Label.new()
	l_v.text = val
	l_v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(l_v, "ui", 20, Color(0.82, 0.90, 0.86))
	
	v_box.add_child(l_k)
	v_box.add_child(l_v)
	card_container.add_child(v_box)

func _add_tile_preview_row(samples: Array, theme_id: String) -> void:
	var center_box := CenterContainer.new()
	center_box.custom_minimum_size = Vector2(0, 110)
	
	var preview_panel := PanelContainer.new()
	var sb := UITheme.create_panel_box(Color(0.02, 0.08, 0.06, 0.85), UITheme.GOLD_MUTED, 1, 14, 0.3)
	preview_panel.add_theme_stylebox_override("panel", sb)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 24)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for s in samples:
		var suit: String = s[0]
		var rank: int = int(s[1])
		var tile_ctrl := TileView.create_preview_tile(suit, rank, theme_id, 1.0)
		hbox.add_child(tile_ctrl)
		
	margin.add_child(hbox)
	preview_panel.add_child(margin)
	center_box.add_child(preview_panel)
	card_container.add_child(center_box)

func _add_palette_preview_card(theme_data: Dictionary) -> void:
	var center_box := CenterContainer.new()
	center_box.custom_minimum_size = Vector2(0, 90)
	
	var preview_panel := PanelContainer.new()
	var sb := UITheme.create_panel_box(Color(0.02, 0.08, 0.06, 0.85), UITheme.GOLD_MUTED, 1, 14, 0.3)
	preview_panel.add_theme_stylebox_override("panel", sb)
	
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var colors: Array = [
		{"name": "Water Felt", "col": theme_data.get("felt_color", Color.BLACK)},
		{"name": "Depth Tone", "col": theme_data.get("secondary_color", Color.BLACK)},
		{"name": "Caustics", "col": theme_data.get("caustic_color", Color.WHITE)},
		{"name": "Gold Vein", "col": theme_data.get("gold_color", Color.GOLD)}
	]
	
	for c_info in colors:
		var v_item := VBoxContainer.new()
		v_item.alignment = BoxContainer.ALIGNMENT_CENTER
		
		var swatch := ColorRect.new()
		swatch.color = c_info["col"]
		swatch.custom_minimum_size = Vector2(60, 36)
		
		var lbl := Label.new()
		lbl.text = c_info["name"]
		UITheme.style_label(lbl, "ui", 16, UITheme.IVORY_MUTED)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		v_item.add_child(swatch)
		v_item.add_child(lbl)
		hbox.add_child(v_item)
		
	margin.add_child(hbox)
	preview_panel.add_child(margin)
	center_box.add_child(preview_panel)
	card_container.add_child(center_box)

func _add_button(text: String, on_click: Callable, is_gold: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 84)
	UITheme.style_button(b, is_gold, 16)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(on_click)
	card_container.add_child(b)
