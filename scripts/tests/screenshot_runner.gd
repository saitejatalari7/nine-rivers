extends Node

## Boots the real game, equips each tile theme in turn, and captures the actual
## viewport - including a frame mid-shatter so the fracture effect is visible.
## Must run WITHOUT --headless: the headless renderer draws nothing.
##
## godot --audio-driver Dummy --path . scenes/screenshot_runner.tscn

const OUT_DIR := "res://assets/branding/screens/real_game/"
const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]

var main: Node2D
var board
var _shots: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))

	var packed: PackedScene = load("res://scenes/main.tscn")
	main = packed.instantiate()
	add_child(main)
	await get_tree().process_frame

	board = main.get_node("Board")
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	# Unlock everything so each paid theme can actually be equipped.
	SaveManager.economy["unlocked_themes"] = [
		"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]
	board.visible = true
	# The boot splash schedules _return_home() ~1.5s in, which re-opens the
	# main menu. Let that fire BEFORE capturing, or it lands mid-shot.
	await _wait(2.2)
	main.get_node("Modal").hide_modal()
	await get_tree().process_frame

	for theme_id in THEMES:
		await _capture_theme(theme_id)

	print("")
	print("SCREENSHOTS")
	for s in _shots:
		print("  " + s)
	get_tree().quit(0)

func _capture_theme(theme_id: String) -> void:
	SaveManager.economy["active_tile_theme"] = theme_id
	MonetizationManager.theme_equipped.emit(theme_id)

	# Level 8 has NO stage modifier (8 % 4 == 0). Level 7 is Winter Frost, whose
	# ice-crack overlay covers every tile and hides the material entirely.
	main._start_calm_mode(8)
	await get_tree().process_frame

	# The boot splash schedules _return_home(), which re-opens the main menu
	# over the board. Close it, and keep closing it while we settle.
	main.get_node("Modal").hide_modal()
	await _wait(1.4)
	main.get_node("Modal").hide_modal()
	await get_tree().process_frame
	await _shoot("board_%s" % theme_id)

	# Now trigger a real match so the fracture effect fires, and catch it
	# a few frames in, while the shards are still in the air.
	var sets: Array = board.get_legal_sets()
	if not sets.is_empty():
		var group: Array = sets[0]
		for t in group:
			var v = board.tile_views.get(t)
			if is_instance_valid(v):
				if t.is_frozen:
					board._on_tile_clicked(v)
				board._on_tile_clicked(v)
		await _wait(0.10)
		await _shoot("shatter_%s" % theme_id)

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func _shoot(name: String) -> void:
	# Wait for the frame to actually be drawn before grabbing the texture.
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	var path: String = OUT_DIR + name + ".png"
	img.save_png(ProjectSettings.globalize_path(path))
	_shots.append(path)
