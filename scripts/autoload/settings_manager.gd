extends Node

signal setting_changed(setting_name: String, new_value: Variant)

var music_enabled: bool:
	get: return SaveManager.settings.get("music", true)
	set(v):
		SaveManager.settings["music"] = v
		SaveManager.save_game()
		setting_changed.emit("music", v)

var sfx_enabled: bool:
	get: return SaveManager.settings.get("sfx", true)
	set(v):
		SaveManager.settings["sfx"] = v
		SaveManager.save_game()
		setting_changed.emit("sfx", v)

var haptics_enabled: bool:
	get: return SaveManager.settings.get("haptics", true)
	set(v):
		SaveManager.settings["haptics"] = v
		SaveManager.save_game()
		setting_changed.emit("haptics", v)

var motion_mode: String:
	get: return SaveManager.settings.get("motion", "full")
	set(v):
		SaveManager.settings["motion"] = v
		SaveManager.save_game()
		setting_changed.emit("motion", v)

var magnetic_assist: bool:
	get: return SaveManager.settings.get("magnetic_assist", true)
	set(v):
		SaveManager.settings["magnetic_assist"] = v
		SaveManager.save_game()
		setting_changed.emit("magnetic_assist", v)

var color_blind_mode: String:
	get: return SaveManager.settings.get("color_blind_mode", "none")
	set(v):
		SaveManager.settings["color_blind_mode"] = v
		SaveManager.save_game()
		setting_changed.emit("color_blind_mode", v)

var high_contrast_borders: bool:
	get: return SaveManager.settings.get("high_contrast_borders", false)
	set(v):
		SaveManager.settings["high_contrast_borders"] = v
		SaveManager.save_game()
		setting_changed.emit("high_contrast_borders", v)

func is_reduced_motion() -> bool:
	return motion_mode == "reduced"

func toggle_setting(k: String) -> void:
	match k:
		"music": music_enabled = not music_enabled
		"sfx": sfx_enabled = not sfx_enabled
		"haptics": haptics_enabled = not haptics_enabled
		"motion": motion_mode = "reduced" if motion_mode == "full" else "full"
		"magnetic_assist": magnetic_assist = not magnetic_assist
		"high_contrast_borders": high_contrast_borders = not high_contrast_borders
		"color_blind_mode":
			match color_blind_mode:
				"none": color_blind_mode = "deuteranopia"
				"deuteranopia": color_blind_mode = "protanopia"
				"protanopia": color_blind_mode = "tritanopia"
				_: color_blind_mode = "none"
