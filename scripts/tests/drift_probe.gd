extends Node

## The binaural render is baked into the PCM, so every cue can be measured
## rather than trusted. Three separate things must be true.

const MAX_LAG: int = 64

func _ready() -> void:
	await get_tree().process_frame
	var fails := 0
	print("event   dir    travel   ITD(us)   far-ear HF   verdict")
	for spec in [["drop", "_mono_drop"], ["air", "_mono_air"], ["note", "_mono_note"]]:
		for ltr in [true, false]:
			var mono: PackedFloat32Array = AudioManager.call(spec[1])
			var wav: AudioStreamWAV = AudioManager._binaural_render(mono, ltr)
			var d: PackedByteArray = wav.data
			var frames: int = d.size() / 4

			var a := _rms(d, 0, int(frames * 0.15))
			var b := _rms(d, int(frames * 0.85), frames)
			var travel: float = (b.y - b.x) - (a.y - a.x)

			# At the start the image is fully to one side, so the far ear should
			# lag the near one by close to the full ITD.
			var lag: int = _lag(d, 0, mini(frames, int(sample_rate() * 0.5)))
			var itd_us: float = abs(float(lag)) / sample_rate() * 1e6

			# And be duller: the head blocks treble more than bass.
			var hf := _hf_ratio(d, 0, int(frames * 0.15))
			var near_hf: float = hf.y if not ltr else hf.x
			var far_hf: float = hf.x if not ltr else hf.y

			var ok_travel: bool = (travel > 0.05) if ltr else (travel < -0.05)
			var ok_itd: bool = itd_us > 150.0
			var ok_shadow: bool = far_hf < near_hf * 0.9
			var verdict := ""
			if not ok_travel:
				verdict += "no travel "
			if not ok_itd:
				verdict += "no ITD "
			if not ok_shadow:
				verdict += "no shadow "
			if verdict.is_empty():
				verdict = "ok"
			else:
				fails += 1
			print("%-7s %-6s %+.2f    %6.0f    %.3f/%.3f   %s" % [
				spec[0], "L->R" if ltr else "R->L", travel, itd_us,
				near_hf, far_hf, verdict])

	print("")
	print("  ITD is the cue amplitude panning cannot produce; >150us means the")
	print("  far ear genuinely hears it later, not just quieter.")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func sample_rate() -> float:
	return AudioManager.sample_rate

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

## Cross-correlation lag between the channels, in samples.
func _lag(d: PackedByteArray, f0: int, f1: int) -> int:
	var best_lag := 0
	var best := -1.0
	for lag in range(-MAX_LAG, MAX_LAG + 1):
		var acc := 0.0
		var n := 0
		for i in range(f0 + MAX_LAG, f1 - MAX_LAG, 3):
			var l: float = float(d.decode_s16(i * 4)) / 32768.0
			var r: float = float(d.decode_s16((i + lag) * 4 + 2)) / 32768.0
			acc += l * r
			n += 1
		if n > 0:
			acc /= float(n)
			if acc > best:
				best = acc
				best_lag = lag
	return best_lag

## Crude high-frequency energy per channel: mean absolute sample-to-sample
## difference, which rises with treble content.
func _hf_ratio(d: PackedByteArray, f0: int, f1: int) -> Vector2:
	var hl := 0.0
	var hr := 0.0
	var n: int = maxi(1, f1 - f0 - 1)
	for i in range(f0, f1 - 1):
		var l0: float = float(d.decode_s16(i * 4)) / 32768.0
		var l1: float = float(d.decode_s16((i + 1) * 4)) / 32768.0
		var r0: float = float(d.decode_s16(i * 4 + 2)) / 32768.0
		var r1: float = float(d.decode_s16((i + 1) * 4 + 2)) / 32768.0
		hl += absf(l1 - l0)
		hr += absf(r1 - r0)
	return Vector2(hl / n, hr / n)
