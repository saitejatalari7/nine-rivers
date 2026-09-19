extends Node

## Screenshots one real dealt board per tile theme.
##
## The paid themes had only ever been judged as isolated tiles on a neutral
## card. That is not what a buyer sees: a theme lives or dies as 32 tiles on
## the felt, stacked, half of them blocked and tinted.

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom",
]
const LAYOUT := "gate_house"
const SEED := 20260919


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.4).timeout

	var board = main.get_node("Board")
	main.get_node("Modal").hide_modal()
	for theme in THEMES:
		SaveManager.economy["active_tile_theme"] = theme
		MonetizationManager.theme_equipped.emit(theme)
		var rng := RandomNumberGenerator.new()
		rng.seed = SEED
		board.load_stage(LAYOUT, rng)
		board.visible = true
		main.get_node("HUD").visible = true
		main.get_node("Camera2D").frame_board(board.board_bounds, get_viewport().get_visible_rect().size)
		await get_tree().create_timer(1.2).timeout
		await RenderingServer.frame_post_draw
		var path := "res://assets/branding/screens/real_game/theme_%s.png" % theme
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
		print("  " + path)
	get_tree().quit(0)
