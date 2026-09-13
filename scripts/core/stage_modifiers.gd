class_name StageModifiers
extends RefCounted

## Stage Modifiers Engine for Nine Rivers
## Implements Fog (concealed faces), Rush (1.5x drain / double score), and Frost (tap-to-shatter ice encasement)

enum Modifier {
	NONE,
	FOG,
	RUSH,
	FROST
}

static var active_modifier: Modifier = Modifier.NONE

static func reset() -> void:
	active_modifier = Modifier.NONE

static func set_modifier_for_stage(mode: int, stage_or_level: int, seed_val: int = 0) -> Modifier:
	# Mode: 0 = CALM, 1 = RUN, 2 = DAILY
	if mode == 0: # CALM
		if stage_or_level < 5:
			active_modifier = Modifier.NONE
		else:
			match stage_or_level % 4:
				1: active_modifier = Modifier.RUSH
				2: active_modifier = Modifier.FOG
				3: active_modifier = Modifier.FROST
				_: active_modifier = Modifier.NONE
	elif mode == 1: # RUN
		if stage_or_level <= 1:
			active_modifier = Modifier.NONE
		else:
			var roll: int = (stage_or_level - 1) % 4
			match roll:
				1: active_modifier = Modifier.FOG
				2: active_modifier = Modifier.RUSH
				3: active_modifier = Modifier.FROST
				_: active_modifier = Modifier.NONE
	elif mode == 2: # DAILY
		var mod_idx: int = absi(seed_val) % 4
		match mod_idx:
			1: active_modifier = Modifier.FOG
			2: active_modifier = Modifier.RUSH
			3: active_modifier = Modifier.FROST
			_: active_modifier = Modifier.NONE
	else:
		active_modifier = Modifier.NONE
	return active_modifier

static func get_modifier_name(mod: Modifier = active_modifier) -> String:
	match mod:
		Modifier.FOG: return "River Fog 🌫️"
		Modifier.RUSH: return "Torrent Rush ⚡"
		Modifier.FROST: return "Winter Frost ❄️"
		_: return ""

static func get_modifier_desc(mod: Modifier = active_modifier) -> String:
	match mod:
		Modifier.FOG: return "Deep river mist conceals all blocked tiles until freed."
		Modifier.RUSH: return "Timer drains 1.5× faster, but scoring is doubled!"
		Modifier.FROST: return "Chilling frost coats tiles. Tap once to shatter the ice."
		_: return ""

static func is_fog_active() -> bool:
	return active_modifier == Modifier.FOG

static func is_rush_active() -> bool:
	return active_modifier == Modifier.RUSH

static func is_frost_active() -> bool:
	return active_modifier == Modifier.FROST
