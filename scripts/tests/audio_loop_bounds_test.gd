extends Node

## A looping WAV mixes up to and including loop_end, so loop_end must be a
## real sample. One past the end crashed phones in the audio thread.

var _fails: int = 0


func _ready() -> void:
	var t0: int = Time.get_ticks_msec()
	while not AudioManager.is_ambient_ready and Time.get_ticks_msec() - t0 < 15000:
		await get_tree().process_frame
	await get_tree().process_frame
	var checked: int = 0
	for p in _players(AudioManager):
		var s = p.stream
		if s is AudioStreamWAV and s.loop_mode != AudioStreamWAV.LOOP_DISABLED:
			var frames: int = s.data.size() / (2 if s.format == AudioStreamWAV.FORMAT_16_BITS else 1) / (2 if s.stereo else 1)
			checked += 1
			var ok: bool = s.loop_end <= frames - 1 and s.loop_begin >= 0 and s.loop_begin < s.loop_end
			print("  %s  %-28s loop %d..%d of %d frames" % ["PASS" if ok else "FAIL", p.name, s.loop_begin, s.loop_end, frames])
			if not ok:
				_fails += 1
	if checked == 0:
		print("  FAIL  no looping WAV found to check")
		_fails += 1
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _players(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is AudioStreamPlayer or c is AudioStreamPlayer2D:
			out.append(c)
		out.append_array(_players(c))
	return out
