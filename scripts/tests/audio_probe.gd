extends Node

## Renders the ambient bed to a .wav and reports what it actually contains,
## so the "does it still sound haunted" question can be answered with numbers
## rather than by listening and guessing.
##
## godot --headless --audio-driver Dummy --path . scenes/audio_probe.tscn

func _ready() -> void:
	await get_tree().process_frame
	# The real track is generated on a worker thread at boot; wait for it.
	for i in range(80):
		if AudioManager.ambient_player.stream != null:
			break
		await get_tree().process_frame
		await get_tree().create_timer(0.05).timeout

	var wav: AudioStreamWAV = AudioManager.ambient_player.stream
	if wav == null:
		printerr("ambient stream never generated")
		get_tree().quit(1)
		return

	var out := "user://ambient_bed.wav"
	wav.save_to_wav(ProjectSettings.globalize_path(out))
	print("wrote ", ProjectSettings.globalize_path(out))
	print("frames: %d  rate: %d  loop: %s" % [wav.data.size() / 2, wav.mix_rate, str(wav.loop_mode)])

	# Decode to floats
	var n: int = wav.data.size() / 2
	var s := PackedFloat32Array(); s.resize(n)
	for i in range(n):
		var lo: int = wav.data[i*2]
		var hi: int = wav.data[i*2 + 1]
		var v: int = (hi << 8) | lo
		if v >= 32768: v -= 65536
		s[i] = float(v) / 32768.0

	# Peak / RMS
	var peak := 0.0; var sq := 0.0
	for v in s:
		peak = maxf(peak, absf(v)); sq += v * v
	var rms: float = sqrt(sq / float(n))
	print("peak %.3f  rms %.4f  headroom %.1f dB" % [peak, rms, linear_to_db(maxf(peak, 0.0001))])

	# Loop seam: compare the last 256 frames against the first 256. A real
	# discontinuity here is what makes a loop tick audibly.
	var seam := 0.0
	for i in range(256):
		seam = maxf(seam, absf(s[n - 256 + i] - s[i]))
	print("loop seam max |delta| %.4f  (lower is smoother)" % seam)

	# Goertzel at the chord tones: confirms the major THIRD is actually present,
	# which is the whole point of the rewrite. D-A-D with no third is the
	# ambiguous, uneasy voicing we were trying to get away from.
	for probe in [
		{"name": "D2  root ", "f": 73.375},
		{"name": "A2  fifth", "f": 110.0},
		{"name": "F#3 THIRD", "f": 138.625},
		{"name": "D3  octave", "f": 146.875},
		{"name": "F3  (minor third, should be ~0)", "f": 174.6},
	]:
		print("  %s %8.3f Hz  mag %.4f" % [probe["name"], probe["f"], _goertzel(s, float(probe["f"]))])

	get_tree().quit(0)

func _goertzel(s: PackedFloat32Array, freq: float) -> float:
	var n: int = s.size()
	var k: float = freq * float(n) / 44100.0
	var w: float = TAU * k / float(n)
	var cw: float = cos(w)
	var coeff: float = 2.0 * cw
	var q1 := 0.0; var q2 := 0.0
	for i in range(n):
		var q0: float = coeff * q1 - q2 + s[i]
		q2 = q1; q1 = q0
	var mag: float = sqrt(q1*q1 + q2*q2 - coeff*q1*q2)
	return mag / float(n) * 2.0
