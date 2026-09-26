extends Node

## The recorded ambience must follow the background, stay at half volume with
## no way up, and stop when music is switched off.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	await get_tree().create_timer(1.0).timeout

	var bus: int = AudioServer.get_bus_index(AudioManager.BUS_AMBIENT)
	_check("ambient bus exists", bus != -1, "")
	_check("and sits at half volume", absf(AudioServer.get_bus_volume_db(bus) + 6.02) < 0.05,
		"%.2f dB" % AudioServer.get_bus_volume_db(bus))
	_check("the bed plays on it", AudioManager.ambient_player.bus == AudioManager.BUS_AMBIENT, "")

	var sc = AudioManager.soundscape
	for id in sc.SCAPES.keys():
		for key in sc.SCAPES[id]["beds"] + sc.SCAPES[id]["events"]:
			var s: AudioStream = sc._load(String(key))
			_check("%s loads" % key, s != null and s.get_length() > 3.0,
				"%.1fs" % (s.get_length() if s != null else 0.0))

	var bg = main.zen_background
	for id in ["moonlit_river", "autumn_stream", "misty_spring"]:
		if bg != null:
			bg.apply_theme_by_id(id, false)
		else:
			AudioManager.set_soundscape(id)
		await get_tree().create_timer(0.3).timeout
		_check("%s gets its own soundscape" % id, sc.current_scape() == id, sc.current_scape())
		var playing: bool = sc._beds[0].playing or sc._beds[1].playing
		_check("and a bed is playing", playing, "")

	SettingsManager.music_enabled = false
	await get_tree().create_timer(1.6).timeout
	_check("music off silences it", not (sc._beds[0].playing or sc._beds[1].playing), "")
	SettingsManager.music_enabled = true

	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-40s %s" % ["PASS" if ok else "FAIL", what, detail])
