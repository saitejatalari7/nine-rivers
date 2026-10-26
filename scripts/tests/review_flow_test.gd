extends Node

## When Play's rating card is asked for: after a three-star clear from stage
## 10, at most three times, a month apart - with Play faked out.

class FakePlay extends RefCounted:
	var reviews: int = 0
	func requestReview() -> void: reviews += 1

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame
	var rm = ReviewManager
	_check("off Android there is no plugin", rm._plugin == null, "")
	rm.after_clear(20, 3)
	_check("and a clear there asks nothing", int(SaveManager.prog.get("review_asked_count", 0)) == 0, "")

	var play := FakePlay.new()
	rm._plugin = play
	SaveManager.prog.erase("review_asked_count")
	SaveManager.prog.erase("review_asked_at")
	var now: int = int(Time.get_unix_time_from_system())
	_check("not before stage 10", not rm.should_ask(9, 3, now), "")
	_check("not for two stars", not rm.should_ask(20, 2, now), "")
	_check("a three-star clear from 10 asks", rm.should_ask(10, 3, now), "")

	rm.after_clear(12, 3)
	await get_tree().create_timer(rm.DELAY + 0.3).timeout
	_check("which opens Play's card", play.reviews == 1, str(play.reviews))
	rm.after_clear(13, 3)
	await get_tree().create_timer(rm.DELAY + 0.3).timeout
	_check("not again the same month", play.reviews == 1, str(play.reviews))
	_check("but a month later", rm.should_ask(30, 3, now + 31 * 86400), "")
	SaveManager.prog["review_asked_count"] = 3
	_check("and never a fourth time", not rm.should_ask(30, 3, now + 400 * 86400), "")
	var kept: Dictionary = SaveManager._sanitize_prog(SaveManager.prog)
	_check("the count survives a save", int(kept.get("review_asked_count", 0)) == 3, str(kept.get("review_asked_count")))

	SaveManager.prog.erase("review_asked_count")
	SaveManager.prog.erase("review_asked_at")
	rm._plugin = null
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(what: String, ok: bool, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
