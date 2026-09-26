extends Node

## ASMR & Procedural Acoustic Engine for Nine Rivers
## 44.1 kHz CD-Quality Physical Modeling:
## - Authentic dual-resonance melamine tile clack transients
## - Multi-harmonic Guzheng/Pipa string pluck synthesis with soundboard resonance
## - Living ambient river stream caustics & meditative pentatonic Guzheng phrasing
## - 3.5-second cascading victory fanfare & resonant temple gong

# Chinese Pentatonic Scale: Gong, Shang, Jue, Zhi, Yu across 3 octaves
# D3, E3, G3, A3, B3, D4, E4, G4, A4, B4, D5, E5, G5, A5
const PENTATONIC: Array[float] = [
	146.83, 164.81, 196.00, 220.00, 246.94,
	293.66, 329.63, 392.00, 440.00, 493.88,
	587.33, 659.25, 783.99, 880.00, 987.77,
	1174.66, 1318.51, 1567.98
]

# Meditative Guzheng Motifs (traditional melodic gestures in pentatonic scale)
const GUZHENG_MOTIFS: Array[Array] = [
	[293.66, 392.00, 440.00],                 # D4, G4, A4 (Spring Brooks)
	[392.00, 587.33, 523.25, 440.00],         # G4, D5, C5, A4 (Flowing Waters)
	[220.00, 293.66, 329.63],                 # A3, D4, E4 (Solitary Mountain)
	[261.63, 329.63, 392.00, 440.00],         # C4, E4, G4, A4 (River Jade)
	[329.63, 392.00, 293.66],                 # E4, G4, D4 (Bamboo Breeze)
	[440.00, 587.33, 659.25, 587.33],         # A4, D5, E5, D5 (Lotus Pond)
	[196.00, 293.66, 392.00]                  # G3, D4, G4 (Deep Valley)
]

var sfx_players: Array[AudioStreamPlayer] = []
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer

var sample_rate: float = 44100.0
var clack_samples: Array[AudioStreamWAV] = []
var shatter_samples: Array[AudioStreamWAV] = []
var sand_samples: Array[AudioStreamWAV] = []
var glass_samples: Array[AudioStreamWAV] = []
var click_sample: AudioStreamWAV = null

# Cache for procedurally synthesized Guzheng notes to prevent redundant CPU work
var _guzheng_cache: Dictionary = {}

const BUS_MUSIC := "NRMusic"
const BUS_SFX := "NRSfx"
const BUS_AMBIENT := "NRAmbient"
## Nature and bed sit at half volume, and there is no control to raise them:
## they are the room the game is played in, never the thing you listen to.
const AMBIENT_CEILING_DB: float = -6.02

## Everything used to play bone dry on Master. A plucked string with no space
## around it is the single biggest reason the audio read as cheap: real
## instruments are always heard in a room. Two buses, because music wants a
## long hall and tile clacks want a small one - drenching the clacks would
## smear the tactile attack that makes them satisfying.
func _setup_audio_buses() -> void:
	for spec in [
		{"name": BUS_MUSIC, "room": 0.82, "damp": 0.42, "wet": 0.34, "spread": 1.0, "predelay": 28.0},
		{"name": BUS_SFX,   "room": 0.46, "damp": 0.58, "wet": 0.16, "spread": 0.7, "predelay": 12.0},
		{"name": BUS_AMBIENT, "room": 0.70, "damp": 0.50, "wet": 0.18, "spread": 1.0, "predelay": 20.0},
	]:
		var bus_name: String = spec["name"]
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx: int = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")
		var rv := AudioEffectReverb.new()
		rv.room_size = spec["room"]
		rv.damping = spec["damp"]
		rv.wet = spec["wet"]
		rv.dry = 1.0
		rv.spread = spec["spread"]
		rv.predelay_msec = spec["predelay"]
		AudioServer.add_bus_effect(idx, rv)
	var amb: int = AudioServer.get_bus_index(BUS_AMBIENT)
	if amb != -1:
		AudioServer.set_bus_volume_db(amb, AMBIENT_CEILING_DB)

func _ready() -> void:
	_setup_audio_buses()

	# Pool of 12 SFX players for dense arpeggios & fanfare
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_SFX
		add_child(p)
		sfx_players.append(p)

	music_player = AudioStreamPlayer.new()
	music_player.bus = BUS_MUSIC
	add_child(music_player)

	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = BUS_AMBIENT
	ambient_player.volume_db = -80.0
	add_child(ambient_player)
	
	_setup_drift_layer()
	_setup_soundscape()
	_setup_positional_players()
	_pregenerate_ui_click()
	_pregenerate_clack_sounds()
	_pregenerate_ice_sounds()
	_pregenerate_shatter_sounds()
	_pregenerate_sand_sounds()
	_pregenerate_glass_shatter_sounds()
	
	# Offload heavy ambient water track generation to WorkerThreadPool to avoid blocking main thread
	WorkerThreadPool.add_task(_pregenerate_ambient_track_task)
	
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_start_ambient_guzheng_loop()

func _pregenerate_ambient_track_task() -> void:
	# Runs on a worker thread. If the game is closed before generation
	# finishes - which a short test run does routinely - this node and the
	# autoloads it touches may already be gone, so every access has to be
	# guarded rather than assumed.
	_pregenerate_ambient_track()
	if not is_instance_valid(self) or is_queued_for_deletion():
		return
	if is_instance_valid(SettingsManager) and SettingsManager.music_enabled:
		call_deferred("start_ambient_music")

func _on_setting_changed(setting_name: String, new_val: Variant) -> void:
	if setting_name == "music":
		if bool(new_val):
			start_ambient_music()
		else:
			stop_ambient_music()
		if soundscape != null:
			soundscape.set_enabled(bool(new_val))


const Soundscape = preload("res://scripts/audio/soundscape.gd")
var soundscape: Node = null

func _setup_soundscape() -> void:
	soundscape = Soundscape.new()
	soundscape.bus = BUS_AMBIENT
	add_child(soundscape)
	soundscape.set_enabled(SettingsManager.music_enabled)

func set_soundscape(background_id: String) -> void:
	if soundscape != null:
		soundscape.set_scape(background_id)

func start_ambient_music() -> void:
	if ambient_player.stream == null:
		return
	if not ambient_player.playing:
		ambient_player.play()
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", -14.0, 2.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func stop_ambient_music() -> void:
	var tween := create_tween()
	tween.tween_property(ambient_player, "volume_db", -80.0, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(ambient_player.stop)

func _start_ambient_guzheng_loop() -> void:
	# Longer and less even than before: the rests are what make it calm.
	var delay: float = randf_range(9.0, 22.0)
	get_tree().create_timer(delay).timeout.connect(func():
		if SettingsManager.music_enabled and ambient_player.playing:
			_play_random_ambient_phrase()
		_start_ambient_guzheng_loop()
	)

## A short walk on the pentatonic scale: mostly steps, the odd leap, and a
## fall back towards where it started. The seven fixed motifs are still in the
## mix, but most phrases are new, so none of them becomes a jingle.
func _compose_phrase() -> Array:
	var idx: int = randi_range(3, 10)
	var phrase: Array = [PENTATONIC[idx]]
	for i in randi_range(2, 4):
		var step: int = [-2, -1, -1, 1, 1, 2, 3][randi() % 7]
		idx = clampi(idx + step, 2, 12)
		phrase.append(PENTATONIC[idx])
	if randf() < 0.4:
		phrase.append(phrase[0])
	return phrase


func _play_random_ambient_phrase() -> void:
	var motif: Array = GUZHENG_MOTIFS[randi() % GUZHENG_MOTIFS.size()] 		if randf() < 0.25 else _compose_phrase()
	var base_time: float = 0.0
	for i in range(motif.size()):
		var freq: float = float(motif[i])
		var duration: float = 2.2 + randf() * 0.6
		var vol: float = 0.18 + randf() * 0.08
		get_tree().create_timer(base_time).timeout.connect(func():
			if SettingsManager.music_enabled and ambient_player.playing:
				_play_guzheng_string(freq, duration, vol)
		)
		base_time += randf_range(0.32, 0.48)

func _pregenerate_ambient_track() -> void:
	var _t_start: int = Time.get_ticks_msec()
	var duration: float = 8.0
	var total_frames: int = int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	
	# WHY THIS WAS REWRITTEN
	# The old bed was three bare sine waves on D2-A2-D3. Three separate things
	# made that sound haunted rather than calm:
	#   1. Pure sines have no overtones. That is the theremin timbre, which is
	#      what horror scoring uses precisely because nothing in nature makes it.
	#   2. D-A-D is a root, fifth and octave with NO THIRD. Tonally ambiguous
	#      chords are the standard film device for unease - the ear cannot tell
	#      major from minor and reads it as dread.
	#   3. It never changed. A perfectly static tone reads as unnatural.
	# The fix is a real chord with a third, harmonics, and slow movement.

	# D Gong pentatonic (D E F# A B). Using the major third F# resolves the
	# tonality, so the bed reads as settled rather than suspended.
	# Frequencies and detunes are snapped to multiples of 1/duration (0.125Hz),
	# so every partial completes a whole number of cycles per loop and the
	# 8-second seam is inaudible. The snap moves each note by a few cents at
	# most - far below what anyone can hear - and costs nothing.
	var voices := [
		{"f": 73.375,  "amp": 0.115, "detune": 0.0625, "phase": 0.0},  # D2 root
		{"f": 110.000, "amp": 0.080, "detune": 0.1250, "phase": 0.7},  # A2 fifth
		{"f": 138.625, "amp": 0.098, "detune": 0.1875, "phase": 1.9},  # F#3 THIRD
		{"f": 146.875, "amp": 0.042, "detune": 0.2500, "phase": 2.6},  # D3 octave
	]
	# Harmonic series per voice - this is what turns a sine into an instrument.
	var harmonics := [
		{"mult": 1.0, "amp": 1.00},
		{"mult": 2.0, "amp": 0.30},
		{"mult": 3.0, "amp": 0.14},
	]

	# Flatten voice x detune x harmonic into plain arrays of oscillators, each
	# advanced by a phase accumulator against a shared sine table. The naive
	# nested version needed ~14 million sin() calls for 8 seconds of audio,
	# which stalled startup; a table lookup with integer wrap is roughly two
	# orders of magnitude cheaper and this runs in well under a second.
	const LUT_BITS := 12
	const LUT_SIZE := 1 << LUT_BITS          # 4096
	const LUT_MASK := LUT_SIZE - 1
	var lut := PackedFloat32Array(); lut.resize(LUT_SIZE)
	for i in range(LUT_SIZE):
		lut[i] = sin(TAU * float(i) / float(LUT_SIZE))

	var osc_phase := PackedFloat32Array()
	var osc_inc := PackedFloat32Array()
	var osc_amp := PackedFloat32Array()
	var osc_voice := PackedInt32Array()
	for vi in range(voices.size()):
		var v: Dictionary = voices[vi]
		var base_f: float = float(v["f"])
		# Two slightly detuned copies per voice. The slow beating between them
		# is what makes a pad breathe instead of sitting still.
		for d in [-1.0, 1.0]:
			var f: float = base_f + d * float(v["detune"])
			for h in harmonics:
				osc_phase.append(float(v["phase"]) / TAU * float(LUT_SIZE))
				osc_inc.append(f * float(h["mult"]) * float(LUT_SIZE) / sample_rate)
				osc_amp.append(float(v["amp"]) * float(h["amp"]) * 0.5)
				osc_voice.append(vi)
	var osc_count: int = osc_phase.size()

	# Per-voice swell, also table-driven. Each voice breathes on its own slow
	# cycle, offset from the others, so the chord is always subtly shifting.
	var swell_phase := PackedFloat32Array(); swell_phase.resize(voices.size())
	var swell_inc: float = 0.125 * float(LUT_SIZE) / sample_rate
	for vi in range(voices.size()):
		swell_phase[vi] = float(voices[vi]["phase"]) / TAU * float(LUT_SIZE)

	var lp_state: float = 0.0
	var swell := PackedFloat32Array(); swell.resize(voices.size())

	for frame in range(total_frames):
		var t: float = float(frame) / sample_rate
		var norm_t: float = float(frame) / float(total_frames)

		for vi in range(voices.size()):
			swell[vi] = 0.75 + 0.25 * lut[int(swell_phase[vi]) & LUT_MASK]
			swell_phase[vi] = swell_phase[vi] + swell_inc

		var pad: float = 0.0
		for o in range(osc_count):
			pad += lut[int(osc_phase[o]) & LUT_MASK] * osc_amp[o] * swell[osc_voice[o]]
			osc_phase[o] = osc_phase[o] + osc_inc[o]

		# Gentle one-pole low pass: rolls the upper harmonics off so the pad is
		# warm rather than buzzy, the way a bowed or blown instrument behaves.
		lp_state += (pad - lp_state) * 0.22
		pad = lp_state


		# Smooth window at loop boundary to guarantee zero click
		var window: float = 1.0
		if norm_t < 0.05:
			window = norm_t / 0.05
		elif norm_t > 0.95:
			window = (1.0 - norm_t) / 0.05
			
		var val: float = pad * window * 0.62
		val = clampf(val, -1.0, 1.0)
		pcm.encode_s16(frame * 2, int(val * 32767.0))
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = total_frames
	wav.data = pcm
	print("Nine Rivers: ambient bed generated in %d ms" % (Time.get_ticks_msec() - _t_start))
	if is_instance_valid(self) and is_instance_valid(ambient_player):
		ambient_player.set_deferred("stream", wav)

func _pregenerate_ui_click() -> void:
	var duration: float = 0.035
	var total_frames: int = int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	
	for frame in range(total_frames):
		var t: float = float(frame) / sample_rate
		var s: float = sin(t * TAU * 1650.0) * exp(-t * 110.0) * 0.55
		var snap: float = (randf() * 2.0 - 1.0) * exp(-t * 300.0) * 0.35
		var val: float = clampf(s + snap, -1.0, 1.0)
		pcm.encode_s16(frame * 2, int(val * 32767.0))
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false
	wav.data = pcm
	click_sample = wav

## The tile clack is the most-heard sound in the game by an order of magnitude:
## a 144-tile board is around 144 taps. Four samples meant hearing each one
## roughly 36 times a board, which is what reads as repetition however good the
## sample is.
##
## Worse, every suit sounded identical, so the most frequent sound in the game
## carried no information. Each suit now has its own material - struck bamboo
## and a porcelain dot are as different to the ear as they are to the eye - so
## a player hears WHAT they cleared without looking, which matters when a tile
## is 33dp across.
##
## These are synthesised, not recorded, so variety costs generation time rather
## than download size: 5 materials x 8 variants is 40 clacks, about 3 seconds
## of audio in total.
const CLACK_PER_MATERIAL: int = 8

## suit -> the physical thing being struck.
##
## The first attempt gave every material the same model - two sines plus noise -
## and only moved the frequencies. The probe measured four of the five as no
## more like themselves than like each other, which is exactly right: that is
## one instrument in four tunings, not four instruments. What separates real
## materials is structural.
##
##   partials  how many modes ring, and at what ratios. Harmonic ratios sound
##             like a note; inharmonic ones sound like an object. A struck
##             plate is 1 : 2.76 : 5.40, which is why ceramic reads as ceramic.
##   noise     how much of the strike is grit rather than tone. Dense wood is
##             nearly all grit; a bell is nearly none.
##   decay     how long it rings. Bronze outlasts hardwood by a factor of five,
##             and that ratio carries more identity than pitch does.
const MATERIALS: Dictionary = {
	# Hollow bamboo tube: low body, one strong air resonance, gone quickly.
	"bam": {
		"body": [700.0, 960.0], "partials": [1.0, 2.62], "amps": [1.0, 0.55],
		"decay": [95.0, 125.0], "noise": [0.30, 0.48], "noise_decay": [430.0, 560.0],
		"noise_lp": 0.35,
	},
	# Glazed porcelain: plate ratios, almost no grit, rings on.
	"dot": {
		"body": [1500.0, 1880.0], "partials": [1.0, 2.76, 5.40], "amps": [1.0, 0.62, 0.30],
		"decay": [26.0, 38.0], "noise": [0.08, 0.16], "noise_decay": [620.0, 780.0],
		"noise_lp": 0.85,
	},
	# Dense hardwood: a thud. Almost all grit, one weak mode, dead fast.
	"char": {
		"body": [330.0, 560.0], "partials": [1.0, 1.72], "amps": [0.55, 0.20],
		"decay": [165.0, 215.0], "noise": [0.80, 0.98], "noise_decay": [260.0, 340.0],
		# Heavily filtered: hardwood on felt is a dull thump with almost no
		# treble, and unfiltered grit is what left this material measuring no
		# more like itself than like the others.
		"noise_lp": 0.06,
	},
	# Small bronze: four modes, a detuned pair beating against each other.
	"wind": {
		"body": [1320.0, 1690.0], "partials": [1.0, 2.01, 3.42, 5.83],
		"amps": [1.0, 0.85, 0.48, 0.26],
		"decay": [17.0, 26.0], "noise": [0.05, 0.11], "noise_decay": [700.0, 860.0],
		"noise_lp": 0.95,
	},
	# Larger bronze: lower, longer, heavier on the low modes.
	"dragon": {
		"body": [560.0, 980.0], "partials": [1.0, 1.98, 2.94, 4.21, 6.05],
		"amps": [1.0, 0.72, 0.55, 0.34, 0.18],
		"decay": [9.0, 22.0], "noise": [0.04, 0.09], "noise_decay": [760.0, 920.0],
		"noise_lp": 0.90,
	},
}

## suit -> bank. Flowers and seasons borrow the dragon voice; they are honours
## too, and giving every wild its own material would be variety nobody hears.
var clack_banks: Dictionary = {}

func _pregenerate_clack_sounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1EA7C1AC
	for suit in MATERIALS.keys():
		var bank: Array[AudioStreamWAV] = []
		for variation in range(CLACK_PER_MATERIAL):
			bank.append(_synth_clack(MATERIALS[suit], variation, rng))
		clack_banks[suit] = bank
		# The generic pool keeps every material, so a caller without a suit
		# still gets the full spread rather than one instrument.
		for w in bank:
			clack_samples.append(w)

## Stratified within the material: 8 independent draws from overlapping ranges
## collide by the birthday problem, and an earlier version produced a pair
## measuring 0.94 similar. Each variant owns a slice and jitters inside it,
## with body and ring strided differently so a bank is not a rising scale.
func _synth_clack(mat: Dictionary, variation: int, rng: RandomNumberGenerator) -> AudioStreamWAV:
	var n: int = CLACK_PER_MATERIAL
	var u: float = (float(variation) + rng.randf()) / float(n)
	var v: float = (float((variation * 5) % n) + rng.randf()) / float(n)
	var w: float = (float((variation * 3) % n) + rng.randf()) / float(n)

	var body: float = lerpf(mat["body"][0], mat["body"][1], u)
	var decay: float = lerpf(mat["decay"][0], mat["decay"][1], w)
	var noise_amp: float = lerpf(mat["noise"][0], mat["noise"][1], v)
	var noise_decay: float = lerpf(mat["noise_decay"][0], mat["noise_decay"][1], u)
	var partials: Array = mat["partials"]
	var amps: Array = mat["amps"]

	# A long ring needs a long buffer or it is cut off mid-decay; a thud does
	# not, and padding it with silence only wastes memory.
	var duration: float = clampf(5.0 / decay, 0.055, 0.42)
	var frames: int = int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(frames * 2)

	# Higher modes of a struck object die faster than the fundamental. Without
	# this every material keeps its full brightness to the end and they all
	# converge on the same timbre.
	var mode_decay := PackedFloat32Array()
	mode_decay.resize(partials.size())
	for m in range(partials.size()):
		mode_decay[m] = decay * (1.0 + float(m) * 0.55)

	var norm: float = 0.0
	for a in amps:
		norm += float(a)
	norm = maxf(norm, 0.001)

	var noise_lp: float = float(mat.get("noise_lp", 1.0))
	# A one-pole this low loses most of the signal, so make up the level or the
	# thud disappears entirely.
	var noise_gain: float = 1.0 / sqrt(maxf(noise_lp, 0.02))
	var noise_state: float = 0.0

	for i in range(frames):
		var t: float = float(i) / sample_rate
		var tone: float = 0.0
		for m in range(partials.size()):
			tone += sin(t * TAU * body * float(partials[m])) * float(amps[m]) * exp(-t * mode_decay[m])
		tone /= norm
		noise_state += ((rng.randf() * 2.0 - 1.0) - noise_state) * noise_lp
		var grit: float = noise_state * exp(-t * noise_decay) * noise_amp * noise_gain
		var val: float = clampf((tone + grit) * 0.62, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(val * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false
	wav.data = pcm
	return wav

## Falls back to the full spread when the suit has no material of its own.
func clack_bank_for(suit: String) -> Array:
	if clack_banks.has(suit):
		return clack_banks[suit]
	if suit == "flower" or suit == "season":
		return clack_banks.get("dragon", clack_samples)
	return clack_samples

var ice_samples: Array[AudioStreamWAV] = []

## Frost is one extra tap and no more, so the ice has to announce itself by
## sound alone or the modifier reads as nothing happening. Bright, short and
## brittle: a high inharmonic pair over a fast noise burst, nothing like the
## wooden or ceramic bodies underneath it.
func _pregenerate_ice_sounds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x1CEC4AC
	for variation in range(8):
		var u: float = (float(variation) + rng.randf()) / 8.0
		var v: float = (float((variation * 3) % 8) + rng.randf()) / 8.0
		var f1: float = lerpf(5200.0, 7400.0, u)
		var f2: float = lerpf(3100.0, 4600.0, v)
		var dur: float = rng.randf_range(0.10, 0.15)
		var frames: int = int(sample_rate * dur)
		var pcm := PackedByteArray()
		pcm.resize(frames * 2)
		for i in range(frames):
			var t: float = float(i) / sample_rate
			# Two envelopes: the snap of the fracture, then a short glassy tail.
			var snap: float = exp(-t * 340.0)
			var tail: float = exp(-t * 46.0) * 0.5
			var tone: float = sin(t * TAU * f1) * 0.7 + sin(t * TAU * f2) * 0.5
			var grit: float = (rng.randf() * 2.0 - 1.0) * snap * 0.9
			var val: float = clampf((tone * (snap + tail) + grit) * 0.42, -1.0, 1.0)
			pcm.encode_s16(i * 2, int(val * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.stereo = false
		wav.data = pcm
		ice_samples.append(wav)

func play_ice_crack(at: Vector2 = Vector2.INF, z: int = 0) -> void:
	haptic(14)
	if not SettingsManager.sfx_enabled or ice_samples.is_empty():
		return
	var sample: AudioStreamWAV = ice_samples[randi() % ice_samples.size()]
	_play_at(sample, at, z, -5.0 + randf() * 1.5, 0.92 + randf() * 0.18)


func _pregenerate_shatter_sounds() -> void:
	# 3 distinct tactile ceramic fracture & crumbling dust whoosh samples
	for variation in range(10):
		var duration: float = 0.28
		var total_frames: int = int(sample_rate * duration)
		var pcm := PackedByteArray()
		pcm.resize(total_frames * 2)
		
		var crack_freq: float = 2800.0 + variation * 350.0
		var ping_freq: float = 4200.0 - variation * 200.0
		
		for frame in range(total_frames):
			var t: float = float(frame) / sample_rate
			
			# 1. Immediate ceramic fracture crack (sharp transient)
			var crack_env: float = exp(-t * 150.0)
			var crack_tone: float = sin(t * TAU * crack_freq) * 0.48 + sin(t * TAU * ping_freq) * 0.32
			var crack_snap: float = (randf() * 2.0 - 1.0) * exp(-t * 350.0) * 0.72
			var crack: float = (crack_tone + crack_snap) * crack_env
			
			# 2. Tactile low-frequency body thud
			var body: float = sin(t * TAU * 185.0) * exp(-t * 38.0) * 0.36
			
			# 3. Soft crumbling dust whoosh (fine powder dispersing into air)
			var dust_env: float = exp(-t * 15.0) * (1.0 - exp(-t * 130.0))
			var dust_whoosh: float = (randf() * 2.0 - 1.0) * dust_env * 0.26
			
			var sample_val: float = (crack + body + dust_whoosh) * 0.62
			sample_val = clampf(sample_val, -1.0, 1.0)
			pcm.encode_s16(frame * 2, int(sample_val * 32767.0))
			
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.stereo = false
		wav.data = pcm
		shatter_samples.append(wav)

func _pregenerate_sand_sounds() -> void:
	# 3 variations of tactile golden sand cascade (fine grains cascading down with golden shimmer)
	for variation in range(10):
		var duration: float = 0.35
		var total_frames: int = int(sample_rate * duration)
		var pcm := PackedByteArray()
		pcm.resize(total_frames * 2)
		
		var shimmer_f1: float = 1760.0 + variation * 220.0
		var shimmer_f2: float = 2640.0 - variation * 180.0
		var last_sand: float = 0.0
		
		for frame in range(total_frames):
			var t: float = float(frame) / sample_rate
			
			# 1. Granular sand trickle noise (band-pass filtered random grains)
			var white: float = randf() * 2.0 - 1.0
			last_sand = (last_sand * 0.78) + (white * 0.22)
			var sand_env: float = (1.0 - exp(-t * 40.0)) * exp(-t * 9.5)
			var sand_cascade: float = last_sand * sand_env * 0.55
			
			# 2. Golden sparkle chime (delicate harmonic overtone)
			var sparkle_env: float = exp(-t * 18.0)
			var sparkle: float = (sin(t * TAU * shimmer_f1) * 0.22 + sin(t * TAU * shimmer_f2) * 0.14) * sparkle_env
			
			# 3. Soft warm foundation
			var warm_body: float = sin(t * TAU * 220.0) * exp(-t * 22.0) * 0.18
			
			var sample_val: float = (sand_cascade + sparkle + warm_body) * 0.68
			sample_val = clampf(sample_val, -1.0, 1.0)
			pcm.encode_s16(frame * 2, int(sample_val * 32767.0))
			
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.stereo = false
		wav.data = pcm
		sand_samples.append(wav)

func _pregenerate_glass_shatter_sounds() -> void:
	# 3 variations of crisp, crystalline physical breaking glass
	for variation in range(10):
		var duration: float = 0.40
		var total_frames: int = int(sample_rate * duration)
		var pcm := PackedByteArray()
		pcm.resize(total_frames * 2)
		
		var crack_f1: float = 4200.0 + variation * 350.0
		var crack_f2: float = 5873.0 - variation * 250.0
		var ring_f: float = 3520.0 + variation * 400.0
		
		for frame in range(total_frames):
			var t: float = float(frame) / sample_rate
			
			# 1. High-energy brittle glass fracture snap
			var snap_env: float = exp(-t * 260.0)
			var snap: float = (randf() * 2.0 - 1.0) * snap_env * 0.95
			var glass_crack: float = (sin(t * TAU * crack_f1) * 0.55 + sin(t * TAU * crack_f2) * 0.42) * exp(-t * 140.0)
			
			# 2. Resonant high-Q crystalline bell ring (glass chalice fracture resonance)
			var ring_env: float = exp(-t * 14.0)
			var crystal_ring: float = sin(t * TAU * ring_f) * ring_env * 0.38
			
			# 3. Tinkling micro-shards falling
			var tinkle_phase: float = sin(t * TAU * 18.0) * 0.5 + 0.5
			var tinkle: float = (randf() * 2.0 - 1.0) * exp(-t * 24.0) * tinkle_phase * 0.22
			
			var sample_val: float = (snap + glass_crack + crystal_ring + tinkle) * 0.72
			sample_val = clampf(sample_val, -1.0, 1.0)
			pcm.encode_s16(frame * 2, int(sample_val * 32767.0))
			
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.stereo = false
		wav.data = pcm
		glass_samples.append(wav)

# ================= PUBLIC SFX PLAY METHODS =================

## Must be called BEFORE any sfx_enabled early return: vibration is a separate
## setting from sound, and muting the game must not silence it.
func haptic(ms: int) -> void:
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(ms)

func play_ui_tap() -> void:
	haptic(4)
	if not SettingsManager.sfx_enabled or click_sample == null:
		return
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = click_sample
		player.pitch_scale = 1.12 + randf() * 0.05
		player.volume_db = -11.0
		player.play()


func play_click() -> void:
	haptic(5)
	if not SettingsManager.sfx_enabled or click_sample == null:
		return
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = click_sample
		player.pitch_scale = 0.98 + randf() * 0.04
		player.volume_db = -5.0
		player.play()

func play_tile_clack(pitch_mod: float = 1.0, at: Vector2 = Vector2.INF, z: int = 0,
		suit: String = "") -> void:
	haptic(8)
	if not SettingsManager.sfx_enabled or clack_samples.is_empty():
		return
	var bank: Array = clack_bank_for(suit)
	if bank.is_empty():
		bank = clack_samples
	var sample: AudioStreamWAV = bank[randi() % bank.size()]
	_play_at(sample, at, z, -3.5 + randf() * 1.6, pitch_mod * (0.90 + randf() * 0.20))

func play_tile_match(flow_level: int, is_triple: bool = false, is_glass: bool = false,
		at: Vector2 = Vector2.INF, z: int = 0) -> void:
	haptic(35 if is_glass else (25 if is_triple else 15))
	if not SettingsManager.sfx_enabled:
		return
	
	# 1. Vanishing sound: Breaking Glass for special tile, Golden Sand for standard tiles
	if is_glass:
		play_glass_shatter(is_triple)
	else:
		play_golden_sand(is_triple)
	
	# 2. Ascending Guzheng pentatonic chime
	var note_idx: int = clampi(flow_level + 4, 0, PENTATONIC.size() - 1)
	var freq: float = PENTATONIC[note_idx]
	_play_guzheng_string(freq, 0.42, 0.68, at, z)
	
	if is_triple:
		# Triple harmony: fifth interval Guzheng chime
		var fifth_freq: float = freq * 1.5
		get_tree().create_timer(0.06).timeout.connect(func(): _play_guzheng_string(fifth_freq, 0.48, 0.52))
	
	if flow_level >= 5:
		# Deep temple gong chime for Flow Overdrive!
		get_tree().create_timer(0.12).timeout.connect(func(): _play_guzheng_string(freq * 0.5, 0.85, 0.88))

func play_golden_sand(is_triple: bool = false) -> void:
	if not SettingsManager.sfx_enabled or sand_samples.is_empty():
		return
	var sample: AudioStreamWAV = sand_samples[randi() % sand_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.92 if is_triple else 1.0) * (0.90 + randf() * 0.20)
		player.volume_db = -1.5 if is_triple else -3.0
		player.play()

func play_glass_shatter(is_triple: bool = false) -> void:
	haptic(40)
	if not SettingsManager.sfx_enabled or glass_samples.is_empty():
		return
	var sample: AudioStreamWAV = glass_samples[randi() % glass_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.95 if is_triple else 1.0) * (0.98 + randf() * 0.05)
		player.volume_db = 0.5 if is_triple else -1.0
		player.play()

func play_tile_shatter(is_triple: bool = false) -> void:
	if not SettingsManager.sfx_enabled or shatter_samples.is_empty():
		return
	var sample: AudioStreamWAV = shatter_samples[randi() % shatter_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.90 if is_triple else 1.0) * (0.90 + randf() * 0.20)
		player.volume_db = -1.5 if is_triple else -3.0
		player.play()

func play_wild_strand() -> void:
	if not SettingsManager.sfx_enabled:
		return
	# Shimmering Guzheng arpeggio
	var notes: Array[float] = [783.99, 987.77, 1174.66]
	for i in range(notes.size()):
		var f: float = notes[i]
		get_tree().create_timer(i * 0.05).timeout.connect(func(): _play_guzheng_string(f, 0.35, 0.45))

func play_misplay() -> void:
	haptic(40)
	if not SettingsManager.sfx_enabled:
		return
	var player := _get_available_player()
	if player:
		var pcm := PackedByteArray()
		var dur := 0.14
		var frames := int(sample_rate * dur)
		pcm.resize(frames * 2)
		for i in range(frames):
			var t := float(i) / sample_rate
			var s := sin(t * TAU * 135.0) * exp(-t * 26.0) * 0.65
			pcm.encode_s16(i * 2, int(s * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.data = pcm
		player.stream = wav
		player.volume_db = -2.0
		player.play()

func play_win() -> void:
	if not SettingsManager.sfx_enabled:
		return
	
	# Grand 3.5s Ascending Chinese Pentatonic Victory Fanfare
	# 8-note Guzheng glissando culminating in a grand bell & low gong resonance
	var glissando: Array[float] = [
		196.00, # G3
		261.63, # C4
		293.66, # D4
		392.00, # G4
		440.00, # A4
		523.25, # C5
		587.33, # D5
		783.99  # G5
	]
	
	for i in range(glissando.size()):
		var f: float = glissando[i]
		var delay: float = i * 0.09
		get_tree().create_timer(delay).timeout.connect(func():
			_play_guzheng_string(f, 0.9, 0.75)
		)
		
	# Culminating grand temple chime chord at +0.85s (C3 + G3 + C4 + G4)
	get_tree().create_timer(0.85).timeout.connect(func():
		_play_guzheng_string(130.81, 2.8, 0.9)  # C3 deep gong
		_play_guzheng_string(196.00, 2.5, 0.7)  # G3
		_play_guzheng_string(261.63, 2.4, 0.65) # C4
		_play_guzheng_string(523.25, 2.2, 0.5)  # C5 high chime
	)

func play_tile_pick(at: Vector2 = Vector2.INF, z: int = 0) -> void:
	haptic(8)
	if not SettingsManager.sfx_enabled:
		return
	_play_guzheng_string(783.99, 0.12, 0.40, at, z)

func play_combo_high() -> void:
	if not SettingsManager.sfx_enabled:
		return
	var notes: Array[float] = [587.33, 783.99, 987.77]
	for i in range(notes.size()):
		var f: float = notes[i]
		get_tree().create_timer(i * 0.07).timeout.connect(func(): _play_guzheng_string(f, 0.55, 0.55))

func play_tick_warn() -> void:
	haptic(12)
	if not SettingsManager.sfx_enabled:
		return
	_play_guzheng_string(329.63, 0.14, 0.42)

func play_water_drop() -> void:
	haptic(8)
	if not SettingsManager.sfx_enabled:
		return
	var player := _get_available_player()
	if player:
		var pcm := PackedByteArray()
		var dur := 0.14
		var frames := int(sample_rate * dur)
		pcm.resize(frames * 2)
		var f_start := 650.0 + randf() * 120.0
		var f_end := 1380.0 + randf() * 180.0
		for i in range(frames):
			var t := float(i) / sample_rate
			var freq := lerpf(f_start, f_end, t / dur)
			var env := exp(-t * 26.0) * (1.0 - exp(-t * 120.0))
			var s := sin(t * TAU * freq) * env * 0.45
			pcm.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.data = pcm
		player.stream = wav
		player.volume_db = -3.5
		player.play()

func play_hitstop_impact() -> void:
	haptic(35)
	if not SettingsManager.sfx_enabled:
		return
	var player := _get_available_player()
	if player:
		var dur := 0.28
		var frames := int(sample_rate * dur)
		var pcm := PackedByteArray()
		pcm.resize(frames * 2)
		for i in range(frames):
			var t := float(i) / sample_rate
			var s := sin(t * TAU * 80.0) * exp(-t * 16.0) * 0.75 # Deep resonant temple bass thud
			var shimmer := sin(t * TAU * 1174.66) * exp(-t * 26.0) * 0.20 # High harmonic chime
			var val := clampf(s + shimmer, -1.0, 1.0)
			pcm.encode_s16(i * 2, int(val * 32767.0))
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.data = pcm
		player.stream = wav
		player.volume_db = -0.5
		player.play()

# ================= GUZHENG PHYSICAL STRING SYNTHESIZER =================

func _play_guzheng_string(freq: float, duration: float, volume: float,
		at: Vector2 = Vector2.INF, z: int = 0) -> void:
	var key: int = int(freq * 10.0) ^ (int(duration * 100.0) << 16)
	var wav: AudioStreamWAV
	
	if _guzheng_cache.has(key):
		wav = _guzheng_cache[key]
	else:
		wav = _synthesize_guzheng_wav(freq, duration)
		# Keep cache bounded to 64 notes
		if _guzheng_cache.size() > 64:
			_guzheng_cache.clear()
		_guzheng_cache[key] = wav
	
	_play_at(wav, at, z, linear_to_db(clampf(volume, 0.01, 1.0)), 1.0)

func _synthesize_guzheng_wav(freq: float, duration: float) -> AudioStreamWAV:
	var total_frames := int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	
	var inv_dur := 1.0 / duration
	
	for i in range(total_frames):
		var t := float(i) / sample_rate
		
		# Micro pitch-drop on initial string pluck tension release
		var cur_freq: float = freq * (1.0 + 0.008 * exp(-t * 85.0))
		
		# Subtle vibrato on sustained notes
		if duration > 0.45 and t > 0.12:
			cur_freq += sin(t * TAU * 5.2) * (freq * 0.0035) * minf(1.0, (t - 0.12) * 3.0)
		
		# Multi-harmonic string spectrum with frequency-dependent overtone damping
		var h1 := sin(t * TAU * cur_freq) * exp(-t * (2.8 * inv_dur))
		var h2 := sin(t * TAU * cur_freq * 2.0) * 0.38 * exp(-t * (4.5 * inv_dur))
		var h3 := sin(t * TAU * cur_freq * 3.0) * 0.18 * exp(-t * (6.5 * inv_dur))
		var h4 := sin(t * TAU * cur_freq * 4.0) * 0.09 * exp(-t * (9.0 * inv_dur))
		var h5 := sin(t * TAU * cur_freq * 5.0) * 0.04 * exp(-t * (13.0 * inv_dur))
		
		# Pluck pick impact transient (brief 4ms high-frequency strike burst)
		var pluck_transient := (randf() * 2.0 - 1.0) * exp(-t * 450.0) * 0.14
		
		# Paulownia wood Guzheng body resonance (warm lower chamber vibration)
		var body_res := sin(t * TAU * 240.0) * exp(-t * 18.0) * 0.08
		
		var sample := (h1 + h2 + h3 + h4 + h5 + pluck_transient + body_res) * 0.72
		sample = clampf(sample, -1.0, 1.0)
		pcm.encode_s16(i * 2, int(sample * 32767.0))
		
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = false
	wav.data = pcm
	return wav

func _get_available_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]


# ================= DRIFTING AMBIENT LAYER =================
## Sparse events that travel across the stereo field. Everything else in this
## file plays dead centre through AudioStreamPlayer, so the board had no width
## at all; these give it somewhere to happen.
##
## Sound design and spatialisation are separate: a generator returns a mono
## signal, and _binaural_render places it. That split is what makes real
## binaural affordable here - these are three events a minute, rendered once
## into a buffer, so the cost is paid at generation and never again. Doing the
## same per tap would mean convolving on every tile.

const DRIFT_MIN_GAP: float = 7.0
const DRIFT_MAX_GAP: float = 16.0

## Interaural time difference at full deflection. A sound reaching one ear
## before the other is the cue amplitude panning cannot fake, and it is most of
## why panned audio sits inside the head while binaural sits outside it.
## ~0.65 ms is the human maximum; kept at the low end because the two channels
## sum acoustically on a phone speaker, and a large ITD would comb-filter there.
const ITD_SECONDS: float = 0.00045
## How hard the head shadows the far ear. One-pole low-pass, because the head
## blocks treble far more than bass.
const SHADOW_MIN: float = 0.18

var drift_players: Array[AudioStreamPlayer] = []
var _drift_timer: float = 0.0
var _drift_rng := RandomNumberGenerator.new()

func _setup_drift_layer() -> void:
	_drift_rng.randomize()
	for i in range(3):
		var p := AudioStreamPlayer.new()
		p.bus = BUS_AMBIENT
		p.volume_db = -19.0
		add_child(p)
		drift_players.append(p)
	_drift_timer = _drift_rng.randf_range(2.0, 5.0)

func _process(delta: float) -> void:
	if drift_players.is_empty() or not SettingsManager.music_enabled:
		return
	_drift_timer -= delta
	if _drift_timer > 0.0:
		return
	_drift_timer = _drift_rng.randf_range(DRIFT_MIN_GAP, DRIFT_MAX_GAP)
	_play_drift_event()

func _play_drift_event() -> void:
	var free_player: AudioStreamPlayer = null
	for p in drift_players:
		if not p.playing:
			free_player = p
			break
	if free_player == null:
		return
	# The synthetic air swell was the "gush of wind" that kept coming back; the
	# recorded soundscape carries air and water now, so only drops and notes.
	var kind: int = 0 if _drift_rng.randf() < 0.5 else 2
	var ltr: bool = _drift_rng.randf() < 0.5
	var mono: PackedFloat32Array
	match kind:
		0:
			mono = _mono_drop()
		1:
			mono = _mono_air()
		_:
			mono = _mono_note()
	free_player.stream = _binaural_render(mono, ltr)
	free_player.play()

## Places a mono signal on a head. Three cues, in order of how much they matter
## for a sound moving horizontally:
##   1. ITD    - the far ear hears it later. The strongest lateralisation cue.
##   2. Shadow - the far ear hears it duller, because the head blocks treble.
##   3. ILD    - the far ear hears it quieter.
##
## This is a structural model, not a measured HRTF. It will not place a sound
## above or behind you - that needs pinna filtering from a real dataset - but
## it does get sounds out of the centre of the skull, which amplitude panning
## never does.
func _binaural_render(mono: PackedFloat32Array, ltr: bool) -> AudioStreamWAV:
	var frames: int = mono.size()
	var pcm := PackedByteArray()
	pcm.resize(frames * 4)
	var max_delay: float = ITD_SECONDS * sample_rate
	var shadow_l: float = 0.0
	var shadow_r: float = 0.0
	for i in range(frames):
		var u: float = float(i) / float(maxi(1, frames - 1))
		# -1 hard left, +1 hard right.
		var azim: float = (u * 2.0 - 1.0) if ltr else (1.0 - u * 2.0)
		var near_right: bool = azim > 0.0
		var mag: float = absf(azim)

		# The near ear reads the signal now; the far ear reads it from the past.
		var delay: float = mag * max_delay
		var far: float = _read_delayed(mono, i, delay)
		var near: float = mono[i]

		# Head shadow on the far ear only.
		var cutoff: float = lerpf(1.0, SHADOW_MIN, mag)
		var l_raw: float
		var r_raw: float
		if near_right:
			shadow_l += (far - shadow_l) * cutoff
			l_raw = shadow_l
			r_raw = near
		else:
			shadow_r += (far - shadow_r) * cutoff
			r_raw = shadow_r
			l_raw = near

		# Equal-power level difference over the top.
		var angle: float = (azim * 0.5 + 0.5) * PI * 0.5
		var gl: float = cos(angle)
		var gr: float = sin(angle)
		pcm.encode_s16(i * 4, int(clampf(l_raw * gl, -1.0, 1.0) * 32767.0))
		pcm.encode_s16(i * 4 + 2, int(clampf(r_raw * gr, -1.0, 1.0) * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = int(sample_rate)
	wav.stereo = true
	wav.data = pcm
	return wav

## Fractional read into the past, linearly interpolated; a whole-sample delay
## would step audibly as the image moves.
func _read_delayed(buf: PackedFloat32Array, i: int, delay: float) -> float:
	var pos: float = float(i) - delay
	if pos <= 0.0:
		return buf[0]
	var i0: int = int(pos)
	var i1: int = mini(i0 + 1, buf.size() - 1)
	var frac: float = pos - float(i0)
	return lerpf(buf[i0], buf[i1], frac)

## A single drop with a short pitch fall and a long tail.
func _mono_drop() -> PackedFloat32Array:
	var dur: float = _drift_rng.randf_range(3.2, 4.8)
	var frames: int = int(sample_rate * dur)
	var out := PackedFloat32Array()
	out.resize(frames)
	var f_start: float = _drift_rng.randf_range(900.0, 1400.0)
	var f_end: float = f_start * 0.55
	var phase: float = 0.0
	for i in range(frames):
		var t: float = float(i) / sample_rate
		var freq: float = lerpf(f_start, f_end, minf(1.0, t / 0.09))
		phase += TAU * freq / sample_rate
		var strike: float = exp(-t * 7.0) * (1.0 - exp(-t * 300.0))
		var tail: float = exp(-t * 0.45) * 0.38
		out[i] = sin(phase) * (strike + tail) * 0.5
	return out

## Filtered noise that swells and fades - a breath of air over the water.
func _mono_air() -> PackedFloat32Array:
	var dur: float = _drift_rng.randf_range(5.0, 7.5)
	var frames: int = int(sample_rate * dur)
	var out := PackedFloat32Array()
	out.resize(frames)
	var lp: float = 0.0
	var hp: float = 0.0
	var cutoff: float = _drift_rng.randf_range(0.02, 0.05)
	for i in range(frames):
		var u: float = float(i) / float(frames)
		var n: float = _drift_rng.randf_range(-1.0, 1.0)
		lp += (n - lp) * cutoff
		hp += (lp - hp) * cutoff * 0.25
		# Two one-pole stages this gentle leave almost nothing behind, so the
		# band needs real make-up gain to be audible at all.
		out[i] = (lp - hp) * 9.0 * sin(u * PI) * 0.75
	return out

## A single pentatonic note, soft enough to sit under the board.
func _mono_note() -> PackedFloat32Array:
	var dur: float = _drift_rng.randf_range(4.0, 6.0)
	var frames: int = int(sample_rate * dur)
	var out := PackedFloat32Array()
	out.resize(frames)
	var base: float = PENTATONIC[_drift_rng.randi_range(5, 12)]
	var p1: float = 0.0
	var p2: float = 0.0
	var p3: float = 0.0
	for i in range(frames):
		var t: float = float(i) / sample_rate
		p1 += TAU * base / sample_rate
		p2 += TAU * base * 2.0 / sample_rate
		p3 += TAU * base * 3.0 / sample_rate
		var env: float = exp(-t * 0.42) * (1.0 - exp(-t * 14.0))
		out[i] = (sin(p1) + sin(p2) * 0.22 + sin(p3) * 0.08) * env * 0.34
	return out

# ================= POSITIONAL BOARD AUDIO =================
## Tile sounds played where the tile is, and coloured by which layer it sits on.
## AudioStreamPlayer2D is right for these (unlike the drift layer): a tile IS in
## the world, so when the camera pans or zooms its sound should move with it.

const POSITIONAL_PANNING: float = 1.6
## Each layer up is nearer the player: a little louder and a little brighter.
const LAYER_GAIN_DB: float = 1.1
const LAYER_PITCH: float = 0.015

var pos_players: Array[AudioStreamPlayer2D] = []

func _setup_positional_players() -> void:
	for i in range(10):
		var p := AudioStreamPlayer2D.new()
		p.bus = BUS_SFX
		p.panning_strength = POSITIONAL_PANNING
		add_child(p)
		pos_players.append(p)

func _free_positional() -> AudioStreamPlayer2D:
	for p in pos_players:
		if not p.playing:
			return p
	return pos_players[0]

## Plays `stream` at a board position. Falls back to the centred pool when the
## caller has no position, so non-board sounds are unaffected.
func _play_at(stream: AudioStream, at: Vector2, z: int, vol_db: float, pitch: float) -> void:
	if stream == null:
		return
	if at == Vector2.INF or pos_players.is_empty():
		var mono := _get_available_player()
		if mono:
			mono.stream = stream
			mono.volume_db = vol_db
			mono.pitch_scale = pitch
			mono.play()
		return
	var p := _free_positional()
	p.stream = stream
	p.global_position = at
	p.volume_db = vol_db + float(z) * LAYER_GAIN_DB
	p.pitch_scale = pitch * (1.0 + float(z) * LAYER_PITCH)
	p.play()
