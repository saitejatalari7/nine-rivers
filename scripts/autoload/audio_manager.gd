extends Node

## ASMR & Procedural Acoustic Engine for Nine Rivers (九河)
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

func _ready() -> void:
	# Pool of 12 SFX players for dense arpeggios & fanfare
	for i in range(12):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		sfx_players.append(p)
	
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Master"
	add_child(music_player)
	
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Master"
	ambient_player.volume_db = -80.0
	add_child(ambient_player)
	
	_pregenerate_ui_click()
	_pregenerate_clack_sounds()
	_pregenerate_shatter_sounds()
	_pregenerate_sand_sounds()
	_pregenerate_glass_shatter_sounds()
	
	# Offload heavy ambient water track generation to WorkerThreadPool to avoid blocking main thread
	WorkerThreadPool.add_task(_pregenerate_ambient_track_task)
	
	SettingsManager.setting_changed.connect(_on_setting_changed)
	_start_ambient_guzheng_loop()

func _pregenerate_ambient_track_task() -> void:
	_pregenerate_ambient_track()
	if SettingsManager.music_enabled:
		call_deferred("start_ambient_music")

func _on_setting_changed(setting_name: String, new_val: Variant) -> void:
	if setting_name == "music":
		if bool(new_val):
			start_ambient_music()
		else:
			stop_ambient_music()

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
	var delay: float = randf_range(7.5, 12.5)
	get_tree().create_timer(delay).timeout.connect(func():
		if SettingsManager.music_enabled and ambient_player.playing:
			_play_random_ambient_phrase()
		_start_ambient_guzheng_loop()
	)

func _play_random_ambient_phrase() -> void:
	var motif: Array = GUZHENG_MOTIFS[randi() % GUZHENG_MOTIFS.size()]
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
	var duration: float = 8.0
	var total_frames: int = int(sample_rate * duration)
	var pcm := PackedByteArray()
	pcm.resize(total_frames * 2)
	
	var last_noise: float = 0.0
	for frame in range(total_frames):
		var t: float = float(frame) / sample_rate
		var norm_t: float = float(frame) / float(total_frames)
		
		# Organic river water bed: warm root chords (D2 73.4Hz, A2 110Hz, D3 146.8Hz)
		var s1: float = sin(t * TAU * 73.416) * 0.13
		var s2: float = sin(t * TAU * 110.0 + 0.4) * 0.09
		var s3: float = sin(t * TAU * 146.83 + 1.1) * 0.06
		
		# Filtered pink/brown water wave lap
		var white: float = randf() * 2.0 - 1.0
		last_noise = (last_noise * 0.94) + (white * 0.06)
		var lap_envelope: float = (sin(t * TAU * 0.25) * 0.5 + 0.5) * 0.08
		var water_lap: float = last_noise * lap_envelope
		
		# Smooth window at loop boundary to guarantee zero click
		var window: float = 1.0
		if norm_t < 0.05:
			window = norm_t / 0.05
		elif norm_t > 0.95:
			window = (1.0 - norm_t) / 0.05
			
		var val: float = (s1 + s2 + s3 + water_lap) * window * 0.70
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

func _pregenerate_clack_sounds() -> void:
	# 4 distinct tactile ceramic clack audio samples modeled after solid melamine tiles
	for variation in range(4):
		var duration: float = 0.075
		var total_frames: int = int(sample_rate * duration)
		var pcm := PackedByteArray()
		pcm.resize(total_frames * 2)
		
		var base_freq: float = 1320.0 + variation * 180.0
		var ring_freq: float = 3100.0 - variation * 160.0
		
		for frame in range(total_frames):
			var t: float = float(frame) / sample_rate
			var env: float = exp(-t * 95.0) # Sharp transient decay
			
			# Multi-body impact modeling: stiff primary knock + high melamine resonance ping + micro fissure snap
			var primary: float = sin(t * TAU * base_freq)
			var ping: float = sin(t * TAU * ring_freq) * 0.42
			var snap: float = (randf() * 2.0 - 1.0) * exp(-t * 450.0) * 0.65
			
			var sample_val: float = (primary + ping + snap) * env * 0.52
			sample_val = clampf(sample_val, -1.0, 1.0)
			pcm.encode_s16(frame * 2, int(sample_val * 32767.0))
			
		var wav := AudioStreamWAV.new()
		wav.format = AudioStreamWAV.FORMAT_16_BITS
		wav.mix_rate = int(sample_rate)
		wav.stereo = false
		wav.data = pcm
		clack_samples.append(wav)

func _pregenerate_shatter_sounds() -> void:
	# 3 distinct tactile ceramic fracture & crumbling dust whoosh samples
	for variation in range(3):
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
	for variation in range(3):
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
	for variation in range(3):
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

func play_click() -> void:
	if not SettingsManager.sfx_enabled or click_sample == null:
		return
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = click_sample
		player.pitch_scale = 0.98 + randf() * 0.04
		player.volume_db = -5.0
		player.play()
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(5)

func play_tile_clack(pitch_mod: float = 1.0) -> void:
	if not SettingsManager.sfx_enabled or clack_samples.is_empty():
		return
	var sample: AudioStreamWAV = clack_samples[randi() % clack_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = pitch_mod * (0.96 + randf() * 0.08)
		player.volume_db = -3.5
		player.play()
	
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(8)

func play_tile_match(flow_level: int, is_triple: bool = false, is_glass: bool = false) -> void:
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
	_play_guzheng_string(freq, 0.42, 0.68)
	
	if is_triple:
		# Triple harmony: fifth interval Guzheng chime
		var fifth_freq: float = freq * 1.5
		get_tree().create_timer(0.06).timeout.connect(func(): _play_guzheng_string(fifth_freq, 0.48, 0.52))
	
	if flow_level >= 5:
		# Deep temple gong chime for Flow Overdrive!
		get_tree().create_timer(0.12).timeout.connect(func(): _play_guzheng_string(freq * 0.5, 0.85, 0.88))
	
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(35 if is_glass else (25 if is_triple else 15))

func play_golden_sand(is_triple: bool = false) -> void:
	if not SettingsManager.sfx_enabled or sand_samples.is_empty():
		return
	var sample: AudioStreamWAV = sand_samples[randi() % sand_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.92 if is_triple else 1.0) * (0.96 + randf() * 0.08)
		player.volume_db = -1.5 if is_triple else -3.0
		player.play()

func play_glass_shatter(is_triple: bool = false) -> void:
	if not SettingsManager.sfx_enabled or glass_samples.is_empty():
		return
	var sample: AudioStreamWAV = glass_samples[randi() % glass_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.95 if is_triple else 1.0) * (0.98 + randf() * 0.05)
		player.volume_db = 0.5 if is_triple else -1.0
		player.play()
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(40)

func play_tile_shatter(is_triple: bool = false) -> void:
	if not SettingsManager.sfx_enabled or shatter_samples.is_empty():
		return
	var sample: AudioStreamWAV = shatter_samples[randi() % shatter_samples.size()]
	var player: AudioStreamPlayer = _get_available_player()
	if player:
		player.stream = sample
		player.pitch_scale = (0.90 if is_triple else 1.0) * (0.96 + randf() * 0.08)
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
	
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(40)

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

func play_tile_pick() -> void:
	if not SettingsManager.sfx_enabled:
		return
	_play_guzheng_string(783.99, 0.12, 0.40)
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(8)

func play_combo_high() -> void:
	if not SettingsManager.sfx_enabled:
		return
	var notes: Array[float] = [587.33, 783.99, 987.77]
	for i in range(notes.size()):
		var f: float = notes[i]
		get_tree().create_timer(i * 0.07).timeout.connect(func(): _play_guzheng_string(f, 0.55, 0.55))

func play_tick_warn() -> void:
	if not SettingsManager.sfx_enabled:
		return
	_play_guzheng_string(329.63, 0.14, 0.42)
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(12)

func play_water_drop() -> void:
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
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(8)

func play_hitstop_impact() -> void:
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
	if SettingsManager.haptics_enabled:
		Input.vibrate_handheld(35)

# ================= GUZHENG PHYSICAL STRING SYNTHESIZER =================

func _play_guzheng_string(freq: float, duration: float, volume: float) -> void:
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
	
	var player := _get_available_player()
	if player:
		player.stream = wav
		player.volume_db = linear_to_db(clampf(volume, 0.01, 1.0))
		player.play()

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

