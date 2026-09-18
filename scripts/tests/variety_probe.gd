extends Node

## "No audible repetition" is a claim, so it gets measured. For each bank this
## reports how many variants exist and how similar the two closest ones are.
##
## Similarity is normalised cross-correlation of the waveforms: 1.0 means
## identical, and anything under about 0.8 is a different sound rather than the
## same sound slightly moved.

const NEAR_DUPLICATE: float = 0.85

func _ready() -> void:
	await get_tree().process_frame
	var fails := 0
	print("bank        variants  closest pair  effective variants*")
	for spec in [
		["clack", AudioManager.clack_samples, 0.20],
		["sand", AudioManager.sand_samples, 0.20],
		["glass", AudioManager.glass_samples, 0.20],
		["shatter", AudioManager.shatter_samples, 0.20],
	]:
		var bank: Array = spec[1]
		var pitch_span: float = spec[2]
		if bank.size() < 2:
			print("%-11s %8d  (too few to compare)" % [spec[0], bank.size()])
			fails += 1
			continue
		var worst := 0.0
		for i in range(bank.size()):
			for j in range(i + 1, bank.size()):
				worst = maxf(worst, _similarity(bank[i], bank[j]))
		# A continuous pitch shift multiplies the bank: the ear resolves pitch
		# steps of roughly 3%, so a +-10% span is about 6 distinguishable pitches.
		var effective: int = bank.size() * int(pitch_span / 0.03)
		var flag := ""
		if worst > NEAR_DUPLICATE:
			flag = "  NEAR-DUPLICATE"
			fails += 1
		print("%-11s %8d  %12.3f  %d%s" % [spec[0], bank.size(), worst, effective, flag])

	print("")
	print("  * bank size x distinguishable pitch steps within the per-play jitter")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Spectral similarity, not waveform similarity. Two short clicks always
## correlate highly in the time domain because they share a sharp envelope -
## the first version of this probe measured "these are both clicks" rather than
## "these sound the same". Comparing magnitude spectra is closer to hearing.
func _similarity(a: AudioStreamWAV, b: AudioStreamWAV) -> float:
	var sa := _spectrum(a)
	var sb := _spectrum(b)
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in range(sa.size()):
		dot += sa[i] * sb[i]
		na += sa[i] * sa[i]
		nb += sb[i] * sb[i]
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	return dot / sqrt(na * nb)

## Coarse magnitude spectrum by direct evaluation at log-spaced frequencies.
func _spectrum(w: AudioStreamWAV) -> PackedFloat32Array:
	const BINS: int = 28
	const STRIDE: int = 3
	var d: PackedByteArray = w.data
	var n: int = d.size() / 2
	var out := PackedFloat32Array()
	out.resize(BINS)
	for b in range(BINS):
		var freq: float = 220.0 * pow(2.0, float(b) * 0.25)
		var re := 0.0
		var im := 0.0
		var i := 0
		while i < n:
			var x: float = float(d.decode_s16(i * 2)) / 32768.0
			var ang: float = TAU * freq * float(i) / 44100.0
			re += x * cos(ang)
			im += x * sin(ang)
			i += STRIDE
		out[b] = sqrt(re * re + im * im)
	return out

func _waveform_similarity(a: AudioStreamWAV, b: AudioStreamWAV) -> float:
	var da: PackedByteArray = a.data
	var db: PackedByteArray = b.data
	var n: int = mini(da.size(), db.size()) / 2
	if n < 16:
		return 0.0
	var dot := 0.0
	var na := 0.0
	var nb := 0.0
	for i in range(n):
		var x: float = float(da.decode_s16(i * 2)) / 32768.0
		var y: float = float(db.decode_s16(i * 2)) / 32768.0
		dot += x * y
		na += x * x
		nb += y * y
	if na <= 0.0 or nb <= 0.0:
		return 0.0
	return absf(dot) / sqrt(na * nb)
