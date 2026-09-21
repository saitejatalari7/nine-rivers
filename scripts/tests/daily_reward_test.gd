extends Node

## The Daily Tide blessing used to be added inside show_daily_clear(), so it was
## paid whenever that screen was DRAWN rather than when the daily was completed.
## Replaying the daily on the same day farmed 150 jade a time, and the layout
## audit paid itself on every run. record_daily_play() always refused to count
## the same day twice; the jade grant did not share that guard.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	await get_tree().create_timer(1.2).timeout
	var modal = main.get_node("Modal")

	# Drawing the clear screen must never move the purse, whatever it is told.
	var start: int = SaveManager.get_jade()
	for i in 5:
		modal.show_daily_clear(3100, 7, 4, 150)
		await get_tree().process_frame
	_check(SaveManager.get_jade() == start, "drawing the clear screen never grants jade",
		"%d -> %d over 5 views" % [start, SaveManager.get_jade()])

	# The grant is gated on record_daily_play(), which counts a day once.
	SaveManager.prog["last_daily_date"] = ""
	var first: bool = SaveManager.record_daily_play()
	var second: bool = SaveManager.record_daily_play()
	var third: bool = SaveManager.record_daily_play()
	_check(first, "the first daily of the day counts", "returned %s" % first)
	_check(not second and not third, "later dailies the same day do not",
		"returned %s, %s" % [second, third])

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-46s %s" % ["PASS" if ok else "FAIL", what, detail])
