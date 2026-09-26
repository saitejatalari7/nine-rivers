extends Node

## Every theme on a real board, not a sheet of faces.
##
## legibility_check measures ink against its own tile face and passes all five
## themes. It says nothing about whether one tile can be told from the tile
## beside it, or which layer a tile is on - and on a dark theme that is where
## the difficulty actually is.

const StagePlan = preload("res://scripts/core/stage_plan.gd")

const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
	"theme_cherry_blossom", "theme_indigo",
]

func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["unlocked_themes"] = THEMES.duplicate()
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()

	# A stage with no modifier. Fog shrouds blocked tiles on purpose, and a
	# render meant to judge tile edges cannot have half its tiles hidden.
	var plain: int = 22
	for lv in range(20, 60):
		if StagePlan.modifier_for_level(lv) == 0:
			plain = lv
			break

	for theme in THEMES:
		MonetizationManager.equip_theme(theme)
		main._start_calm_mode(plain)
		await get_tree().create_timer(1.6).timeout
		main.get_node("HUD").visible = false
		await get_tree().create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var p := "res://assets/branding/screens/real_game/board_%s.png" % theme
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
		print("  " + p)
	get_tree().quit(0)
