extends Node

## Frame cost of selecting a tile on a full board.
##
## Selection redraws a tile every frame it moves, which it did not used to do,
## and the shadow's corner radius is written on every one of those draws. This
## measures the cost instead of arguing about it.

const FRAMES: int = 90

var main: Node2D
var board


func _ready() -> void:
	await get_tree().process_frame
	main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	SaveManager.prog["tutorial_completed"] = true
	await get_tree().create_timer(1.2).timeout
	main.get_node("Modal").hide_modal()
	board = main.get_node("Board")
	main._start_calm_mode(12)
	await get_tree().create_timer(1.0).timeout

	print("board: %d tiles" % board.get_active_tiles().size())
	print("counters after deal: body=%d face=%d" % [TileView.debug_body_draws, TileView.debug_face_draws])
	var probe_sets: Array = board.get_legal_sets()
	print("legal sets: %d" % probe_sets.size())
	if not probe_sets.is_empty():
		var pv = board.tile_views.get(probe_sets[0][0])
		print("probe view: %s" % ("found" if pv != null else "MISSING"))
		if pv != null:
			pv.set_selected(true)
			await get_tree().create_timer(0.4).timeout
			print("after one select: body=%d face=%d" % [TileView.debug_body_draws, TileView.debug_face_draws])
			pv.set_selected(false)
	var idle: float = await _sample("idle", Callable())
	var match_ms: float = await _sample("matching", func():
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			return
		for t in sets[0]:
			var v = board.tile_views.get(t)
			if v != null:
				board._on_tile_clicked(v)
	)
	var sel: float = await _sample("selecting", func():
		var sets: Array = board.get_legal_sets()
		if sets.is_empty():
			return
		var v = board.tile_views.get(sets[0][0])
		if v != null:
			v.set_selected(not v.is_selected)
	)
	print("")
	print("idle      %.2f ms/frame" % idle)
	print("selecting %.2f ms/frame  (%+.2f)" % [sel, sel - idle])
	print("matching  %.2f ms/frame  (%+.2f)" % [match_ms, match_ms - idle])
	get_tree().quit(0)


## Drives `each` once, then measures the frames while its animation plays out.
func _sample(label: String, each: Callable) -> float:
	var worst: float = 0.0
	var _body: int = 0
	var _face: int = 0
	var total: float = 0.0
	var n: int = 0
	for i in range(FRAMES):
		if each.is_valid() and i % 30 == 0:
			each.call()
		var b0: int = TileView.debug_body_draws
		var f0: int = TileView.debug_face_draws
		var t0: int = Time.get_ticks_usec()
		await RenderingServer.frame_post_draw
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		total += ms
		worst = maxf(worst, ms)
		_body += TileView.debug_body_draws - b0
		_face += TileView.debug_face_draws - f0
		n += 1
	print("  %-10s avg %.2f ms  worst %.2f ms  body draws %d  face draws %d" % [
		label, total / float(n), worst, _body, _face])
	return total / float(n)
