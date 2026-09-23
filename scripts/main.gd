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
	modal.deadlock_accepted.connect(_on_deadlock_accepted)
	modal.deadlock_retry.connect(_on_deadlock_retry)
	modal.resume_game_requested.connect(_resume_game)
	modal.return_home_requested.connect(_return_home)
	modal.background_quiet_changed.connect(func(quiet: bool):
		if zen_background and zen_background.has_method("set_quiet"):
			zen_background.set_quiet(quiet))
	modal.replay_tutorial_requested.connect(func():
		_start_calm_mode(1)
		tutorial.start_tutorial(board)
	)
	
	# Wire GameManager
	GameManager.game_over.connect(_on_game_over)
	GameManager.flow_updated.connect(_on_flow_updated_shader)
	
	if BACK_DIAGNOSTIC:
		_build_back_diagnostic()

	# Show intro splash on boot
	_show_intro_splash()

func _show_intro_splash() -> void:
	splash_screen.visible = true
	$SplashScreen/SplashTexture.modulate.a = 1.0
	board.visible = false
	hud.visible = false
	AudioManager.play_win()
	# The engine already shows the same artwork during init; this only dissolves
	# it into the pond. Keep it short.
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property($SplashScreen/SplashTexture, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		# Only finish the splash if the splash is still up. Tapping through it,
		# or any route that dismisses it first, used to leave this callback armed
		# to fire 0.55s later and haul the player back to the main menu from
		# wherever they had got to.
		if not splash_screen.visible:
			return
		splash_screen.visible = false
		board.visible = true
		hud.visible = true
		_return_home()
	)

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

func _unhandled_input(event: InputEvent) -> void:
	if splash_screen.visible and event is InputEventMouseButton and event.pressed:
		splash_screen.visible = false
		board.visible = true
		hud.visible = true
		_return_home()
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
		outcome = "splash->home"
		splash_screen.visible = false
		board.visible = true
		hud.visible = true
		_return_home()
	elif modal.visible:
		# Back never leaves the game. It used to exit from the main menu, on the
		# Android convention that back quits at the root, and losing a session to
		# a stray gesture is worse than having no gesture to quit with.
		if modal._current_screen != "main":
			outcome = "modal:%s" % modal._current_screen
			modal.handle_back_pressed()
		else:
			outcome = "modal:main (ignored)"
	elif board.visible:
		outcome = "board->pause"
		_on_menu_clicked()
	else:
		outcome = "nothing visible"
	_report_back_route(route, outcome)

# ============================ BACK DIAGNOSTIC ============================
## Switch this to false to remove the on-screen back banner entirely; nothing
## else needs changing and the banner layer is then never created.
const BACK_DIAGNOSTIC: bool = true

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
		hud.show_toast("Realm: %s (%s)" % [theme_data.get("name", ""), theme_data.get("name_zh", "")])

func _return_home() -> void:
	board.clear_board()
	board.visible = false
	hud.visible = false
	GameManager.is_timer_active = false
	StageModifiers.reset()
	modal.show_main_menu()

func _start_calm_mode(level: int) -> void:
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
	
	if level == 1 and not SaveManager.prog.get("tutorial_completed", false):
		# The board is handed over so the lesson can point at real tiles rather
		# than describe them.
		tutorial.start_tutorial(board)

func _start_run_mode() -> void:
	# The menu hides the row when the runs are spent, but the signal can also
	# arrive from a stale screen, so the cap is enforced where the run actually
	# starts rather than only where it is offered.
	if not SaveManager.record_rapids_start():
		hud.show_toast("No Rapids runs left today. Back tomorrow.")
		_return_home()
		return
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
		hud.show_toast("Today's Tide is cleared. Back tomorrow.")
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
		modal.show_level_clear(int(p["level"]), int(p["score"]), int(p["stars"]))
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

## Held while the unlock offer is up, so the clear screen can follow it rather
## than being skipped by it.
var _pending_clear: Dictionary = {}

func _on_board_cleared() -> void:
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
		if not granted.is_empty():
			_pending_clear = {"level": GameManager.current_level, "score": GameManager.score, "stars": stars}
			modal.show_theme_unlocked(granted[0])
			return
		modal.show_level_clear(GameManager.current_level, GameManager.score, stars)
		MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "level_clear")
	elif GameManager.current_mode == GameManager.GameMode.DAILY:
		var first_today: bool = SaveManager.record_daily_play()
		var blessing: int = DAILY_BLESSING_PEARLS if first_today else 0
		if blessing > 0:
			SaveManager.add_pearls(blessing)
		modal.show_daily_clear(GameManager.score, GameManager.best_flow,
			int(SaveManager.prog.get("daily_streak", 1)), blessing)
	else:
		# Straight into the next board. There used to be a relic draft here; it
		# was the thing testers understood least and it is gone, so a cleared
		# stage now just leads to the next one.
		hud.show_toast("Stage %d cleared" % GameManager.current_stage_no)
		await get_tree().create_timer(1.1).timeout
		_next_stage()

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
	hud.visible = false
	modal.show_game_over(reason)
	MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "game_over")
