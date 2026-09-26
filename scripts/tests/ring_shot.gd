extends Node2D

## Every highlight ring on every tile set, at 3x on the pond colour: plain,
## selected, hint, revealed.

const TileViewScene = preload("res://scenes/tile.tscn")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const THEMES: Array[String] = [
	"classic_jade", "theme_imperial_gold", "theme_obsidian_ink",
	"theme_cherry_blossom", "theme_indigo",
]
const STATES: Array[String] = ["plain", "selected", "hint", "revealed"]

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0a1f18"))
	get_window().size = Vector2i(1000, 1500)
	await get_tree().process_frame
	for r in THEMES.size():
		for c in STATES.size():
			var t := RiverTile.new(0, 0, 0, "dot", 5, r * 10 + c, 2)
			var holder := Node2D.new()
			holder.scale = Vector2(3, 3)
			holder.position = Vector2(60 + c * 240, 60 + r * 290)
			add_child(holder)
			var v = TileViewScene.instantiate()
			v.theme_override = THEMES[r]
			holder.add_child(v)
			v.setup(t, true)
			match STATES[c]:
				"selected": v.set_selected(true)
				"hint": v.set_hint(true)
				"revealed": v.set_revealed(true)
	await get_tree().create_timer(0.9).timeout
	await RenderingServer.frame_post_draw
	var p := "res://release/rings.png"
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(p))
	print("  " + p)
	get_tree().quit(0)
