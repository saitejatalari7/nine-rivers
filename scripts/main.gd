extends Node2D

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const BoardController = preload("res://scripts/core/board_controller.gd")
const CameraController = preload("res://scripts/ui/camera_controller.gd")
const HudController = preload("res://scripts/ui/hud_controller.gd")
const ModalController = preload("res://scripts/ui/modal_controller.gd")
const StagePlan = preload("res://scripts/core/stage_plan.gd")
const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")
const TutorialController = preload("res://scripts/ui/tutorial_controller.gd")

@onready var board: BoardController = $Board
@onready var camera: CameraController = $Camera2D
@onready var hud: HudController = $HUD
@onready var modal: ModalController = $Modal
## On its own CanvasLayer: parented to the Node2D it inherited the gameplay
## camera's pan and zoom, so opening the pond after a board left it off-centre.
@onready var splash_screen: CanvasLayer = $SplashScreen
@onready var zen_background = $FeltBackground

var tutorial: TutorialController

# Reference BoardGenerator's canonical ladder
const LADDER: Array[String] = BoardGenerator.LADDER

## Paid once per calendar day, on the first Daily Tide cleared that day. Was
## 150 River Jade before the currencies merged, at three jade to a pearl.
const DAILY_BLESSING_PEARLS: int = 50

func _ready() -> void:
	# Instantiate Tutorial Controller
	tutorial = TutorialController.new()
	tutorial.name = "TutorialController"
	add_child(tutorial)

	# Wire HUD signals
	hud.menu_clicked.connect(_on_menu_clicked)
	hud.undo_clicked.connect(_on_undo_clicked)
	hud.hint_clicked.connect(_on_hint_clicked)
	hud.shuffle_clicked.connect(_on_shuffle_clicked)
	hud.pearls_clicked.connect(func(): modal.show_bazaar_modal())

	# Wire Board signals
	board.move_completed.connect(_on_board_move_completed)
	board.tile_matched.connect(_on_tile_matched_ripple)
	board.tile_matched.connect(func(_p): _charge_rapids_run())
	board.board_cleared.connect(_on_board_cleared)
	board.no_moves_left.connect(_on_no_moves_left)
	board.toast_requested.connect(func(msg): hud.show_toast(msg))
	board.blocked_tap.connect(func(tile): tutorial.notify_blocked_tap(tile))
	board.move_completed.connect(func(_r, _l): tutorial.notify_match())

	# Wire Zen Background theme notifications
	if zen_background and zen_background.has_signal("theme_changed"):
		zen_background.theme_changed.connect(_on_theme_changed)

	# Wire Modal signals
	modal.start_calm_requested.connect(_start_calm_mode)
	modal.start_run_requested.connect(_start_run_mode)
	modal.start_daily_requested.connect(_start_daily_mode)
	modal.restart_stage_requested.connect(_restart_current_stage)
	modal.next_stage_requested.connect(_next_stage)
	modal.premium_shop_requested.connect(func(): _pending_clear = {})
	modal.deadlock_accepted.connect(_on_deadlock_accepted)
	modal.deadlock_retry.connect(_on_deadlock_retry)
	modal.resume_game_requested.connect(_resume_game)
	modal.return_home_requested.connect(_return_home)
	modal.background_quiet_changed.connect(func(quiet: bool):
		if zen_background and zen_background.has_method("set_quiet"):
			zen_background.set_quiet(quiet))
	modal.replay_tutorial_requested.connect(_on_replay_tutorial)
	modal.quit_requested.connect(_quit_game)
	modal.resume_session_requested.connect(func():
		if not _resume_session():
			_start_calm_mode(int(SaveManager.prog.get("level", 1))))

	# Wire GameManager
	GameManager.game_over.connect(_on_game_over)
	GameManager.flow_updated.connect(_on_flow_updated_shader)

	if BACK_DIAGNOSTIC:
		_build_back_diagnostic()

	# Show intro splash on boot
	_show_intro_splash()

## The splash is a loading screen: it stays up until the game is actually
## ready, so the menu never appears half-built and the first board never
## stutters. It used to dissolve after 0.55 s regardless, while the ambient
## bed was still being synthesised and every tile shader was still waiting to
## compile on first use.
const BOOT_MIN_SECONDS: float = 1.0
const BOOT_MAX_SECONDS: float = 4.0

var _booting: bool = false
var _boot_bar: ColorRect = null

func _show_intro_splash() -> void:
	splash_screen.visible = true
	$SplashScreen/SplashTexture.modulate.a = 1.0
	board.visible = false
	hud.visible = false
	_build_boot_bar()
	_boot_load()


func _build_boot_bar() -> void:
	var track := ColorRect.new()
	track.color = Color(1, 1, 1, 0.10)
	track.anchor_left = 0.3
	track.anchor_right = 0.7
	track.anchor_top = 0.86
	track.anchor_bottom = 0.86
	track.offset_bottom = 4.0
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	splash_screen.add_child(track)
	_boot_bar = ColorRect.new()
	_boot_bar.color = UITheme.GOLD_CORE
	_boot_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_boot_bar.anchor_right = 0.0
	_boot_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.add_child(_boot_bar)


func _boot_progress(p: float) -> void:
	if _boot_bar != null:
		create_tween().tween_property(_boot_bar, "anchor_right", clampf(p, 0.0, 1.0), 0.25)


func _boot_load() -> void:
	_booting = true
	var started: int = Time.get_ticks_msec()
	var deadline: int = started + int(BOOT_MAX_SECONDS * 1000.0)
	_boot_progress(0.15)

	# 1. The ambient bed, synthesised on a worker thread.
	while not AudioManager.is_ambient_ready and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	_boot_progress(0.5)
	if not splash_screen.visible:
		_booting = false
		return

	# 2. Tile shaders compile on first draw. Draw a lesson board once, hidden
	#    under the splash, so the first real board does not hitch.
	board.visible = true
	board.restore_stage(TutorialBoards.C_LAYERS.duplicate(true))
	for i in 3:
		await get_tree().process_frame
	board.clear_board()
	board.visible = false
	_boot_progress(0.8)
	# Anything that took the splash down already (the test harnesses do, to
	# drive the game directly) owns the screen now; do not pull it home.
	if not splash_screen.visible:
		_booting = false
		return

	# 3. The menu, built behind the splash so it is whole when revealed.
	_return_home()
	for i in 2:
		await get_tree().process_frame
	_boot_progress(1.0)

	var elapsed: float = float(Time.get_ticks_msec() - started) / 1000.0
	if elapsed < BOOT_MIN_SECONDS:
		await get_tree().create_timer(BOOT_MIN_SECONDS - elapsed).timeout
	_booting = false
	AudioManager.play_win()
	var tween := create_tween()
	tween.tween_property($SplashScreen/SplashTexture, "modulate:a", 0.0, 0.5) 		.set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(_boot_bar.get_parent(), "modulate:a", 0.0, 0.3)
	tween.tween_callback(func(): splash_screen.visible = false)

## Every tap disturbs the water. _input() runs before the GUI consumes the
## event, so this fires over menus and modals as well as the board - the pond
## is behind all of them, and with the Rack's transparent card the ripple is
## visible between the tiles.
func _input(event: InputEvent) -> void:
	# Back is handled here rather than in _unhandled_input because a focused
	# Button consumes the key first, which is why the gesture appeared to do
	# nothing on device even with the notification wired up.
	if event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_BACK or k.physical_keycode == KEY_BACK or k.keycode == KEY_ESCAPE:
			_handle_back_action("key")
			get_viewport().set_input_as_handled()
			return
	if zen_background == null or not zen_background.has_method("add_ripple"):
		return
	var pos := Vector2.INF
	if event is InputEventScreenTouch and event.pressed:
		pos = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pos = event.position
	if pos == Vector2.INF:
		return
	if SettingsManager.is_reduced_motion():
		return
	# Gentler than a match ripple, and attract=false: if the koi darted at every
	# touch they would be permanently frantic and the reaction would stop
	# meaning anything when a real match happens.
	zen_background.add_ripple(pos, 0.45, false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_action("notification")
	# Android kills a backgrounded app without warning, so the board has to be on
	# disk before the app loses focus, not when it is told it is closing.
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_capture_session()

func _unhandled_input(event: InputEvent) -> void:
	# The splash can no longer be tapped away: it lifts itself when loading is
	# done, and the menu behind it is already built.
	if splash_screen.visible and event is InputEventMouseButton and event.pressed:
		return


## Back can arrive on two routes at once, and godotengine/godot#123454 reports
## the notification itself firing twice for one press. Either would walk two
## screens back per gesture, so one press only ever drives one transition.
const BACK_DEBOUNCE_MS: int = 250
var _last_back_msec: int = -100000

func _handle_back_action(route: String = "unknown") -> void:
	var now: int = Time.get_ticks_msec()
	if now - _last_back_msec < BACK_DEBOUNCE_MS:
		_report_back_route(route, "debounced")
		return
	_last_back_msec = now

	var outcome: String = ""
	if splash_screen.visible:
		# Loading: the splash lifts itself onto a menu that is already built.
		outcome = "splash (loading)"
	elif modal.visible:
		# Back never leaves the game. It used to exit from the main menu, on the
		# Android convention that back quits at the root, and losing a session to
		# a stray gesture is worse than having no gesture to quit with.
		if modal._current_screen != "main":
			outcome = "modal:%s" % modal._current_screen
			modal.handle_back_pressed()
		else:
			# The root screen. Back quits from here, which is the Android
			# convention, and there is nothing to lose: no board is in play on the
			# main menu. Anywhere else it navigates rather than exits.
			outcome = "modal:main -> quit"
			_quit_game()
	elif board.visible:
		outcome = "board->pause"
		_on_menu_clicked()
	else:
		outcome = "nothing visible"
	_report_back_route(route, outcome)

# ============================ BACK DIAGNOSTIC ============================
## Switch this to false to remove the on-screen back banner entirely; nothing
## else needs changing and the banner layer is then never created.
const BACK_DIAGNOSTIC: bool = false

var _back_diag: Label = null
var _back_diag_tween: Tween = null

func _build_back_diagnostic() -> void:
	var layer := CanvasLayer.new()
	layer.name = "BackDiagnostic"
	layer.layer = 90
	add_child(layer)
	_back_diag = Label.new()
	_back_diag.anchor_right = 1.0
	_back_diag.offset_top = 8.0
	_back_diag.offset_left = 8.0
	_back_diag.offset_right = -8.0
	_back_diag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back_diag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_back_diag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_diag.add_theme_color_override("font_color", Color(1, 1, 1))
	_back_diag.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_back_diag.add_theme_constant_override("outline_size", 8)
	_back_diag.add_theme_font_size_override("font_size", 34)
	_back_diag.modulate.a = 0.0
	layer.add_child(_back_diag)

func _report_back_route(route: String, outcome: String) -> void:
	# Always logged, so `adb logcat -s godot` answers the question even if the
	# banner is switched off or the device never renders it.
	print("[BACK] route=%s outcome=%s" % [route, outcome])
	if not BACK_DIAGNOSTIC or _back_diag == null:
		return
	_back_diag.text = "BACK via %s\n%s" % [route.to_upper(), outcome]
	if _back_diag_tween != null and _back_diag_tween.is_valid():
		_back_diag_tween.kill()
	_back_diag.modulate.a = 1.0
	_back_diag_tween = create_tween()
	_back_diag_tween.tween_interval(2.5)
	_back_diag_tween.tween_property(_back_diag, "modulate:a", 0.0, 0.5)

func _on_flow_updated_shader(flow: int, _suit: String, is_overdrive: bool) -> void:
	if zen_background and zen_background.has_method("set_flow_level"):
		zen_background.set_flow_level(flow, is_overdrive)
	else:
		var bg: ColorRect = $FeltBackground/BgColor
		if bg and bg.material is ShaderMaterial:
			var mat: ShaderMaterial = bg.material as ShaderMaterial
			mat.set_shader_parameter("flow_level", float(flow))
			mat.set_shader_parameter("overdrive", 1.0 if is_overdrive else 0.0)

func _on_tile_matched_ripple(world_pos: Vector2) -> void:
	if zen_background and zen_background.has_method("add_ripple"):
		var screen_pos: Vector2 = get_viewport().get_canvas_transform() * world_pos
		zen_background.add_ripple(screen_pos)

func _on_theme_changed(theme_data: Dictionary, new_level: int) -> void:
	if new_level > 1 and hud:
		hud.show_toast("Realm: %s" % theme_data.get("name", ""))

## Leaves the game. Flushes first: the profile batches its writes, so quitting
## on an unflushed one would lose whatever changed in the last few seconds.
func _quit_game() -> void:
	quit_attempts += 1
	if quit_suppressed:
		return
	SaveManager.save_game()
	get_tree().quit()

## Test-only: lets an audit drive the back gesture at the main menu without
## taking the harness down with it. The counter is what an audit asserts on,
## since a suppressed quit is otherwise indistinguishable from nothing at all.
var quit_suppressed: bool = false
var quit_attempts: int = 0

func _return_home() -> void:
	# Leaving for the menu ends the board. Keeping the session here would offer
	# the player a board they walked away from as if they had been interrupted.
	#
	# Only when there IS a board: the boot splash finishes by calling this, and
	# wiping the session there would mean nothing could ever be resumed.
	if board.get_active_tiles().size() > 0:
		SaveManager.clear_session()
	board.clear_board()
	board.visible = false
	hud.visible = false
	GameManager.is_timer_active = false
	StageModifiers.reset()
	modal.show_main_menu()

func _start_calm_mode(level: int) -> void:
	# Before anything is dealt. Dealing stage 1 and then starting the lesson
	# over the top of it meant GameManager was mid-stage-1 the whole time,
	# and clearing a four-tile lesson board recorded a three-star clear of
	# stage 1 - the player finished the tutorial already past it.
	if level == 1 and not SaveManager.prog.get("tutorial_completed", false) and not _onboarding_active:
		_start_onboarding()
		return
	board.visible = true
	hud.visible = true
	GameManager.start_calm(level)
	hud.setup_hud(GameManager.GameMode.CALM, level)
	var plan: Dictionary = StagePlan.describe(level)
	var layout_name: String = plan["layout"]
	GameManager.current_layout_name = layout_name

	if zen_background and zen_background.has_method("set_level"):
		zen_background.set_level(level)

	StageModifiers.active_modifier = plan["modifier"] as StageModifiers.Modifier
	if StageModifiers.active_modifier != StageModifiers.Modifier.NONE:
		hud.show_toast("%s: %s" % [StageModifiers.get_modifier_name(), StageModifiers.get_modifier_desc()])

	# Seeded from the level number, so a stage is the same puzzle every time.
	var rng := RandomNumberGenerator.new()
	rng.seed = plan["seed"]
	board.load_stage(layout_name, rng)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)

	_offer_theme_sample(level)


## False until this run has cost the player one of their three. A run is
## charged when the first match is made, not when the board is dealt: opening
## the mode, looking at it and backing out used to spend a run, so three looks
## cost a whole day of them.
var _rapids_charged: bool = false

func _start_run_mode() -> void:
	# The menu hides the row when the runs are spent, but the signal can also
	# arrive from a stale screen, so the cap is checked where the run actually
	# starts rather than only where it is offered.
	if SaveManager.rapids_runs_left() <= 0:
		hud.show_toast("No timed runs left today - %s." % SaveManager.time_until_reset())
		_return_home()
		return
	_rapids_charged = false
	board.visible = true
	hud.visible = true
	GameManager.start_timed_run()
	hud.setup_hud(GameManager.GameMode.RUN, 1)
	var layout_name: String = LADDER[0]
	GameManager.current_layout_name = layout_name

	if zen_background and zen_background.has_method("set_level"):
		zen_background.set_level(1)

	StageModifiers.set_modifier_for_stage(1, 1)

	board.load_stage(layout_name)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)

## Every player sees the same board on the same date, because the only input is
## the date itself. Drawn from the substantial shapes only - a daily challenge
## that deals a 36-tile opener is not a challenge - and the LCG step keeps
## consecutive dates from simply walking down the list.
static func daily_layout_pool() -> Array[String]:
	var pool: Array[String] = []
	for tier in [3, 4, 5]:
		for name in StagePlan.layouts_in_tier(tier):
			if not pool.has(name):
				pool.append(name)
	pool.sort()
	return pool

static func daily_layout_for_seed(seed_value: int) -> String:
	var pool: Array[String] = daily_layout_pool()
	if pool.is_empty():
		return BoardGenerator.LADDER[1]
	# A single LCG step leaves consecutive dates striding the pool by a fixed
	# alternating amount (17, 13, 17, 13...), so a whole year is predictable
	# from one day. Mix properly before taking the modulo.
	var h: int = seed_value * 2654435761
	h = (h ^ (h >> 15)) * 2246822519
	h = (h ^ (h >> 13)) * 3266489917
	h = absi(h ^ (h >> 16))
	return pool[h % pool.size()]

func _start_daily_mode() -> void:
	if SaveManager.daily_done_today():
		hud.show_toast("Today's puzzle is done - %s." % SaveManager.time_until_reset())
		_return_home()
		return
	board.visible = true
	hud.visible = true
	GameManager.start_daily_tide()
	hud.setup_hud(GameManager.GameMode.DAILY, 1)
	var layout_name: String = daily_layout_for_seed(GameManager.daily_seed)
	GameManager.current_layout_name = layout_name
	GameManager.apply_daily_time(BoardGenerator.get_layout_positions(layout_name).size())

	if zen_background and zen_background.has_method("set_level"):
		var daily_level: int = (abs(GameManager.daily_seed) % 25) + 1
		zen_background.set_level(daily_level)

	StageModifiers.set_modifier_for_stage(2, 1, GameManager.daily_seed)
	if StageModifiers.active_modifier != StageModifiers.Modifier.NONE:
		hud.show_toast("%s: %s" % [StageModifiers.get_modifier_name(), StageModifiers.get_modifier_desc()])

	var rng := RandomNumberGenerator.new()
	rng.seed = GameManager.daily_seed
	board.load_stage(layout_name, rng)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)
	_offer_daily_theme_sample()

func _restart_current_stage() -> void:
	board.visible = true
	hud.visible = true
	var rng: RandomNumberGenerator = null
	if GameManager.current_mode == GameManager.GameMode.DAILY:
		rng = RandomNumberGenerator.new()
		rng.seed = GameManager.daily_seed
	GameManager.on_stage_started()
	board.load_stage(GameManager.current_layout_name, rng)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)

func _next_stage() -> void:
	# The unlock offer stands in front of the clear screen, so when it closes the
	# clear screen is still owed.
	if not _pending_clear.is_empty():
		var p: Dictionary = _pending_clear
		_pending_clear = {}
		modal.show_level_clear(int(p["level"]), int(p["score"]), int(p["stars"]), String(p.get("sampled", "")))
		MonetizationManager.show_interstitial_if_ready(int(p["level"]), "level_clear")
		return

	if GameManager.current_mode == GameManager.GameMode.CALM:
		_start_calm_mode(GameManager.current_level + 1)
	else:
		# _on_board_cleared() hid the HUD to clear the way for the reward screen;
		# without this the next stage deals with no menu button, timer or props.
		board.visible = true
		hud.visible = true
		GameManager.current_stage_no += 1
		var layout_idx: int = mini(LADDER.size() - 1, GameManager.current_stage_no - 1)
		var layout_name: String = LADDER[layout_idx]
		GameManager.current_layout_name = layout_name
		hud.setup_hud(GameManager.current_mode, GameManager.current_stage_no)
		GameManager.on_stage_started()

		if zen_background and zen_background.has_method("set_level"):
			zen_background.set_level(GameManager.current_stage_no)

		var mod_mode := 0 if GameManager.current_mode == GameManager.GameMode.CALM else 1
		StageModifiers.set_modifier_for_stage(mod_mode, GameManager.current_stage_no)
		if StageModifiers.active_modifier != StageModifiers.Modifier.NONE:
			hud.show_toast("%s: %s" % [StageModifiers.get_modifier_name(), StageModifiers.get_modifier_desc()])

		board.load_stage(layout_name)
		camera.frame_board(board.board_bounds, get_viewport_rect().size)

func _resume_game() -> void:
	if GameManager.current_mode != GameManager.GameMode.CALM:
		GameManager.is_timer_active = true

func _on_menu_clicked() -> void:
	GameManager.is_timer_active = false
	modal.show_pause_menu()

func _on_undo_clicked() -> void:
	if GameManager.undos > 0 and board.undo_last_move():
		GameManager.undos -= 1
		GameManager.props_used += 1
		GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
		hud.show_toast("Undid last move.")
	elif GameManager.undos <= 0:
		hud.show_toast("No Undos left! Tap ◈ Pearls to visit Bazaar.")

func _on_hint_clicked() -> void:
	if GameManager.hints > 0 and board.provide_hint():
		GameManager.hints -= 1
		GameManager.props_used += 1
		GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
		hud.show_toast("Hint shown!")
	elif GameManager.hints <= 0:
		hud.show_toast("No Hints left! Tap ◈ Pearls to visit Bazaar.")

func _on_shuffle_clicked() -> void:
	if GameManager.shuffles <= 0:
		hud.show_toast("No Shuffles left! Tap ◈ Pearls to visit Bazaar.")
		return
	if board.shuffle_remaining_tiles():
		GameManager.props_used += 1
		GameManager.shuffles -= 1
		GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
		hud.show_toast("Board reshuffled!")
		return
	# The charge is not spent on a refusal. This happens when what is left
	# cannot be arranged into a solvable board at all - two tiles sharing one
	# column, for instance, where the lower can never be uncovered. The player
	# did nothing wrong and should not pay for it.
	hud.show_toast("This board cannot be untangled. Restart the stage from the menu.")

func _on_board_move_completed(remaining: int, legal_moves: int) -> void:
	hud.update_board_stats(remaining, legal_moves)


## Spends one of the three daily runs, once, on the first match of the run.
##
## Hung off tile_matched rather than move_completed: move_completed is emitted
## by load_stage as well, so charging there would have spent the run at the
## moment the board was dealt - the very thing this exists to stop.
func _charge_rapids_run() -> void:
	if _rapids_charged or GameManager.current_mode != GameManager.GameMode.RUN:
		return
	_rapids_charged = true
	SaveManager.record_rapids_start()

## Held while the unlock offer is up, so the clear screen can follow it rather
## than being skipped by it.
var _pending_clear: Dictionary = {}

func _on_board_cleared() -> void:
	# A lesson board emptying is not a level cleared. It has no stars, no
	# score and no next stage - the tutorial decides what follows it. Without
	# this, finishing the four-tile first lesson recorded a three-star clear
	# of stage 1 and moved the player past it.
	if _onboarding_active:
		return
	SaveManager.clear_session()
	GameManager.is_timer_active = false
	hud.visible = false
	AudioManager.play_win()

	MonetizationManager.record_level_cleared()

	if GameManager.current_mode == GameManager.GameMode.CALM:
		var stars: int = 1
		if GameManager.misplays <= 2: stars += 1
		if GameManager.props_used == 0: stars += 1
		SaveManager.record_level_clear(GameManager.current_level, GameManager.score, stars)
		# A milestone set is offered before the usual clear screen, so it reads as
		# the event it is rather than a row on a results sheet. Taking it or
		# leaving it both carry on to the next stage.
		var granted: Array[String] = MonetizationManager.grant_milestone_themes(GameManager.current_level)
		var offer_sample: bool = GameManager.current_level == SAMPLE_STAGE 			and not sampled_theme.is_empty() 			and not MonetizationManager.is_theme_unlocked(sampled_theme)
		if not granted.is_empty() or offer_sample:
			_pending_clear = {"level": GameManager.current_level, "score": GameManager.score,
				"stars": stars, "sampled": sampled_theme}
			if not granted.is_empty():
				modal.show_theme_unlocked(granted[0])
			else:
				modal.show_premium_offer(sampled_theme)
			return
		modal.show_level_clear(GameManager.current_level, GameManager.score, stars, sampled_theme)
		MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "level_clear")
	elif GameManager.current_mode == GameManager.GameMode.DAILY:
		var first_today: bool = SaveManager.record_daily_play()
		var blessing: int = DAILY_BLESSING_PEARLS if first_today else 0
		if blessing > 0:
			SaveManager.add_pearls(blessing)
		modal.show_daily_clear(GameManager.score, GameManager.best_flow,
			int(SaveManager.prog.get("daily_streak", 1)), blessing, sampled_theme)
	else:
		# Straight into the next board. There used to be a relic draft here; it
		# was the thing testers understood least and it is gone, so a cleared
		# stage now just leads to the next one.
		hud.show_toast("Stage %d cleared" % GameManager.current_stage_no)
		await get_tree().create_timer(1.1).timeout
		_next_stage()

## ===================== SESSION (resume after a close) =====================
## Writes the board straight to disk rather than marking it dirty: the caller is
## a shutdown or background notification, and SaveManager may already have taken
## its own turn at that notification before this one runs.
func _capture_session() -> void:
	if not hud.visible or board.get_active_tiles().size() < 2:
		return
	if tutorial != null and tutorial.visible:
		return
	SaveManager.session = {
		"tiles": board.snapshot_tiles(),
		"mode": int(GameManager.current_mode),
		"level": GameManager.current_level,
		"stage_no": GameManager.current_stage_no,
		"layout": GameManager.current_layout_name,
		"daily_seed": GameManager.daily_seed,
		"modifier": int(StageModifiers.active_modifier),
		"score": GameManager.score,
		"flow_level": GameManager.flow_level,
		"flow_suit": GameManager.flow_suit,
		"best_flow": GameManager.best_flow,
		"misplays": GameManager.misplays,
		"props_used": GameManager.props_used,
		"undos": GameManager.undos,
		"hints": GameManager.hints,
		"shuffles": GameManager.shuffles,
		"time_left": GameManager.time_left,
		"max_time": GameManager.max_time,
		"rapids_charged": _rapids_charged,
	}
	SaveManager.save_game()

## Puts the player back on the board they left. A Rapids run resumed this way is
## the same run: whether it has been charged travels with the session, so
## closing the app can neither buy a fourth run nor give one back.
func _resume_session() -> bool:
	var s: Dictionary = SaveManager.session
	if s.is_empty():
		return false
	var mode: int = int(s.get("mode", 0))
	GameManager.current_mode = mode as GameManager.GameMode
	GameManager.current_level = int(s.get("level", 1))
	GameManager.current_stage_no = int(s.get("stage_no", 1))
	GameManager.current_layout_name = String(s.get("layout", "turtle"))
	GameManager.daily_seed = int(s.get("daily_seed", 0))
	StageModifiers.active_modifier = int(s.get("modifier", 0)) as StageModifiers.Modifier

	board.visible = true
	hud.visible = true
	if not board.restore_stage(s.get("tiles", [])):
		SaveManager.clear_session()
		return false

	GameManager.score = int(s.get("score", 0))
	GameManager.flow_level = int(s.get("flow_level", 0))
	GameManager.flow_suit = String(s.get("flow_suit", ""))
	GameManager.best_flow = int(s.get("best_flow", 0))
	GameManager.misplays = int(s.get("misplays", 0))
	GameManager.props_used = int(s.get("props_used", 0))
	GameManager.undos = int(s.get("undos", 0))
	GameManager.hints = int(s.get("hints", 0))
	GameManager.shuffles = int(s.get("shuffles", 0))
	GameManager.max_time = float(s.get("max_time", 180.0))
	GameManager.time_left = float(s.get("time_left", GameManager.max_time))
	GameManager.is_first_match_of_stage = GameManager.flow_level <= 0
	# A run that was left before its first match has not been charged yet, and
	# resuming must not charge it either - the first match still will.
	_rapids_charged = bool(s.get("rapids_charged", true))

	var hud_no: int = GameManager.current_level if mode == 0 else GameManager.current_stage_no
	hud.setup_hud(GameManager.current_mode, hud_no)
	GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
	GameManager.score_updated.emit(GameManager.score, 0)
	GameManager.flow_updated.emit(GameManager.flow_level, GameManager.flow_suit,
		GameManager.is_overdrive_active())
	GameManager.is_timer_active = mode != 0
	GameManager.time_updated.emit(GameManager.time_left, GameManager.max_time)

	if zen_background and zen_background.has_method("set_level"):
		zen_background.set_level(GameManager.current_level)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)
	modal.hide_modal()
	return true

## The onboarding owns the board while it runs, and hands it back when done.
## The HUD goes with it: a lesson about matching two tiles has no use for a
## score, a tile count or a props bar, and every one of them is something to
## explain that nobody asked about yet.
var _onboarding_active: bool = false

func _start_onboarding() -> void:
	_onboarding_active = true
	hud.visible = false
	board.visible = true
	modal.hide_modal()
	if not tutorial.tutorial_finished.is_connected(_on_onboarding_finished):
		tutorial.tutorial_finished.connect(_on_onboarding_finished)
	tutorial.start_tutorial(board)


func _on_onboarding_finished() -> void:
	_onboarding_active = false
	hud.visible = true
	# The stage the player is actually up to, dealt fresh. For a first-timer
	# that is stage 1; for someone replaying the lesson from Settings at stage
	# 10 it is stage 10. The lesson consumed the board either way, so one of
	# them has to be dealt, and it must not be stage 1 for a player who is
	# well past it.
	_start_calm_mode(int(SaveManager.prog.get("level", 1)))


## A set the player cannot see is a set they will not buy. Rather than a trial
## with an expiry - new save state, a clock to defend, and a decision about what
## happens when it lapses mid-board - a few tiles simply arrive wearing it.
##
## Nothing is persisted. The stage number decides when it happens, so there is
## no counter to sign and nothing to corrupt.
const SAMPLE_STAGE: int = 5
const SAMPLE_TILES: int = 7
const DAILY_SAMPLE_EVERY_DAYS: int = 3
const DAILY_SAMPLE_TILES: int = 10

## The set being shown off on this board, or "". Read by the clear screen so the
## offer follows the board it belongs to.
var sampled_theme: String = ""

func _offer_theme_sample(level: int) -> void:
	sampled_theme = ""
	if level != SAMPLE_STAGE:
		return
	_apply_theme_sample(SAMPLE_TILES)


static func is_daily_sample_day(unix_time: int) -> bool:
	return (unix_time / 86400) % DAILY_SAMPLE_EVERY_DAYS == 0


func _offer_daily_theme_sample() -> void:
	sampled_theme = ""
	if not is_daily_sample_day(int(Time.get_unix_time_from_system())):
		return
	_apply_theme_sample(DAILY_SAMPLE_TILES)


func _apply_theme_sample(count: int) -> void:
	var theme: String = MonetizationManager.cheapest_locked_theme()
	if theme.is_empty():
		return
	if board.sample_theme(theme, count) <= 0:
		return
	sampled_theme = theme
	hud.show_toast("A few tiles are wearing %s" % modal.theme_display_name(theme))


## The lesson points at whatever tiles are live, so it only needs to deal a board
## when there is none - and then it deals the stage the player is up to.
func _on_replay_tutorial() -> void:
	modal.hide_modal()
	_start_onboarding()


func _on_no_moves_left() -> void:
	# A board with no legal move is usually recoverable: a shuffle re-deals what
	# is left into an arrangement that can be played. When even that is
	# impossible the player is genuinely stuck through no fault of their own,
	# and is offered the stage rather than left staring at it.
	if board.can_reshuffle():
		hud.show_toast("No moves left! Use a shuffle or restart.")
		return
	hud.visible = false
	modal.show_deadlock(GameManager.current_level, board.get_active_tiles().size())


func _on_deadlock_accepted() -> void:
	SaveManager.clear_session()
	# One star, not three. They did not clear it, and a board that hands out a
	# perfect score for getting stuck would be worth getting stuck on.
	if GameManager.current_mode == GameManager.GameMode.CALM:
		SaveManager.record_level_clear(GameManager.current_level, GameManager.score, 1)
	modal.hide_modal()
	hud.visible = true
	if GameManager.current_mode == GameManager.GameMode.CALM:
		_start_calm_mode(GameManager.current_level + 1)
	else:
		_next_stage()


func _on_deadlock_retry() -> void:
	modal.hide_modal()
	hud.visible = true
	_restart_current_stage()

func _on_game_over(reason: String) -> void:
	SaveManager.clear_session()
	hud.visible = false
	modal.show_game_over(reason)
	MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "game_over")
