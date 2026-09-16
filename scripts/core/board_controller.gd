class_name BoardController
extends Node2D

signal move_completed(remaining_tiles: int, legal_moves: int)
signal tile_matched(world_pos: Vector2)
signal board_cleared()
signal no_moves_left()
signal toast_requested(message: String)

const RiverTile = preload("res://scripts/core/river_tile.gd")
const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const TileView = preload("res://scripts/ui/tile_view.gd")
const TileViewScene = preload("res://scenes/tile.tscn")
const ClearSparksScene = preload("res://scenes/effects/clear_sparks.tscn")
const TileShatterDustScene = preload("res://scenes/effects/tile_shatter_dust.tscn")
const FloatingChip = preload("res://scripts/ui/floating_chip.gd")
const FloatingChipScene = preload("res://scenes/effects/floating_chip.tscn")
const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")

const TW: float = 64.0
const TH: float = 84.0
const LAYER_OFF_X: float = 8.0
const LAYER_OFF_Y: float = 10.0

var live_tiles: Array[RiverTile] = []
var tile_views: Dictionary = {} # RiverTile -> TileView

var selected_tiles: Array[RiverTile] = []
var history: Array[Dictionary] = [] # For Undo

var board_bounds := Rect2()
var current_max_z: int = 0
var stage_match_count: int = 0
var tide_caller_used_in_flow: bool = false

var _cached_legal_sets: Array[Array] = []
var _legal_sets_dirty: bool = true

func invalidate_legal_sets() -> void:
	_legal_sets_dirty = true

func _ready() -> void:
	GameManager.flow_updated.connect(_on_flow_updated)
	if is_instance_valid(MonetizationManager) and MonetizationManager.has_signal("theme_equipped"):
		MonetizationManager.theme_equipped.connect(_on_theme_equipped)

func _on_theme_equipped(_theme_id: String) -> void:
	for t in tile_views.keys():
		var view = tile_views.get(t)
		if is_instance_valid(view) and view.has_method("update_theme_style"):
			view.update_theme_style()

func _on_flow_updated(flow: int, _suit: String, _is_overdrive: bool) -> void:
	if flow == 0:
		tide_caller_used_in_flow = false
	elif flow >= 7 and GameManager.has_relic("tide_caller") and not tide_caller_used_in_flow:
		tide_caller_used_in_flow = true
		get_tree().create_timer(0.25).timeout.connect(func():
			if auto_clear_one_set():
				toast_requested.emit("Tide Caller: Tidal wave cleared a set!")
		)

func load_stage(layout_name: String, rng: RandomNumberGenerator = null) -> void:
	clear_board()
	stage_match_count = 0
	tide_caller_used_in_flow = false
	var tiles := BoardGenerator.deal_board(layout_name, rng)
	live_tiles = tiles
	selected_tiles.clear()
	history.clear()
	
	if StageModifiers.is_frost_active():
		for t in live_tiles:
			if t.z >= 1 or (t.x + t.y) % 5 == 0:
				t.is_frozen = true
	
	var max_x: int = 0
	var max_y: int = 0
	var max_z: int = 0
	for t in live_tiles:
		max_x = maxi(max_x, t.x)
		max_y = maxi(max_y, t.y)
		max_z = maxi(max_z, t.z)
	# Sort live_tiles so bottom layers (z=0) are instantiated and added first,
	# and top layers (z=max_z) are added last.
	# In Godot, Control nodes receive GUI mouse input in reverse tree order (last child first).
	# This guarantees top-layer tiles always receive mouse clicks and are never intercepted by covered tiles beneath.
	live_tiles.sort_custom(func(a: RiverTile, b: RiverTile):
		if a.z != b.z:
			return a.z < b.z
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)
		
	# Instantiate tile visual nodes
	for t in live_tiles:
		var view: TileView = TileViewScene.instantiate()
		add_child(view)
		
		var px: float = (t.x * 0.5) * TW + t.z * LAYER_OFF_X
		var py: float = (t.y * 0.5) * TH + (max_z - t.z) * LAYER_OFF_Y
		var target_pos := Vector2(px, py)
		
		# Cascading staggered deal animation (0.35s total wave)
		var delay: float = clampf((t.z * 0.06) + (t.y * 0.012) + (t.x * 0.006), 0.0, 0.38)
		view.position = target_pos - Vector2(0, 50.0)
		view.modulate.a = 0.0
		view.scale = Vector2(0.85, 0.85)
		
		var tween := view.create_tween()
		tween.tween_interval(delay)
		tween.tween_property(view, "position", target_pos, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(view, "modulate:a", 1.0, 0.16)
		
		view.z_index = t.z * 100 + t.y * 2 + (1 if t.x % 2 == 1 else 0)
		
		view.tile_clicked.connect(_on_tile_clicked)
		view.tile_long_pressed.connect(_on_tile_long_pressed)
		view.tree_exiting.connect(func():
			if tile_views.get(t) == view:
				tile_views.erase(t)
		)
		tile_views[t] = view
		
	board_bounds = Rect2(0, 0, (max_x * 0.5) * TW + TW + max_z * LAYER_OFF_X, (max_y * 0.5) * TH + TH + max_z * LAYER_OFF_Y)
	
	update_all_tiles_status()
	move_completed.emit(live_tiles.size(), get_legal_sets().size())

func _reorder_tile_children() -> void:
	var views: Array[TileView] = []
	for c in get_children():
		if c is TileView and is_instance_valid(c):
			views.append(c)
	views.sort_custom(func(a: TileView, b: TileView):
		if not a.tile_data or not b.tile_data:
			return false
		if a.tile_data.z != b.tile_data.z:
			return a.tile_data.z < b.tile_data.z
		if a.tile_data.y != b.tile_data.y:
			return a.tile_data.y < b.tile_data.y
		return a.tile_data.x < b.tile_data.x
	)
	for i in range(views.size()):
		move_child(views[i], i)

func clear_board() -> void:
	invalidate_legal_sets()
	for c in get_children():
		c.queue_free()
	live_tiles.clear()
	tile_views.clear()
	selected_tiles.clear()
	history.clear()

func get_spatial_grid(active_list: Array[RiverTile]) -> Dictionary:
	var grid := {}
	for u in active_list:
		grid[Vector3i(u.x, u.y, u.z)] = u
	return grid

func get_tile_blocked_reason(t: RiverTile, grid: Dictionary) -> String:
	var top_z: int = maxi(current_max_z, t.z + 1)
	for z_above in range(t.z + 1, top_z + 1):
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				if grid.has(Vector3i(t.x + dx, t.y + dy, z_above)):
					return "covered"

	var left_blocked := false
	for dy in range(-1, 2):
		if grid.has(Vector3i(t.x - 2, t.y + dy, t.z)):
			left_blocked = true
			break

	var right_blocked := false
	for dy in range(-1, 2):
		if grid.has(Vector3i(t.x + 2, t.y + dy, t.z)):
			right_blocked = true
			break

	if left_blocked and right_blocked:
		return "side_blocked"

	return "free"

func is_tile_free_grid(t: RiverTile, grid: Dictionary) -> bool:
	return get_tile_blocked_reason(t, grid) == "free"

func update_all_tiles_status() -> void:
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	for t in active:
		var v = tile_views.get(t)
		if is_instance_valid(v):
			var free := is_tile_free_grid(t, grid)
			v.setup(t, free)

func get_active_tiles() -> Array[RiverTile]:
	var res: Array[RiverTile] = []
	for t in live_tiles:
		if not t.is_removed:
			res.append(t)
	return res

func is_tile_free(t: RiverTile, active_list: Array[RiverTile]) -> bool:
	var grid := get_spatial_grid(active_list)
	return is_tile_free_grid(t, grid)

func _unhandled_input(event: InputEvent) -> void:
	if not SettingsManager.magnetic_assist:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_magnetic_tap(get_local_mouse_position())

func _handle_magnetic_tap(pos: Vector2) -> void:
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	var best_dist: float = 18.0 # 18px magnetic capture radius
	var best_view: TileView = null
	var best_z: int = -1
	
	for t in active:
		if not is_tile_free_grid(t, grid):
			continue
		var v = tile_views.get(t)
		if not is_instance_valid(v):
			continue
		var rect := Rect2(v.position.x, v.position.y, TW, TH)
		var dx: float = maxf(0.0, maxf(rect.position.x - pos.x, pos.x - rect.end.x))
		var dy: float = maxf(0.0, maxf(rect.position.y - pos.y, pos.y - rect.end.y))
		var dist: float = sqrt(dx * dx + dy * dy)
		
		if dist <= best_dist:
			if dist < best_dist or t.z > best_z:
				best_dist = dist
				best_view = v
				best_z = t.z
				
	if best_view:
		_on_tile_clicked(best_view)

func _on_tile_clicked(view: TileView) -> void:
	clear_all_hints()
	var t: RiverTile = view.tile_data
	if not t or t.is_removed:
		return
		
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	var reason := get_tile_blocked_reason(t, grid)
	if reason != "free":
		view.play_wrong_shake()
		AudioManager.play_tile_clack(0.7)
		if reason == "covered":
			toast_requested.emit("Covered by a tile above!")
		else:
			toast_requested.emit("Blocked on both left and right sides!")
		return
		
	# Frost encasement: first tap cracks the ice and thaws the tile
	if t.is_frozen:
		t.is_frozen = false
		view.play_wrong_shake()
		AudioManager.play_tile_clack(1.6)
		toast_requested.emit("Ice cracked! Tile thawed.")
		view.queue_redraw()
		return
		
	# Deselect if clicked again
	if selected_tiles.has(t):
		selected_tiles.erase(t)
		view.set_selected(false)
		AudioManager.play_tile_clack(1.1)
		return
		
	# Compatibility check with current selection
	if not selected_tiles.is_empty():
		var first: RiverTile = selected_tiles[0]
		if not first.is_compatible_with(t):
			view.play_wrong_shake()
			GameManager.register_misplay()
			toast_requested.emit("Tiles don't match!")
			# Reset selection to the new clicked tile
			for s in selected_tiles:
				var sv = tile_views.get(s)
				if is_instance_valid(sv):
					sv.set_selected(false)
			selected_tiles = [t]
			view.set_selected(true)
			return
			
	selected_tiles.append(t)
	view.set_selected(true)
	AudioManager.play_tile_clack(1.2)
	AudioManager.play_tile_pick()
	
	# Check if set is complete
	var required_size: int = 2
	for s in selected_tiles:
		required_size = maxi(required_size, s.size)
		
	if selected_tiles.size() >= required_size:
		_resolve_matched_set(selected_tiles.duplicate())
		selected_tiles.clear()

func _on_tile_long_pressed(view: TileView) -> void:
	var t: RiverTile = view.tile_data
	if not t or t.is_removed:
		return
	# Peek highlight: highlight matching free tiles
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	for other in active:
		if other != t and t.is_compatible_with(other) and is_tile_free_grid(other, grid):
			var ov = tile_views.get(other)
			if is_instance_valid(ov):
				ov.flash_hint(1.8)

func _resolve_matched_set(group: Array[RiverTile]) -> void:
	# Snapshot GameManager state for Undo rollback before mutating state
	var gm_snap: Dictionary = GameManager.snapshot_state()

	var is_triple: bool = group.size() >= 3
	var suit_name: String = group[0].suit
	var max_mastery: int = 0
	var last_view_pos := Vector2.ZERO
	var has_last_pos := false
	var is_glass_match: bool = false
	for t in group:
		if t.is_glass:
			is_glass_match = true
			break

	for t in group:
		t.is_removed = true
		SaveManager.record_tile_mastery(t.suit, t.rank)
		max_mastery = maxi(max_mastery, SaveManager.get_tile_mastery_level(t.suit, t.rank))
		var v = tile_views.get(t)
		if is_instance_valid(v):
			last_view_pos = v.position
			has_last_pos = true
			# Spawn visual particle shatter dust on cleared tiles
			var dust = TileShatterDustScene.instantiate()
			dust.position = v.position + Vector2(TW * 0.5, TH * 0.5)
			dust.z_index = v.z_index + 40
			add_child(dust)
			if dust.has_method("setup"):
				dust.setup(v.get_accent_color(), is_triple, t.suit, t.is_glass)
			v.play_clear_animation()
		tile_views.erase(t)
			
	# Strand-to-Wild ripple resolution
	var ripples: Array[Dictionary] = []
	var set_ids := {}
	for t in group:
		set_ids[t.set_id] = true
		
	for sid in set_ids.keys():
		for other in live_tiles:
			if other.set_id == sid and not other.is_removed and not other.is_open and not other.is_wild_suit():
				ripples.append({"tile": other, "open": other.is_open, "size": other.size})
				other.is_open = true
				other.size = 2
				var ov = tile_views.get(other)
				if is_instance_valid(ov):
					ov.play_strand_ripple()
					ov.queue_redraw()
					
	# Save for Undo
	history.append({
		"group": group.duplicate(),
		"ripples": ripples,
		"gm_snap": gm_snap
	})
	
	# Register match in GameManager with tile mastery score boost and crystal glass bonus
	var pts: int = GameManager.register_match(suit_name, is_triple, max_mastery, is_glass_match)
	
	if has_last_pos:
		var match_center := last_view_pos + Vector2(TW * 0.5, TH * 0.5)
		tile_matched.emit(match_center)
		var chip: FloatingChip = FloatingChipScene.instantiate()
		chip.position = last_view_pos + Vector2(TW * 0.5, TH * 0.3)
		add_child(chip)
		chip.setup("+" + str(pts), is_triple or GameManager.flow_level >= 5 or is_glass_match)
		
	if is_glass_match:
		toast_requested.emit("Crystal Glass Shattered! (+500 pts)")
		
	if not ripples.is_empty():
		AudioManager.play_wild_strand()
		toast_requested.emit("%d orphaned tile now Wild!" % ripples.size())
		
	# Phoenix Feather: Triples reveal all covered tiles for 4s
	if is_triple and GameManager.has_relic("phoenix_feather"):
		reveal_covered_tiles(4.0)
		toast_requested.emit("Phoenix Feather: Covered tiles revealed!")
		
	# Wild tile Jade bonus / Jade Whisper: 5 Jade (or 10 with Jade Whisper)
	var has_wild: bool = false
	for t in group:
		if t.is_wild():
			has_wild = true
			break
	if has_wild:
		var jade_gain: int = 10 if GameManager.has_relic("jade_whisper") else 5
		SaveManager.add_jade(jade_gain)
		toast_requested.emit("+%d 玉 River Jade" % jade_gain)

	# Dragon Bell: Every 4th match rings bell to highlight a legal set
	stage_match_count += 1
	if GameManager.has_relic("dragon_bell") and stage_match_count % 4 == 0:
		provide_hint()
		AudioManager.play_combo_high()
		toast_requested.emit("Dragon Bell chimed!")
		
	# Camera punch on Flow Overdrive
	if GameManager.is_overdrive_active():
		var cam = get_viewport().get_camera_2d()
		if cam and cam.has_method("punch_camera"):
			cam.punch_camera(Vector2(randf_range(-5.0, 5.0), randf_range(3.0, 6.0)))
		
	invalidate_legal_sets()
	update_all_tiles_status()
	
	var remaining := get_active_tiles()
	var legal_moves := get_legal_sets().size()
	move_completed.emit(remaining.size(), legal_moves)
	
	if remaining.is_empty():
		board_cleared.emit()
	elif legal_moves == 0:
		no_moves_left.emit()

func get_legal_sets() -> Array[Array]:
	if not _legal_sets_dirty:
		return _cached_legal_sets
		
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	var free_list: Array[RiverTile] = []
	for t in active:
		if is_tile_free_grid(t, grid):
			free_list.append(t)
			
	var wilds: Array[RiverTile] = []
	var normal: Array[RiverTile] = []
	for t in free_list:
		if t.is_wild():
			wilds.append(t)
		else:
			normal.append(t)
			
	var by_key := {}
	for t in normal:
		var k := t.get_match_key()
		if not by_key.has(k):
			by_key[k] = []
		by_key[k].append(t)
		
	var legal_sets: Array[Array] = []
	for k in by_key.keys():
		var list: Array = by_key[k]
		var s2: Array[RiverTile] = []
		var s3: Array[RiverTile] = []
		for t in list:
			if t.size == 2: s2.append(t)
			else: s3.append(t)
			
		# Pairs of size 2
		for i in range(s2.size()):
			for j in range(i + 1, s2.size()):
				legal_sets.append([s2[i], s2[j]])
				
		# Triples from full list (must contain at least one size 3 tile)
		if list.size() >= 3:
			for i in range(list.size()):
				for j in range(i + 1, list.size()):
					for k_idx in range(j + 1, list.size()):
						if list[i].size == 3 or list[j].size == 3 or list[k_idx].size == 3:
							legal_sets.append([list[i], list[j], list[k_idx]])
					
		# Triples completed by 1 wild tile
		if not wilds.is_empty() and list.size() >= 2:
			for i in range(list.size()):
				for j in range(i + 1, list.size()):
					# Only require 3 if at least one is banded or player aims for triple
					if list[i].size == 3 or list[j].size == 3:
						for w in wilds:
							legal_sets.append([list[i], list[j], w])
						
		# Triples completed by 2 wild tiles
		if wilds.size() >= 2 and not s3.is_empty():
			for t in s3:
				for w1_idx in range(wilds.size()):
					for w2_idx in range(w1_idx + 1, wilds.size()):
						legal_sets.append([t, wilds[w1_idx], wilds[w2_idx]])
			
	# Wild pairs: C(wilds.size(), 2)
	for i in range(wilds.size()):
		for j in range(i + 1, wilds.size()):
			legal_sets.append([wilds[i], wilds[j]])
			
	# Wild + Normal pair (where normal tile is size 2)
	for w in wilds:
		for t in normal:
			if t.size == 2:
				legal_sets.append([w, t])
		
	_cached_legal_sets = legal_sets
	_legal_sets_dirty = false
	return _cached_legal_sets

func reveal_covered_tiles(duration: float = 4.0) -> void:
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	for t in active:
		if not is_tile_free_grid(t, grid):
			var v = tile_views.get(t)
			if is_instance_valid(v):
				v.flash_revealed(duration)

func auto_clear_one_set() -> bool:
	var sets := get_legal_sets()
	if sets.is_empty():
		return false
	var target: Array = sets[0]
	var group: Array[RiverTile] = []
	for item in target:
		if item is RiverTile:
			group.append(item)
	if group.is_empty():
		return false
	_resolve_matched_set(group)
	return true

func clear_all_hints() -> void:
	for t in get_active_tiles():
		var v = tile_views.get(t)
		if is_instance_valid(v) and v.is_hinted:
			v.set_hint(false)

func provide_hint() -> bool:
	var sets := get_legal_sets()
	if sets.is_empty():
		return false
	var chosen: Array = sets[randi() % sets.size()]
	for t in chosen:
		var v = tile_views.get(t)
		if is_instance_valid(v):
			v.flash_hint(2.5)
	return true

func undo_last_move() -> bool:
	if history.is_empty():
		return false
	var last: Dictionary = history.pop_back()
	var group: Array = last["group"]
	var ripples: Array = last["ripples"]
	var gm_snap: Dictionary = last.get("gm_snap", {})
	
	if not gm_snap.is_empty():
		GameManager.restore_state(gm_snap)
	
	for t in group:
		t.is_removed = false
		var v = tile_views.get(t)
		if not is_instance_valid(v) or v.is_queued_for_deletion():
			v = TileViewScene.instantiate()
			add_child(v)
			var px: float = (t.x * 0.5) * TW + t.z * LAYER_OFF_X
			var py: float = (t.y * 0.5) * TH + (current_max_z - t.z) * LAYER_OFF_Y
			v.position = Vector2(px, py)
			v.z_index = t.z * 100 + t.y * 2 + (1 if t.x % 2 == 1 else 0)
			v.tile_clicked.connect(_on_tile_clicked)
			v.tile_long_pressed.connect(_on_tile_long_pressed)
			v.tree_exiting.connect(func():
				if tile_views.get(t) == v:
					tile_views.erase(t)
			)
			tile_views[t] = v
			
			# Swoop-in undo animation
			v.scale = Vector2(0.5, 0.5)
			v.modulate.a = 0.0
			var tween: Tween = v.create_tween().set_parallel(true)
			tween.tween_property(v, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			tween.tween_property(v, "modulate:a", 1.0, 0.14)
		else:
			v.modulate.a = 1.0
			v.scale = Vector2.ONE
			v.mouse_filter = Control.MOUSE_FILTER_STOP
			
	for r in ripples:
		var rt: RiverTile = r["tile"]
		rt.is_open = r["open"]
		rt.size = r["size"]
		var rv = tile_views.get(rt)
		if is_instance_valid(rv):
			rv.queue_redraw()
			
	selected_tiles.clear()
	invalidate_legal_sets()
	_reorder_tile_children()
	update_all_tiles_status()
	move_completed.emit(get_active_tiles().size(), get_legal_sets().size())
	return true

func shuffle_remaining_tiles() -> bool:
	var active := get_active_tiles()
	if active.size() < 2:
		return false
		
	# Collect all free slots of active tiles
	var slots: Array[Vector3i] = []
	for t in active:
		slots.append(Vector3i(t.x, t.y, t.z))
	slots.shuffle()
	
	for i in range(active.size()):
		var t := active[i]
		var s := slots[i]
		t.x = s.x
		t.y = s.y
		t.z = s.z
		var v = tile_views.get(t)
		if is_instance_valid(v):
			var px: float = (t.x * 0.5) * TW + t.z * LAYER_OFF_X
			var py: float = (t.y * 0.5) * TH + (current_max_z - t.z) * LAYER_OFF_Y
			var tween := create_tween()
			tween.tween_property(v, "position", Vector2(px, py), 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			v.z_index = t.z * 100 + t.y * 2 + (1 if t.x % 2 == 1 else 0)
			
	selected_tiles.clear()
	invalidate_legal_sets()
	_reorder_tile_children()
	update_all_tiles_status()
	move_completed.emit(active.size(), get_legal_sets().size())
	return true
