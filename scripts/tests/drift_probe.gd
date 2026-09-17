extends Node

## The pan is baked into the PCM, so it can be measured directly rather than
## trusted. Each event must start on one side and end on the other.

func _ready() -> void:
	await get_tree().process_frame
	var fails := 0
	print("event        dir      start L/R        end L/R        travel")
	for spec in [["drop", "_make_drift_drop"], ["air", "_make_drift_air"], ["note", "_make_drift_note"]]:
		for ltr in [true, false]:
			var wav: AudioStreamWAV = AudioManager.call(spec[1], ltr)
			var d: PackedByteArray = wav.data
			var frames: int = d.size() / 4
			var a: Vector2 = _rms(d, 0, int(frames * 0.15))
			var b: Vector2 = _rms(d, int(frames * 0.85), frames)
			# Positive means energy moved left-to-right.
			var travel: float = (b.y - b.x) - (a.y - a.x)
			var want_positive: bool = ltr
			var ok: bool = (travel > 0.05) if want_positive else (travel < -0.05)
			if not ok:
				fails += 1
			print("%-12s %-8s %5.2f/%-5.2f    %5.2f/%-5.2f    %+.2f %s" % [
				spec[0], "L->R" if ltr else "R->L", a.x, a.y, b.x, b.y, travel,
				"" if ok else "  FAIL"])
	print("")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _rms(d: PackedByteArray, f0: int, f1: int) -> Vector2:
	var sl := 0.0
	var sr := 0.0
	var n: int = maxi(1, f1 - f0)
	for i in range(f0, f1):
		var l: float = float(d.decode_s16(i * 4)) / 32768.0
		var r: float = float(d.decode_s16(i * 4 + 2)) / 32768.0
		sl += l * l
		sr += r * r
	return Vector2(sqrt(sl / n), sqrt(sr / n))
