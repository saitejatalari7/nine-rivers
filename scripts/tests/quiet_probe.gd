extends Node

func _ready() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	var pond: Node = main.get_node("FeltBackground")
	var modal: Node = main.get_node("Modal")
	var fails := 0

	modal.show_main_menu()
	await get_tree().process_frame
	if pond._quiet:
		print("  FAIL  main menu should stay at full rate"); fails += 1
	else:
		print("  PASS  main menu (The Rack) runs at full rate")

	modal.show_settings_menu()
	await get_tree().process_frame
	if pond._quiet:
		print("  PASS  settings throttles the pond")
	else:
		print("  FAIL  settings did not throttle the pond"); fails += 1

	var koi_quiet := true
	for k in pond.fish_container.get_children():
		if not k._quiet:
			koi_quiet = false
	if koi_quiet:
		print("  PASS  koi inherited the throttle")
	else:
		print("  FAIL  koi still running free"); fails += 1

	modal.show_main_menu()
	await get_tree().process_frame
	if pond._quiet:
		print("  FAIL  returning to main did not restore full rate"); fails += 1
	else:
		print("  PASS  returning to main restores full rate")

	modal.hide_modal()
	await get_tree().create_timer(0.25).timeout
	if pond._quiet:
		print("  FAIL  board play should not be throttled"); fails += 1
	else:
		print("  PASS  hidden modal (board play) is not throttled")

	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
