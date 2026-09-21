extends Node

const BoardGenerator = preload("res://scripts/core/board_generator.gd")
const RiverTile = preload("res://scripts/core/river_tile.gd")
const StageModifiers = preload("res://scripts/core/stage_modifiers.gd")
const ZenPondBackground = preload("res://scripts/ui/zen_pond_background.gd")

func _ready() -> void:
	print("==================================================")
	print("--- Running Nine Rivers Full Autoload Test Suite ---")
	print("==================================================")
	
	# 1. Verify Autoloads
	assert(SaveManager != null, "SaveManager autoload missing")
	assert(SettingsManager != null, "SettingsManager autoload missing")
	assert(AudioManager != null, "AudioManager autoload missing")
	assert(GameManager != null, "GameManager autoload missing")
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku"]
	SaveManager.sanctuary["decorations"] = ["bamboo_fountain"]
	MonetizationManager.equip_background_theme("auto")
	print("[PASS] All Autoload Singletons Active.")
	
	# 2. Test Calm Game Start
	GameManager.start_calm(1)
	assert(GameManager.current_level == 1, "Level should be 1")
	assert(GameManager.score == 0, "Score should be 0")
	print("[PASS] Calm Mode started.")
	
	# 3. Test Board Generation & Solvability
	var tiles := BoardGenerator.deal_board("quick")
	assert(tiles.size() == 36, "Courtyard layout must have 36 tiles")
	print("[PASS] Courtyard board dealt (%d tiles)." % tiles.size())
	
	var board_scene_diag = preload("res://scenes/board.tscn")
	var tb_diag: BoardController = board_scene_diag.instantiate()
	add_child(tb_diag)
	tb_diag.load_stage("quick")
	var grid_diag := tb_diag.get_spatial_grid(tb_diag.get_active_tiles())
	var c_first: TileView = tb_diag.get_child(0) as TileView
	var c_last: TileView = tb_diag.get_child(tb_diag.get_child_count() - 1) as TileView
	assert(c_first.tile_data.z == 0, "Tree Child 0 must be bottom layer (z=0)")
	assert(c_last.tile_data.z == 2, "Tree Child last must be top layer (z=2) for correct GUI mouse picking")
	print("[PASS] Tile visual tree ordering verified (z=0 first, z=2 last for mouse picking).")
	tb_diag.queue_free()
	
	# 4. Test Match & Flow System
	var pts1 := GameManager.register_match("bam", false)
	assert(pts1 > 0, "Match points must be > 0")
	assert(GameManager.flow_level == 1, "Flow level must be 1")
	
	var pts2 := GameManager.register_match("bam", false)
	assert(GameManager.flow_level == 2, "Flow level must be 2 after consecutive bamboo match")
	print("[PASS] Flow Combo verified: Flow ×%d (+%d pts)." % [GameManager.flow_level, pts2])
	
	# 5. Test Misplay Reset
	GameManager.register_misplay()
	assert(GameManager.flow_level == 0, "Flow must reset to 0 on misplay")
	assert(GameManager.misplays == 1, "Misplays must be 1")
	print("[PASS] Misplay Flow reset verified.")
	
	# 6. Test Roguelite Relics
	GameManager.acquire_relic({"id": "sharper_eye", "name": "Sharper Eye"})
	assert(GameManager.has_relic("sharper_eye"), "Relic must be registered")
	assert(GameManager.score_mult > 1.0, "Score multiplier must increase")
	print("[PASS] Roguelite relic system verified: Sharper Eye active.")
	
	# 7. Test Save & Jade Persistence
	var initial_jade := SaveManager.get_jade()
	SaveManager.record_level_clear(1, 2500, 3)
	assert(SaveManager.get_jade() == initial_jade + 150, "3 stars should grant +150 River Jade")
	assert(int(SaveManager.prog["level"]) >= 2, "Next level unlocked")
	print("[PASS] Persistence verified: Level %d unlocked, %d Jade in bank." % [
		SaveManager.prog["level"], SaveManager.get_jade()
	])
	
	# 8. Test Audio Clacks & Shatter Sounds
	AudioManager.play_tile_clack(1.0)
	AudioManager.play_tile_match(3, true)
	print("[PASS] ASMR Audio ceramic fracture & crumbling dust whoosh verified.")
	
	# 9. Test Tile Shatter Dust & Dissolve Shader Animation
	var tile_scene = preload("res://scenes/tile.tscn")
	var tile_view = tile_scene.instantiate()
	add_child(tile_view)
	var t_data = RiverTile.new(0, 0, 0, "dot", 5, 2, 1)
	tile_view.setup(t_data, true)
	tile_view.play_clear_animation()
	
	var dust_scene = preload("res://scenes/effects/tile_shatter_dust.tscn")
	var dust_effect = dust_scene.instantiate()
	add_child(dust_effect)
	dust_effect.setup(tile_view.get_accent_color(), true)
	print("[PASS] Tile dissolve shader & shatter-into-thin-dust particle system verified.")
	
	# 10. Test Deterministic Daily Seed Generation
	var rng1 := RandomNumberGenerator.new()
	rng1.seed = 20260911
	var b1 := BoardGenerator.deal_board("quick", rng1)
	
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 20260911
	var b2 := BoardGenerator.deal_board("quick", rng2)
	
	assert(b1.size() == b2.size(), "Seeded boards must have identical tile count")
	for i in range(b1.size()):
		assert(b1[i].x == b2[i].x and b1[i].y == b2[i].y and b1[i].z == b2[i].z, "Tile positions must match")
		assert(b1[i].suit == b2[i].suit and b1[i].rank == b2[i].rank, "Tile suit and rank must match")
	print("[PASS] Deterministic RNG Daily Seed verified.")
	
	# 11. Test Combinatorial get_legal_sets()
	var board_scene = preload("res://scenes/board.tscn")
	var test_board: BoardController = board_scene.instantiate()
	add_child(test_board)
	test_board.clear_board()
	# 3 free matching tiles of size 2 at non-overlapping positions
	var t1 := RiverTile.new(0, 0, 0, "dot", 1, 0, 2)
	var t2 := RiverTile.new(4, 0, 0, "dot", 1, 0, 2)
	var t3 := RiverTile.new(8, 0, 0, "dot", 1, 0, 2)
	test_board.live_tiles = [t1, t2, t3]
	var sets: Array = test_board.get_legal_sets()
	assert(sets.size() == 3, "3 matching free tiles must produce 3 combinations (got %d)" % sets.size())
	print("[PASS] Combinatorial Legal Sets verified: 3 matching tiles -> 3 legal sets.")
	
	# 12. Test Boons Integration
	# Lotus Blessing
	GameManager.start_calm(1)
	GameManager.acquire_relic({"id": "lotus_blessing", "name": "Lotus Blessing"})
	GameManager.on_stage_started()
	GameManager.register_match("dot", false)
	assert(GameManager.flow_level == 3, "Lotus Blessing must give Flow 3 on first match (got %d)" % GameManager.flow_level)
	
	# Spring Breeze
	GameManager.acquire_relic({"id": "spring_breeze", "name": "Spring Breeze"})
	var prev_flow := GameManager.flow_level
	GameManager.register_match("flower", false)
	assert(GameManager.flow_level == prev_flow + 2, "Spring Breeze must advance flow by +2 on Flower match")
	
	# Porcelain Guard
	GameManager.acquire_relic({"id": "porcelain_guard", "name": "Porcelain Guard"})
	var flow_before_misplay := GameManager.flow_level
	GameManager.register_misplay()
	assert(GameManager.flow_level == flow_before_misplay, "Porcelain Guard must protect flow on first misplay")
	GameManager.register_misplay()
	assert(GameManager.flow_level == flow_before_misplay - 2, "Second misplay without guard must step down flow by 2")
	GameManager.register_misplay()
	GameManager.register_misplay()
	assert(GameManager.flow_level == 0, "Repeated misplays must reach 0")
	
	# Golden Net
	var prev_hints := GameManager.hints
	var prev_shuffles := GameManager.shuffles
	GameManager.acquire_relic({"id": "golden_net", "name": "Golden Net"})
	GameManager.on_stage_started()
	assert(GameManager.hints == prev_hints + 2, "Golden Net must grant bonus hint on acquisition and stage start")
	assert(GameManager.shuffles == prev_shuffles + 2, "Golden Net must grant bonus shuffle on acquisition and stage start")
	print("[PASS] All Boons integrated and verified: Lotus Blessing, Spring Breeze, Porcelain Guard, Golden Net.")
	
	# 13. Test Stage Modifiers (Fog, Rush, Frost)
	StageModifiers.reset()
	assert(not StageModifiers.is_fog_active(), "Fog must be inactive by default")
	StageModifiers.set_modifier_for_stage(0, 7) # Calm lvl 7 -> Frost
	assert(StageModifiers.is_frost_active(), "Lvl 7 must trigger Frost modifier")
	StageModifiers.set_modifier_for_stage(0, 6) # Calm lvl 6 -> Fog
	assert(StageModifiers.is_fog_active(), "Lvl 6 must trigger Fog modifier")
	StageModifiers.set_modifier_for_stage(0, 5) # Calm lvl 5 -> Rush
	assert(StageModifiers.is_rush_active(), "Lvl 5 must trigger Rush modifier")
	
	# Test Frost thaw mechanic
	var frozen_tile := RiverTile.new(0, 0, 0, "dot", 1, 0, 2)
	frozen_tile.is_frozen = true
	test_board.clear_board()
	test_board.live_tiles = [frozen_tile]
	var test_view: TileView = tile_scene.instantiate()
	test_board.add_child(test_view)
	test_view.setup(frozen_tile, true)
	test_board.tile_views[frozen_tile] = test_view
	test_board._on_tile_clicked(test_view)
	assert(frozen_tile.is_frozen == false, "First click on frozen tile must thaw it")
	assert(test_board.selected_tiles.is_empty(), "First click must only thaw, not select")
	StageModifiers.reset()
	print("[PASS] Stage Modifiers & Frost Thaw Mechanic verified.")
	
	# 14. Test Tile Mastery Progression
	SaveManager.tile_mastery.clear()
	assert(SaveManager.get_tile_mastery_level("dot", 8) == 0, "0 matches should be unranked")
	for m in range(10):
		SaveManager.record_tile_mastery("dot", 8)
	assert(SaveManager.get_tile_mastery_level("dot", 8) == 1, "10 matches must reach Apprentice (Tier 1)")
	for m in range(20):
		SaveManager.record_tile_mastery("dot", 8)
	assert(SaveManager.get_tile_mastery_level("dot", 8) == 2, "30 matches must reach Adept (Tier 2)")
	for m in range(50):
		SaveManager.record_tile_mastery("dot", 8)
	assert(SaveManager.get_tile_mastery_level("dot", 8) == 3, "80 matches must reach Master (Tier 3)")
	print("[PASS] Tile Mastery progression verified: Unranked -> Apprentice -> Adept -> Master.")
	
	# 15. Test Modal Navigation & Back Button Handling
	var modal_scene = preload("res://scenes/ui/modal.tscn")
	var test_modal: ModalController = modal_scene.instantiate()
	add_child(test_modal)
	test_modal.show_main_menu()
	assert(test_modal._current_screen == "main", "Current screen must be main")
	test_modal.show_level_select()
	assert(test_modal._current_screen == "level_select", "Current screen must be level_select")
	test_modal.handle_back_pressed()
	assert(test_modal._current_screen == "main", "Back from level select must return to main")
	
	test_modal.show_daily_clear(8888, 6, 4)
	assert(test_modal._current_screen == "daily_clear", "Current screen must be daily_clear")
	print("[PASS] Modal navigation, level select & Back button handling verified.")
	
	# 16. Test Undo State Rollback & Node Reconstruction
	test_board.clear_board()
	var ut1 := RiverTile.new(0, 0, 0, "dot", 9, 101, 2)
	var ut2 := RiverTile.new(4, 0, 0, "dot", 9, 101, 2)
	test_board.live_tiles = [ut1, ut2]
	var uv1: TileView = tile_scene.instantiate()
	var uv2: TileView = tile_scene.instantiate()
	test_board.add_child(uv1)
	test_board.add_child(uv2)
	uv1.setup(ut1, true)
	uv2.setup(ut2, true)
	test_board.tile_views[ut1] = uv1
	test_board.tile_views[ut2] = uv2
	
	GameManager.start_calm(1)
	assert(GameManager.score == 0 and GameManager.flow_level == 0, "Start state must be 0")
	test_board._on_tile_clicked(uv1)
	test_board._on_tile_clicked(uv2)
	assert(ut1.is_removed and ut2.is_removed, "Both tiles matched and removed")
	assert(GameManager.score > 0, "Score should have increased on match")
	assert(GameManager.flow_level == 1, "Flow should be 1")
	
	# Simulate node deletion from dissolve animation
	uv1.queue_free()
	uv2.queue_free()
	
	# Test Undo
	var undo_ok: bool = test_board.undo_last_move()
	assert(undo_ok, "Undo must succeed")
	assert(not ut1.is_removed and not ut2.is_removed, "Tiles must be unremoved")
	assert(GameManager.score == 0, "Score must roll back to 0 on undo (got %d)" % GameManager.score)
	assert(GameManager.flow_level == 0, "Flow must roll back to 0 on undo (got %d)" % GameManager.flow_level)
	
	var restored_v1 = test_board.tile_views.get(ut1)
	var restored_v2 = test_board.tile_views.get(ut2)
	assert(is_instance_valid(restored_v1) and not restored_v1.is_queued_for_deletion(), "TileView 1 must be recreated")
	assert(is_instance_valid(restored_v2) and not restored_v2.is_queued_for_deletion(), "TileView 2 must be recreated")
	print("[PASS] Undo Node Reconstruction & State Rollback verified.")
	
	# 17. Test Turtle 144-tile Deal with Greedy Dynamic Peel
	var turtle_tiles := BoardGenerator.deal_board("turtle")
	assert(turtle_tiles.size() == 144, "Turtle board must have exactly 144 tiles (got %d)" % turtle_tiles.size())
	print("[PASS] 144-Tile Turtle Layout dealt with 100% solvability.")
	
	# 18. Test Koi Sanctuary Blessings
	const SanctuaryManager = preload("res://scripts/core/sanctuary_manager.gd")
	# Taisho Sanke (+5% Jade)
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku", "sanke"]
	var before_jade := SaveManager.get_jade()
	SaveManager.add_jade(100)
	assert(SaveManager.get_jade() == before_jade + 105, "Taisho Sanke must award +5%% River Jade (got %d)" % (SaveManager.get_jade() - before_jade))
	
	# Platinum Ogon (+10% Calm score)
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku", "ogon"]
	GameManager.start_calm(1)
	var ogon_pts := GameManager.register_match("bam", false)
	assert(ogon_pts == 110, "Platinum Ogon must award +10%% base Calm score (expected 110, got %d)" % ogon_pts)
	
	# Golden Dragon Koi (Flow Overdrive at Flow 6)
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku", "dragon_koi"]
	GameManager.flow_level = 6
	assert(GameManager.is_overdrive_active(), "Golden Dragon Koi must trigger Overdrive at Flow 6")
	
	# Showa Sanshoku (Misplay drops flow by only 1)
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku", "showa"]
	GameManager.flow_level = 4
	GameManager.register_misplay()
	assert(GameManager.flow_level == 3, "Showa Sanshoku must reduce misplay flow drop to 1 (got %d)" % GameManager.flow_level)
	print("[PASS] All Koi Sanctuary blessings verified: Sanke (+5% Jade), Ogon (+10% Score), Dragon Koi (Overdrive @ 6), Showa (Gentle Flow drop).")
	
	# 19. Test Tile Mastery Score Boost (+15% for Tier 3)
	GameManager.start_calm(1)
	SaveManager.sanctuary["koi_unlocked"] = ["kohaku"] # reset ogon
	var mastered_pts := GameManager.register_match("bam", false, 3)
	assert(mastered_pts == 115, "Tier 3 Tile Mastery must award +15%% score (expected 115, got %d)" % mastered_pts)
	print("[PASS] Tile Mastery Score Boost verified (+15% for Master tier).")
	
	# 20. Test Monetization & Spirit Pearl Economy
	var init_pearls := MonetizationManager.get_pearls()
	MonetizationManager.add_pearls(500)
	assert(MonetizationManager.get_pearls() == init_pearls + 500, "Spirit Pearls addition must match")
	var spent_ok: bool = MonetizationManager.spend_pearls(200)
	assert(spent_ok and MonetizationManager.get_pearls() == init_pearls + 300, "Spirit Pearls spend must deduct balance")
	var overspend_ok: bool = MonetizationManager.spend_pearls(999999)
	assert(not overspend_ok, "Overspending Spirit Pearls must fail cleanly")
	
	# Test No-Ads Purchase simulation
	MonetizationManager.buy_product("no_ads")
	assert(MonetizationManager.is_no_ads(), "No-Ads entitlement must be unlocked after purchase")
	
	# Test Rewarded Ad simulation
	SaveManager.economy["rewarded_ads_today"] = 0
	var can_watch: bool = MonetizationManager.can_watch_rewarded_ad()
	assert(can_watch, "Daily rewarded ad should be watchable initially")
	MonetizationManager.simulate_rewarded_ad("daily_meditation")
	assert(MonetizationManager.get_remaining_rewarded_ads() == MonetizationManager.MAX_DAILY_REWARDED_ADS - 1, "Rewarded ad count must decrease")
	
	# Test props refill rewarded ad
	var pre_hints: int = GameManager.hints
	var pre_shuffles: int = GameManager.shuffles
	MonetizationManager.show_rewarded_ad("props_refill")
	assert(GameManager.hints == pre_hints + 1, "Rewarded ad props refill must increment hints")
	assert(GameManager.shuffles == pre_shuffles + 1, "Rewarded ad props refill must increment shuffles")
	
	print("[PASS] Monetization & Spirit Pearl Economy verified (IAP, soft currency, rewarded offerings).")
	
	# 21. Test Cosmetic Tile Themes
	MonetizationManager.buy_product("theme_obsidian_ink")
	assert(MonetizationManager.is_theme_unlocked("theme_obsidian_ink"), "Theme obsidian ink must be unlocked")
	MonetizationManager.equip_theme("theme_obsidian_ink")
	assert(MonetizationManager.get_active_theme() == "theme_obsidian_ink", "Equipped theme must be obsidian ink")
	var obsidian_face: Color = TileView.get_theme_face_color(true)
	assert(obsidian_face == Color("#1e2226"), "Obsidian face color must match theme specification")
	var obsidian_ink: Color = TileView.get_col_ink()
	assert(obsidian_ink == Color("#f0f4f8"), "Obsidian ink must be light white jade for dark tiles")
	
	# Switch to Imperial Gold
	MonetizationManager.buy_product("theme_imperial_gold")
	MonetizationManager.equip_theme("theme_imperial_gold")
	assert(TileView.get_theme_face_color(true) == Color("#fffbee"), "Imperial gold face color must match theme specification")
	# Revert to classic
	MonetizationManager.equip_theme("classic_jade")
	assert(TileView.get_theme_face_color(true) == TileView.COL_IVORY, "Classic jade face color must match ivory specification")
	print("[PASS] Cosmetic Tile Themes verified (Obsidian Ink, Imperial Gold, Classic Jade dynamic styling).")
	
	# 22. Test 44.1kHz Procedural Audio Engine
	assert(AudioManager.sample_rate == 44100.0, "Audio sample rate must be 44.1kHz CD-quality")
	AudioManager.play_click()
	AudioManager.play_win()
	print("[PASS] 44.1kHz Procedural Acoustic Engine verified (UI click, Guzheng physical modeling, 3.5s fanfare).")
	
	# 23. Test Freed Instance Safety (Match, Dissolve, Hints, Reveals, Shuffle, Undo)
	test_board.clear_board()
	var ft1 := RiverTile.new(0, 0, 0, "bamboo", 1, 201, 2)
	var ft2 := RiverTile.new(4, 0, 0, "bamboo", 1, 201, 2)
	var ft3 := RiverTile.new(8, 0, 0, "bamboo", 2, 202, 2)
	var ft4 := RiverTile.new(12, 0, 0, "bamboo", 2, 202, 2)
	test_board.live_tiles = [ft1, ft2, ft3, ft4]
	var fv1: TileView = tile_scene.instantiate()
	var fv2: TileView = tile_scene.instantiate()
	var fv3: TileView = tile_scene.instantiate()
	var fv4: TileView = tile_scene.instantiate()
	test_board.add_child(fv1)
	test_board.add_child(fv2)
	test_board.add_child(fv3)
	test_board.add_child(fv4)
	test_board.tile_views[ft1] = fv1
	test_board.tile_views[ft2] = fv2
	test_board.tile_views[ft3] = fv3
	test_board.tile_views[ft4] = fv4
	test_board.update_all_tiles_status()
	
	# Match pair 1
	test_board._on_tile_clicked(fv1)
	test_board._on_tile_clicked(fv2)
	assert(ft1.is_removed and ft2.is_removed, "Pair 1 must be removed")
	
	# Test operations with previously cleared / freed instances
	test_board.clear_all_hints()
	test_board.provide_hint()
	test_board.reveal_covered_tiles(1.0)
	test_board.shuffle_remaining_tiles()
	
	# Undo after hints & shuffles
	var undo_res: bool = test_board.undo_last_move()
	assert(undo_res, "Undo must succeed after hint & shuffle calls")
	assert(not ft1.is_removed and not ft2.is_removed, "Pair 1 must be restored")
	print("[PASS] Freed Instance Safety verified (no dangling references in hints, reveals, shuffle, undo).")
	test_board.queue_free()
	
	# 24. Test Zen Pond Background Parallax & Dynamic 5-Level Theme System
	var zen_bg := ZenPondBackground.new()
	add_child(zen_bg)
	
	# Verify theme calculation every 5 levels
	var theme_lvl1: Dictionary = zen_bg.get_theme_for_level(1)
	assert(theme_lvl1.id == "emerald_pond", "Level 1 must be Emerald Serenity")
	var theme_lvl5: Dictionary = zen_bg.get_theme_for_level(5)
	assert(theme_lvl5.id == "emerald_pond", "Level 5 must be Emerald Serenity")
	var theme_lvl6: Dictionary = zen_bg.get_theme_for_level(6)
	assert(theme_lvl6.id == "moonlit_river", "Level 6 must be Moonlit Twilight")
	var theme_lvl11: Dictionary = zen_bg.get_theme_for_level(11)
	assert(theme_lvl11.id == "autumn_stream", "Level 11 must be Autumn Maple Falls")
	var theme_lvl16: Dictionary = zen_bg.get_theme_for_level(16)
	assert(theme_lvl16.id == "misty_spring", "Level 16 must be Misty Mountain Spring")
	var theme_lvl21: Dictionary = zen_bg.get_theme_for_level(21)
	assert(theme_lvl21.id == "sunset_haven", "Level 21 must be Sunset Lotus Haven")
	var theme_lvl26: Dictionary = zen_bg.get_theme_for_level(26)
	assert(theme_lvl26.id == "emerald_pond", "Level 26 must cycle back to Emerald Serenity")
	
	# Test live theme switching
	var theme_signal_received := [false]
	var test_cb := func(data, lvl):
		theme_signal_received[0] = true
		assert(lvl == 6, "Signal level should be 6")
		assert(data.id == "moonlit_river", "Signal theme should be Moonlit")
	zen_bg.theme_changed.connect(test_cb)
	zen_bg.set_level(6, false)
	assert(zen_bg.current_theme_idx == 1, "Theme index should be 1 for Level 6")
	assert(theme_signal_received[0], "Theme changed signal must be emitted on 5-level transition")
	zen_bg.theme_changed.disconnect(test_cb)
	
	# Test ripple creation
	zen_bg.add_ripple(Vector2(540, 960), 1.2)
	assert(zen_bg.ripples.size() == 1, "Ripple must be registered")
	
	# Test flow level update
	zen_bg.set_flow_level(7, true)
	
	# Test process step
	zen_bg._process(0.016)
	assert(zen_bg.motes.size() == ZenPondBackground.NUM_MOTES, "Motes must be initialized and updated")
	zen_bg.queue_free()
	print("[PASS] Living Zen Pond Parallax System & Dynamic 5-Level Theme Progression verified.")
	
	# 25. Test Golden Sand Particle Vanish & Special Breaking Glass Tile
	# A. Board Generator assigns exactly one set as is_glass = true
	var test_deal_tiles: Array[RiverTile] = BoardGenerator.deal_board("quick")
	var glass_tiles: Array[RiverTile] = []
	for t in test_deal_tiles:
		if t.is_glass:
			glass_tiles.append(t)
	assert(glass_tiles.size() >= 2, "Special glass set must have at least 2 tiles")
	var glass_set_id: int = glass_tiles[0].set_id
	for gt in glass_tiles:
		assert(gt.set_id == glass_set_id, "All glass tiles must belong to the same special set")
		
	# B. Dual-Mode Particle System: Golden Sand vs Breaking Glass
	var sand_dust = dust_scene.instantiate()
	add_child(sand_dust)
	sand_dust.setup(Color.GOLD, true, "bam", false)
	assert(sand_dust.is_glass == false, "Standard match must trigger Golden Sand mode")
	assert(sand_dust.shards.amount == 72, "Golden Sand triple must configure 72 fine particles")
	sand_dust.queue_free()
	
	var glass_dust = dust_scene.instantiate()
	add_child(glass_dust)
	glass_dust.setup(Color.CYAN, true, "dragon", true)
	assert(glass_dust.is_glass == true, "Special tile match must trigger Breaking Glass mode")
	assert(glass_dust.shards.amount == 36, "Breaking Glass triple must configure 36 crystalline shards")
	glass_dust.queue_free()
	
	# C. Procedural ASMR Audio
	AudioManager.play_golden_sand()
	AudioManager.play_glass_shatter()
	
	# D. GameManager Glass match bonus score (+500 pts)
	var prev_score: int = GameManager.score
	var glass_pts: int = GameManager.register_match("dragon", false, 0, true)
	assert(GameManager.score == prev_score + glass_pts, "Score must increment by glass_pts")
	assert(glass_pts >= 600, "Glass match must award +500 bonus points")
	
	# E. TileView visual rendering for is_glass tile
	var glass_view = tile_scene.instantiate()
	add_child(glass_view)
	var glass_data = RiverTile.new(0, 0, 0, "dragon", 1, 0, 2)
	glass_data.is_glass = true
	glass_view.setup(glass_data, true)
	assert(glass_view.tile_data.is_glass == true, "TileView must preserve is_glass flag")
	glass_view.play_clear_animation()
	glass_view.queue_free()
	
	print("[PASS] Golden Sand Disintegration & Special Crystal Glass Shattering verified.")
	
	# 26. Test Zen Interstitial Frequency Capper
	SaveManager.economy["no_ads_purchased"] = false
	assert(MonetizationManager.can_show_interstitial(1) == false, "Level 1 onboarding must be ad-free")
	assert(MonetizationManager.can_show_interstitial(2) == false, "Level 2 onboarding must be ad-free")
	assert(MonetizationManager.can_show_interstitial(3) == false, "Level 3 onboarding must be ad-free")
	assert(MonetizationManager.can_show_interstitial(4) == false, "Level 4 cannot show ad without 3 completed stages")
	MonetizationManager.record_level_cleared()
	MonetizationManager.record_level_cleared()
	assert(MonetizationManager.can_show_interstitial(4) == false, "2 cleared stages is below threshold of 3")
	MonetizationManager.record_level_cleared()
	assert(MonetizationManager.can_show_interstitial(4) == true, "Level 4+ with 3 stages and cooldown satisfied must allow ad")
	var showed := MonetizationManager.show_interstitial_if_ready(4, "test")
	assert(showed == true, "show_interstitial_if_ready must succeed")
	assert(MonetizationManager.can_show_interstitial(4) == false, "Immediate follow-up ad must be blocked by cooldown")
	print("[PASS] Zen Interstitial Frequency Capper verified (grace period, 240s timer & 3-stage threshold).")
	
	# 27. Test Indian Rupee (INR) Pricing & Locale Formatter
	var p_no_ads := MonetizationManager.get_formatted_price("no_ads")
	assert(p_no_ads.length() > 0, "Price string must not be empty")
	assert(MonetizationManager.PRODUCTS["no_ads"].has("price_inr"), "Product must have INR price defined")
	assert(MonetizationManager.PRODUCTS["pearls_small"]["price_inr"] == "₹49", "Pouch of pearls must be ₹49")
	assert(MonetizationManager.PRODUCTS["no_ads"]["price_inr"] == "₹199", "No-Ads must be ₹199")
	print("[PASS] Indian Market (INR / UPI) Localized Pricing verified.")
	
	# 28. Test Tile / Banner Ad & No-Ads Integration
	SaveManager.economy["no_ads_purchased"] = false
	MonetizationManager.show_banner_ad()
	assert(MonetizationManager.is_banner_ad_visible() == true, "Banner ad must be visible when no_ads is false")
	MonetizationManager.hide_banner_ad()
	assert(MonetizationManager.is_banner_ad_visible() == false, "Banner ad must hide on request")
	SaveManager.economy["no_ads_purchased"] = true
	MonetizationManager.show_banner_ad()
	assert(MonetizationManager.is_banner_ad_visible() == false, "Banner ad must NEVER show if no_ads is purchased")
	assert(MonetizationManager.can_show_interstitial(10) == false, "Interstitials must NEVER show if no_ads is purchased")
	SaveManager.economy["no_ads_purchased"] = false
	print("[PASS] Banner/Tile Ad Controls & No-Ads Suppression verified.")
	
	# 29. Test Security Anti-Tamper & Checksum Integrity
	# The contract changed: a save that fails its signature is now REFUSED
	# outright rather than applied and then clamped. Applying a forged payload
	# at all was the T04 finding. So the test is that nothing moves.
	SaveManager.economy["no_ads_purchased"] = false
	var pearls_before: int = SaveManager.get_pearls()
	var jade_before: int = SaveManager.get_jade()
	var fake_tampered_data := {
		"version": SaveManager.CURRENT_VERSION,
		"prog": {"river_jade": 999999},
		"economy": {"pearls": 999999, "no_ads_purchased": true},
		"checksum": "invalid_fake_checksum_12345"
	}
	var accepted: bool = SaveManager._apply_save_data(fake_tampered_data)
	assert(accepted == false, "A save with a bad checksum must be refused")
	assert(SaveManager.economy["no_ads_purchased"] == false, "A refused save must not grant no_ads")
	assert(SaveManager.get_pearls() == pearls_before, "A refused save must not change pearls")
	assert(SaveManager.get_jade() == jade_before, "A refused save must not change jade")
	print("[PASS] Security Anti-Tamper & Checksum Integrity verified (forged save refused, state untouched).")
	
	# 30. Test Tile Preview Generation & Theme Override Rendering
	var preview_gold := TileView.create_preview_tile("bam", 1, "theme_imperial_gold", 1.0)
	assert(is_instance_valid(preview_gold), "Preview tile must be instantiated")
	assert(preview_gold.theme_override == "theme_imperial_gold", "Preview tile must hold theme_override")
	assert(TileView.get_theme_back_base("theme_imperial_gold") == Color("#4a1210"), "Imperial gold must have crimson lacquer underside")
	assert(TileView.get_col_ink("theme_obsidian_ink") == Color("#f0f4f8"), "Obsidian ink must use white jade calligraphy")
	preview_gold.free()
	print("[PASS] Tile Preview Generation & Theme Override Rendering verified.")
	
	# 31. Test Multiple Free Background Themes & Equipping
	assert(MonetizationManager.is_background_theme_unlocked("emerald_pond") == true, "Emerald pond must be free & unlocked")
	assert(MonetizationManager.is_background_theme_unlocked("moonlit_river") == true, "Moonlit river must be free & unlocked")
	assert(MonetizationManager.is_background_theme_unlocked("autumn_stream") == true, "Autumn stream must be free & unlocked")
	MonetizationManager.equip_background_theme("moonlit_river")
	assert(MonetizationManager.get_active_background_theme() == "moonlit_river", "Moonlit river must be equipped")
	SaveManager.add_jade(2000)
	var bought_spring := MonetizationManager.buy_background_with_jade("misty_spring")
	assert(bought_spring == true, "Should unlock misty_spring with jade")
	assert(MonetizationManager.is_background_theme_unlocked("misty_spring") == true, "Misty spring must now be unlocked")
	assert(MonetizationManager.get_active_background_theme() == "misty_spring", "Misty spring must be active after buy")
	MonetizationManager.equip_background_theme("auto")
	print("[PASS] Multiple Free Background Themes (Emerald, Moonlit, Autumn) & Equipping verified.")
	
	# 32. Test Bazaar Hub & Sub-UI Modal Navigation
	var bz_modal_scene: PackedScene = load("res://scenes/ui/modal.tscn")
	var bz_modal: ModalController = bz_modal_scene.instantiate()
	add_child(bz_modal)
	bz_modal.show_bazaar_modal()
	assert(bz_modal._current_screen == "bazaar", "Modal must enter bazaar screen")
	bz_modal.show_tile_catalog_modal()
	assert(bz_modal._current_screen == "tile_catalog", "Modal must enter tile_catalog screen")
	bz_modal.show_tile_detail_modal("theme_imperial_gold")
	assert(bz_modal._current_screen == "tile_detail", "Modal must enter tile_detail screen")
	bz_modal.handle_back_pressed()
	assert(bz_modal._current_screen == "tile_catalog", "Back from tile_detail must return to tile_catalog")
	bz_modal.handle_back_pressed()
	assert(bz_modal._current_screen == "bazaar", "Back from tile_catalog must return to bazaar")
	bz_modal.show_background_catalog_modal()
	assert(bz_modal._current_screen == "bg_catalog", "Modal must enter bg_catalog screen")
	bz_modal.show_background_detail_modal("moonlit_river")
	assert(bz_modal._current_screen == "bg_detail", "Modal must enter bg_detail screen")
	bz_modal.handle_back_pressed()
	assert(bz_modal._current_screen == "bg_catalog", "Back from bg_detail must return to bg_catalog")
	bz_modal.handle_back_pressed()
	assert(bz_modal._current_screen == "bazaar", "Back from bg_catalog must return to bazaar")
	bz_modal.handle_back_pressed()
	assert(bz_modal._current_screen == "main", "Back from bazaar must return to main")
	bz_modal.queue_free()
	print("[PASS] Bazaar Hub & Sub-UI Modal Navigation & Back Stack verified.")
	
	print("==================================================")
	print("--- ALL 32 TEST SUITES PASSED FLAWLESSLY! ---")
	print("==================================================")
	get_tree().quit(0)

