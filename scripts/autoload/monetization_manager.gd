extends Node

## Nine Rivers — Monetization & In-App Economy Service
## Manages Spirit Pearls, IAPs (No-Ads, Pearl Treasury, Cosmetic Themes),
## Rewarded Offerings, Zen Interstitial Frequency Capping, and Tile/Banner Ads.
## Tailored for Google Play Store with Indian Market (INR / UPI) & Global USD support.

signal pearls_updated(new_balance: int)
signal purchase_succeeded(product_id: String)
signal purchase_failed(product_id: String, reason: String)
signal rewarded_ad_rewarded(placement: String, reward_type: String, amount: int)
signal rewarded_ad_unavailable(placement: String)
signal interstitial_ad_shown(context: String)
signal banner_visibility_changed(is_visible: bool)
signal theme_unlocked(theme_id: String)
signal theme_equipped(theme_id: String)
signal background_theme_unlocked(theme_id: String)
signal background_theme_equipped(theme_id: String)

const PRODUCTS: Dictionary = {
	"no_ads": {
		"id": "no_ads",
		"name": "Serenity Blessing (Remove Ads)",
		"desc": "Permanently removes all interstitial and banner offerings + 500 Spirit Pearls + 1 extra daily prop.",
		"price_usd": "$2.99",
		"price_inr": "₹199",
		"price_str": "₹199 / $2.99",
		"pearls_grant": 500,
		"is_consumable": false
	},
	"pearls_small": {
		"id": "pearls_small",
		"name": "Pouch of Spirit Pearls",
		"desc": "500 glistening Spirit Pearls from the river bed.",
		"price_usd": "$0.99",
		"price_inr": "₹49",
		"price_str": "₹49 / $0.99",
		"pearls_grant": 500,
		"is_consumable": true
	},
	"pearls_medium": {
		"id": "pearls_medium",
		"name": "Chest of Spirit Pearls",
		"desc": "2,500 Spirit Pearls (+25% bonus value).",
		"price_usd": "$3.99",
		"price_inr": "₹149",
		"price_str": "₹149 / $3.99",
		"pearls_grant": 2500,
		"is_consumable": true
	},
	"pearls_large": {
		"id": "pearls_large",
		"name": "Dragon Hoard of Pearls",
		"desc": "7,500 Spirit Pearls (+50% bonus value).",
		"price_usd": "$9.99",
		"price_inr": "₹399",
		"price_str": "₹399 / $9.99",
		"pearls_grant": 7500,
		"is_consumable": true
	},
	"theme_imperial_gold": {
		"id": "theme_imperial_gold",
		"name": "Imperial Gold Tile Set",
		"desc": "24k gold leaf filigree faces on imperial lacquer.",
		"price_usd": "$1.99",
		"price_inr": "₹99",
		"price_str": "₹99 / $1.99 (or 4,000 ◈)",
		"pearl_cost": 4000,
		"is_consumable": false
	},
	"theme_obsidian_ink": {
		"id": "theme_obsidian_ink",
		"name": "Obsidian Ink Tile Set",
		"desc": "Deep basalt stone tiles with luminous white-jade calligraphy.",
		"price_usd": "$1.99",
		"price_inr": "₹99",
		"price_str": "₹99 / $1.99 (or 6,000 ◈)",
		"pearl_cost": 6000,
		"is_consumable": false
	},
	"theme_cherry_blossom": {
		"id": "theme_cherry_blossom",
		"name": "Cherry Blossom Porcelain Set",
		"desc": "Delicate pale rose porcelain with vermilion engravings.",
		"price_usd": "$1.99",
		"price_inr": "₹99",
		"price_str": "₹99 / $1.99 (or 8,000 ◈)",
		"pearl_cost": 8000,
		"is_consumable": false
	},
	# Neither bought nor paid for: reaching Calm level 50 unlocks it. No
	# pearl_cost and no money price, so no storefront or currency path can
	# offer it by accident.
	"theme_indigo": {
		"id": "theme_indigo",
		"name": "Deep Indigo Tile Set",
		"desc": "Polished indigo glaze with pale gold calligraphy. Reach Stage 50.",
		"price_str": "Stage 50",
		"unlock_level": 50,
		"earn_only": true,
		"is_consumable": false
	},
	"bg_misty_spring": {
		"id": "bg_misty_spring",
		"theme_id": "misty_spring",
		"name": "Misty Mountain Spring",
		"desc": "Teal mist water, delicate sakura petals, and rare Asagi koi.",
		"price_usd": "$0.99",
		"price_inr": "₹49",
		"price_str": "₹49 / $0.99 (or 500 ◈)",
		"pearl_cost": 500,
		"is_consumable": false
	},
	"bg_sunset_haven": {
		"id": "bg_sunset_haven",
		"theme_id": "sunset_haven",
		"name": "Sunset Lotus Haven",
		"desc": "Twilight purple water, glowing crimson caustics, and royal Tancho koi.",
		"price_usd": "$0.99",
		"price_inr": "₹49",
		"price_str": "₹49 / $0.99 (or 500 ◈)",
		"pearl_cost": 500,
		"is_consumable": false
	}
}

## Backgrounds every player owns. These are never withdrawn by a Play reconcile.
const FREE_BACKGROUND_THEMES: Array[String] = ["emerald_pond", "moonlit_river", "autumn_stream"]

const MAX_DAILY_REWARDED_ADS: int = 4

# The Zen Ad Model Frequency Capping Rules:
# 1. Zero ads during onboarding (Levels 1 to 3)
# 2. Minimum 4 minutes (240s) real-time between full-screen ads
# 3. Minimum 3 completed stages between full-screen ads
# 4. Never interrupt active board gameplay
## When an interstitial may appear. All three have to be satisfied, and all
## three survive a restart - the previous version kept them in memory and timed
## from Time.get_ticks_msec(), so closing and reopening the app cleared the cap
## and a player who restarted between levels saw an ad every single time.
const INTERSTITIAL_MIN_INTERVAL: float = 240.0
const INTERSTITIAL_MIN_LEVELS: int = 3
## Nothing before this stage: three levels are played untroubled first, which is
## also long enough for onboarding to finish.
const INTERSTITIAL_START_LEVEL: int = 4
## Quiet after any purchase. Someone who has just paid should not be sold to
## again ten seconds later.
const POST_PURCHASE_QUIET: float = 900.0

var _banner_visible: bool = false

const BillingClientScript = preload("res://addons/GodotGooglePlayBilling/BillingClient.gd")
var _billing: Node = null
## Play's own localised price per product, once product details arrive.
var _play_prices: Dictionary = {}
var _admob: Object = null
var _pending_callbacks: Dictionary = {}
var _pending_ad_placement: String = ""
var _pending_ad_callback: Callable = Callable()

## Test builds only. The "testbuild" feature is set by a dedicated export
## preset, and a release export does not carry it. Belt and braces: it also
## refuses to run unless this is a debug build, so a preset edited by hand
## cannot turn it on in something shipped.
##
## It exists because there is no other way to see the paid sets on real
## hardware before billing works.
const TEST_BUILD_FEATURE := "testbuild"
const TEST_BUILD_PEARLS: int = 50000

func _grant_everything_for_testing() -> void:
	if not OS.has_feature(TEST_BUILD_FEATURE) or not OS.is_debug_build():
		return
	var themes: Array = ["classic_jade"]
	var backgrounds: Array = ["auto"]
	for pid in PRODUCTS.keys():
		var id: String = String(pid)
		if id.begins_with("theme_"):
			themes.append(id)
		elif id.begins_with("bg_"):
			backgrounds.append(id.trim_prefix("bg_"))
	for bg in FREE_BACKGROUND_THEMES:
		if not backgrounds.has(bg):
			backgrounds.append(bg)

	SaveManager.economy["unlocked_themes"] = themes
	SaveManager.economy["unlocked_background_themes"] = backgrounds
	SaveManager.economy["no_ads_purchased"] = true
	SaveManager.economy["pearls"] = TEST_BUILD_PEARLS
	SaveManager.request_save()
	print("Nine Rivers: TEST BUILD - %d tile sets, %d ponds, no ads, %d pearls." % [
		themes.size(), backgrounds.size(), TEST_BUILD_PEARLS])


func _ready() -> void:
	_check_daily_ad_reset()
	_grant_everything_for_testing()
	_init_platform_billing()
	_init_platform_ads()

# ================= LOCALIZATION & PRICING =================
func is_india_locale() -> bool:
	var loc := OS.get_locale().to_upper()
	return loc.ends_with("_IN") or loc.begins_with("HI_") or loc == "IN"

func get_formatted_price(product_id: String) -> String:
	if _play_prices.has(product_id):
		return String(_play_prices[product_id])
	if not PRODUCTS.has(product_id):
		return ""
	var p: Dictionary = PRODUCTS[product_id]
	if is_india_locale():
		return str(p.get("price_inr", p.get("price_str", "$0.99")))
	return str(p.get("price_usd", p.get("price_str", "$0.99")))

# ================= BILLING INITIALIZATION & HANDLING =================
## Plugin v3 is driven through its BillingClient wrapper, which calls the
## required initPlugin() and passes purchase() its full argument list. The raw
## singleton was being called directly with v2-era names and arities, so on a
## device every purchase failed before reaching Play.
func _init_platform_billing() -> void:
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	_billing = BillingClientScript.new()
	add_child(_billing)
	_billing.connected.connect(_on_billing_connected)
	_billing.disconnected.connect(_on_billing_disconnected)
	_billing.connect_error.connect(_on_billing_purchase_error)
	_billing.on_purchase_updated.connect(_on_billing_purchases_updated)
	_billing.query_purchases_response.connect(_on_billing_query_purchases_response)
	_billing.query_product_details_response.connect(_on_billing_product_details)
	_billing.start_connection()


func _iap_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for pid in PRODUCTS.keys():
		if not is_earn_only(String(pid)):
			ids.append(String(pid))
	return ids


## Play will not start a purchase for a product whose details were not fetched
## first, so the catalogue is queried every time the connection comes up.
func _on_billing_connected() -> void:
	_billing.query_product_details(_iap_ids(), BillingClientScript.ProductType.INAPP)
	_billing.query_purchases(BillingClientScript.ProductType.INAPP)


func _on_billing_disconnected() -> void:
	get_tree().create_timer(5.0).timeout.connect(func():
		if _billing != null and not _billing.is_ready():
			_billing.start_connection())


func _on_billing_product_details(response: Dictionary) -> void:
	if int(response.get("response_code", -1)) != 0:
		push_warning("Nine Rivers: product details failed: %s" % str(response.get("debug_message", "")))
		return
	for d in response.get("product_details", []):
		if not (d is Dictionary):
			continue
		var offers: Array = d.get("one_time_purchase_offer_details_list", [])
		if offers.is_empty() or not (offers[0] is Dictionary):
			continue
		var price: String = String(offers[0].get("formatted_price", ""))
		if not price.is_empty():
			_play_prices[String(d.get("product_id", ""))] = price


## v3 reports a purchase's products as an array, product_ids.
static func _purchase_pid(p: Dictionary) -> String:
	var ids: Array = p.get("product_ids", [])
	if not ids.is_empty():
		return String(ids[0])
	return String(p.get("product_id", ""))

func _on_billing_purchases_updated(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", 0))
	if code != 0:
		var reason: String = "Purchase cancelled"
		if code != 1:
			reason = "Billing error (%d): %s" % [code, str(response.get("debug_message", ""))]
		for pid in _pending_callbacks.keys():
			purchase_failed.emit(String(pid), reason)
		_pending_callbacks.clear()
		return

	for p in response.get("purchases", []):
		if not (p is Dictionary):
			continue
		# PENDING (2) is money not yet taken - e.g. a cash payment. It is
		# granted when Play reports it PURCHASED, never before.
		if int(p.get("purchase_state", 0)) != 1:
			continue
		var pid: String = _purchase_pid(p)
		if PRODUCTS.has(pid):
			var prod: Dictionary = PRODUCTS[pid]
			var token: String = str(p.get("purchase_token", ""))
			if bool(prod.get("is_consumable", false)):
				_billing.consume_purchase(token)
			elif not bool(p.get("is_acknowledged", false)):
				_billing.acknowledge_purchase(token)
			_fulfill_purchase(pid, prod)
			if _pending_callbacks.has(pid):
				var cb: Callable = _pending_callbacks[pid]
				_pending_callbacks.erase(pid)
				if cb.is_valid():
					cb.call()
			purchase_succeeded.emit(pid)

## Response to our explicit query_purchases() call: the complete list of items
## this Google account owns. Unlike purchases_updated (which reports only what
## just changed), this is authoritative, so it is the one place we reconcile.
func _on_billing_query_purchases_response(response: Dictionary) -> void:
	var code: int = int(response.get("response_code", -1))
	var purchase_list: Array = response.get("purchases", [])

	# Only reconcile against a successful answer. A network failure must never be
	# read as "this player owns nothing".
	if code != 0:
		push_warning("Nine Rivers: purchase query failed (code %d). Keeping local entitlements." % code)
		return

	var owned: Array[String] = []
	for p in purchase_list:
		if not (p is Dictionary):
			continue
		if int(p.get("purchase_state", 0)) != 1:
			continue
		var pid: String = _purchase_pid(p)
		if not pid.is_empty():
			owned.append(pid)

	_grant_from_play(purchase_list)
	_revoke_unconfirmed(owned)
	SaveManager.save_game()

## Re-grants everything Play confirms, so a reinstall or a new phone restores
## purchases without the player doing anything.
func _grant_from_play(purchase_list: Array) -> void:
	for p in purchase_list:
		if not (p is Dictionary):
			continue
		if int(p.get("purchase_state", 0)) != 1:
			continue
		var pid: String = _purchase_pid(p)
		if not PRODUCTS.has(pid):
			continue
		var prod: Dictionary = PRODUCTS[pid]
		if bool(prod.get("is_consumable", false)):
			# A pearl pack paid for but never consumed (app killed mid-purchase)
			# is owed: grant it once and consume it now.
			if _billing != null:
				_billing.consume_purchase(str(p.get("purchase_token", "")))
			_fulfill_purchase(pid, prod)
			continue
		if not bool(p.get("is_acknowledged", false)) and _billing != null:
			_billing.acknowledge_purchase(str(p.get("purchase_token", "")))
		_fulfill_purchase(pid, prod, "iap", true)

## Withdraws any non-consumable that the save file claims was paid for with money
## but Google Play does not list. Items bought with in-game pearls are
## left alone, since Play has no record of those and never will.
func _revoke_unconfirmed(owned: Array[String]) -> void:
	var sources: Dictionary = SaveManager.economy.get("entitlement_source", {})
	if not (sources is Dictionary):
		sources = {}

	for pid in PRODUCTS.keys():
		var prod: Dictionary = PRODUCTS[pid]
		if bool(prod.get("is_consumable", false)):
			continue
		if pid in owned:
			continue

		var source: String = str(sources.get(pid, "unknown"))
		var buyable_with_currency: bool = int(prod.get("pearl_cost", 0)) > 0
		# "unknown" means the entitlement predates source tracking or was injected
		# into the file directly. Trust it only where an in-game purchase is even
		# possible; products sold for money alone must come from Play.
		if source == "pearls":
			continue
		if source == "unknown" and buyable_with_currency:
			continue

		if _revoke_product(pid, prod):
			sources.erase(pid)
			push_warning("Nine Rivers: '%s' is not owned on this Google account. Entitlement withdrawn." % pid)

	SaveManager.economy["entitlement_source"] = sources

func _revoke_product(product_id: String, prod: Dictionary) -> bool:
	if product_id == "no_ads":
		if not bool(SaveManager.economy.get("no_ads_purchased", false)):
			return false
		SaveManager.economy["no_ads_purchased"] = false
		return true

	if product_id.begins_with("theme_"):
		var unlocked: Array = _as_array(SaveManager.economy.get("unlocked_themes", []), ["classic_jade"])
		if not (product_id in unlocked):
			return false
		unlocked.erase(product_id)
		SaveManager.economy["unlocked_themes"] = unlocked
		if get_active_theme() == product_id:
			equip_theme("classic_jade")
		return true

	if product_id.begins_with("bg_"):
		var bg_id: String = str(prod.get("theme_id", ""))
		if bg_id.is_empty() or bg_id in FREE_BACKGROUND_THEMES:
			return false
		var bgs: Array = _as_array(SaveManager.economy.get("unlocked_background_themes", []), FREE_BACKGROUND_THEMES)
		if not (bg_id in bgs):
			return false
		bgs.erase(bg_id)
		SaveManager.economy["unlocked_background_themes"] = bgs
		if get_active_background_theme() == bg_id:
			equip_background_theme("auto")
		return true

	return false

## Records how a non-consumable was paid for, so _revoke_unconfirmed() knows
## whether Google Play is entitled to take it away again.
## Any purchase, by money or by pearls, starts a quiet window. Selling to
## someone who has just bought something is the fastest way to make the next
## ad feel like a punishment.
func _note_purchase() -> void:
	SaveManager.economy["last_purchase_unix"] = _unix_now()
	SaveManager.request_save()


func _mark_entitlement_source(product_id: String, source: String) -> void:
	_note_purchase()
	var sources: Dictionary = SaveManager.economy.get("entitlement_source", {})
	if not (sources is Dictionary):
		sources = {}
	sources[product_id] = source
	SaveManager.economy["entitlement_source"] = sources

func _as_array(value: Variant, fallback: Array) -> Array:
	return value.duplicate() if value is Array else fallback.duplicate()

func _on_billing_purchase_error(code: int, msg: String) -> void:
	push_warning("Nine Rivers: billing connection error (%d): %s" % [code, msg])

# ================= ADS INITIALIZATION =================
## The AdMob account's own identifiers. Kept here, named, rather than pasted
## into whatever plugin call site needs them: they are account facts, and the
## plugin underneath them may yet be swapped.
const ADMOB_APP_ID := "ca-app-pub-2056760294521107~6852510420"
const ADMOB_REWARDED_ID := "ca-app-pub-2056760294521107/4608567029"
const ADMOB_INTERSTITIAL_ID := "ca-app-pub-2056760294521107/9151370704"

## Google's published test units. Serving live ads to yourself is a policy
## violation that gets AdMob accounts suspended, so a debug build never touches
## the real units - the switch is the build type, not a flag anyone can forget.
const TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const TEST_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"

static func rewarded_unit_id() -> String:
	return TEST_REWARDED_ID if OS.is_debug_build() else ADMOB_REWARDED_ID

static func interstitial_unit_id() -> String:
	return TEST_INTERSTITIAL_ID if OS.is_debug_build() else ADMOB_INTERSTITIAL_ID


func _init_platform_ads() -> void:
	if Engine.has_singleton("GodotAdMob"):
		_admob = Engine.get_singleton("GodotAdMob")
		if _admob.has_signal("rewarded"):
			_admob.rewarded.connect(_on_admob_reward_granted)
	elif Engine.has_singleton("PoingGodotAdMob"):
		_admob = Engine.get_singleton("PoingGodotAdMob")
		if _admob.has_signal("on_rewarded_ad_user_earned_reward"):
			_admob.on_rewarded_ad_user_earned_reward.connect(func(_type, _amt): _on_admob_reward_granted("", 0))

## Only an ad WE asked for pays out. This used to grant on any call: with no
## pending placement it fell to the catch-all arm of _grant_reward and paid 50
## pearls for nothing, and firing twice for one ad paid twice. Harmless only
## while no ad plugin is installed, which is a state issue 04 plans to end.
func _on_admob_reward_granted(_type: String = "", _amount: int = 0) -> void:
	if _pending_ad_placement.is_empty():
		return
	var placement: String = _pending_ad_placement
	var cb: Callable = _pending_ad_callback
	_pending_ad_placement = ""
	_pending_ad_callback = Callable()
	_grant_reward(placement, cb)

func _check_daily_ad_reset() -> void:
	var dt := Time.get_date_dict_from_system(true)
	var today_str := "%04d-%02d-%02d" % [dt["year"], dt["month"], dt["day"]]
	# Only a LATER date refills the charges. Any mismatch used to do it, so
	# winding the device clock back and forward refilled the four ad charges
	# indefinitely.
	var last_seen: String = str(SaveManager.economy.get("last_rewarded_date", ""))
	if last_seen == today_str:
		return
	if last_seen.is_empty() or today_str > last_seen:
		SaveManager.economy["last_rewarded_date"] = today_str
		SaveManager.economy["rewarded_ads_today"] = 0
		SaveManager.request_save()

func is_no_ads() -> bool:
	return bool(SaveManager.economy.get("no_ads_purchased", false))

func get_pearls() -> int:
	return SaveManager.get_pearls()

func add_pearls(amount: int) -> void:
	SaveManager.add_pearls(amount)
	pearls_updated.emit(get_pearls())

func spend_pearls(amount: int) -> bool:
	var ok: bool = SaveManager.spend_pearls(amount)
	if ok:
		pearls_updated.emit(get_pearls())
	return ok

func is_theme_unlocked(theme_id: String) -> bool:
	if theme_id == "classic_jade":
		return true
	var unlocked: Array = SaveManager.economy.get("unlocked_themes", ["classic_jade"])
	return theme_id in unlocked

func unlock_theme(theme_id: String) -> bool:
	var unlocked: Array = SaveManager.economy.get("unlocked_themes", ["classic_jade"])
	if not (theme_id in unlocked):
		unlocked.append(theme_id)
		SaveManager.economy["unlocked_themes"] = unlocked
		SaveManager.request_save()
		theme_unlocked.emit(theme_id)
		return true
	return false

func equip_theme(theme_id: String) -> void:
	if is_theme_unlocked(theme_id):
		SaveManager.economy["active_tile_theme"] = theme_id
		SaveManager.request_save()
		theme_equipped.emit(theme_id)

func get_active_theme() -> String:
	return String(SaveManager.economy.get("active_tile_theme", "classic_jade"))

func is_background_theme_unlocked(theme_id: String) -> bool:
	if theme_id in ["auto", "emerald_pond", "moonlit_river", "autumn_stream"]:
		return true
	var unlocked: Array = SaveManager.economy.get("unlocked_background_themes", ["emerald_pond", "moonlit_river", "autumn_stream"])
	return theme_id in unlocked

func unlock_background_theme(theme_id: String) -> bool:
	var unlocked: Array = SaveManager.economy.get("unlocked_background_themes", ["emerald_pond", "moonlit_river", "autumn_stream"])
	if not (theme_id in unlocked):
		unlocked.append(theme_id)
		SaveManager.economy["unlocked_background_themes"] = unlocked
		SaveManager.request_save()
		background_theme_unlocked.emit(theme_id)
		return true
	return false

func equip_background_theme(theme_id: String) -> void:
	if is_background_theme_unlocked(theme_id):
		SaveManager.economy["active_background_theme"] = theme_id
		SaveManager.request_save()
		background_theme_equipped.emit(theme_id)

func get_active_background_theme() -> String:
	return String(SaveManager.economy.get("active_background_theme", "auto"))

func buy_background_with_pearls(theme_id: String) -> bool:
	var prod_key := "bg_" + theme_id
	var cost: int = 500
	if PRODUCTS.has(prod_key):
		cost = int(PRODUCTS[prod_key].get("pearl_cost", 500))
	if spend_pearls(cost):
		unlock_background_theme(theme_id)
		equip_background_theme(theme_id)
		_mark_entitlement_source(prod_key, "pearls")
		# Currency spent and goods granted: commit both together.
		SaveManager.save_game()
		AudioManager.play_win()
		return true
	return false

func can_watch_rewarded_ad() -> bool:
	_check_daily_ad_reset()
	var count: int = int(SaveManager.economy.get("rewarded_ads_today", 0))
	return count < MAX_DAILY_REWARDED_ADS

func get_remaining_rewarded_ads() -> int:
	_check_daily_ad_reset()
	var count: int = int(SaveManager.economy.get("rewarded_ads_today", 0))
	return maxi(0, MAX_DAILY_REWARDED_ADS - count)

# ================= ZEN INTERSTITIAL FREQUENCY CAPPER =================
func record_level_cleared() -> void:
	SaveManager.economy["stages_since_ad"] = int(SaveManager.economy.get("stages_since_ad", 0)) + 1

func _unix_now() -> float:
	return float(Time.get_unix_time_from_system())


## Why an ad is or is not allowed, as a string. Returned rather than logged so
## a test can assert the reason instead of only the verdict - "no ad appeared"
## is true for six different reasons and they are not interchangeable.
func interstitial_block_reason(current_level: int = 4) -> String:
	if is_no_ads():
		return "no_ads_purchased"
	if current_level < INTERSTITIAL_START_LEVEL:
		return "too_early"
	if int(SaveManager.economy.get("stages_since_ad", 0)) < INTERSTITIAL_MIN_LEVELS:
		return "too_few_stages"
	var now: float = _unix_now()
	var last_ad: float = float(SaveManager.economy.get("last_interstitial_unix", 0.0))
	var last_buy_t: float = float(SaveManager.economy.get("last_purchase_unix", 0.0))
	# Checked before the intervals: a clock wound backwards leaves a timestamp in
	# the future, and "now - then" is then negative, which reads as recent and
	# would otherwise be reported as the wrong reason.
	if last_ad > now or last_buy_t > now:
		return "clock_moved"
	if last_ad > 0.0 and now - last_ad < INTERSTITIAL_MIN_INTERVAL:
		return "too_soon"
	var last_buy: float = float(SaveManager.economy.get("last_purchase_unix", 0.0))
	if last_buy > 0.0 and now - last_buy < POST_PURCHASE_QUIET:
		return "just_purchased"
	return ""


func can_show_interstitial(current_level: int = 4) -> bool:
	return interstitial_block_reason(current_level).is_empty()

func show_interstitial_if_ready(current_level: int = 4, context: String = "level_clear") -> bool:
	if can_show_interstitial(current_level):
		show_interstitial(context)
		return true
	return false

func show_interstitial(context: String = "general") -> void:
	SaveManager.economy["last_interstitial_unix"] = _unix_now()
	SaveManager.economy["stages_since_ad"] = 0
	SaveManager.request_save()

	if _admob != null and _admob.has_method("show_interstitial"):
		_admob.show_interstitial()

	interstitial_ad_shown.emit(context)

# ================= TILE / BANNER ADS =================
func show_banner_ad() -> void:
	if is_no_ads():
		hide_banner_ad()
		return

	_banner_visible = true
	if _admob != null and _admob.has_method("show_banner"):
		_admob.show_banner()
	banner_visibility_changed.emit(true)

func hide_banner_ad() -> void:
	_banner_visible = false
	if _admob != null and _admob.has_method("hide_banner"):
		_admob.hide_banner()
	banner_visibility_changed.emit(false)

func is_banner_ad_visible() -> bool:
	return _banner_visible and not is_no_ads()

# ================= PURCHASE PROCESSING =================
func buy_product(product_id: String, on_success: Callable = Callable()) -> void:
	if not PRODUCTS.has(product_id):
		purchase_failed.emit(product_id, "Unknown product")
		return

	var prod: Dictionary = PRODUCTS[product_id]

	if _billing != null:
		if not _billing.is_ready():
			_billing.start_connection()
			purchase_failed.emit(product_id, "Connecting to Google Play. Please try again in a moment.")
			return
		_pending_callbacks[product_id] = on_success
		var res: Dictionary = _billing.purchase(product_id)
		if int(res.get("response_code", 0)) != 0:
			_pending_callbacks.erase(product_id)
			purchase_failed.emit(product_id, "Could not start the purchase (%s)." % str(res.get("debug_message", res.get("response_code", ""))))
		return

	# Mobile Release Guard: never allow free fulfillment if billing service failed to connect
	if OS.has_feature("mobile") and not OS.is_debug_build():
		purchase_failed.emit(product_id, "Google Play Billing service unavailable. Please check your network connection.")
		return

	# Desktop/Editor/Debug: Simulate purchase fulfillment for testing
	_fulfill_purchase(product_id, prod)
	if on_success.is_valid():
		on_success.call()
	purchase_succeeded.emit(product_id)

## What a set costs in pearls, and whether money can buy it at all. The detail
## screen used to print a hard-coded 1,500 for every set, which was wrong for
## all four once the prices were spread.
func get_pearl_cost(product_id: String) -> int:
	if not PRODUCTS.has(product_id):
		return 0
	return int(PRODUCTS[product_id].get("pearl_cost", 0))


## Earn-only products carry no Play Store price and must never show a purchase
## row. Deep Indigo is the one set that cannot be bought, which is the whole
## point of it.
## The Calm stage that unlocks a theme, or 0 if it is not a milestone reward.
func get_unlock_level(product_id: String) -> int:
	if not PRODUCTS.has(product_id):
		return 0
	return int(PRODUCTS[product_id].get("unlock_level", 0))


## Grants any milestone theme the player has now earned. Returns the ids newly
## granted, so the caller can offer them rather than silently switching.
func grant_milestone_themes(cleared_level: int) -> Array[String]:
	var granted: Array[String] = []
	for pid in PRODUCTS.keys():
		var lvl: int = get_unlock_level(pid)
		if lvl > 0 and cleared_level >= lvl and not is_theme_unlocked(pid):
			unlock_theme(pid)
			granted.append(pid)
	if not granted.is_empty():
		SaveManager.save_game()
	return granted


func is_earn_only(product_id: String) -> bool:
	if not PRODUCTS.has(product_id):
		return false
	return bool(PRODUCTS[product_id].get("earn_only", false))


## The cheapest tile set the player does not own and could actually buy, or ""
## when there is nothing left to show them. Milestone sets are skipped: they are
## earned, and dangling one in front of a player who cannot buy it is a tease
## with no answer.
func cheapest_locked_theme() -> String:
	var best: String = ""
	var best_cost: int = 0
	for pid in PRODUCTS.keys():
		var id: String = String(pid)
		if not id.begins_with("theme_"):
			continue
		if is_earn_only(id) or is_theme_unlocked(id):
			continue
		var cost: int = get_pearl_cost(id)
		if cost <= 0:
			continue
		if best.is_empty() or cost < best_cost:
			best = id
			best_cost = cost
	return best


func buy_with_pearls(product_id: String, on_success: Callable = Callable()) -> bool:
	if not PRODUCTS.has(product_id):
		return false
	var prod: Dictionary = PRODUCTS[product_id]
	var cost: int = int(prod.get("pearl_cost", 0))
	if cost <= 0:
		return false

	if spend_pearls(cost):
		unlock_theme(product_id)
		equip_theme(product_id)
		_mark_entitlement_source(product_id, "pearls")
		# Currency spent and goods granted: commit both together.
		SaveManager.save_game()
		if on_success.is_valid():
			on_success.call()
		return true
	return false

## Grants a product. `source` records who vouched for it: "iap" means Google Play
## confirmed the purchase, and such grants are re-checked against Play on every
## launch. `is_restore` suppresses the celebration when we are merely re-applying
## something the player already owned on another device.
func _fulfill_purchase(product_id: String, prod: Dictionary, source: String = "iap", is_restore: bool = false) -> void:
	var granted: bool = false

	if product_id == "no_ads":
		if not bool(SaveManager.economy.get("no_ads_purchased", false)):
			granted = true
		SaveManager.economy["no_ads_purchased"] = true
		hide_banner_ad()
		# Pearls ride along with the purchase itself, never with a restore, or a
		# player could farm them by reinstalling.
		if not is_restore:
			add_pearls(int(prod.get("pearls_grant", 500)))
	elif prod.has("pearls_grant"):
		# Consumable pearl packs. Google forgets these once consumed, so there is
		# nothing to restore and nothing to mark.
		if not is_restore:
			add_pearls(int(prod.get("pearls_grant", 0)))
			AudioManager.play_win()
			SaveManager.request_save()
		return
	elif product_id.begins_with("theme_"):
		granted = unlock_theme(product_id)
		equip_theme(product_id)
	elif product_id.begins_with("bg_"):
		# Previously unhandled: a paid background purchase granted nothing at all.
		var bg_id: String = str(prod.get("theme_id", ""))
		if not bg_id.is_empty():
			granted = unlock_background_theme(bg_id)
			equip_background_theme(bg_id)

	if not bool(prod.get("is_consumable", false)):
		_mark_entitlement_source(product_id, source)
	if granted and not is_restore:
		AudioManager.play_win()
	SaveManager.request_save()

func restore_purchases() -> void:
	AudioManager.play_click()
	if _billing != null and _billing.is_ready():
		_billing.query_purchases(BillingClientScript.ProductType.INAPP)
	SaveManager.save_game()

# ================= REWARDED AD OFFERINGS =================
func simulate_rewarded_ad(placement: String = "daily_pearls") -> void:
	show_rewarded_ad(placement, Callable())

## An ad the player never watched is not a reward they earned. buy_product()
## has always refused to fulfil on a mobile release build with no billing - the
## same reasoning was never applied here, so with no ad plugin installed every
## offer paid out immediately: four a day at 60 pearls, for a currency that is
## otherwise sold for money.
##
## The simulated grant survives in the editor and in debug builds, which is
## where it is useful.
## Test-only: forces the mobile-release branch so the guard that matters can be
## exercised from a desktop run. Never set outside scripts/tests.
static var debug_force_release_mobile: bool = false


func _is_release_mobile() -> bool:
	return debug_force_release_mobile or (OS.has_feature("mobile") and not OS.is_debug_build())


func is_rewarded_ad_available() -> bool:
	# _init_platform_ads accepts either singleton, so both API names count.
	# Checking only the Godot 3.x name would refuse every offer while a working
	# Poing plugin was installed.
	if _admob == null:
		return false
	return _admob.has_method("show_rewarded_video") or _admob.has_method("show")


## The one question the UI and show_rewarded_ad must both ask, so an offer is
## shown exactly when taking it would do something. Gating the screen on
## is_rewarded_ad_available() alone hid the offers in the editor and in debug
## builds too, which made the simulated grant this file deliberately keeps
## unreachable from any UI.
func can_offer_rewarded_ad() -> bool:
	if not can_watch_rewarded_ad():
		return false
	return is_rewarded_ad_available() or not _is_release_mobile()


func show_rewarded_ad(placement: String, on_reward: Callable = Callable()) -> void:
	if not can_watch_rewarded_ad():
		return

	if not is_rewarded_ad_available():
		if _is_release_mobile():
			rewarded_ad_unavailable.emit(placement)
			return
		# Editor and debug builds keep the simulated grant so the flow can be
		# exercised without an ad network.
		_consume_rewarded_charge()
		_grant_reward(placement, on_reward)
		return

	_consume_rewarded_charge()
	_pending_ad_placement = placement
	_pending_ad_callback = on_reward
	_admob.show_rewarded_video()


## Only called once an ad is actually going to be shown, or once a debug grant
## is actually made. It used to run before the plugin check, so a refused offer
## still burned one of the four daily charges.
func _consume_rewarded_charge() -> void:
	_check_daily_ad_reset()
	var cur: int = int(SaveManager.economy.get("rewarded_ads_today", 0))
	SaveManager.economy["rewarded_ads_today"] = cur + 1
	SaveManager.request_save()

func _grant_reward(placement: String, on_reward: Callable = Callable()) -> void:
	match placement:
		"props_refill":
			GameManager.hints += 1
			GameManager.shuffles += 1
			GameManager.props_updated.emit(GameManager.undos, GameManager.hints, GameManager.shuffles)
			rewarded_ad_rewarded.emit(placement, "props", 1)
			if on_reward.is_valid():
				on_reward.call("props", 1)
		"daily_pearls":
			add_pearls(60)
			rewarded_ad_rewarded.emit(placement, "pearls", 60)
			if on_reward.is_valid():
				on_reward.call("pearls", 60)
		"double_clear":
			add_pearls(100)
			rewarded_ad_rewarded.emit(placement, "pearls", 100)
			if on_reward.is_valid():
				on_reward.call("pearls", 100)
		_:
			# An unrecognised placement is a bug, not a 50-pearl payout.
			push_warning("rewarded ad: unknown placement, granting nothing")
