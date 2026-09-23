extends Node

## A new player starts with nothing and earns everything.
##
## The old 250-pearl starting balance was a leftover from when pearls were a
## premium-only currency. After the merge it bought nothing at all - the
## cheapest item is a 500-pearl background - so it read as a balance that was
## permanently just short of something.

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame

	# A brand-new profile, as the defaults declare it.
	_check(int(SaveManager.DEFAULT_ECONOMY_PEARLS) == 0,
		"a new profile starts on zero pearls",
		"default=%d" % SaveManager.DEFAULT_ECONOMY_PEARLS)

	# Nothing in the shop is reachable on day one.
	SaveManager.economy["pearls"] = 0
	var cheapest: int = 1 << 30
	var cheapest_id := ""
	for pid in MonetizationManager.PRODUCTS.keys():
		var c: int = MonetizationManager.get_pearl_cost(pid)
		if c > 0 and c < cheapest:
			cheapest = c
			cheapest_id = pid
	_check(cheapest > 0, "something is buyable with pearls at all",
		"cheapest is %s at %d" % [cheapest_id, cheapest])
	_check(not MonetizationManager.buy_with_pearls(cheapest_id),
		"a new player cannot buy the cheapest item",
		"%s costs %d, purse 0" % [cheapest_id, cheapest])

	# And the first goal is a sane distance away.
	var per_level: int = SaveManager.PEARLS_PER_STAR * 3
	var levels: int = int(ceil(float(cheapest) / float(per_level)))
	_check(levels >= 5 and levels <= 20,
		"the first purchase is a reasonable first goal",
		"%s reachable around stage %d at %d/level" % [cheapest_id, levels, per_level])

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-48s %s" % ["PASS" if ok else "FAIL", what, detail])
