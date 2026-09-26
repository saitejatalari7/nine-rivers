extends Node

## On the dark themes a tile you cannot click must be grey, and a tile you can
## must not be. Checked against the engine's own idea of "free", tile by tile,
## because the whole reason this exists is that a player could not tell by eye.

const StagePlan = preload("res://scripts/core/stage_plan.gd")

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	SaveManager.economy["unlocked_themes"] = ["classic_jade", "theme_obsidian_ink", "theme_indigo"]
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	var board = main.get_node("Board")

	var plain: int = 22
	for lv in range(20, 60):
		if StagePlan.modifier_for_level(lv) == 0:
			plain = lv
			break

	for theme in ["theme_obsidian_ink", "theme_indigo", "classic_jade"]:
		MonetizationManager.equip_theme(theme)
		main._start_calm_mode(plain)
		await get_tree().create_timer(1.2).timeout
		var active: Array = board.get_active_tiles()
		var grid: Dictionary = board.get_spatial_grid(active)
		var wrong: int = 0
		var greyed: int = 0
		for t in active:
			var v = board.tile_views.get(t)
			var free: bool = board.is_tile_free_grid(t, grid)
			var is_grey: bool = v.material == TileView._grey_material()
			if is_grey:
				greyed += 1
			var want_grey: bool = theme != "classic_jade" and not free
			if is_grey != want_grey:
				wrong += 1
		var label: String = "%s: blocked tiles grey, free tiles normal" % theme
		if theme == "classic_jade":
			label = "classic_jade: light themes are left alone"
		_check(wrong == 0, label, "%d greyed of %d, %d wrong" % [greyed, active.size(), wrong])

	# And the look has to follow play: take a pair and whatever it freed must
	# come back to normal.
	MonetizationManager.equip_theme("theme_obsidian_ink")
	main._start_calm_mode(plain)
	await get_tree().create_timer(1.2).timeout
	var sets: Array = board.get_legal_sets()
	var typed: Array[RiverTile] = []
	for t in sets[0]:
		typed.append(t)
	board._resolve_matched_set(typed)
	await get_tree().create_timer(0.6).timeout
	var active2: Array = board.get_active_tiles()
	var grid2: Dictionary = board.get_spatial_grid(active2)
	var stale: int = 0
	for t in active2:
		var v = board.tile_views.get(t)
		if board.is_tile_free_grid(t, grid2) and v.material == TileView._grey_material():
			stale += 1
	_check(stale == 0, "a tile freed by a match turns normal again", "%d still grey" % stale)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-54s %s" % ["PASS" if ok else "FAIL", what, detail])
