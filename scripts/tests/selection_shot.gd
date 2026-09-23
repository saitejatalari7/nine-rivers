extends Node2D

## Two identical tiles at 4x, one selected, so the lift and its shadow can be
## judged rather than argued about.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0a1f18"))
	await get_tree().process_frame
	for i in range(2):
		var t := RiverTile.new(0, 0, 0, "dot", 5, i, 2)
		var holder := Node2D.new()
		holder.scale = Vector2(4, 4)
		holder.position = Vector2(120 + i * 400, 500)
		add_child(holder)
		var v = TileViewScene.instantiate()
		holder.add_child(v)
		v.setup(t, true)
		if i == 1:
			v.set_selected(true)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/selection_lift.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
	get_tree().quit(0)
