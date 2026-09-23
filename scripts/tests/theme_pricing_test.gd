extends Node

## Tile-set unlocking.
##
## Three sets are bought. Deep Indigo is not for sale at any price - it unlocks
## by reaching Calm stage 50 - so the test is that no currency or storefront
## path can reach it, and that the milestone grants it exactly once.
##
## Prices were spread because 1,500 flat meant every set was owned by level 75
## of 350 and pearls were dead for the remaining 275.

const PAID: Dictionary = {
	"theme_imperial_gold": 4000,
	"theme_obsidian_ink": 6000,
	"theme_cherry_blossom": 8000,
}
const MILESTONE_ID := "theme_indigo"
const MILESTONE_LEVEL := 50

var _fails: int = 0


func _ready() -> void:
	await get_tree().process_frame

	for id in PAID:
		_check(MonetizationManager.get_pearl_cost(id) == PAID[id],
			"%s costs %d pearls" % [id, PAID[id]],
			"got %d" % MonetizationManager.get_pearl_cost(id))
		_check(MonetizationManager.get_unlock_level(id) == 0,
			"%s is not a milestone set" % id, "")

	_check(MonetizationManager.get_unlock_level(MILESTONE_ID) == MILESTONE_LEVEL,
		"Deep Indigo unlocks at stage %d" % MILESTONE_LEVEL,
		"got %d" % MonetizationManager.get_unlock_level(MILESTONE_ID))
	_check(MonetizationManager.get_pearl_cost(MILESTONE_ID) == 0,
		"Deep Indigo has no pearl price", "cost=%d" % MonetizationManager.get_pearl_cost(MILESTONE_ID))
	var prod: Dictionary = MonetizationManager.PRODUCTS.get(MILESTONE_ID, {})
	_check(not prod.has("price_usd") and not prod.has("price_inr"),
		"Deep Indigo has no money price", "")

	# Pearls must not be able to reach it even if the caller tries directly.
	SaveManager.economy["unlocked_themes"] = ["classic_jade"]
	SaveManager.economy["pearls"] = 99999
	var bought: bool = MonetizationManager.buy_with_pearls(MILESTONE_ID)
	_check(not bought and not MonetizationManager.is_theme_unlocked(MILESTONE_ID),
		"pearls cannot buy a milestone set", "buy returned %s" % str(bought))

	# Below the milestone, nothing is granted.
	var early: Array[String] = MonetizationManager.grant_milestone_themes(MILESTONE_LEVEL - 1)
	_check(early.is_empty() and not MonetizationManager.is_theme_unlocked(MILESTONE_ID),
		"stage %d grants nothing" % (MILESTONE_LEVEL - 1), "granted=%s" % str(early))

	# At the milestone it is granted, once.
	var first: Array[String] = MonetizationManager.grant_milestone_themes(MILESTONE_LEVEL)
	_check(first.has(MILESTONE_ID), "stage %d grants Deep Indigo" % MILESTONE_LEVEL,
		"granted=%s" % str(first))
	var again: Array[String] = MonetizationManager.grant_milestone_themes(MILESTONE_LEVEL + 12)
	_check(again.is_empty(), "it is not granted a second time", "granted=%s" % str(again))

	# Granting must not switch the player's tiles for them.
	_check(MonetizationManager.get_active_theme() != MILESTONE_ID,
		"unlocking does not equip it",
		"active=%s" % MonetizationManager.get_active_theme())

	var per_level: int = SaveManager.PEARLS_PER_STAR * 3
	var total: int = 0
	for id in PAID:
		total += int(PAID[id])
	print("  pacing at %d pearls/level: all three paid sets by about stage %d" % [
		per_level, int(ceil(float(total) / float(per_level)))])

	print("")
	print("Failures: %d" % _fails)
	get_tree().quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String, detail: String) -> void:
	if not ok:
		_fails += 1
	print("  %s  %-44s %s" % ["PASS" if ok else "FAIL", what, detail])
