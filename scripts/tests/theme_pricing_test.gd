extends Node

## Tile-set pricing and the earn-only rule.
##
## The three paid sets are spread so pearls stay worth something across a
## 350-level campaign: at 20 pearls a star, 1,500 flat meant all three were
## owned by level 75 and the currency was dead for the remaining 275.
##
## Deep Indigo is the one set money cannot buy. That only holds if nothing
## anywhere offers it for a price, so this checks the data rather than the UI.

const EXPECTED: Dictionary = {
	"theme_indigo": 2500,
	"theme_imperial_gold": 4000,
	"theme_obsidian_ink": 6000,
	"theme_cherry_blossom": 8000,
}

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame

	for id in EXPECTED:
		var cost: int = MonetizationManager.get_pearl_cost(id)
		_check(cost == EXPECTED[id], "%s costs %d pearls" % [id, EXPECTED[id]],
			"got %d" % cost)

	_check(MonetizationManager.is_earn_only("theme_indigo"),
		"Deep Indigo is earn-only", "earn_only=%s" % MonetizationManager.is_earn_only("theme_indigo"))
	for id in ["theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]:
		_check(not MonetizationManager.is_earn_only(id), "%s is purchasable" % id, "")

	# An earn-only product must carry no money price at all, or a storefront or
	# a formatter could still surface one.
	var prod: Dictionary = MonetizationManager.PRODUCTS.get("theme_indigo", {})
	_check(not prod.has("price_usd") and not prod.has("price_inr"),
		"Deep Indigo carries no money price",
		"usd=%s inr=%s" % [str(prod.has("price_usd")), str(prod.has("price_inr"))])

	# Pacing: at 20 pearls per star, three-starring every level.
	var per_level: int = SaveManager.PEARLS_PER_STAR * 3
	var lines: Array[String] = []
	for id in ["theme_indigo", "theme_imperial_gold", "theme_obsidian_ink", "theme_cherry_blossom"]:
		lines.append("%s ~L%d" % [id.replace("theme_", ""), int(ceil(float(EXPECTED[id]) / float(per_level)))])
	print("  pacing at %d pearls/level: %s" % [per_level, ", ".join(lines)])

	var total: int = 0
	for id in EXPECTED:
		total += int(EXPECTED[id])
	var all_by: int = int(ceil(float(total) / float(per_level)))
	_check(all_by > 250, "owning every set takes most of the campaign",
		"all four by about level %d of 350" % all_by)

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
