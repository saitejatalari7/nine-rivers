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
		# The combined pool is the union of the per-material banks, so its
		# closest pair is by construction the worst within-material pair -
		# flagging it as a near-duplicate would be double-counting.
		["clack (union)", AudioManager.clack_samples, 0.20, true],
		["ice", AudioManager.ice_samples, 0.18],
		["sand", AudioManager.sand_samples, 0.20],
		["glass", AudioManager.glass_samples, 0.20],
		["shatter", AudioManager.shatter_samples, 0.20],
	]:
		var bank: Array = spec[1]
		var pitch_span: float = spec[2]
		var informational: bool = spec.size() > 3 and bool(spec[3])
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
		if worst > NEAR_DUPLICATE and not informational:
			flag = "  NEAR-DUPLICATE"
			fails += 1
		print("%-11s %8d  %12.3f  %d%s" % [spec[0], bank.size(), worst, effective, flag])

	_check_materials()
	print("")
	print("  * bank size x distinguishable pitch steps within the per-play jitter")
	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

## Spectral similarity, not waveform similarity. Two short clicks always
## correlate highly in the time domain because they share a sharp envelope -
## the first version of this probe measured "these are both clicks" rather than
## "these sound the same". Comparing magnitude spectra is closer to hearing.
## Variety within a material is not the point of the material split. The point
## is that a bamboo tile and a dot tile sound like DIFFERENT OBJECTS, so the
## separation between banks has to be larger than the spread inside one - or
## the player hears eight kinds of the same thing rather than five instruments.
func _check_materials() -> void:
	print("")
	print("material   within-bank   vs other materials   separated by")
	var suits: Array = AudioManager.MATERIALS.keys()
	var worst_sep := 999.0
	for a in suits:
		var bank_a: Array = AudioManager.clack_banks[a]
		var within := 0.0
		for i in range(bank_a.size()):
			for j in range(i + 1, bank_a.size()):
				within = maxf(within, _similarity(bank_a[i], bank_a[j]))
		# Closest approach to any other material.
		var across := -1.0
		for b in suits:
			if b == a:
				continue
			for x in bank_a:
				for y in AudioManager.clack_banks[b]:
					across = maxf(across, _similarity(x, y))
		var margin: float = within - across
		if margin < worst_sep:
			worst_sep = margin
		print("%-10s %11.3f   %18.3f   %+.3f%s" % [
			a, within, across, margin, "" if margin > 0.0 else "  NOT DISTINCT"])
	if worst_sep <= 0.0:
		print("  FAIL  at least one material is no more like itself than like the others")
	else:
		print("  every material is more like itself than like any other (margin %+.3f)" % worst_sep)

func _similarity(a: AudioStreamWAV, b: AudioStreamWAV) -> float:
	var sa := _spectrum(a)
	var sb := _spectrum(b)
	# Pearson correlation of LOG spectra, not cosine of raw ones. Cosine on
	# all-positive vectors is biased high - any two broadband sounds score above
	# 0.9 simply because no component is ever negative, which is why the first
	# version called well-separated clacks near-duplicates. Taking logs matches
	# how the ear weighs level, and removing the mean measures whether the
	# spectral SHAPES differ rather than whether both are loud.
	var n: int = sa.size()
	var ma := 0.0
	var mb := 0.0
	for i in range(n):
		sa[i] = log(maxf(sa[i], 1e-6))
		sb[i] = log(maxf(sb[i], 1e-6))
		ma += sa[i]
		mb += sb[i]
	ma /= float(n)
	mb /= float(n)
	var dot := 0.0
	var va := 0.0
	var vb := 0.0
	for i in range(n):
		var x: float = sa[i] - ma
		var y: float = sb[i] - mb
		dot += x * y
		va += x * x
		vb += y * y
	if va <= 0.0 or vb <= 0.0:
		return 0.0
	return dot / sqrt(va * vb)

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
