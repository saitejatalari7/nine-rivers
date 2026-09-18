extends Node

## Nine Rivers — modal show/hide tween race
##
## show_modal() and hide_modal() each start a tween that only settles the
## modal's final state when it ENDS. If a second call arrives while the first
## tween is still running, the two write the same properties and the loser's
## ending is applied last. The invariant that must hold is simple: once
## everything has settled, the modal's state must match the LAST call made,
## whatever order the calls arrived in.
##
## Run: godot --headless --audio-driver Dummy --path . scenes/modal_race_test.tscn

const GAP_FRAMES: int = 1
## Longest transition is show_modal's 0.22s scale tween; 0.5s clears it twice over.
const SETTLE: float = 0.5

var fails: Array[String] = []

func _ready() -> void:
	# Each case: the calls in order, and whether the modal must end up shown.
	var cases: Array = [
		[["hide"], false],
		[["show"], true],
		[["hide", "show"], true],
		[["show", "hide"], false],
		[["hide", "show", "hide"], false],
		[["show", "hide", "show"], true],
		[["hide", "show", "hide", "show"], true],
		[["show", "hide", "show", "hide"], false],
	]
	for case in cases:
		await _run_case(case[0], bool(case[1]))
	print("")
	if fails.is_empty():
		print("MODAL TWEEN RACE TEST PASSED")
	else:
		for f in fails:
			print("  FAIL  " + f)
	print("Failures: %d" % fails.size())
	get_tree().quit(1 if not fails.is_empty() else 0)

func _run_case(calls: Array, want_shown: bool) -> void:
	var modal: ModalController = (load("res://scenes/ui/modal.tscn") as PackedScene).instantiate()
	add_child(modal)
	await get_tree().process_frame
	# A populated card: show_modal() lays the card out, and an empty one would
	# not exercise the same path the player takes out of the main menu.
	modal.show_main_menu()
	await get_tree().create_timer(SETTLE).timeout

	for c in calls:
		if c == "show":
			modal.show_main_menu()
		else:
			modal.hide_modal()
		for i in range(GAP_FRAMES):
			await get_tree().process_frame
	await get_tree().create_timer(SETTLE).timeout

	var label: String = " -> ".join(PackedStringArray(calls))
	var alpha: float = modal.card_panel.modulate.a
	var ok := true
	if modal.visible != want_shown:
		fails.append("%s: visible=%s, expected %s" % [label, modal.visible, want_shown])
		ok = false
	var want_alpha: float = 1.0 if want_shown else 0.0
	if absf(alpha - want_alpha) > 0.01:
		fails.append("%s: card alpha=%.2f, expected %.2f" % [label, alpha, want_alpha])
		ok = false
	print("%-34s visible=%-5s alpha=%.2f  %s" % [label, modal.visible, alpha, "ok" if ok else "FAIL"])
	modal.queue_free()
	await get_tree().process_frame
