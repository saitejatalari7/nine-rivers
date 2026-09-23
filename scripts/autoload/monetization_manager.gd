extends Node

## Nine Rivers (九河) — Monetization & In-App Economy Service
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
	# Earned only: pearls buy it, money never does. It deliberately carries no
	# price_usd or price_inr, which is what marks it as unpurchasable.
	"theme_indigo": {
		"id": "theme_indigo",
		"name": "Deep Indigo Tile Set",
		"desc": "Polished indigo glaze with pale gold calligraphy. Earned at the board.",
		"price_str": "2,500 ◈ · earned only",
		"pearl_cost": 2500,
		"earn_only": true,
		"is_consumable": false
	},
	"bg_misty_spring": {
		"id": "bg_misty_spring",
		"theme_id": "misty_spring",
		"name": "Misty Mountain Spring",
		"name_zh": "清岚泉",
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
		"name_zh": "夕霞泽",
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
const INTERSTITIAL_MIN_INTERVAL: float = 240.0
const INTERSTITIAL_MIN_LEVELS: int = 3
const INTERSTITIAL_START_LEVEL: int = 4

var _last_interstitial_time: float = -240.0
var _stages_cleared_since_ad: int = 0
var _banner_visible: bool = false

var _billing: Object = null
var _admob: Object = null
var _pending_callbacks: Dictionary = {}
var _pending_ad_placement: String = ""
var _pending_ad_callback: Callable = Callable()

func _ready() -> void:
	_check_daily_ad_reset()
	_init_platform_billing()
	_init_platform_ads()

# ================= LOCALIZATION & PRICING =================
func is_india_locale() -> bool:
	var loc := OS.get_locale().to_upper()
	return loc.ends_with("_IN") or loc.begins_with("HI_") or loc == "IN"

func get_formatted_price(product_id: String) -> String:
	if not PRODUCTS.has(product_id):
		return ""
	var p: Dictionary = PRODUCTS[product_id]
	if is_india_locale():
		return str(p.get("price_inr", p.get("price_str", "$0.99")))
	return str(p.get("price_usd", p.get("price_str", "$0.99")))

# ================= BILLING INITIALIZATION & HANDLING =================
func _init_platform_billing() -> void:
	if Engine.has_singleton("GodotGooglePlayBilling"):
		_billing = Engine.get_singleton("GodotGooglePlayBilling")
	elif Engine.has_singleton("GodotPlayBilling"):
		_billing = Engine.get_singleton("GodotPlayBilling")
		
	if _billing != null:
		if _billing.has_signal("connected"):
			_billing.connected.connect(_on_billing_connected)
		if _billing.has_signal("purchases_updated"):
			_billing.purchases_updated.connect(_on_billing_purchases_updated)
		elif _billing.has_signal("on_purchase_updated"):
			_billing.on_purchase_updated.connect(_on_billing_purchases_updated)
		if _billing.has_signal("purchase_error"):
			_billing.purchase_error.connect(_on_billing_purchase_error)
		elif _billing.has_signal("connect_error"):
			_billing.connect_error.connect(func(code, msg): _on_billing_purchase_error(code, msg))
		# The full owned-items list arrives on its own signal, separate from the
		# per-purchase updates above. Without this the launch-time restore never
		# produced a result and entitlements came from the save file alone.
		if _billing.has_signal("query_purchases_response"):
			_billing.query_purchases_response.connect(_on_billing_query_purchases_response)
		if _billing.has_signal("sku_details_query_completed"):
			_billing.sku_details_query_completed.connect(_on_billing_sku_details_completed)
		if _billing.has_method("startConnection"):
			_billing.startConnection()
		elif _billing.has_method("start_connection"):
			_billing.start_connection()

func _on_billing_connected() -> void:
	if _billing and _billing.has_method("query_purchases"):
		_billing.query_purchases("inapp")
	elif _billing and _billing.has_method("queryPurchases"):
		_billing.queryPurchases("inapp", false)

func _on_billing_purchases_updated(purchases: Variant) -> void:
	var purchase_list: Array = []
	if purchases is Array:
		purchase_list = purchases
	elif purchases is Dictionary and purchases.has("purchases"):
		purchase_list = purchases.get("purchases", [])
		
	for p in purchase_list:
		var pid: String = ""
		if p is Dictionary:
			var pstate = int(p.get("purchase_state", 1))
			if pstate != 1:
				continue
			pid = str(p.get("sku", p.get("product_id", "")))
		if PRODUCTS.has(pid):
			var prod: Dictionary = PRODUCTS[pid]
			var token: String = str(p.get("purchase_token", ""))
			if bool(prod.get("is_consumable", false)):
				if _billing and _billing.has_method("consume_purchase"):
					_billing.consume_purchase(token)
				elif _billing and _billing.has_method("consumePurchase"):
					_billing.consumePurchase(token)
			else:
				if not bool(p.get("is_acknowledged", false)):
					if _billing and _billing.has_method("acknowledge_purchase"):
						_billing.acknowledge_purchase(token)
					elif _billing and _billing.has_method("acknowledgePurchase"):
						_billing.acknowledgePurchase(token)
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
func _on_billing_query_purchases_response(response: Variant) -> void:
	var code: int = 0
	var purchase_list: Array = []
	if response is Dictionary:
		code = int(response.get("response_code", response.get("code", 0)))
		purchase_list = response.get("purchases", [])
	elif response is Array:
		purchase_list = response

	# Only reconcile against a successful answer. A network failure must never be
	# read as "this player owns nothing".
	if code != 0:
		push_warning("Nine Rivers: purchase query failed (code %d). Keeping local entitlements." % code)
		return

	var owned: Array[String] = []
	for p in purchase_list:
		if not (p is Dictionary):
			continue
		if int(p.get("purchase_state", 1)) != 1:
			continue
		var pid: String = str(p.get("sku", p.get("product_id", "")))
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
		if int(p.get("purchase_state", 1)) != 1:
			continue
		var pid: String = str(p.get("sku", p.get("product_id", "")))
		if not PRODUCTS.has(pid):
			continue
		var prod: Dictionary = PRODUCTS[pid]
		if bool(prod.get("is_consumable", false)):
			continue # Consumables are settled in _on_billing_purchases_updated.
		if not bool(p.get("is_acknowledged", false)):
			var token: String = str(p.get("purchase_token", ""))
			if _billing and _billing.has_method("acknowledge_purchase"):
				_billing.acknowledge_purchase(token)
			elif _billing and _billing.has_method("acknowledgePurchase"):
				_billing.acknowledgePurchase(token)
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
func _mark_entitlement_source(product_id: String, source: String) -> void:
	var sources: Dictionary = SaveManager.economy.get("entitlement_source", {})
	if not (sources is Dictionary):
		sources = {}
	sources[product_id] = source
	SaveManager.economy["entitlement_source"] = sources

func _as_array(value: Variant, fallback: Array) -> Array:
	return value.duplicate() if value is Array else fallback.duplicate()

func _on_billing_purchase_error(code: int, msg: String) -> void:
	purchase_failed.emit("", "Billing Error (%d): %s" % [code, msg])

func _on_billing_sku_details_completed(_details: Array) -> void:
	pass

# ================= ADS INITIALIZATION =================
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
	_stages_cleared_since_ad += 1

func can_show_interstitial(current_level: int = 4) -> bool:
	if is_no_ads():
		return false
	if current_level < INTERSTITIAL_START_LEVEL:
		return false
	if _stages_cleared_since_ad < INTERSTITIAL_MIN_LEVELS:
		return false
	var now_sec: float = float(Time.get_ticks_msec()) / 1000.0
	if now_sec - _last_interstitial_time < INTERSTITIAL_MIN_INTERVAL:
		return false
	return true

func show_interstitial_if_ready(current_level: int = 4, context: String = "level_clear") -> bool:
	if can_show_interstitial(current_level):
		show_interstitial(context)
		return true
	return false

func show_interstitial(context: String = "general") -> void:
	_last_interstitial_time = float(Time.get_ticks_msec()) / 1000.0
	_stages_cleared_since_ad = 0
	
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
		_pending_callbacks[product_id] = on_success
		var res = null
		if _billing.has_method("purchase"):
			res = _billing.purchase(product_id)
		elif _billing.has_method("purchaseProduct"):
			res = _billing.purchaseProduct(product_id)
			
		if res is Dictionary and res.get("status", OK) != OK:
			purchase_failed.emit(product_id, "Purchase initialization error: " + str(res.get("response_code", "")))
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
func is_earn_only(product_id: String) -> bool:
	if not PRODUCTS.has(product_id):
		return false
	return bool(PRODUCTS[product_id].get("earn_only", false))


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
	if _billing != null:
		if _billing.has_method("query_purchases"):
			_billing.query_purchases("inapp")
		elif _billing.has_method("queryPurchases"):
			_billing.queryPurchases("inapp", false)
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
