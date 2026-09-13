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

@onready var backdrop: ColorRect = $Backdrop
@onready var card_container: VBoxContainer = $Center/Card/Content
@onready var card_panel: PanelContainer = $Center/Card

var _current_screen: String = "main"

func _ready() -> void:
	visible = false
	var sb_card := UITheme.create_panel_box(Color(0.04, 0.12, 0.09, 0.97), UITheme.GOLD_MUTED, 2, 20, 0.6)
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
	
	_add_tally("🌊 Journey Progress", "Stage %d / 50" % cur_lvl)
	_add_tally("🦪 Spirit Pearls", "%d" % pearls)
	_add_tally("🪨 River Jade", "%d" % jade)
	_add_tally("🔥 Daily Tide Streak", "%d Days" % streak)
	
	_add_separator()
	
	_add_button("⛩️ Continue Journey (Stage %d)" % cur_lvl, func():
		hide_modal()
		start_calm_requested.emit(cur_lvl)
	, true)
	
	_add_button("📜 Stages Map (1 - 50)", func():
		show_level_select()
	)
	
	_add_button("⚡ Timed Rapids (Roguelite Run)", func():
		hide_modal()
		start_run_requested.emit()
	)
	
	_add_button("🌊 The Daily Tide (Global Challenge)", func():
		hide_modal()
		start_daily_requested.emit()
	)
	
	_add_button("🏮 Koi Sanctuary (Zen Garden)", func():
		hide_modal()
		open_sanctuary_requested.emit()
	)
	
	_add_button("💎 Spirit Bazaar & Treasury", func():
		show_bazaar_modal()
	)
	
	_add_button("⚙️ Settings & Accessibility", func():
		show_settings_menu()
	)
	
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
	
	# Section 1: Serenity Blessing & Pearls Treasury
	if not MonetizationManager.is_no_ads():
		_add_button("🌸 Serenity Blessing (No-Ads + 500 🦪) — %s" % MonetizationManager.get_formatted_price("no_ads"), func():
			MonetizationManager.buy_product("no_ads", func(): show_bazaar_modal())
		, true)
	else:
		_add_tally("✨ Serenity Status", "Permanent No-Ads Active (+Daily Prop)")
		
	_add_button("🦪 Pouch of 500 Pearls — %s" % MonetizationManager.get_formatted_price("pearls_small"), func():
		MonetizationManager.buy_product("pearls_small", func(): show_bazaar_modal())
	)
	_add_button("🦪 Chest of 2,500 Pearls (+25%) — %s" % MonetizationManager.get_formatted_price("pearls_medium"), func():
		MonetizationManager.buy_product("pearls_medium", func(): show_bazaar_modal())
	)
	_add_button("🦪 Dragon Hoard (7,500 Pearls +50%) — %s" % MonetizationManager.get_formatted_price("pearls_large"), func():
		MonetizationManager.buy_product("pearls_large", func(): show_bazaar_modal())
	)
	
	_add_separator()
	
	# Section 2: Artisan Cosmetic Themes
	var cur_theme := MonetizationManager.get_active_theme()
	for theme_key in ["theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]:
		var prod: Dictionary = MonetizationManager.PRODUCTS[theme_key]
		var is_unlocked: bool = MonetizationManager.is_theme_unlocked(theme_key)
		var is_active: bool = (cur_theme == theme_key)
		
		var btn_label := ""
		if is_active:
			btn_label = "✓ %s (Equipped)" % prod["name"]
		elif is_unlocked:
			btn_label = "Equip: %s" % prod["name"]
		else:
			btn_label = "Unlock %s (%s)" % [prod["name"], MonetizationManager.get_formatted_price(theme_key)]
			
		_add_button(btn_label, func():
			if is_active:
				return
			elif is_unlocked:
				MonetizationManager.equip_theme(theme_key)
				show_bazaar_modal()
			else:
				if not MonetizationManager.buy_with_pearls(theme_key, func(): show_bazaar_modal()):
					MonetizationManager.buy_product(theme_key, func(): show_bazaar_modal())
		, is_active)
	
	_add_separator()
	
	# Section 3: Spiritual Offerings (Rewarded Ads)
	var remaining_ads: int = MonetizationManager.get_remaining_rewarded_ads()
	if remaining_ads > 0:
		_add_button("🏮 Daily Meditation Blessing (+60 🦪 Free / Ad) [%d left]" % remaining_ads, func():
			MonetizationManager.show_rewarded_ad("daily_pearls", func(_t, _a):
				AudioManager.play_win()
				show_bazaar_modal()
			)
		)
		_add_button("🎋 Spirits' Prop Aid (+1 Hint & Shuffle / Ad)", func():
			MonetizationManager.show_rewarded_ad("props_refill", func(_t, _a):
				AudioManager.play_win()
				show_bazaar_modal()
			)
		)
	else:
		_add_tally("🏮 Daily Offerings", "Completed for today (resets at dawn)")
	
	_add_separator()
	_add_button("↺ Restore Purchases", func():
		MonetizationManager.restore_purchases()
		show_bazaar_modal()
	)
	_add_button("← Back to Menu", func():
		show_main_menu()
	)
	show_modal()

func show_settings_menu() -> void:
	_current_screen = "settings"
	_clear_content()
	_add_title("Settings & Accessibility")
	_add_subtitle("Audio, Display & Preferences")
	
	_add_button("🎵 Ambient Music: " + ("ON" if SettingsManager.music_enabled else "OFF"), func():
		SettingsManager.toggle_setting("music")
		show_settings_menu()
	)
	_add_button("🥢 Tile ASMR Clacks: " + ("ON" if SettingsManager.sfx_enabled else "OFF"), func():
		SettingsManager.toggle_setting("sfx")
		show_settings_menu()
	)
	_add_button("📳 Haptic Vibrations: " + ("ON" if SettingsManager.haptics_enabled else "OFF"), func():
		SettingsManager.toggle_setting("haptics")
		show_settings_menu()
	)
	_add_button("💨 Motion Mode: " + SettingsManager.motion_mode.to_upper(), func():
		SettingsManager.toggle_setting("motion")
		show_settings_menu()
	)
	_add_button("👁️ Color-Blind Mode: " + SettingsManager.color_blind_mode.capitalize(), func():
		SettingsManager.toggle_setting("color_blind_mode")
		show_settings_menu()
	)
	_add_button("🔲 High Contrast Borders: " + ("ON" if SettingsManager.high_contrast_borders else "OFF"), func():
		SettingsManager.toggle_setting("high_contrast_borders")
		show_settings_menu()
	)
	
	_add_separator()
	_add_button("📖 Replay Tutorial", func():
		hide_modal()
		replay_tutorial_requested.emit()
	)
	_add_button("📜 Privacy Policy", func():
		show_privacy_modal()
	)
	_add_button("🏆 Credits & Acknowledgments", func():
		show_credits_modal()
	)
	_add_button("← Back", func():
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
func _clear_content() -> void:
	for c in card_container.get_children():
		c.queue_free()

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

func _add_button(text: String, on_click: Callable, is_gold: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 84)
	UITheme.style_button(b, is_gold, 16)
	b.add_theme_font_size_override("font_size", 26)
	b.pressed.connect(on_click)
	card_container.add_child(b)
