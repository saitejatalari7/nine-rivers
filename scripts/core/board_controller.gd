class_name BoardController
extends Node2D

signal move_completed(remaining_tiles: int, legal_moves: int)
signal tile_matched(world_pos: Vector2)
signal board_cleared()
signal no_moves_left()
## A tap that was refused because the tile is not free. Onboarding uses it: the
## lesson "a covered tile will not move" is completed by trying it, and nothing
## is matched, so move_completed never fires.
signal blocked_tap(tile: RiverTile)
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
const TileLighting = preload("res://scripts/ui/tile_lighting.gd")

## A wild tile pays a small bonus. Was 5 River Jade before the currencies
## merged; three jade were worth one pearl.
const WILD_TILE_PEARLS: int = 2

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

var _cached_legal_sets: Array[Array] = []
var _legal_sets_dirty: bool = true

func invalidate_legal_sets() -> void:
	_legal_sets_dirty = true

func _ready() -> void:
	# Onto the parent, not this node. clear_board() frees every child of the
	# board, so lights parented here died on the first deal and the bevel
	# lighting never ran in the game at all; they were also children 0 and 1,
	# which broke the child-order assumption that drives mouse picking.
	var light_host: Node = get_parent() if get_parent() != null else self
	TileLighting.attach(light_host)
	if is_instance_valid(MonetizationManager) and MonetizationManager.has_signal("theme_equipped"):
		MonetizationManager.theme_equipped.connect(_on_theme_equipped)

func _on_theme_equipped(_theme_id: String) -> void:
	for t in tile_views.keys():
		var view = tile_views.get(t)
		if is_instance_valid(view) and view.has_method("update_theme_style"):
			view.update_theme_style()

func load_stage(layout_name: String, rng: RandomNumberGenerator = null) -> void:
	clear_board()
	_auto_thaw_armed = false
	stage_match_count = 0
	var tiles := BoardGenerator.deal_board(layout_name, rng)
	live_tiles = tiles
	selected_tiles.clear()
	history.clear()
	
	if StageModifiers.is_frost_active():
		for t in live_tiles:
			if t.z >= 1 or (t.x + t.y) % 5 == 0:
				t.is_frozen = true
	
	_seat_tiles(true)

## Builds a view for every tile in live_tiles and settles the board around them.
## Shared by a fresh deal and by a session restored from disk; the restore skips
## the dealing wave, because a board the player was already looking at should be
## there when they come back, not deal itself again.
func _seat_tiles(animate: bool) -> void:
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
		
	# Instantiate tile visual nodes. A restored board has already-matched tiles
	# in the list, for the geometry and for the bounds above; they get no view.
	for t in live_tiles:
		if t.is_removed:
			continue
		var view: TileView = TileViewScene.instantiate()
		add_child(view)
		
		var px: float = (t.x * 0.5) * TW + t.z * LAYER_OFF_X
		var py: float = (t.y * 0.5) * TH + (max_z - t.z) * LAYER_OFF_Y
		var target_pos := Vector2(px, py)
		
		if animate:
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
		else:
			view.position = target_pos

		view.z_index = t.z * 100 + t.y * 2 + (1 if t.x % 2 == 1 else 0)
		
		view.tile_clicked.connect(_on_tile_clicked)
		view.tile_long_pressed.connect(_on_tile_long_pressed)
		view.tree_exiting.connect(func():
			if tile_views.get(t) == view:
				tile_views.erase(t)
		)
		tile_views[t] = view
		
	board_bounds = Rect2(0, 0, (max_x * 0.5) * TW + TW + max_z * LAYER_OFF_X, (max_y * 0.5) * TH + TH + max_z * LAYER_OFF_Y)
	
	_auto_thaw_armed = false
	update_all_tiles_status()
	_auto_thaw_armed = true
	move_completed.emit(live_tiles.size(), get_legal_sets().size())

## The board as plain data, for a session written to disk. Only what cannot be
## re-derived: the layout name replays the geometry, but which tiles were dealt
## where, and which of them are gone, cannot be worked out from anything else.
## Dresses a handful of tiles in a set the player does not own, so a premium
## theme can be seen on a real board instead of only on a shop page. Returns
## how many were dressed.
##
## Top layers first: a sample buried under three tiles is not a sample. Nothing
## about this is persisted - the override lives on the view and dies with the
## board.
func sample_theme(theme_id: String, count: int) -> int:
	if theme_id.is_empty() or count <= 0:
		return 0
	var live: Array[RiverTile] = get_active_tiles()
	live.sort_custom(func(a: RiverTile, b: RiverTile): return a.z > b.z)
	var dressed: int = 0
	var step: int = maxi(1, live.size() / maxi(1, count * 2))
	var i: int = 0
	while i < live.size() and dressed < count:
		var v = tile_views.get(live[i])
		if v != null and is_instance_valid(v):
			v.theme_override = theme_id
			v.update_theme_style()
			dressed += 1
		i += step
	return dressed


func snapshot_tiles() -> Array:
	var out: Array = []
	for t in live_tiles:
		out.append({
			"x": t.x, "y": t.y, "z": t.z,
			"suit": t.suit, "rank": t.rank,
			"set_id": t.set_id, "size": t.size,
			"open": t.is_open, "gone": t.is_removed,
			"frozen": t.is_frozen, "glass": t.is_glass,
		})
	return out

## Rebuilds a board from snapshot_tiles(). Returns false and leaves the board
## empty if the data is unusable, so a truncated or hand-edited session is
## refused rather than half-restored.
##
## The undo history is deliberately not restored. Undo works on board snapshots
## taken in memory, and carrying them through a save would multiply the file
## size by the length of the stack for a feature nobody reaches for after
## closing the app.
func restore_stage(tiles_data: Array) -> bool:
	clear_board()
	_auto_thaw_armed = false
	stage_match_count = 0
	var rebuilt: Array[RiverTile] = []
	for entry in tiles_data:
		if not (entry is Dictionary):
			return false
		var d: Dictionary = entry
		var t := RiverTile.new(
			int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)),
			String(d.get("suit", "dot")), int(d.get("rank", 1)),
			int(d.get("set_id", 0)), int(d.get("size", 2)))
		t.is_open = bool(d.get("open", false))
		t.is_removed = bool(d.get("gone", false))
		t.is_frozen = bool(d.get("frozen", false))
		t.is_glass = bool(d.get("glass", false))
		rebuilt.append(t)
	if rebuilt.is_empty():
		return false
	live_tiles = rebuilt
	selected_tiles.clear()
	history.clear()
	_seat_tiles(false)
	invalidate_legal_sets()
	update_all_tiles_status()
	_auto_thaw_armed = true
	move_completed.emit(get_active_tiles().size(), get_legal_sets().size())
	return true

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

## Set once the deal has settled. Without it the first status pass would thaw
## every frozen tile that happens to start free, and Frost would be over before
## the player touched anything.
var _auto_thaw_armed: bool = false

func update_all_tiles_status() -> void:
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	for t in active:
		var v = tile_views.get(t)
		if not is_instance_valid(v):
			continue
		var free := is_tile_free_grid(t, grid)
		# Clearing what blocked a frozen tile cracks its ice. Only on the
		# transition: a tile that was already free and frozen at the deal stays
		# frozen, which is what leaves the player something to tap.
		if _auto_thaw_armed and t.is_frozen and free and not v.is_free:
			_thaw(t, v)
		v.setup(t, free)

## Cracks the ice on one tile: state, sound and shards. Shared so a tap and an
## auto-crack cannot drift apart.
func _thaw(t: RiverTile, v) -> void:
	t.is_frozen = false
	var centre: Vector2 = v.position + Vector2(TW * 0.5, TH * 0.5)
	AudioManager.play_ice_crack(centre, t.z)
	var dust = TileShatterDustScene.instantiate()
	dust.position = centre
	dust.z_index = v.z_index + 40
	add_child(dust)
	if dust.has_method("setup"):
		# is_glass true gives the icy palette the frost tiles already use.
		dust.setup(Color(0.70, 0.92, 1.0), false, t.suit, true)
	v.queue_redraw()

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

## While onboarding is pointing at specific tiles, only those tiles answer. A
## first-time player who wanders off mid-instruction ends up somewhere the
## script cannot follow, and the lesson breaks rather than the player learning
## anything. Empty means no restriction, which is every other moment in the
## game.
var tutorial_focus: Array[RiverTile] = []

func _on_tile_clicked(view: TileView) -> void:
	var t: RiverTile = view.tile_data
	if not t or t.is_removed:
		return
	if not tutorial_focus.is_empty() and not tutorial_focus.has(t):
		view.play_wrong_shake()
		return
	clear_all_hints()
		
	var active := get_active_tiles()
	var grid := get_spatial_grid(active)
	var reason := get_tile_blocked_reason(t, grid)
	if reason != "free":
		blocked_tap.emit(t)
		view.play_wrong_shake()
		AudioManager.play_tile_clack(0.7, view.position + Vector2(TW * 0.5, TH * 0.5), t.z, t.suit)
		if reason == "covered":
			toast_requested.emit("Covered by a tile above!")
		else:
			toast_requested.emit("Blocked on both left and right sides!")
		return
		
	# Frost encasement: a tap still cracks the ice, for the tiles that were
	# frozen where they lay and never had a blocker to clear.
	if t.is_frozen:
		_thaw(t, view)
		toast_requested.emit("Ice cracked! Tile thawed.")
		return
		
	# Deselect if clicked again
	if selected_tiles.has(t):
		selected_tiles.erase(t)
		view.set_selected(false)
		AudioManager.play_tile_clack(1.1, view.position + Vector2(TW * 0.5, TH * 0.5), t.z, t.suit)
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
	var tile_at: Vector2 = view.position + Vector2(TW * 0.5, TH * 0.5)
	AudioManager.play_tile_clack(1.2, tile_at, t.z, t.suit)
	AudioManager.play_tile_pick(tile_at, t.z)
	
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
	var last_view_pos := Vector2.ZERO
	var last_z: int = 0
	var has_last_pos := false
	var is_glass_match: bool = false
	for t in group:
		if t.is_glass:
			is_glass_match = true
			break

	for t in group:
		t.is_removed = true
		SaveManager.record_tile_mastery(t.suit, t.rank)
		var v = tile_views.get(t)
		if is_instance_valid(v):
			last_view_pos = v.position
			last_z = t.z
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
	
	# Register the match in GameManager.
	# Position first: register_match plays the chime, so it needs the centre of
	# the group that was just cleared.
	var match_at: Vector2 = Vector2.INF
	if has_last_pos:
		match_at = last_view_pos + Vector2(TW * 0.5, TH * 0.5)
	var pts: int = GameManager.register_match(suit_name, is_triple,
		is_glass_match, match_at, last_z)
	
	if has_last_pos:
		var match_center := match_at
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
		
	# Wild tiles pay a small Jade bonus.
	var has_wild: bool = false
	for t in group:
		if t.is_wild():
			has_wild = true
			break
	if has_wild:
		SaveManager.add_pearls(WILD_TILE_PEARLS)
		toast_requested.emit("+%d ◈ Spirit Pearls" % WILD_TILE_PEARLS)

	stage_match_count += 1
		
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
	else:
		_nudge_if_iced_in()

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
	# Prefer a set with no ice in it. If every remaining set is iced, the hint
	# points at ice, and the player has to be told that tapping it is a move -
	# nothing else on the board says so once auto-thaw has handled the rest.
	var clear_sets: Array[Array] = []
	for s in sets:
		if not _set_has_ice(s):
			clear_sets.append(s)
	var pool: Array = clear_sets if not clear_sets.is_empty() else sets
	var chosen: Array = pool[randi() % pool.size()]
	for t in chosen:
		var v = tile_views.get(t)
		if is_instance_valid(v):
			v.flash_hint(2.5)
	if clear_sets.is_empty():
		toast_requested.emit("Frozen - tap the ice to crack it open.")
	return true

func _set_has_ice(s: Array) -> bool:
	for t in s:
		if t.is_frozen:
			return true
	return false

## Fires after a match when every remaining move is behind ice, so a player who
## has only ever seen tiles auto-thaw is told that they can crack it directly.
func _nudge_if_iced_in() -> void:
	var sets := get_legal_sets()
	if sets.is_empty():
		return
	for s in sets:
		if not _set_has_ice(s):
			return
	toast_requested.emit("Frozen - tap the ice to crack it open.")

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

## Re-deals the remaining tiles into the remaining slots so the board is
## solvable again, rather than permuting them at random and hoping.
##
## The old version shuffled slot positions and returned true whatever came out.
## It could leave no legal move at all, and on a board down to two tiles sitting
## in one column every permutation is still one tile on top of another - the
## geometry is unsolvable, not the arrangement. A player hit exactly that at
## stage 2, pressed Shuffle, and watched a charge disappear for nothing.
##
## peel_dynamic builds a clearing order over the slots that are actually left,
## and the tiles are dealt back along it, so a solution provably exists from the
## new arrangement. When the slots admit no such order the function reports
## failure and changes nothing, which lets the caller keep the charge and say
## something honest.
## Groups the remaining tiles the way the match rule actually groups them.
##
## Grouping by set_id was wrong: a match pairs tiles by their match key, not by
## the set they were dealt in, so two tiles of one type from different sets are
## matched together and leave an orphan in each. Every reshuffle attempt failed
## on "group of 1" for exactly that reason.
##
## Returns [] when what is left cannot be grouped into playable sets at all.
func _group_for_shuffle(live: Array) -> Array:
	var buckets: Dictionary = {}
	var wilds: Array = []
	for t in live:
		if t.is_wild():
			wilds.append(t)
			continue
		# Keyed by type AND set size. A banded triple and a plain pair of the
		# same type land in one bucket otherwise, and the group size is taken
		# from whichever tile happens to be first - a bucket of five then makes
		# two pairs and strands one tile, which fails the whole grouping. On a
		# full 144-tile board that happened every time.
		var k: String = "%s#%d" % [t.get_match_key(), maxi(2, int(t.size))]
		if not buckets.has(k):
			buckets[k] = []
		buckets[k].append(t)

	var groups: Array = []
	var leftovers: Array = []
	for k in buckets.keys():
		var b: Array = buckets[k]
		while not b.is_empty():
			# A banded triple asks for three; everything else asks for two.
			var want: int = maxi(2, int(b[0].size))
			if b.size() < want:
				for rem in b:
					leftovers.append(rem)
				b = []
				break
			var g: Array = []
			for i in range(want):
				g.append(b.pop_back())
			groups.append(g)

	# A wild matches anything, so it can complete an odd leftover. Pair them up
	# rather than refusing a board that is still playable.
	while not leftovers.is_empty() and not wilds.is_empty():
		groups.append([leftovers.pop_back(), wilds.pop_back()])
	while wilds.size() >= 2:
		groups.append([wilds.pop_back(), wilds.pop_back()])

	if not leftovers.is_empty() or not wilds.is_empty():
		return []
	return groups


## Whether a shuffle could produce a playable board, without performing one.
## Lets the caller tell a genuine dead end - where no arrangement of what is
## left can be played - from simply having run out of shuffle charges. The two
## deserve different answers, and only the first deserves a way out.
func can_reshuffle() -> bool:
	var active := get_active_tiles()
	if active.size() < 2:
		return false
	var all_groups: Array = _group_for_shuffle(active)
	if all_groups.is_empty():
		return false
	var pairs: int = 0
	var triples: int = 0
	for g in all_groups:
		if g.size() == 3:
			triples += 1
		else:
			pairs += 1
	var slots: Array[Dictionary] = []
	for t in active:
		slots.append({"x": t.x, "y": t.y, "z": t.z})
	var probe := RandomNumberGenerator.new()
	probe.seed = 20260923
	return not BoardGenerator.peel_dynamic(slots, triples, pairs, probe).is_empty()


func shuffle_remaining_tiles() -> bool:
	var active := get_active_tiles()
	if active.size() < 2:
		return false

	var all_groups: Array = _group_for_shuffle(active)
	if all_groups.is_empty():
		return false
	var pairs: Array = []
	var triples: Array = []
	for g in all_groups:
		if g.size() == 3:
			triples.append(g)
		else:
			pairs.append(g)

	var slots: Array[Dictionary] = []
	for t in active:
		slots.append({"x": t.x, "y": t.y, "z": t.z})

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var order: Array[Dictionary] = BoardGenerator.peel_dynamic(
		slots, triples.size(), pairs.size(), rng)
	if order.is_empty():
		return false

	# Deal the groups back along the clearing order. Sizes match by
	# construction: peel_dynamic was asked for exactly these counts.
	for entry in order:
		var want: int = int(entry["size"])
		var g: Array = triples.pop_back() if want == 3 else pairs.pop_back()
		var placed: Array = entry["slots"]
		for i in range(g.size()):
			var t: RiverTile = g[i]
			t.x = int(placed[i]["x"])
			t.y = int(placed[i]["y"])
			t.z = int(placed[i]["z"])

	for t in active:
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
	# A shuffle re-seats every tile, so half the board flips from blocked to
	# free at once. Auto-thaw read that as the player clearing blockers and
	# melted most of the ice - three taps took a Frost board from 76 frozen to
	# 38. Moving a tile is not clearing what covered it.
	_auto_thaw_armed = false
	update_all_tiles_status()
	_auto_thaw_armed = true
	move_completed.emit(active.size(), get_legal_sets().size())
	return true
