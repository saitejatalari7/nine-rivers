extends Node2D

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const BoardController = preload("res://scripts/core/board_controller.gd")
const CameraController = preload("res://scripts/ui/camera_controller.gd")
const HudController = preload("res://scripts/ui/hud_controller.gd")
const ModalController = preload("res://scripts/ui/modal_controller.gd")
const SanctuaryView = preload("res://scripts/ui/sanctuary_view.gd")
const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")
const TutorialController = preload("res://scripts/ui/tutorial_controller.gd")

@onready var board: BoardController = $Board
@onready var camera: CameraController = $Camera2D
@onready var hud: HudController = $HUD
@onready var modal: ModalController = $Modal
@onready var sanctuary: SanctuaryView = $Sanctuary
@onready var splash_screen: CanvasLayer = $SplashScreen
@onready var zen_background = $FeltBackground

var tutorial: TutorialController

# Reference BoardGenerator's canonical ladder
const LADDER: Array[String] = BoardGenerator.LADDER

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
	
	# Wire Zen Background theme notifications
	if zen_background and zen_background.has_signal("theme_changed"):
		zen_background.theme_changed.connect(_on_theme_changed)
	
	# Wire Modal signals
	modal.start_calm_requested.connect(_start_calm_mode)
	modal.start_run_requested.connect(_start_run_mode)
	modal.start_daily_requested.connect(_start_daily_mode)
	modal.restart_stage_requested.connect(_restart_current_stage)
	modal.next_stage_requested.connect(_next_stage)
	modal.resume_game_requested.connect(_resume_game)
	modal.return_home_requested.connect(_return_home)
	modal.open_sanctuary_requested.connect(_open_sanctuary)
	modal.background_quiet_changed.connect(func(quiet: bool):
		if zen_background and zen_background.has_method("set_quiet"):
			zen_background.set_quiet(quiet))
	modal.replay_tutorial_requested.connect(func():
		_start_calm_mode(1)
		tutorial.start_tutorial()
	)
	sanctuary.back_requested.connect(_return_home_from_sanctuary)
	
	# Wire GameManager
	GameManager.game_over.connect(_on_game_over)
	GameManager.flow_updated.connect(_on_flow_updated_shader)
	
	# Show intro splash on boot
	_show_intro_splash()

func _show_intro_splash() -> void:
	splash_screen.visible = true
	$SplashScreen/SplashTexture.modulate.a = 1.0
	board.visible = false
	hud.visible = false
	AudioManager.play_win()
	# The engine already shows boot_splash/image - the same artwork - for the
	# whole of engine init. This layer only exists to dissolve it into the pond
	# instead of cutting. It used to hold for a further 1.0s and fade for 0.5s,
	# so the player looked at a finished, interactive game behind a static
	# image for a second and a half of every launch.
	var tween := create_tween()
	tween.tween_interval(0.15)
	tween.tween_property($SplashScreen/SplashTexture, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
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
		_handle_back_action()

func _unhandled_input(event: InputEvent) -> void:
	if splash_screen.visible and event is InputEventMouseButton and event.pressed:
		splash_screen.visible = false
		board.visible = true
		hud.visible = true
		_return_home()
		return
		
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK:
			_handle_back_action()
			get_viewport().set_input_as_handled()

func _handle_back_action() -> void:
	if splash_screen.visible:
		splash_screen.visible = false
		board.visible = true
		hud.visible = true
		_return_home()
	elif sanctuary.visible:
		_return_home_from_sanctuary()
	elif modal.visible:
		modal.handle_back_pressed()
	elif board.visible and not modal.visible:
		_on_menu_clicked()

func _open_sanctuary() -> void:
	board.visible = false
	hud.visible = false
	sanctuary.visible = true
	sanctuary.refresh_sanctuary()

func _return_home_from_sanctuary() -> void:
	sanctuary.visible = false
	board.visible = true
	hud.visible = true
	_return_home()

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
	sanctuary.visible = false
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
	var layout_idx: int = mini(LADDER.size() - 1, int((level - 1) / 2))
	var layout_name: String = LADDER[layout_idx]
	GameManager.current_layout_name = layout_name
	
	if zen_background and zen_background.has_method("set_level"):
		zen_background.set_level(level)
	
	StageModifiers.set_modifier_for_stage(0, level)
	if StageModifiers.active_modifier != StageModifiers.Modifier.NONE:
		hud.show_toast("%s: %s" % [StageModifiers.get_modifier_name(), StageModifiers.get_modifier_desc()])
	
	board.load_stage(layout_name)
	camera.frame_board(board.board_bounds, get_viewport_rect().size)
	
	if level == 1 and not SaveManager.prog.get("tutorial_completed", false):
		tutorial.start_tutorial()

func _start_run_mode() -> void:
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

func _start_daily_mode() -> void:
	board.visible = true
	hud.visible = true
	GameManager.start_daily_tide()
	hud.setup_hud(GameManager.GameMode.DAILY, 1)
	var layout_name: String = LADDER[1] # Gate House
	GameManager.current_layout_name = layout_name
	
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
	if GameManager.current_mode == GameManager.GameMode.CALM:
		_start_calm_mode(GameManager.current_level + 1)
	else:
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
	var free_surge: bool = GameManager.has_relic("tide_surge") and GameManager.time_left < 20.0 and GameManager.current_mode != GameManager.GameMode.CALM
	if (GameManager.shuffles > 0 or free_surge) and board.shuffle_remaining_tiles():
		GameManager.props_used += 1
		if free_surge:
			hud.show_toast("Tide Surge! Free shuffle under 20s.")
		else:
			GameManager.shuffles -= 1
			GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
			hud.show_toast("Board reshuffled!")
	elif GameManager.shuffles <= 0 and not free_surge:
		hud.show_toast("No Shuffles left! Tap ◈ Pearls to visit Bazaar.")

func _on_board_move_completed(remaining: int, legal_moves: int) -> void:
	hud.update_board_stats(remaining, legal_moves)

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
		modal.show_level_clear(GameManager.current_level, GameManager.score, stars)
		MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "level_clear")
	elif GameManager.current_mode == GameManager.GameMode.DAILY:
		SaveManager.record_daily_play()
		modal.show_daily_clear(GameManager.score, GameManager.best_flow, int(SaveManager.prog.get("daily_streak", 1)))
	else:
		modal.show_boon_draft()

func _on_no_moves_left() -> void:
	hud.show_toast("No moves left! Use a shuffle or restart.")

func _on_game_over(reason: String) -> void:
	hud.visible = false
	modal.show_game_over(reason)
	MonetizationManager.show_interstitial_if_ready(GameManager.current_level, "game_over")
