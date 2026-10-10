extends Node

## The loading screen at a tall phone's shape, mid-load and near the end.

func _ready() -> void:
	get_window().size = Vector2i(540, 1158)
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	var out: String = OS.get_environment("SHOT_DIR")
	for at in [0.35, 0.9]:
		await get_tree().create_timer(at if at < 0.5 else 0.55).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out + "/boot_%d.png" % int(at * 100))
	get_tree().quit(0)
