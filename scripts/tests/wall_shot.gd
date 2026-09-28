extends Node2D

## Each tile set, three neighbours in a row: plain, selected, plain - plus a
## revealed tile. Shows the bottom wall and every set's selection look.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
	"theme_cherry_blossom", "theme_indigo",
]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0a1f18"))
	get_window().size = Vector2i(1000, 1500)
	await get_tree().process_frame
	for r in THEMES.size():
		for c in 4:
			var holder := Node2D.new()
			holder.scale = Vector2(2.2, 2.2)
			holder.position = Vector2(30 + c * 64 * 2.2 + (40 if c == 3 else 0), 40 + r * 250)
			add_child(holder)
			var v = TileViewScene.instantiate()
			v.theme_override = THEMES[r]
			holder.add_child(v)
			v.setup(RiverTile.new(c * 2, 0, 0, ["dot", "char", "bam", "dot"][c], [5, 3, 7, 2][c], r * 10 + c, 2), true)
			if c == 1:
				holder.z_index = 10
				v.set_selected(true)
			elif c == 3:
				v.set_revealed(true)
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://release/walls.png"))
	get_tree().quit(0)
