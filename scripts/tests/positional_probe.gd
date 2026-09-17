extends Node

## Confirms board sounds are routed to positioned players and coloured by layer.
## Actual perceived pan cannot be measured headlessly, so this checks the wiring
## and the depth law, and says so rather than claiming more.

func _ready() -> void:
	await get_tree().process_frame
	var fails := 0

	if AudioManager.pos_players.is_empty():
		print("  FAIL  no positional players were created")
		fails += 1
	else:
		print("  PASS  %d positional players on the SFX bus, panning strength %.1f" % [
			AudioManager.pos_players.size(), AudioManager.pos_players[0].panning_strength])

	# A sound with a position must land on a 2D player at that position.
	SettingsManager.sfx_enabled = true
	AudioManager.play_tile_clack(1.0, Vector2(640, 480), 2)
	await get_tree().process_frame
	var placed: AudioStreamPlayer2D = null
	for p in AudioManager.pos_players:
		if p.playing and p.global_position.is_equal_approx(Vector2(640, 480)):
			placed = p
			break
	if placed == null:
		print("  FAIL  a positioned clack did not reach a 2D player at that point")
		fails += 1
	else:
		print("  PASS  clack placed at %s, layer 2 -> %+.1f dB, pitch x%.3f" % [
			placed.global_position, placed.volume_db + 3.5, placed.pitch_scale])

	# Depth law: a higher layer must be louder and brighter than a lower one.
	var lo := _capture(0)
	var hi := _capture(3)
	if hi.x <= lo.x or hi.y <= lo.y:
		print("  FAIL  layer 3 is not louder/brighter than layer 0 (%s vs %s)" % [hi, lo])
		fails += 1
	else:
		print("  PASS  depth reads: layer 0 %.1f dB x%.3f, layer 3 %.1f dB x%.3f" % [
			lo.x, lo.y, hi.x, hi.y])

	# No position given: must stay on the centred pool, not silently vanish.
	AudioManager.play_tile_clack(1.0)
	await get_tree().process_frame
	var mono_playing := false
	for p in AudioManager.sfx_players:
		if p.playing:
			mono_playing = true
			break
	if not mono_playing:
		print("  FAIL  a clack with no position did not play on the centred pool")
		fails += 1
	else:
		print("  PASS  sounds without a position still play centred")

	print("  NOTE  perceived pan is not measured here; it needs a device listen")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _capture(z: int) -> Vector2:
	for p in AudioManager.pos_players:
		p.stop()
	AudioManager.play_tile_clack(1.0, Vector2(100 + z, 100), z)
	for p in AudioManager.pos_players:
		if p.playing:
			return Vector2(p.volume_db, p.pitch_scale)
	return Vector2.ZERO
