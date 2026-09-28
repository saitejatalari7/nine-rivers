extends Node

## One stacked board on each tile set, for judging tile depth and layer step.
## Pass an output suffix after --: `-- before` / `-- after`.

const StagePlan = preload("res://scripts/core/stage_plan.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const OUT := "res://release/depth/"
const THEMES: Array[String] = ["classic_jade", "theme_imperial_gold", "theme_obsidian_ink"]

func _ready() -> void:
	var tag: String = "shot"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		tag = args[0]
	get_window().size = Vector2i(1080, 1920)
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["unlocked_themes"] = [
		"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
		"theme_cherry_blossom", "theme_indigo"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await get_tree().create_timer(1.5).timeout
	main.get_node("Modal").hide_modal()
	# A tall stack with no modifier, so layers are the subject.
	# The plain stage whose shape has the most layers.
	var stage: int = 33
	var best_z: int = -1
	for lv in range(5, 200):
		if StagePlan.modifier_for_level(lv) != 0:
			continue
		var max_z: int = 0
		for pos in BoardGenerator.get_layout_positions(StagePlan.layout_for_level(lv)):
			max_z = maxi(max_z, int(pos.z))
		if max_z > best_z:
			best_z = max_z
			stage = lv
	for theme in THEMES:
		MonetizationManager.equip_theme(theme)
		main._start_calm_mode(stage)
		await get_tree().create_timer(1.5).timeout
		main.get_node("HUD").visible = false
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "%s_%s.png" % [theme, tag]))
		print("  %s %s stage %d" % [theme, tag, stage])
	MonetizationManager.equip_theme("classic_jade")
	get_tree().quit(0)
