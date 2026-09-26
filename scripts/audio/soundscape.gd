extends Node

## Recorded nature under the music, different for each background.
##
## The old bed was one baked 8-second loop, and its water whoosh came back on
## the same beat forever. Here nothing loops: a bed plays a random slice of a
## clip and crossfades into a random slice of another clip from the same pool
## before it ends, so the seam never falls in the same place twice. Events
## (birdsong) are cut the same way, at a random length, pitch and gap.
##
## Everything plays on the ambient bus, which AudioManager holds at half volume.

const DIR := "res://assets/audio/ambience/"

const STREAMS: Array = ["stream_1", "stream_2", "stream_3", "stream_4"]
const RAIN: Array = ["rain_1", "rain_2"]

const SCAPES: Dictionary = {
	"emerald_pond": {"beds": STREAMS, "events": ["birdsong"]},
	"moonlit_river": {"beds": RAIN, "events": []},
	"autumn_stream": {"beds": STREAMS, "events": ["birdsong"]},
	"misty_spring": {"beds": RAIN, "events": ["birdsong"]},
	"sunset_haven": {"beds": ["forest"], "events": []},
}

const BED_DB: float = -8.0
## Share of a clip one slice plays before handing over.
const SLICE := Vector2(0.45, 0.7)
const FADE_RANGE := Vector2(3.0, 8.0)
const EVENT_DB: float = -14.0
const EVENT_GAP := Vector2(30.0, 75.0)
const EVENT_LEN := Vector2(5.0, 12.0)
const EVENT_FADE: float = 2.0

var bus: String = "Master"
var _scape: String = ""
var _beds: Array[AudioStreamPlayer] = []
var _active_bed: int = 0
var _bed_timer: float = 0.0
var _event: AudioStreamPlayer
var _event_timer: float = 0.0
var _cache: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _enabled: bool = true


func _ready() -> void:
	_rng.randomize()
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.bus = bus
		p.volume_db = -80.0
		add_child(p)
		_beds.append(p)
	_event = AudioStreamPlayer.new()
	_event.bus = bus
	_event.volume_db = -80.0
	add_child(_event)
	_event_timer = _rng.randf_range(EVENT_GAP.x * 0.5, EVENT_GAP.y * 0.5)


func set_scape(id: String) -> void:
	if id == _scape or not SCAPES.has(id):
		return
	_scape = id
	_next_bed()


func set_enabled(on: bool) -> void:
	_enabled = on
	if on:
		if not _scape.is_empty():
			_next_bed()
	else:
		for p in _beds:
			_fade(p, -80.0, 1.2, true)
		_fade(_event, -80.0, 1.2, true)


func current_scape() -> String:
	return _scape


func _process(delta: float) -> void:
	if not _enabled or _scape.is_empty():
		return
	_bed_timer -= delta
	if _bed_timer <= 0.0:
		_next_bed()
	var events: Array = SCAPES[_scape]["events"]
	if events.is_empty():
		return
	_event_timer -= delta
	if _event_timer <= 0.0:
		_event_timer = _rng.randf_range(EVENT_GAP.x, EVENT_GAP.y)
		_play_event(String(events[_rng.randi() % events.size()]))


## Crossfades to a random slice of a clip from the pool. The next handover is
## timed to land before this slice reaches the end of its clip.
func _next_bed() -> void:
	_bed_timer = 5.0
	if not _enabled:
		return
	var pool: Array = SCAPES[_scape]["beds"]
	var stream := _load(String(pool[_rng.randi() % pool.size()]))
	if stream == null:
		return
	var clip: float = stream.get_length()
	var fade: float = clampf(clip * 0.3, FADE_RANGE.x, FADE_RANGE.y)
	var hold: float = clip * _rng.randf_range(SLICE.x, SLICE.y)
	var offset: float = _rng.randf_range(0.0, maxf(0.0, clip - hold - fade))
	_bed_timer = maxf(2.0, hold)
	var old: AudioStreamPlayer = _beds[_active_bed]
	_active_bed = 1 - _active_bed
	var fresh: AudioStreamPlayer = _beds[_active_bed]
	fresh.stream = stream
	fresh.volume_db = -80.0
	fresh.pitch_scale = _rng.randf_range(0.97, 1.03)
	fresh.play(offset)
	_fade(fresh, BED_DB + _rng.randf_range(-2.0, 1.0), fade, false)
	if old.playing:
		_fade(old, -80.0, fade, true)


## A slice of the recording, not the whole of it: where it starts, how long it
## runs and how high it sits all change every time.
func _play_event(key: String) -> void:
	var stream := _load(key)
	if stream == null or _event.playing:
		return
	var length: float = _rng.randf_range(EVENT_LEN.x, EVENT_LEN.y)
	_event.stream = stream
	_event.pitch_scale = _rng.randf_range(0.93, 1.07)
	_event.volume_db = -80.0
	_event.play(_rng.randf_range(0.0, maxf(0.0, stream.get_length() - 1.0)))
	var peak: float = EVENT_DB + _rng.randf_range(-4.0, 0.0)
	var old: Tween = _fades.get(_event)
	if old != null and old.is_valid():
		old.kill()
	var t := create_tween()
	_fades[_event] = t
	t.tween_property(_event, "volume_db", peak, EVENT_FADE).set_trans(Tween.TRANS_SINE)
	t.tween_interval(maxf(0.0, length - EVENT_FADE * 2.0))
	t.tween_property(_event, "volume_db", -80.0, EVENT_FADE).set_trans(Tween.TRANS_SINE)
	t.tween_callback(_event.stop)


## One fade per player: switching backgrounds quickly would otherwise leave two
## tweens fighting over the same volume.
var _fades: Dictionary = {}

func _fade(p: AudioStreamPlayer, to_db: float, secs: float, stop_after: bool) -> void:
	var old: Tween = _fades.get(p)
	if old != null and old.is_valid():
		old.kill()
	var t := create_tween()
	_fades[p] = t
	t.tween_property(p, "volume_db", to_db, secs).set_trans(Tween.TRANS_SINE)
	if stop_after:
		t.tween_callback(p.stop)


func _load(key: String) -> AudioStream:
	if _cache.has(key):
		return _cache[key]
	var path: String = DIR + key + (".mp3" if key == "forest" else ".ogg")
	var s: AudioStream = load(path) as AudioStream
	if s == null:
		return null
	if "loop" in s:
		s.set("loop", true)
	_cache[key] = s
	return s
