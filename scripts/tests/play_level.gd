extends Node

## Opens the game on a chosen level for hand testing: PLAY_LEVEL=10.

func _ready() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.0).timeout
	main.get_node("Modal").hide_modal()
	var lv: int = int(OS.get_environment("PLAY_LEVEL")) if OS.get_environment("PLAY_LEVEL") != "" else 10
	main._start_calm_mode(lv)
