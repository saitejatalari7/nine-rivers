extends Node

## The ASCII layouts must deal exactly the boards the hardcoded builders did.

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

func _ready() -> void:
	var fails := 0
	for name in BoardGenerator.LADDER:
		if not LayoutData.LAYOUTS.has(name):
			print("  FAIL  %s has no ASCII layout" % name)
			fails += 1
			continue
		var from_ascii := _key_set(BoardGenerator.positions_from_ascii(LayoutData.LAYOUTS[name]))
		var from_code := _key_set(BoardGenerator.legacy_layout_positions(name))
		var only_ascii := _diff(from_ascii, from_code)
		var only_code := _diff(from_code, from_ascii)
		if only_ascii.is_empty() and only_code.is_empty():
			print("  PASS  %-12s %3d tiles identical" % [name, from_ascii.size()])
		else:
			print("  FAIL  %-12s +%d ascii-only, +%d code-only  %s %s" % [
				name, only_ascii.size(), only_code.size(),
				only_ascii.slice(0, 4), only_code.slice(0, 4)])
			fails += 1

	print("Failures: %d" % fails)
	get_tree().quit(1 if fails > 0 else 0)

func _key_set(pos: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for p in pos:
		out.append("%d,%d,%d" % [int(p["x"]), int(p["y"]), int(p["z"])])
	out.sort()
	return out

func _diff(a: Array[String], b: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for k in a:
		if not b.has(k):
			out.append(k)
	return out
