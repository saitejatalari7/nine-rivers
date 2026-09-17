class_name SanctuaryManager
extends RefCounted

const KOI_SHOP: Array[Dictionary] = [
	{"id": "kohaku", "name": "Kohaku", "cost": 0, "desc": "Your first koi"},
	{"id": "sanke", "name": "Taisho Sanke", "cost": 200, "desc": "+5% River Jade"},
	{"id": "showa", "name": "Showa Sanshoku", "cost": 400, "desc": "Longer Flow window"},
	{"id": "ogon", "name": "Platinum Ogon", "cost": 750, "desc": "+10% score in Calm"},
	{"id": "dragon_koi", "name": "Golden Dragon Koi", "cost": 1500, "desc": "Overdrive at Flow ×6"}
]

const DECORATIONS: Array[Dictionary] = [
	{"id": "bamboo_fountain", "name": "Bamboo Fountain", "cost": 0, "desc": "Rhythmic, peaceful wooden clacks."},
	{"id": "stone_lantern", "name": "Stone Lantern", "cost": 150, "desc": "Casts warm, soft light on the riverbank."},
	{"id": "pink_lotus", "name": "Lotus Blossom", "cost": 300, "desc": "Floating flower with soft ambient particles."},
	{"id": "stepping_stones", "name": "Stepping Stones", "cost": 500, "desc": "Ancient mossy stones crossing the stream."}
]

static func is_koi_unlocked(id: String) -> bool:
	var unlocked: Array = SaveManager.sanctuary.get("koi_unlocked", ["kohaku"])
	return unlocked.has(id)

static func unlock_koi(id: String) -> bool:
	if is_koi_unlocked(id):
		return false
	var item: Dictionary = {}
	for k in KOI_SHOP:
		if k["id"] == id:
			item = k
			break
	if item.is_empty():
		return false
	var cost: int = item["cost"]
	if SaveManager.get_jade() < cost:
		return false
	SaveManager.add_jade(-cost)
	var list: Array = SaveManager.sanctuary.get("koi_unlocked", ["kohaku"])
	if not list.has(id):
		list.append(id)
	SaveManager.sanctuary["koi_unlocked"] = list
	SaveManager.save_game()
	return true

static func is_decoration_unlocked(id: String) -> bool:
	var unlocked: Array = SaveManager.sanctuary.get("decorations", ["bamboo_fountain"])
	return unlocked.has(id)

static func unlock_decoration(id: String) -> bool:
	if is_decoration_unlocked(id):
		return false
	var item: Dictionary = {}
	for d in DECORATIONS:
		if d["id"] == id:
			item = d
			break
	if item.is_empty():
		return false
	var cost: int = item["cost"]
	if SaveManager.get_jade() < cost:
		return false
	SaveManager.add_jade(-cost)
	var list: Array = SaveManager.sanctuary.get("decorations", ["bamboo_fountain"])
	if not list.has(id):
		list.append(id)
	SaveManager.sanctuary["decorations"] = list
	SaveManager.save_game()
	return true
