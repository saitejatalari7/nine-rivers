class_name ModalController
extends CanvasLayer

## Nine Rivers - Imperial Modal & Relic Deck Controller
## Features lacquered scroll framing, golden crest headers, and responsive level grid.

signal start_calm_requested(level: int)
signal start_run_requested()
signal start_daily_requested()
signal restart_stage_requested()
signal next_stage_requested()
signal premium_shop_requested()
signal deadlock_accepted()
signal deadlock_retry()
signal resume_game_requested()
## The board the player was on when the app closed, not the pause menu's Resume.
signal resume_session_requested()
## Leaving the game entirely, from the main menu only.
signal quit_requested()
signal return_home_requested()
signal replay_tutorial_requested()
signal background_quiet_changed(quiet: bool)

const UITheme = preload("res://scripts/ui/ui_theme.gd")
const StagePlan = preload("res://scripts/core/stage_plan.gd")

const TILE_THEME_DETAILS: Dictionary = {
	"classic_jade": {
		"id": "classic_jade",
		"name": "Classic Jade",
		"subtitle": "Timeless Chinese Ceramic Craftsmanship",
		"desc": "Fine milk-ivory ceramic tiles with hand-engraved cinnabar vermilion and emerald jade calligraphy on a warm biscuit terracotta underside.",
		"purpose": "Balanced natural contrast for both bright sunlight and dim rooms. High-clarity strokes prevent misreads during fast-paced clearing.",
		"tactile": "Smooth glazed ceramic texture with crisp, acoustic stone clacks. Clears fracture into delicate jade dust.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 2]]
	},
	"theme_imperial_gold": {
		"id": "theme_imperial_gold",
		"name": "Imperial Gold",
		"subtitle": "24-Karat Gold Leaf on Crimson Lacquer",
		"desc": "Opulent gilded face with delicate chased gold filigree on imperial crimson lacquer backing. Fits the grandeur of royal courts.",
		"purpose": "Maximum visual prominence. Gilded tile faces catch the light, making free playable tiles immediately distinct in dense 3D stacks.",
		"tactile": "Heavy lacquered clack. Every match disintegrates into a radiant shower of glittering 24k golden sand.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 2]]
	},
	"theme_obsidian_ink": {
		"id": "theme_obsidian_ink",
		"name": "Obsidian Ink",
		"subtitle": "Polished Basalt Stone & Luminous White Jade",
		"desc": "Carved from deep volcanic basalt stone with luminous white-jade glyphs and cinnabar seals on a dark basalt underside.",
		"purpose": "True OLED Dark Mode. Drastically minimizes screen glare and blue light emissions, preventing eye strain during evening play.",
		"tactile": "Deep, resonant mineral clatter. Matched pairs disperse into wisps of midnight basalt mist.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 1]]
	},
	# Earned, never sold. It has no Play Store price, so the detail screen shows
	# one row rather than a price and a purchase.
	"theme_indigo": {
		"id": "theme_indigo",
		"name": "Deep Indigo",
		"subtitle": "Polished Indigo Glaze, Earned at the Board",
		"desc": "Night-blue porcelain under a high polish, with pale gold calligraphy and a rim where the glaze has pooled and caught the light.",
		"purpose": "The only set that cannot be bought. Pale ink on a deep face reads cleanly in a dark room without the glare of a light tile.",
		"tactile": "A low glassy chime. Matched tiles break into cold blue light.",
		"samples": [["bam", 1], ["char", 9], ["dragon", 2]]
	},
	"theme_cherry_blossom": {
		"id": "theme_cherry_blossom",
		"name": "Cherry Blossom",
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
		"name": "Dynamic River Flow",
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
		"name": "Emerald Serenity",
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
		"name": "Moonlit Twilight",
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
		"name": "Autumn Maple Falls",
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
		"name": "Misty Mountain Spring",
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
		"name": "Sunset Lotus Haven",
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
@onready var card_container: VBoxContainer = $Center/Card/Scroll/Content
@onready var card_panel: PanelContainer = $Center/Card
@onready var scroll_view: ScrollContainer = $Center/Card/Scroll

var _current_screen: String = "main": set = _set_current_screen

## The one screen where the pond is the hero, so it is not throttled.
const LIGHT_SCREENS: Array[String] = ["main"]

func _set_current_screen(value: String) -> void:
	_current_screen = value
	_sync_background_load()
	# Screens build synchronously after this, so a one-frame wait measures them.
	_fit_scroll()

## A ScrollContainer reports a near-zero minimum size, which would collapse the
## card, so size it to its content and cap it at the space available.
func _fit_scroll() -> void:
	if not is_instance_valid(scroll_view):
		return
	await get_tree().process_frame
	if not is_instance_valid(scroll_view) or not is_instance_valid(card_container):
		return
	var vp := get_viewport()
	if vp == null:
		return
	var insets: Vector2 = UITheme.get_safe_insets(vp)
	# Measured, not assumed: _set_card_backing swaps the stylebox per screen.
	var chrome: float = 0.0
	var sb: StyleBox = card_panel.get_theme_stylebox("panel")
	if sb != null:
		chrome = sb.get_margin(SIDE_TOP) + sb.get_margin(SIDE_BOTTOM)
	var avail: float = vp.get_visible_rect().size.y - insets.x - insets.y - chrome
	var wanted: float = card_container.get_combined_minimum_size().y
	scroll_view.custom_minimum_size.y = minf(wanted, maxf(avail, 240.0))

func _sync_background_load() -> void:
	background_quiet_changed.emit(visible and not (_current_screen in LIGHT_SCREENS))

func _apply_safe_area() -> void:
	var insets: Vector2 = UITheme.get_safe_insets(get_viewport())
	var c := $Center
	c.offset_top = insets.x
	c.offset_bottom = -insets.y
	_fit_scroll()

func _ready() -> void:
	visible = false
	_apply_safe_area()
	get_tree().get_root().size_changed.connect(_apply_safe_area)
	await get_tree().process_frame
	_apply_safe_area()
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

## hide_modal() only clears `visible` from a tween callback, so a screen that
## hides and immediately re-shows (back out of Board Cleared, which hides the
## card and then asks main.gd for the home screen) would be switched off again a
## frame later, leaving the player staring at an empty pond.
## Both transitions are tracked, not just the hide. An untracked show tween
## outlives the hide that was meant to cancel it and keeps driving the card's
## alpha after the hide callback has already switched `visible` off.
var _hide_tween: Tween = null
var _show_tween: Tween = null

func _kill_transitions() -> void:
	if _hide_tween != null and _hide_tween.is_valid():
		_hide_tween.kill()
	_hide_tween = null
	if _show_tween != null and _show_tween.is_valid():
		_show_tween.kill()
	_show_tween = null

func show_modal() -> void:
	_kill_transitions()
	visible = true
	_sync_background_load()
	_fit_scroll()
	card_panel.scale = Vector2(0.92, 0.92)
	card_panel.modulate.a = 0.0
	_show_tween = create_tween().set_parallel(true)
	_show_tween.tween_property(card_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_tween.tween_property(card_panel, "modulate:a", 1.0, 0.16)

func hide_modal() -> void:
	_kill_transitions()
	_hide_tween = create_tween()
	_hide_tween.tween_property(card_panel, "modulate:a", 0.0, 0.12)
	_hide_tween.tween_callback(func():
		visible = false
		_hide_tween = null
		_sync_background_load())

func show_main_menu() -> void:
	_current_screen = "main"
	_clear_content()
	# The Rack floats directly on the water; the tiles supply their own opacity.
	_set_card_backing(false)

	_add_title("NINE RIVERS")
	_add_subtitle("Zen Roguelite Mahjong Solitaire")
	
	var cur_lvl: int = int(SaveManager.prog.get("level", 1))
	var streak: int = int(SaveManager.prog.get("daily_streak", 0))
	var pearls: int = MonetizationManager.get_pearls()
	
	# One compact purse line instead of four stacked tallies. The old version
	# gave the eye four identical rows to read before reaching anything
	# actionable.
	var purse := Label.new()
	purse.text = "%d ◈   ·   %d day streak" % [pearls, streak]
	purse.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(purse, "ui", UITheme.FS_CAPTION, UITheme.GOLD_MUTED,
		UITheme.W_MEDIUM, 2)
	card_container.add_child(purse)

	_add_hairline()

	# THE RACK.
	# A board left in progress is offered ahead of a fresh one. Anything else
	# would deal over the top of the board they were interrupted on.
	if SaveManager.has_session():
		var s_lvl: int = int(SaveManager.session.get("level", cur_lvl))
		var s_left: int = 0
		for t in SaveManager.session.get("tiles", []):
			if not bool((t as Dictionary).get("gone", false)):
				s_left += 1
		_add_tile_row(UITheme.RED_CINNABAR, "Resume",
			"Stage %d · %d tiles left" % [s_lvl, s_left], "", func():
				hide_modal()
				resume_session_requested.emit()
		, true)
	else:
		# "Continue" only means something once there is something to continue. A
		# player who has never cleared a stage was being invited to carry on with
		# a game they had not started.
		var started: bool = not SaveManager.prog.get("stars", {}).is_empty() or cur_lvl > 1
		_add_tile_row(UITheme.RED_CINNABAR,
			"Continue" if started else "Play",
			("Stage %d of %d" % [cur_lvl, StagePlan.TOTAL_LEVELS]) if started
				else "Start at stage 1", "", func():
				hide_modal()
				start_calm_requested.emit(cur_lvl)
		, true)

	_add_tile_row(Color("#1f7a52"), "Levels",
		"%d chapters" % StagePlan.CHAPTERS,
		"%d/%d" % [cur_lvl, StagePlan.TOTAL_LEVELS], func(): show_level_select())

	# Both timed modes run out for the day. The row says how many are left and
	# goes quiet when there are none, rather than letting a player start a run
	# that is refused a moment later.
	var runs_left: int = SaveManager.rapids_runs_left()
	_add_tile_row(UITheme.RED_CINNABAR, "Timed Mode",
		"Three runs a day" if runs_left > 0 else SaveManager.time_until_reset(),
		"%d left" % runs_left if runs_left > 0 else "Spent", func():
			if SaveManager.rapids_runs_left() <= 0:
				return
			hide_modal()
			start_run_requested.emit()
	, runs_left > 0)

	var daily_done: bool = SaveManager.daily_done_today()
	_add_tile_row(Color("#28527a"), "Daily Puzzle",
		"One board a day" if not daily_done else SaveManager.time_until_reset(),
		"Ready" if not daily_done else "Done", func():
			if SaveManager.daily_done_today():
				return
			hide_modal()
			start_daily_requested.emit()
	, not daily_done)

	_add_tile_row(Color("#9e6d19"), "Shop", "Tiles, backgrounds, pearls",
		"%d ◈" % pearls, func(): show_bazaar_modal())

	_add_tile_row(Color("#6d6455"), "Settings", "Audio & accessibility",
		"", func():
			_settings_from_pause = false
			show_settings_menu())

	# Quiet, and last. There was no way out of the game at all: back is inert
	# everywhere else by design, and the main menu offered nothing.
	_add_separator()
	_add_toggle_row("Quit", "›", func():
			quit_requested.emit()
	, UITheme.IVORY_MUTED)

	show_modal()

func show_level_select() -> void:
	_current_screen = "level_select"
	_clear_content()
	
	var max_unlocked: int = int(SaveManager.prog.get("level", 1))
	var stars_data: Dictionary = SaveManager.prog.get("stars", {})
	var total_stars: int = 0
	for s_val in stars_data.values():
		total_stars += int(s_val)
		
	_add_header("Levels", "%d chapters" % StagePlan.CHAPTERS)
	_add_purse_line("%d / %d ★  ·  Stage %d unlocked" % [
		total_stars, StagePlan.total_stars(), max_unlocked])
	_add_hairline()

	# No inner ScrollContainer: the card scrolls, and nesting two is ambiguous
	# on touch.
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 16)
	
	# Only chapters the player has reached, plus the next one, so 20 chapters
	# do not become 1000 rows of mostly-blank grid.
	var shown_last: int = mini(StagePlan.chapter_of(max_unlocked) + 1, StagePlan.CHAPTERS - 1)
	var chapters: Array[Dictionary] = []
	for c in range(shown_last + 1):
		var r: Vector2i = StagePlan.chapter_range(c)
		chapters.append({
			"name": StagePlan.chapter_title(c),
			"sub": StagePlan.chapter_subtitle(c),
			"start": r.x, "end": r.y, "index": c,
			"gate": StagePlan.stars_required(c),
			"open": StagePlan.is_chapter_unlocked(c, total_stars),
		})
	
	for ch in chapters:
		var ch_box := VBoxContainer.new()
		ch_box.add_theme_constant_override("separation", 6)
		
		# Chapter Header Row
		var h_box := HBoxContainer.new()
		h_box.add_theme_constant_override("separation", 16)

		var title_col := VBoxContainer.new()
		title_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_col.add_theme_constant_override("separation", 2)
		h_box.add_child(title_col)

		var ch_title := Label.new()
		ch_title.text = String(ch["name"])
		ch_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(ch_title, "ui", UITheme.FS_BODY, UITheme.GOLD_CORE, UITheme.W_SEMIBOLD)
		title_col.add_child(ch_title)

		var ch_sub := Label.new()
		ch_sub.text = String(ch["sub"]).to_upper()
		ch_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch_sub.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(ch_sub, "ui", UITheme.FS_CAPTION, UITheme.IVORY_MUTED,
			UITheme.W_MEDIUM, 2)
		title_col.add_child(ch_sub)
		
		var ch_stars: int = 0
		for lvl in range(ch["start"], ch["end"] + 1):
			ch_stars += int(stars_data.get(str(lvl), 0))
		var span: int = int(ch["end"]) - int(ch["start"]) + 1
		var stars_lbl := Label.new()
		if bool(ch["open"]):
			stars_lbl.text = "%d/%d ★" % [ch_stars, span * 3]
		else:
			stars_lbl.text = "%d ★ to open" % int(ch["gate"])
		stars_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_label(stars_lbl, "ui", UITheme.FS_CAPTION, UITheme.GOLD_BRIGHT,
			UITheme.W_SEMIBOLD)
		h_box.add_child(stars_lbl)
		ch_box.add_child(h_box)
		
		# Chapter Grid
		var grid := GridContainer.new()
		grid.columns = 5
		grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_theme_constant_override("h_separation", 8)
		grid.add_theme_constant_override("v_separation", 8)
		
		if not bool(ch["open"]):
			# Locked: the gate line above says what it costs, so the grid would
			# only be 50 identical dead tokens.
			vbox.add_child(ch_box)
			continue

		for lvl in range(ch["start"], ch["end"] + 1):
			var btn := Button.new()
			# 5 x 144 + separation = 752 of the 812px available.
			var tok: float = UITheme.TOUCH_MIN
			btn.custom_minimum_size = Vector2(tok, tok)
			btn.add_theme_font_size_override("font_size", UITheme.FS_BODY)
			if lvl <= max_unlocked:
				var s_count: int = int(stars_data.get(str(lvl), 0))
				var star_str := ""
				for s in range(3):
					star_str += "★" if s < s_count else "☆"
				btn.text = "%d\n%s" % [lvl, star_str]
				# A cleared stage is a face-up tile, small enough to fit the
				# map grid; the same material as the rest of the interface.
				_style_stage_token(btn, lvl == max_unlocked)
				btn.pressed.connect(func():
					hide_modal()
					start_calm_requested.emit(lvl)
				)
			else:
				# No padlock glyph: a stage you have not reached is simply a
				# tile still lying face-down, not inked in yet.
				btn.text = "%d\n·  ·  ·" % lvl
				btn.disabled = true
				_style_stage_token_locked(btn)
			grid.add_child(btn)
			
		ch_box.add_child(grid)
		vbox.add_child(ch_box)
		
	card_container.add_child(vbox)

	_add_separator()
	_add_button("Back", func():
		show_main_menu()
	)
	show_modal()

func show_pause_menu() -> void:
	_current_screen = "pause"
	_clear_content()
	_add_header("Paused", "Score %d" % GameManager.score)
	_add_hairline()

	_add_tile_row(GLYPH_JADE, "Resume Game", "Go back to your game", "", func():
		hide_modal()
		resume_game_requested.emit()
	, true)

	_add_tile_row(GLYPH_GOLD, "Restart Board", "Deal this stage again", "", func():
		hide_modal()
		restart_stage_requested.emit()
	)

	_add_separator()
	_add_toggle_row("Settings", "›", func():
		_settings_from_pause = true
		show_settings_menu()
	, UITheme.IVORY_MUTED)
	_add_toggle_row("Quit to Menu", "›", func():
		return_home_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()

## The display name of a tile set, for callers outside this file.
func theme_display_name(theme_id: String) -> String:
	var d: Dictionary = TILE_THEME_DETAILS.get(theme_id, {})
	return String(d.get("name", "a premium set"))


func show_level_clear(level: int, score: int, stars: int, sampled: String = "") -> void:
	_current_screen = "level_clear"
	_clear_content()
	_add_header("Board Cleared", "Stage %d" % level)

	var star_lbl := Label.new()
	var star_str := ""
	for i in range(3):
		star_str += "★ " if i < stars else "☆ "
	star_lbl.text = star_str.strip_edges()
	star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(star_lbl, "ui", UITheme.FS_DISPLAY, UITheme.GOLD_BRIGHT)
	card_container.add_child(star_lbl)
	
	_add_hairline()
	_add_sheet_row("Final Score", str(score), UITheme.GOLD_CORE)
	_add_sheet_row("Pearls Earned", "+%d ◈" % (SaveManager.PEARLS_PER_STAR * stars))
	_add_sheet_row("Best Combo", "×%d" % GameManager.best_flow)
	_add_separator()

	_add_tile_row(GLYPH_JADE, "Next Stage", "On to the next board", "", func():
		hide_modal()
		next_stage_requested.emit()
	, true)

	# The set a few tiles on this board were wearing. The offer follows the
	# board it belongs to, and leads to the page where it can be bought rather
	# than to a shop the player then has to navigate.
	if not sampled.is_empty() and not MonetizationManager.is_theme_unlocked(sampled):
		var captured_sample: String = sampled
		_add_toggle_row("Keep the %s tiles" % theme_display_name(sampled),
			"%s ◈" % _thousands(MonetizationManager.get_pearl_cost(sampled)), func():
				show_tile_detail_modal(captured_sample)
		)

	_add_separator()
	_add_toggle_row("Replay Board", "›", func():
		hide_modal()
		restart_stage_requested.emit()
	, UITheme.IVORY_MUTED)
	_add_toggle_row("Main Menu", "›", func():
		return_home_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()

## blessing is what the caller actually granted, not what it would have granted.
## The jade used to be added here, which paid out every time this screen was
## drawn rather than once per daily - replaying the daily farmed it freely.
func show_daily_clear(score: int, best_flow: int, streak: int, blessing: int = 0, sampled: String = "") -> void:
	_current_screen = "daily_clear"
	_clear_content()
	_add_header("Daily Puzzle", "Cleared")
	_add_hairline()

	_add_sheet_row("Final Score", str(score), UITheme.GOLD_CORE)
	_add_sheet_row("Best Combo", "×%d" % best_flow)
	_add_sheet_row("Day Streak", "%d days" % streak)
	_add_sheet_row("Daily Reward",
		"+%d ◈" % blessing if blessing > 0 else "claimed today")

	_add_separator()
	if not sampled.is_empty() and not MonetizationManager.is_theme_unlocked(sampled):
		var captured_sample: String = sampled
		_add_toggle_row("Keep the %s tiles" % theme_display_name(sampled),
			"%s ◈" % _thousands(MonetizationManager.get_pearl_cost(sampled)), func():
				show_tile_detail_modal(captured_sample)
		)
	_add_toggle_row("Main Menu", "›", func():
		return_home_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()

## Offered when the board has tied itself into a corner: no legal move, and no
## arrangement of what is left that would produce one. That is not the player's
## mistake and not something they can undo, so it is framed as a curiosity and
## they are given the choice rather than a loss.
##
## Only ever shown for a genuine dead end. Running out of shuffle charges is a
## different situation with a different answer; if this appeared there too, a
## player could skip any hard stage by spending their shuffles first.
func show_deadlock(level: int, tiles_left: int) -> void:
	_current_screen = "deadlock"
	_clear_content()
	_add_header("Deadlock", "Stage %d · no moves remain" % level)
	_add_hairline()

	_add_description("No tiles can be matched, and rearranging them will not help. This board cannot be finished.")
	_add_sheet_row("Tiles remaining", str(tiles_left), UITheme.GOLD_CORE)

	_add_separator()
	_add_tile_row(GLYPH_GOLD, "Complete this level",
		"Counted as cleared, one star", "", func():
			deadlock_accepted.emit()
	, true)
	_add_toggle_row("Retry", "Fresh board, same stage", func():
		deadlock_retry.emit()
	, UITheme.IVORY_MUTED)
	show_modal()


func show_game_over(reason: String) -> void:
	_current_screen = "game_over"
	_clear_content()
	_add_header("Game Over", reason)
	_add_hairline()

	_add_sheet_row("Final Score", str(GameManager.score), UITheme.GOLD_CORE)
	_add_sheet_row("Stages Cleared", str(GameManager.current_stage_no - 1))
	_add_sheet_row("Best Combo", "×%d" % GameManager.best_flow)
	_add_separator()

	_add_tile_row(GLYPH_JADE, "Try Again", "Start again from stage 1", "", func():
		hide_modal()
		if GameManager.current_mode == GameManager.GameMode.DAILY:
			start_daily_requested.emit()
		else:
			start_run_requested.emit()
	, true)

	_add_separator()
	_add_toggle_row("Main Menu", "›", func():
		return_home_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()

## Four rows, one currency. It was five rows across two currencies, which is
## why nobody could tell the Treasury from the Blessings - the split was by what
## each screen took, not by what the player wanted.
func show_bazaar_modal() -> void:
	_current_screen = "bazaar"
	_clear_content()
	
	_add_header("Shop", "Tiles, backgrounds and deals")

	var pearls: int = MonetizationManager.get_pearls()
	_add_purse_line("%d ◈ pearls" % pearls)
	_add_hairline()

	_add_tile_row(GLYPH_JADE, "Tile Sets",
		"%d collections" % TILE_THEME_DETAILS.size(),
		str(TILE_THEME_DETAILS.size()), func():
			show_tile_catalog_modal()
	, true)

	_add_tile_row(GLYPH_JADE, "Backgrounds",
		"Ponds, koi and weather", str(BG_THEME_DETAILS.size()), func():
			show_background_catalog_modal()
	)

	_add_tile_row(GLYPH_GOLD, "Buy Pearls",
		"Buy pearls, remove ads", "%d ◈" % pearls, func():
			show_treasury_modal()
	)

	_add_separator()
	_add_toggle_row("Restore Purchases", "›", func():
		MonetizationManager.restore_purchases()
		show_bazaar_modal()
	, UITheme.IVORY_MUTED)

	_add_separator()
	_add_button("Back", func():
		show_main_menu()
	)
	show_modal()

func show_tile_catalog_modal() -> void:
	_current_screen = "tile_catalog"
	_clear_content()
	
	_add_header("Tile Sets", "Ceramic, gold leaf and basalt")
	_add_hairline()

	var cur_theme := MonetizationManager.get_active_theme()
	for theme_key in ["classic_jade", "theme_indigo", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]:
		var detail: Dictionary = TILE_THEME_DETAILS[theme_key]
		var is_active: bool = (cur_theme == theme_key)
		var is_unlocked: bool = MonetizationManager.is_theme_unlocked(theme_key)

		var tag := ""
		if is_active:
			tag = "Equipped"
		elif is_unlocked:
			tag = "Owned"
		else:
			# A milestone set has no price of any kind; it has a condition.
			var need: int = MonetizationManager.get_unlock_level(theme_key)
			if need > 0:
				tag = "Stage %d" % need
			else:
				tag = MonetizationManager.get_formatted_price(theme_key)

		var captured_key: String = theme_key
		# The equipped set wears the gold band, exactly as a banded triple does
		# in play, so "which one am I using" needs no tag to be read.
		_add_tile_row(_accent_for(theme_key),
			String(detail["name"]), "", tag, func():
				show_tile_detail_modal(captured_key)
		, is_active)

	_add_separator()
	_add_button("Back", func():
		show_bazaar_modal()
	)
	show_modal()

## Offered, not applied. A set that switches itself on is a surprise; a set the
## player chooses is a reward. Shown once, when the milestone is first cleared.
func show_theme_unlocked(theme_key: String) -> void:
	_current_screen = "theme_unlocked"
	_clear_content()
	var detail: Dictionary = TILE_THEME_DETAILS.get(theme_key, {})
	_add_header(String(detail.get("name", "New Tile Set")) + " unlocked",
		String(detail.get("subtitle", "")))
	_add_hairline()

	if detail.has("samples"):
		_add_tile_preview_row(detail["samples"], theme_key)
	if detail.has("desc"):
		_add_description(String(detail["desc"]))

	_add_separator()
	var captured: String = theme_key
	_add_tile_row(_accent_for(theme_key),
		"Use these tiles", "Change it any time in the Bazaar", "", func():
			MonetizationManager.equip_theme(captured)
			AudioManager.play_win()
			hide_modal()
			next_stage_requested.emit()
	, true)
	_add_toggle_row("Keep my current set", "›", func():
		hide_modal()
		next_stage_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()


## Shown once, after the stage that wore a premium set. Skip carries on to the
## clear screen; Shop drops it and opens the set's page.
func show_premium_offer(theme_key: String) -> void:
	_current_screen = "premium_offer"
	_clear_content()
	var detail: Dictionary = TILE_THEME_DETAILS.get(theme_key, {})
	_add_header("Premium Tiles", "Like the %s tiles?" % theme_display_name(theme_key))
	_add_hairline()
	if detail.has("samples"):
		_add_tile_preview_row(detail["samples"], theme_key, DETAIL_TILE_SCALE)
	_add_separator()
	var captured: String = theme_key
	_add_tile_row(_accent_for(theme_key), "Go to Shop", "Get these and more tile sets", "", func():
		premium_shop_requested.emit()
		show_tile_detail_modal(captured)
	, true)
	_add_toggle_row("Skip", "›", func():
		hide_modal()
		next_stage_requested.emit()
	, UITheme.IVORY_MUTED)
	show_modal()


## Big enough to be the point of the screen rather than an illustration on it.
const DETAIL_TILE_SCALE: float = 2.4

func show_tile_detail_modal(theme_key: String) -> void:
	_current_screen = "tile_detail"
	_clear_content()
	
	var detail: Dictionary = TILE_THEME_DETAILS.get(theme_key, TILE_THEME_DETAILS["classic_jade"])
	_add_header(String(detail["name"]), "")

	# The tiles, large, and nothing else. This screen used to carry the subtitle,
	# a description, a "Tactical Purpose" paragraph and a "Feel & Dissolution"
	# paragraph above the price - four blocks of prose about an object the player
	# can simply be shown.
	_add_tile_preview_row(detail["samples"], theme_key, DETAIL_TILE_SCALE)
	_add_separator()

	var cur_theme := MonetizationManager.get_active_theme()
	var is_active: bool = (cur_theme == theme_key)
	var is_unlocked: bool = MonetizationManager.is_theme_unlocked(theme_key)

	if is_active:
		_add_sheet_row("Status", "Equipped & in play", UITheme.GOLD_CORE)
	elif is_unlocked:
		_add_tile_row(GLYPH_JADE, "Equip This Set",
			"Takes effect on the next board", "", func():
				MonetizationManager.equip_theme(theme_key)
				AudioManager.play_win()
				show_tile_detail_modal(theme_key)
		, true)
	else:
		# One heavy way in, one light one. Two identical slabs would make the
		# player read both before choosing either.
		# The price comes from the product rather than a literal: the three paid
		# sets are 4,000 / 6,000 / 8,000 and the earned one is 2,500, so a hard
		# coded 1,500 here lied about all four.
		var need: int = MonetizationManager.get_unlock_level(theme_key)
		if need > 0:
			# Nothing to press. A milestone set is not for sale at any price, so
			# offering a button here would only invite the player to try.
			_add_sheet_row("Unlocks at", "Stage %d" % need, UITheme.GOLD_CORE)
			_add_sheet_row("Your furthest stage", str(SaveManager.prog.get("level", 1)), UITheme.IVORY_MUTED)
		else:
			var cost: int = MonetizationManager.get_pearl_cost(theme_key)
			_add_tile_row(GLYPH_GOLD, "Buy with Pearls",
				"Pearls you already hold", "%s ◈" % _thousands(cost), func():
					if MonetizationManager.buy_with_pearls(theme_key, func(): show_tile_detail_modal(theme_key)):
						AudioManager.play_win()
						show_tile_detail_modal(theme_key)
					else:
						show_treasury_modal()
			, true)
			_add_toggle_row("Buy outright",
				MonetizationManager.get_formatted_price(theme_key), func():
					MonetizationManager.buy_product(theme_key, func(): show_tile_detail_modal(theme_key))
			)

	_add_separator()
	_add_button("Back", func():
		show_tile_catalog_modal()
	)
	show_modal()

func show_background_catalog_modal() -> void:
	_current_screen = "bg_catalog"
	_clear_content()
	
	_add_header("Backgrounds", "Living water, koi and flora")
	_add_hairline()

	var cur_bg := MonetizationManager.get_active_background_theme()
	for bg_id in ["auto", "emerald_pond", "moonlit_river", "autumn_stream", "misty_spring", "sunset_haven"]:
		var detail: Dictionary = BG_THEME_DETAILS[bg_id]
		var is_active: bool = (cur_bg == bg_id)
		var is_unlocked: bool = MonetizationManager.is_background_theme_unlocked(bg_id)
		
		var tag := ""
		if is_active:
			tag = "Flowing"
		elif bool(detail.get("is_free", false)):
			tag = "Free"
		elif is_unlocked:
			tag = "Owned"
		else:
			tag = "500 ◈"

		var captured_id: String = bg_id
		_add_tile_row(_accent_for(bg_id),
			String(detail["name"]), "", tag, func():
				show_background_detail_modal(captured_id)
		, is_active)

	_add_separator()
	_add_button("Back", func():
		show_bazaar_modal()
	)
	show_modal()

func show_background_detail_modal(theme_id: String) -> void:
	_current_screen = "bg_detail"
	_clear_content()
	
	var detail: Dictionary = BG_THEME_DETAILS.get(theme_id, BG_THEME_DETAILS["emerald_pond"])
	_add_header(String(detail["name"]), "")

	# The pond, large, and nothing else - the same cut the tile sets got. This
	# carried a subtitle, a description, and rows for Water Atmosphere, Living
	# Koi Species and Floating Aquatic Flora above the price.
	_add_palette_preview_card(detail["theme_data"], DETAIL_TILE_SCALE)
	_add_separator()

	var cur_bg := MonetizationManager.get_active_background_theme()
	var is_active: bool = (cur_bg == theme_id)
	var is_unlocked: bool = MonetizationManager.is_background_theme_unlocked(theme_id)

	if is_active:
		_add_sheet_row("Status", "Flowing behind the board", UITheme.GOLD_CORE)
	elif is_unlocked:
		_add_tile_row(GLYPH_JADE, "Use this background",
			"Set as your backdrop", "", func():
				MonetizationManager.equip_background_theme(theme_id)
				AudioManager.play_win()
				show_background_detail_modal(theme_id)
		, true)
	else:
		_add_tile_row(GLYPH_GOLD, "Buy with Pearls",
			"Earned at the board or bought", "500 ◈", func():
				if MonetizationManager.buy_background_with_pearls(theme_id):
					show_background_detail_modal(theme_id)
				else:
					show_treasury_modal()
		, true)
		_add_toggle_row("Buy outright",
			MonetizationManager.get_formatted_price("bg_" + theme_id), func():
				MonetizationManager.buy_product("bg_" + theme_id, func(): show_background_detail_modal(theme_id))
		)

	_add_separator()
	_add_button("Back", func():
		show_background_catalog_modal()
	)
	show_modal()

func show_treasury_modal() -> void:
	_current_screen = "treasury"
	_clear_content()
	
	_add_header("Buy Pearls", "Pearls and the no-ads upgrade")
	_add_purse_line("%d ◈ Spirit Pearls in Treasury" % MonetizationManager.get_pearls())
	_add_hairline()

	if not MonetizationManager.is_no_ads():
		_add_tile_row(GLYPH_JADE, "Remove Ads",
			"No ads · +500 ◈ pearls",
			MonetizationManager.get_formatted_price("no_ads"), func():
				MonetizationManager.buy_product("no_ads", func(): show_treasury_modal())
		, true)
	else:
		_add_sheet_row("Ads removed", "Active · +1 prop a day", UITheme.GOLD_CORE)

	# A price ladder, not four identical slabs: the two small pouches are quiet
	# lines, the best-value hoard is a tile.
	_add_toggle_row("Pouch of 500 Pearls",
		MonetizationManager.get_formatted_price("pearls_small"), func():
			MonetizationManager.buy_product("pearls_small", func(): show_treasury_modal())
	)
	_add_toggle_row("Chest of 2,500 Pearls · +25%",
		MonetizationManager.get_formatted_price("pearls_medium"), func():
			MonetizationManager.buy_product("pearls_medium", func(): show_treasury_modal())
	)

	_add_tile_row(GLYPH_GOLD, "Best Value Pack",
		"7,500 pearls · +50% bonus",
		MonetizationManager.get_formatted_price("pearls_large"), func():
			MonetizationManager.buy_product("pearls_large", func(): show_treasury_modal())
	)

	_add_separator()
	_add_toggle_row("Restore Purchases", "›", func():
		MonetizationManager.restore_purchases()
		show_treasury_modal()
	, UITheme.IVORY_MUTED)

	_add_separator()
	_add_button("Back", func():
		show_bazaar_modal()
	)
	show_modal()

## The Free Rewards screen lived here. It offered pearls and props for watching
## a rewarded ad, and it was cut because the daily puzzle already gives pearls
## for free - two free-pearl surfaces was one too many, and the shop is for
## buying. The rewarded-ad plumbing is untouched in MonetizationManager; if ads
## ship it needs a home, and this is not it.

## Remembers which screen opened Settings. Both back paths used to ask
## GameManager.is_timer_active, which is false while paused and false in Calm
## for the whole campaign, so Back always went to the main menu and abandoned
## the board whatever mode you were in.
var _settings_from_pause: bool = false

func show_settings_menu() -> void:
	_current_screen = "settings"
	_clear_content()
	_add_header("Settings", "Audio and accessibility")
	_add_hairline()

	var on_col := Color("#57bd92")
	var off_col := UITheme.IVORY_MUTED

	_add_toggle_row("Ambient Music",
		"On" if SettingsManager.music_enabled else "Off", func():
			SettingsManager.toggle_setting("music")
			show_settings_menu()
	, on_col if SettingsManager.music_enabled else off_col)

	_add_toggle_row("Tile Sounds",
		"On" if SettingsManager.sfx_enabled else "Off", func():
			SettingsManager.toggle_setting("sfx")
			show_settings_menu()
	, on_col if SettingsManager.sfx_enabled else off_col)

	_add_toggle_row("Haptic Vibration",
		"On" if SettingsManager.haptics_enabled else "Off", func():
			SettingsManager.toggle_setting("haptics")
			show_settings_menu()
	, on_col if SettingsManager.haptics_enabled else off_col)

	_add_toggle_row("Motion",
		SettingsManager.motion_mode.capitalize(), func():
			SettingsManager.toggle_setting("motion")
			show_settings_menu()
	)

	_add_toggle_row("Colour-Blind Mode",
		SettingsManager.color_blind_mode.capitalize(), func():
			SettingsManager.toggle_setting("color_blind_mode")
			show_settings_menu()
	)

	_add_toggle_row("High Contrast Borders",
		"On" if SettingsManager.high_contrast_borders else "Off", func():
			SettingsManager.toggle_setting("high_contrast_borders")
			show_settings_menu()
	, on_col if SettingsManager.high_contrast_borders else off_col)

	# NOTE: the Cloud Save toggle lives on feat/cloud-save-pgs, where the
	# CloudSaveManager autoload exists. Referencing it here would not parse.
	
	_add_separator()
	_add_toggle_row("Replay Tutorial", "›", func():
		hide_modal()
		replay_tutorial_requested.emit()
	)
	_add_toggle_row("Privacy Policy", "›", func(): show_privacy_modal())
	_add_toggle_row("Credits", "›", func(): show_credits_modal())

	_add_separator()
	_add_button("Back", func():
		if _settings_from_pause:
			show_pause_menu()
		else:
			show_main_menu()
	)
	show_modal()

func show_privacy_modal() -> void:
	_current_screen = "privacy"
	_clear_content()
	_add_header("Privacy", "Nine Rivers")
	_add_hairline()

	_add_sheet_row("Data Collection", "None")
	_add_sheet_row("Save Storage", "Local device only")
	_add_sheet_row("In-App Purchases", "Apple / Google Play")
	_add_sheet_row("Family Safe", "COPPA & all-ages")

	_add_separator()
	_add_button("Back", func():
		show_settings_menu()
	)
	show_modal()

func show_credits_modal() -> void:
	_current_screen = "credits"
	_clear_content()
	_add_header("Credits", "Nine Rivers")
	_add_hairline()

	_add_sheet_row("Game Design", "Nine Rivers Studio")
	_add_sheet_row("Art Direction", "Ceramic & ink vector engine")
	_add_sheet_row("Typography", "Noto Serif CJK · Ma Shan Zheng")
	_add_sheet_row("Audio", "Procedural guzheng & clacks")
	_add_sheet_row("Engine", "Godot 4.6")

	_add_separator()
	_add_button("Back", func():
		show_settings_menu()
	)
	show_modal()

func handle_back_pressed() -> void:
	match _current_screen:
		"level_select", "bazaar":
			show_main_menu()
		"tile_catalog", "bg_catalog", "treasury":
			show_bazaar_modal()
		"tile_detail":
			show_tile_catalog_modal()
		"premium_offer":
			hide_modal()
			next_stage_requested.emit()
		"bg_detail":
			show_background_catalog_modal()
		"settings":
			if _settings_from_pause:
				show_pause_menu()
			else:
				show_main_menu()
		"privacy", "credits":
			show_settings_menu()
		"pause":
			hide_modal()
			resume_game_requested.emit()
		"level_clear", "daily_clear", "game_over", "theme_unlocked", "deadlock":
			# No hide_modal(): _return_home() puts the main menu up in its place,
			# and hiding first would race the fade against it.
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
## Row accent inks. Cinnabar is deliberately absent: it is spent once per
## screen, on the header mark, and nowhere else.
const GLYPH_JADE := Color("#1f7a52")
const GLYPH_GOLD := Color("#9e6d19")
const GLYPH_INK := Color("#3a352c")
const GLYPH_STONE := Color("#6d6455")

## Each row on a catalogue screen carries a colour, not a carved character.
const ACCENT_COLS: Dictionary = {
	"classic_jade": GLYPH_JADE, "theme_imperial_gold": GLYPH_GOLD,
	"theme_indigo": GLYPH_INK,
	"theme_obsidian_ink": GLYPH_INK, "theme_cherry_blossom": GLYPH_STONE,
	"auto": GLYPH_JADE, "emerald_pond": GLYPH_JADE, "moonlit_river": GLYPH_INK,
	"autumn_stream": GLYPH_GOLD, "misty_spring": GLYPH_STONE, "sunset_haven": GLYPH_GOLD
}

func _accent_for(key: String) -> Color:
	return ACCENT_COLS.get(key, GLYPH_JADE)

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
func _add_tile_row(accent: Color, title: String, sub: String,
		meta: String, on_click: Callable, banded: bool = false) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN + (8.0 if banded else 0.0))
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_stylebox_override("normal", _make_tile_box())
	b.add_theme_stylebox_override("hover", _make_tile_box())
	b.add_theme_stylebox_override("focus", _make_tile_box())
	b.add_theme_stylebox_override("pressed", _make_tile_box(true))
	b.pressed.connect(on_click)
	UITheme.add_press_feedback(b)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24; row.offset_right = -24
	# -12 at the bottom leaves the biscuit lip exposed; that lip is the whole
	# reason this reads as a tile rather than a list row.
	# A banded tile needs more clearance still: the gold band sits inside the
	# face, and at -12 it ran straight through the subtitle's descenders, so
	# the text read as struck through.
	row.offset_top = 0
	row.offset_bottom = -30 if banded else -14
	row.add_theme_constant_override("separation", 18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	# Was a carved Chinese character. The colour was the part that told the rows
	# apart at a glance, so it stays as a spine and the character goes.
	var spine := PanelContainer.new()
	var spine_sb := StyleBoxFlat.new()
	spine_sb.bg_color = accent
	spine_sb.set_corner_radius_all(4)
	spine.add_theme_stylebox_override("panel", spine_sb)
	spine.custom_minimum_size = Vector2(9, 0)
	spine.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	spine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 62)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spine.add_child(spacer)
	row.add_child(spine)

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
	UITheme.style_label(t, "ui", UITheme.FS_BODY_LG, TILE_INK, UITheme.W_SEMIBOLD)
	col.add_child(t)

	if not sub.is_empty():
		var s := Label.new()
		s.text = sub.to_upper()
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.style_label(s, "ui", UITheme.FS_CAPTION, TILE_SUBINK,
			UITheme.W_MEDIUM, 2)
		col.add_child(s)

	if not meta.is_empty():
		var m := Label.new()
		m.text = meta
		m.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UITheme.style_label(m, "ui", UITheme.FS_CAPTION, TILE_META, UITheme.W_SEMIBOLD)
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

## A stage on the map, drawn as a small face-up tile. `current` gets the gold
## band the player already reads as "this is the one that matters".
func _style_stage_token(btn: Button, current: bool) -> void:
	for state in ["normal", "hover", "focus", "disabled"]:
		var sb := _make_tile_box()
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		sb.border_width_bottom = 5
		if current:
			sb.border_color = UITheme.GOLD_CORE
		btn.add_theme_stylebox_override(state, sb)
	var pressed_sb := _make_tile_box(true)
	pressed_sb.content_margin_left = 6
	pressed_sb.content_margin_right = 6
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_color_override("font_color", TILE_INK)
	btn.add_theme_color_override("font_hover_color", TILE_INK)
	btn.add_theme_color_override("font_pressed_color", TILE_INK)
	btn.add_theme_color_override("font_focus_color", TILE_INK)
	UITheme.add_press_feedback(btn)

## A stage still out of reach: no tile, no border, just the number waiting.
func _style_stage_token_locked(btn: Button) -> void:
	var empty := StyleBoxEmpty.new()
	for state in ["normal", "hover", "focus", "pressed", "disabled"]:
		btn.add_theme_stylebox_override(state, empty)
	btn.add_theme_color_override("font_disabled_color",
		Color(UITheme.IVORY_MUTED.r, UITheme.IVORY_MUTED.g, UITheme.IVORY_MUTED.b, 0.34))

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
func _add_header(title: String, sub: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	card_container.add_child(row)

	# This was a cinnabar chop carrying a Chinese character. The character is
	# gone; the stamp of colour beside the title is what gave the headers their
	# weight, so it stays as a plain mark.
	var seal := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UITheme.RED_CINNABAR
	sb.set_corner_radius_all(3)
	seal.add_theme_stylebox_override("panel", sb)
	seal.custom_minimum_size = Vector2(8, 0)
	seal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(seal)

	var seal_h := Control.new()
	seal_h.custom_minimum_size = Vector2(0, 56)
	seal.add_child(seal_h)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	row.add_child(col)

	var t := Label.new()
	t.text = title
	# UI face: MaShanZheng draws Latin badly; the seal carries the calligraphy.
	UITheme.style_label(t, "ui", UITheme.FS_TITLE, UITheme.GOLD_CORE,
		UITheme.W_SEMIBOLD, 1)
	col.add_child(t)

	if not sub.is_empty():
		var s := Label.new()
		s.text = sub
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		UITheme.style_label(s, "ui", UITheme.FS_CAPTION, UITheme.IVORY_MUTED,
			UITheme.W_MEDIUM, 2)
		col.add_child(s)

## A tappable settings line: carved glyph, label, current value. Hairline rule
## underneath instead of a box around it, so ten of these read as one list
## rather than ten separate objects.
func _add_toggle_row(label: String, value: String,
		on_click: Callable, value_col: Color = UITheme.GOLD_CORE) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN)
	var flat := StyleBoxEmpty.new()
	var hov := StyleBoxFlat.new()
	hov.bg_color = Color(1, 1, 1, 0.045)
	hov.set_corner_radius_all(5)
	b.add_theme_stylebox_override("normal", flat)
	b.add_theme_stylebox_override("focus", flat)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", UITheme.create_press_wash(5))
	b.pressed.connect(on_click)
	UITheme.add_press_feedback(b)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 8; row.offset_right = -8
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(row)

	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(l, "ui", UITheme.FS_BODY_LG, UITheme.IVORY_BASE, UITheme.W_MEDIUM)
	row.add_child(l)

	var v := Label.new()
	v.text = value
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_label(v, "ui", UITheme.FS_BODY, value_col, UITheme.W_SEMIBOLD)
	row.add_child(v)

	card_container.add_child(b)
	_add_hairline()

## One compact centred line of currency, instead of a stack of tallies that the
## eye has to read through before it reaches anything actionable.
func _add_purse_line(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", UITheme.FS_CAPTION, UITheme.GOLD_MUTED)
	card_container.add_child(l)

## A key/value line on the rice-paper sheet: hairline rule, no boxes.
func _add_sheet_row(key: String, val: String, val_col: Color = UITheme.IVORY_BASE) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	# Read-only, so it needs legible height rather than a full touch target.
	row.custom_minimum_size = Vector2(0, 96)
	card_container.add_child(row)

	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	k.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(k, "ui", UITheme.FS_BODY, UITheme.IVORY_MUTED)
	row.add_child(k)

	var v := Label.new()
	v.text = val
	v.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UITheme.style_label(v, "ui", UITheme.FS_BODY, val_col, UITheme.W_SEMIBOLD)
	row.add_child(v)

	_add_hairline()

## Tracked caps in the UI face, not the brush face - see _add_header.
func _add_title(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", UITheme.FS_TITLE, UITheme.GOLD_CORE,
		UITheme.W_SEMIBOLD, 8)
	card_container.add_child(l)

func _add_subtitle(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", UITheme.FS_BODY, UITheme.IVORY_MUTED, UITheme.W_MEDIUM)
	card_container.add_child(l)

func _add_description(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_label(l, "ui", UITheme.FS_BODY, Color(0.85, 0.90, 0.88))
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
	UITheme.style_label(l_k, "ui", UITheme.FS_BODY, Color(0.72, 0.82, 0.77))
	
	var l_v := Label.new()
	l_v.text = val
	UITheme.style_label(l_v, "ui", UITheme.FS_BODY_LG, UITheme.GOLD_BRIGHT, UITheme.W_SEMIBOLD)
	
	box.add_child(l_k)
	box.add_child(l_v)
	card_container.add_child(box)

func _add_feature_row(key: String, val: String) -> void:
	var v_box := VBoxContainer.new()
	v_box.add_theme_constant_override("separation", 2)
	
	var l_k := Label.new()
	l_k.text = key
	UITheme.style_label(l_k, "ui", UITheme.FS_BODY, UITheme.GOLD_CORE, UITheme.W_SEMIBOLD)
	
	var l_v := Label.new()
	l_v.text = val
	l_v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UITheme.style_label(l_v, "ui", UITheme.FS_CAPTION, Color(0.82, 0.90, 0.86))
	
	v_box.add_child(l_k)
	v_box.add_child(l_v)
	card_container.add_child(v_box)

## scale is what the detail screen turns up. The set is the product; the player
## is buying how it LOOKS, and three thumbnails under four paragraphs of prose
## told them everything except that.
func _add_tile_preview_row(samples: Array, theme_id: String, scale: float = 1.0) -> void:
	var center_box := CenterContainer.new()
	center_box.custom_minimum_size = Vector2(0, 110.0 * scale)
	
	var preview_panel := PanelContainer.new()
	# No border: the tiles are the object here, and a gold box around them would
	# be one more frame inside an already-framed card.
	var sb := UITheme.create_panel_box(Color(0.02, 0.08, 0.06, 0.55), UITheme.GOLD_MUTED, 0, 14, 0.0)
	preview_panel.add_theme_stylebox_override("panel", sb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", int(24.0 * scale))
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	for s in samples:
		var suit: String = s[0]
		var rank: int = int(s[1])
		var tile_ctrl := TileView.create_preview_tile(suit, rank, theme_id, scale)
		# In a holder, not straight into the box: a Container lays its children out
		# and resets the scale doing it, so a scaled tile added directly came back
		# at 1.0 however large its minimum size was.
		var holder := Control.new()
		holder.custom_minimum_size = tile_ctrl.custom_minimum_size
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tile_ctrl)
		hbox.add_child(holder)
		
	margin.add_child(hbox)
	preview_panel.add_child(margin)
	center_box.add_child(preview_panel)
	card_container.add_child(center_box)

## The pond itself, running, rather than four colour chips captioned "Water
## Felt" and "Depth Tone". A player buying a background is buying how the water
## looks; naming its constituent colours told them everything except that.
##
## The live shader, not a screenshot: it is the same material the board uses, so
## the preview cannot drift away from the thing being sold.
const RiverFeltShader = preload("res://assets/shaders/river_felt.gdshader")

## Portrait, in the shape of the screen it will fill. A wide band across the
## card showed the colours but not the pond: this game is played on a tall
## screen, and a background is chosen by how it sits behind a board, not by how
## it looks as a stripe.
const BG_PREVIEW := Vector2(300, 533)

func _add_palette_preview_card(theme_data: Dictionary, _scale: float = 1.0) -> void:
	var center_box := CenterContainer.new()
	center_box.custom_minimum_size = Vector2(0, BG_PREVIEW.y)

	var frame := PanelContainer.new()
	var sb := UITheme.create_panel_box(Color(0, 0, 0, 0), UITheme.GOLD_MUTED, 1, 14, 0.0)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = BG_PREVIEW
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var water := ColorRect.new()
	water.custom_minimum_size = BG_PREVIEW
	water.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = RiverFeltShader
	mat.set_shader_parameter("felt_color", theme_data.get("felt_color", Color.BLACK))
	mat.set_shader_parameter("secondary_color", theme_data.get("secondary_color", Color.BLACK))
	mat.set_shader_parameter("caustic_color", theme_data.get("caustic_color", Color.WHITE))
	mat.set_shader_parameter("gold_color", theme_data.get("gold_color", Color.GOLD))
	# flow_level is what lights the caustics. At zero this rendered as a
	# near-black rectangle: technically the pond, no use for choosing one.
	mat.set_shader_parameter("flow_level", 4.0)
	mat.set_shader_parameter("overdrive", 0.0)
	mat.set_shader_parameter("speed", 0.6)
	water.material = mat

	# No clip_children on the frame: it blanks the shader entirely.
	frame.add_child(water)
	center_box.add_child(frame)
	card_container.add_child(center_box)

func _add_button(text: String, on_click: Callable, is_gold: bool = false) -> void:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, UITheme.TOUCH_MIN)
	UITheme.style_button(b, is_gold, 16)
	b.add_theme_font_size_override("font_size", UITheme.FS_BODY_LG)
	b.pressed.connect(on_click)
	card_container.add_child(b)


## 4000 -> "4,000". Prices are read at a glance on a phone and an unseparated
## five-figure number is not.
static func _thousands(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
