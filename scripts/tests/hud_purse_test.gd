extends Node

## The HUD's pearl readout was written once when the HUD was built and never
## updated, so pearls earned mid-board did not appear until the game restarted.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(main)
	await get_tree().process_frame
	main.get_node("SplashScreen").visible = false
	await get_tree().create_timer(1.2).timeout

	var hud = main.get_node("HUD")
	var btn = hud.get_node_or_null("TopBar/BtnPearls")
	_check(btn != null, "the HUD has a pearl readout", "found=%s" % (btn != null))
	if btn == null:
		_finish()
		return

	SaveManager.economy["pearls"] = 100
	SaveManager.add_pearls(0)
	await get_tree().process_frame
	var before: String = btn.text

	SaveManager.add_pearls(37)
	await get_tree().process_frame
	_check(btn.text == "◈ 137", "earning pearls updates the readout",
		"%s -> %s" % [before, btn.text])

	SaveManager.spend_pearls(37)
	await get_tree().process_frame
	_check(btn.text == "◈ 100", "spending pearls updates the readout too",
		"-> %s" % btn.text)

	_finish()


func _finish() -> void:
	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
