extends Node

## River Jade and Spirit Pearls became one currency. Anyone already playing has
## a jade balance, and it has to arrive as pearls rather than vanish - a silent
## wipe of an earned purse is the worst outcome of this change.
##
## Rate is three jade to a pearl, which is what the shop already implied: a
## background cost 1,500 jade or 500 pearls.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame

	_case("a jade balance converts", 900, 100, 100 + 300)
	_case("an exact multiple converts cleanly", 1500, 0, 500)
	_case("a remainder rounds down rather than up", 1499, 0, 499)
	_case("no jade leaves the purse alone", 0, 250, 250)
	_case("a jade-only save still ends up with pearls", 600, 0, 200)

	# The migration must not fire twice. A second load of an already-migrated
	# profile would otherwise keep minting pearls from a balance of zero.
	SaveManager.prog["river_jade"] = 300
	SaveManager.economy["pearls"] = 0
	SaveManager._migrate_jade_to_pearls()
	var once: int = SaveManager.get_pearls()
	SaveManager._migrate_jade_to_pearls()
	SaveManager._migrate_jade_to_pearls()
	_check(SaveManager.get_pearls() == once, "converting is idempotent",
		"%d after one pass, %d after three" % [once, SaveManager.get_pearls()])
	_check(int(SaveManager.prog.get("river_jade", -1)) == 0,
		"the jade balance is zeroed so it cannot convert again",
		"river_jade=%s" % SaveManager.prog.get("river_jade"))

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _case(what: String, jade: int, pearls: int, expect: int) -> void:
	SaveManager.prog["river_jade"] = jade
	SaveManager.economy["pearls"] = pearls
	SaveManager._migrate_jade_to_pearls()
	_check(SaveManager.get_pearls() == expect, what,
		"%d jade + %d pearls -> %d (expected %d)" % [jade, pearls, SaveManager.get_pearls(), expect])


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
