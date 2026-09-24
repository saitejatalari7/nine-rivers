extends Node2D

## Bamboo 1 to 9 at 5x, so the bird can be judged at the size it is drawn.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0d2a21"))
	await get_tree().process_frame
	TileLighting.attach(self)
	for i in range(9):
		var holder := Node2D.new()
		holder.scale = Vector2(5, 5)
		holder.position = Vector2(30 + (i % 3) * 350, 40 + (i / 3) * 470)
		add_child(holder)
		var v = TileViewScene.instantiate()
		holder.add_child(v)
		v.setup(RiverTile.new(0, 0, 0, "bam", i + 1), true)
	await get_tree().create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	var p := "res://assets/branding/screens/real_game/bamboo.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
	get_tree().quit(0)
