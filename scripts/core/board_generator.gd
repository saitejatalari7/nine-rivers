class_name BoardGenerator
extends RefCounted

const RiverTile = preload("res://scripts/core/river_tile.gd")
const LayoutData = preload("res://scripts/core/layout_data.gd")

static var last_deal_order: Array = []

const LAYOUT_NAMES: Dictionary = {
	"quick": "Courtyard",
	"gate": "Gate House",
	"steps": "River Steps",
	"garden": "Garden Walk",
	"lotus": "Lotus Pagoda",
	"bridges": "Twin Bridges",
	"keep": "Stone Keep",
	"waterfall": "Jade Cascade",
	"dragon_gate": "Dragon Gate",
	"citadel": "Citadel",
	"turtle": "Nine Rivers"
}

const LADDER: Array[String] = [
	"quick", "gate", "steps", "garden", "lotus", "bridges", "keep", "waterfall", "dragon_gate", "citadel", "turtle"
]

## Data-driven where a shape exists in LayoutData, falling back to the original
## hardcoded builders otherwise. layout_parity_test asserts the two agree.
static func get_layout_positions(name: String) -> Array[Dictionary]:
	if LayoutData.LAYOUTS.has(name):
		return positions_from_ascii(LayoutData.LAYOUTS[name])
	return legacy_layout_positions(name)

static func positions_from_ascii(entry: Dictionary) -> Array[Dictionary]:
	var pos: Array[Dictionary] = []
	var layers: Array = entry.get("layers", [])
	for z in range(layers.size()):
		var rows: PackedStringArray = String(layers[z]).split("
")
		var r := 0
		for line in rows:
			if line.strip_edges().is_empty():
				continue
			for c in range(line.length()):
				if line[c] != "." and line[c] != " ":
					pos.append({"x": c * 2, "y": r * 2, "z": z})
			r += 1
	for e in entry.get("extras", []):
		pos.append({"x": int(e[0]), "y": int(e[1]), "z": int(e[2])})
	return pos

static func legacy_layout_positions(name: String) -> Array[Dictionary]:
	var pos: Array[Dictionary] = []
	match name:
		"quick":
			_grid(pos, 0, 5, 0, 3, 0)
			_grid(pos, 1, 4, 1, 2, 1)
			_grid(pos, 2, 3, 1, 2, 2)
		"gate":
			_grid(pos, 0, 7, 0, 3, 0)
			_grid(pos, 2, 5, 1, 2, 1)
		"steps":
			_grid(pos, 0, 9, 0, 3, 0)
			_grid(pos, 1, 8, 1, 2, 1)
			_grid(pos, 3, 6, 1, 1, 2)
		"garden":
			_grid(pos, 0, 7, 0, 5, 0)
			_grid(pos, 1, 6, 1, 3, 1)
			_grid(pos, 3, 4, 1, 3, 2)
		"lotus":
			_grid(pos, 0, 7, 0, 5, 0)
			_grid(pos, 2, 5, 1, 4, 1)
			_grid(pos, 3, 4, 2, 3, 2)
		"bridges":
			_grid(pos, 0, 2, 0, 5, 0)
			_grid(pos, 6, 8, 0, 5, 0)
			_grid(pos, 3, 5, 2, 3, 0)
			_grid(pos, 0, 2, 1, 4, 1)
			_grid(pos, 6, 8, 1, 4, 1)
			_grid(pos, 3, 5, 2, 3, 1)
			_grid(pos, 1, 1, 2, 3, 2)
			_grid(pos, 7, 7, 2, 3, 2)
		"keep":
			_grid(pos, 0, 11, 0, 4, 0)
			_grid(pos, 2, 9, 1, 3, 1)
			_grid(pos, 4, 7, 2, 2, 2)
		"waterfall":
			_grid(pos, 0, 9, 0, 4, 0)
			_grid(pos, 2, 7, 0, 3, 1)
			_grid(pos, 3, 6, 0, 2, 2)
			_grid(pos, 4, 5, 0, 1, 3)
		"dragon_gate":
			_grid(pos, 0, 9, 0, 5, 0)
			_grid(pos, 1, 8, 1, 4, 1)
			_grid(pos, 3, 6, 2, 3, 2)
		"citadel":
			_grid(pos, 0, 11, 0, 5, 0)
			_grid(pos, 2, 9, 1, 4, 1)
			_grid(pos, 4, 7, 2, 3, 2)
			_grid(pos, 5, 6, 2, 2, 3)
		"turtle", _:
			# Classic Nine Rivers / Turtle formation (144 tiles)
			var rows := [
				[1, 12], [3, 10], [2, 11], [1, 12],
				[1, 12], [2, 11], [3, 10], [1, 12]
			]
			for y in range(rows.size()):
				var r: Array = rows[y]
				for x in range(r[0], r[1] + 1):
					_add_pos(pos, x, y, 0)
			# Flanks
			_add_pos(pos, 0, 3.5, 0)
			_add_pos(pos, 13, 3.5, 0)
			_add_pos(pos, 14, 3.5, 0)
			# Layer 1
			for y in range(1, 7):
				for x in range(3, 9):
					_add_pos(pos, x, y, 1)
			# Layer 2
			for y in range(2, 6):
				for x in range(4, 8):
					_add_pos(pos, x, y, 2)
			# Layer 3
			for y in range(3, 5):
				for x in range(5, 7):
					_add_pos(pos, x, y, 3)
			# Cap
			_add_pos(pos, 5.5, 3.5, 4)
	return pos

static func _grid(p: Array[Dictionary], x0: int, x1: int, y0: int, y1: int, z: int) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			p.append({"x": x * 2, "y": y * 2, "z": z})

static func _add_pos(p: Array[Dictionary], x: float, y: float, z: int) -> void:
	p.append({"x": int(round(x * 2.0)), "y": int(round(y * 2.0)), "z": z})

# ================= TOPOLOGY HELPERS =================
static func is_covered(p: Dictionary, live_slots: Array) -> bool:
	for u in live_slots:
		if u == p:
			continue
		if u["z"] > p["z"] and abs(u["x"] - p["x"]) < 2 and abs(u["y"] - p["y"]) < 2:
			return true
	return false

static func is_side_blocked(p: Dictionary, live_slots: Array, dir: int) -> bool:
	var target_x: int = p["x"] + 2 * dir
	for u in live_slots:
		if u == p:
			continue
		if u["z"] == p["z"] and u["x"] == target_x and abs(u["y"] - p["y"]) < 2:
			return true
	return false

static func is_slot_free(p: Dictionary, live_slots: Array) -> bool:
	if is_covered(p, live_slots):
		return false
	return not (is_side_blocked(p, live_slots, -1) and is_side_blocked(p, live_slots, 1))

# ================= SOLVER & DEALER =================
static func get_type_pool() -> Array[Dictionary]:
	var t: Array[Dictionary] = []
	for s in ["dot", "bam", "char"]:
		for r in range(1, 10):
			t.append({"suit": s, "rank": r})
	for r in range(1, 5):
		t.append({"suit": "wind", "rank": r})
	for r in range(1, 4):
		t.append({"suit": "dragon", "rank": r})
	return t

static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func plan_sets(total: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var triples: int = 2 if total <= 40 else (4 if total <= 72 else 6)
	var wild_pairs: int = 1 if total <= 40 else (2 if total <= 88 else 3)
	
	var pool := get_type_pool()
	_shuffle_array(pool, rng)
	var pool_idx: int = 0
	var sets: Array[Dictionary] = []
	
	for k in range(triples):
		sets.append({"n": 3, "type": pool[pool_idx % pool.size()]})
		pool_idx += 1
		
	for k in range(wild_pairs):
		sets.append({"n": 2, "type": {"suit": "flower" if k % 2 == 0 else "season"}})
		
	var remaining: int = int((total - 3 * triples - 2 * wild_pairs) / 2)
	for k in range(remaining):
		sets.append({"n": 2, "type": pool[pool_idx % pool.size()]})
		pool_idx += 1
		
	_shuffle_array(sets, rng)
	return sets

static func peel_dynamic(positions: Array[Dictionary], num_triples: int, num_pairs: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	for attempt in range(150):
		var live: Array[Dictionary] = positions.duplicate(true)
		var order: Array[Dictionary] = []
		var rem_triples: int = num_triples
		var rem_pairs: int = num_pairs
		var valid: bool = true
		
		while not live.is_empty():
			var free_slots: Array[Dictionary] = []
			for p in live:
				if is_slot_free(p, live):
					free_slots.append(p)
			
			if free_slots.size() < 2:
				valid = false
				break
			
			# Decide set size dynamically based on available free slots and remaining sets
			var n: int = 2
			if rem_triples > 0 and free_slots.size() >= 3:
				if rem_pairs > 0:
					# Bias toward triples to open up the board, but keep it organic
					n = 3 if (rng.randf() < 0.65 or free_slots.size() >= 5) else 2
				else:
					n = 3
			elif rem_pairs > 0:
				n = 2
			elif rem_triples > 0 and free_slots.size() < 3:
				# Cannot place a triple with fewer than 3 free slots
				valid = false
				break
			else:
				valid = false
				break
				
			if n == 3:
				rem_triples -= 1
			else:
				rem_pairs -= 1
				
			# Prefer peeling higher layers first to maintain stability
			free_slots.sort_custom(func(a, b): return a["z"] > b["z"])
			var pool_size: int = maxi(n, int(ceil(free_slots.size() * 0.7)))
			var candidate_pool := free_slots.slice(0, pool_size)
			
			var picked: Array[Dictionary] = []
			_shuffle_array(candidate_pool, rng)
			for i in range(n):
				picked.append(candidate_pool[i])
				
			order.append({"size": n, "slots": picked})
			for p in picked:
				live.erase(p)
				
		if valid and live.is_empty() and rem_triples == 0 and rem_pairs == 0:
			return order
			
	return []

static func deal_board(layout_name: String, rng: RandomNumberGenerator = null) -> Array[RiverTile]:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
		
	var positions := get_layout_positions(layout_name)
	var total: int = positions.size()
	var triples_count: int = 2 if total <= 40 else (4 if total <= 72 else 6)
	var wild_pairs_count: int = 1 if total <= 40 else (2 if total <= 88 else 3)
	var normal_pairs_count: int = int((total - 3 * triples_count - 2 * wild_pairs_count) / 2)
	var total_pairs_count: int = wild_pairs_count + normal_pairs_count
	
	# Prepare type pool
	var pool := get_type_pool()
	_shuffle_array(pool, rng)
	var pool_idx: int = 0
	
	var triple_sets: Array[Dictionary] = []
	for k in range(triples_count):
		triple_sets.append({"n": 3, "type": pool[pool_idx % pool.size()]})
		pool_idx += 1
		
	var pair_sets: Array[Dictionary] = []
	for k in range(wild_pairs_count):
		pair_sets.append({"n": 2, "type": {"suit": "flower" if k % 2 == 0 else "season"}})
	for k in range(normal_pairs_count):
		pair_sets.append({"n": 2, "type": pool[pool_idx % pool.size()]})
		pool_idx += 1
	_shuffle_array(pair_sets, rng)
	
	var order := peel_dynamic(positions, triples_count, total_pairs_count, rng)
	# Exposed for layout_validator: the peel order IS a valid clearing sequence,
	# so replaying it proves the dealt board can be finished.
	last_deal_order = order
	
	var tiles: Array[RiverTile] = []
	if not order.is_empty():
		for group_idx in range(order.size()):
			var group_dict: Dictionary = order[group_idx]
			var set_size: int = group_dict["size"]
			var pos_group: Array = group_dict["slots"]
			var set_info: Dictionary = triple_sets.pop_back() if set_size == 3 else pair_sets.pop_back()
			var ty: Dictionary = set_info["type"]
			var suit: String = ty["suit"]
			
			for p in pos_group:
				var rank: int = ty.get("rank", 1)
				if suit == "flower" or suit == "season":
					rank = rng.randi_range(1, 4)
				var tile := RiverTile.new(p["x"], p["y"], p["z"], suit, rank, group_idx, set_size)
				tiles.append(tile)
	else:
		# Fallback solver if an abnormal custom layout cannot be strictly peeled
		tiles = _deal_fallback(positions, triple_sets, pair_sets, rng)
		
	# Designate exactly one specific special tile set in each match as the Crystal Glass Tile
	_assign_special_glass_set(tiles, rng)
		
	return tiles

static func _assign_special_glass_set(tiles: Array[RiverTile], rng: RandomNumberGenerator) -> void:
	if tiles.is_empty():
		return
		
	# Collect unique set_ids and their primary tile
	var sets_map: Dictionary = {}
	for t in tiles:
		if not sets_map.has(t.set_id):
			sets_map[t.set_id] = []
		sets_map[t.set_id].append(t)
		
	if sets_map.is_empty():
		return
		
	# Check for Dragon, Flower, or Season set preference first for prestige
	var candidate_set_ids: Array = []
	for sid in sets_map.keys():
		var group: Array = sets_map[sid]
		if not group.is_empty():
			var s0: RiverTile = group[0]
			if s0.suit == "dragon" or s0.suit == "flower" or s0.suit == "season":
				candidate_set_ids.append(sid)
				
	var chosen_sid: int = -1
	if not candidate_set_ids.is_empty():
		chosen_sid = candidate_set_ids[rng.randi() % candidate_set_ids.size()]
	else:
		# Fallback: pick any random set from all available sets
		var all_sids: Array = sets_map.keys()
		chosen_sid = all_sids[rng.randi() % all_sids.size()]
		
	for t in sets_map.get(chosen_sid, []):
		t.is_glass = true

static func _deal_fallback(positions: Array[Dictionary], triple_sets: Array[Dictionary], pair_sets: Array[Dictionary], rng: RandomNumberGenerator) -> Array[RiverTile]:
	var remaining := positions.duplicate(true)
	remaining.sort_custom(func(a, b): return a["z"] > b["z"])
	var all_sets: Array[Dictionary] = []
	all_sets.append_array(triple_sets)
	all_sets.append_array(pair_sets)
	_shuffle_array(all_sets, rng)
	
	var tiles: Array[RiverTile] = []
	var cur_idx: int = 0
	for group_idx in range(all_sets.size()):
		var set_info: Dictionary = all_sets[group_idx]
		var n: int = set_info["n"]
		var ty: Dictionary = set_info["type"]
		var suit: String = ty["suit"]
		
		for i in range(n):
			if cur_idx < remaining.size():
				var p: Dictionary = remaining[cur_idx]
				cur_idx += 1
				var rank: int = ty.get("rank", 1)
				if suit == "flower" or suit == "season":
					rank = rng.randi_range(1, 4)
				var tile := RiverTile.new(p["x"], p["y"], p["z"], suit, rank, group_idx, n)
				tiles.append(tile)
	return tiles
