# Nine Rivers — Game Design Document & Technical Specification

**Target Platform:** Mobile (iOS / Android), PC (Steam / Web)  
**Engine:** Godot 4.6 (GDScript / 2.5D Canvas & Mobile Renderer)  
**Genre:** Zen Roguelite Tile Puzzler (Mahjong Solitaire meets Roguelite Combos)  
**Inspiration & Comparisons:** *Balatro* (poker synergies), *Mahjong Solitaire / Shanghai* (board clearing), *Grindstone* (color/suit flow chains).

---

## 1. Executive Summary & Vision

**Nine Rivers** reimagines traditional Mahjong Solitaire as a fast, tactile, combo-driven roguelite puzzle game. Instead of passive, slow pair-hunting, Nine Rivers turns tile clearing into an active strategic flow:

1. **Mixed Sets (Pairs & Triples):** Players match pairs (2-of-a-kind) and banded tiles (3-of-a-kind).
2. **Strand-to-Wild Cascades:** Breaking or orphaning a set doesn't brick the board; stranded tiles ignite into golden **Wilds**, creating cascading combo chains.
3. **Suit Flow:** Matching consecutive sets of the same suit builds a **Flow Multiplier** ($×1 \to ×9$), accompanied by ascending pentatonic musical melodies.
4. **Guaranteed Solvability:** Boards are generated in reverse using a topological peel algorithm—every board is mathematically guaranteed to be solvable without relying on wild cards.
5. **Two Complementary Modes:**
   - **Calm Journey:** 50+ stages with 3-star ratings, bespoke goals, and no timer.
   - **Timed River Run (Roguelite):** Arcade survival with ticking clock, stage modifiers (Rush, Fog, Drought), and drafting synergistic **Boons** (relics) between stages.

---

## 2. Core Game Mechanics

### 2.1 The Tile Rule (Mahjong Solitaire Topology)
A tile is **free** and eligible for selection if:
- **Top Clearance:** No tile rests on top of it at higher Z-elevation within its bounding box ($|Δx| < 2$ and $|Δy| < 2$).
- **Side Clearance:** At least one long side (left or right) is completely open at the same Z-elevation ($x - 2$ or $x + 2$).

### 2.2 Tile Sets & Banded Triples
Traditional Mahjong only uses 2-of-a-kind pairs. Nine Rivers mixes two set types:
- **Standard Pair (Size 2):** Two identical tiles (same suit and rank).
- **Banded Triple (Size 3):** Three identical tiles adorned with a **Gold Band** on the bottom bezel. All three must be collected to resolve the set.
- **Wild Tiles:**
  - **Flowers & Seasons:** Wild by nature. Match with any tile or with each other.
  - **Stranded Wilds (Open Tiles):** Generated dynamically when a set's sibling is cleared or orphaned. Glows gold and matches any tile.

### 2.3 The Strand-to-Wild Cascade ("The Ripple Effect")
When a player uses a wild tile to complete a set, or when an odd single tile is left behind:
- Any orphaned sibling tile is flagged as `open = true` (Wild) and reduced to `size = 2`.
- A golden ripple visual/sound effect fires.
- This prevents dead-ends and rewards bold, aggressive matching strategies.

### 2.4 The Flow Combo Multiplier
- Clearing consecutive sets of the **same suit** (Dots $\to$ Dots, or Bamboo $\to$ Bamboo) increases the Flow level:
  $$\text{Flow Level} \in [1, 9]$$
- Score formula:
  $$\text{Score} = \text{Base Points} \times \min(6, \text{Flow}) \times \text{Multiplier}$$
  *(Base Points: 100 for Pairs, 250 for Triples)*
- Switching suits resets Flow back to 1 (unless protected by specific Boons).
- As Flow rises, procedural chime notes scale up the Chinese pentatonic scale (Gong, Shang, Jiao, Zhi, Yu).

---

## 3. Game Modes

## 3. Game Modes & Daily Retention Engine

### 3.1 The Daily Tide — The "Morning Coffee" Habit Loop
- **One Global Seeded Challenge Per Day:** Every player worldwide plays the exact same 3-stage board, resetting daily at midnight UTC.
- **2–3 Minute Target Session:** Tuned for morning coffee, commutes, or quick breaks.
- **Wordle-Style Shareable Scorecard:** Generates an emoji/brushstroke spoiler-free summary ready for copy-pasting to social apps:
  ```
  Nine Rivers #42 🌊
  Flow: 🀄🀄🀄🀄🀄 (Peak ×5)
  Score: 14,280 [Master Rank]
  ⭐⭐⭐ Clean Clear
  ```
- **Forgiving Streak Mechanics:** Daily play builds a **River Streak**. Players earn **River Stones** through play, which can auto-repair a missed streak once per week without resetting progress to zero.

### 3.2 Calm Journey (50+ Progressive Levels)
- **Goal:** Clear the board without a clock.
- **3-Star Rating System:**
  - ⭐ **1 Star:** Board cleared.
  - ⭐ **2 Stars:** Secondary objective met (e.g., "Clear all Bamboo before 40% of board is cleared", "Reach Flow ×4", or "Clear without using props").
  - ⭐ **3 Stars:** Flawless run (≤ 2 misplays and no shuffle used).
- **Spirit Pearl Drops:** Every star earned awards **Spirit Pearls** (20 per star), the game's single currency. River Jade was folded into Pearls; old saves migrate at 3 jade to 1 pearl.

### 3.3 Timed River Run (Roguelite Survival with 3-Act Pacing)
- **Session Pacing (The 5-Minute Window):**
  - **Act 1: Courtyard (36 tiles)** — 45s fast opener to build immediate Flow momentum.
  - **Act 2: Garden (72 tiles)** — 90s midgame introducing stage modifiers (Rush, Fog, Frost).
  - **Act 3: Citadel/Turtle (108–144 tiles)** — 2.5m climax where drafted relics unleash maximum combo potential.
- **Clock Dynamics:**
  - Starting time: 100 seconds.
  - Set returns: $+1.5\text{s}$ for pairs, $+2.5\text{s}$ for triples.
  - Clearing a stage awards $+25\text{s}$ plus speed bonus score.
- **Synergistic Relic Drafting (The Balatro Effect):**
  Players draft 1 of 3 randomized relics post-stage to discover game-breaking synergies:

| Relic Name | Type | Effect |
| :--- | :--- | :--- |
| **River Dragon** | Synergy | Bamboo and Character suits chain together without resetting Flow. |
| **Phoenix Feather** | Vision | Completing a Triple pulses all covered tiles, revealing their faces for 4s. |
| **Jade Alchemist** | Transmute | Every Dot match permanently converts one buried tile on the board into a Wild tile. |
| **Tide Surge** | Safety | Shuffling does not consume a shuffle charge if time is under 20s. |
| **Ancestral Bell** | Relic | Every 4th match automatically frees 1 buried tile on the board. |
| **Jade Kiln** | Scoring | Banded triples award 3× score and grant +5s. |
| **Spring Breeze** | Wild | Flower and Season matches immediately advance Flow by +2. |
| **Golden Net** | Economy | Start each stage with +1 free Hint and +1 free Shuffle. |
| **Deep Breath** | Time | +60 seconds added to the clock immediately. |
| **Steady Hand** | Shield | Misplays no longer deduct time from the clock. |
| **Sharper Eye** | Multiplier | Permanent +30% score multiplier for the rest of the run. |

---

## 4. The Metagame: The Koi Sanctuary

Abstract stars don't retain players; personal ownership does. Between runs, players spend **Spirit Pearls** to restore an ancient Zen water garden:
1. **Water Clarity:** Cleared stages clean the murky river water, revealing river pebbles and sunken stones.
2. **Koi Fish Collection:** Unlock and release varieties of swimming Koi (Kohaku, Taisho Sanke, Showa, Platinum Ogon). Purely decorative — the Koi Blessings that once granted passive bonuses were removed, because a cosmetic pond that quietly changes the maths is not cosmetic.
3. **Garden Elements:** Place Lotus Blossoms, Stone Lanterns, and Bamboo Water Fountains (Shishi-odoshi) that tap softly in the background.
4. **Tile Mastery:** Every tile rank (e.g. 1-Bamboo, Red Dragon, Autumn) levels up through gameplay, unlocking ornate gold-filigree borders and passive score boosts.

---

## 5. Sensory & Audiovisual Design (Tactile ASMR & Flow Overdrive)

### 5.1 Flow Overdrive (Dynamic Audiovisual Crescendo)
- **Flow 1–3 (Gentle Stream):** Crisp ceramic clacks, gentle Guzheng plucks, peaceful dark felt.
- **Flow 4–6 (Rising River):** Golden river currents light up beneath the felt. Pipa and percussion swell with rhythm.
- **Flow 7–9 (FLOW OVERDRIVE):**
  - Table felt glows with radiant water caustics and swimming golden koi.
  - Subtle 40ms hit-stop on set resolutions for heavy tactile impact.
  - Resounding temple gong and cascading crystal waterfall audio.
  - Final clearance triggers an explosive golden confetti and tile shower celebration.

### 5.2 Mobile Ergonomics & Tactile Controls
- **Magnetic Tap Assist:** Tapping within 14px of a free tile magnetically snaps selection to it.
- **Peek Gesture:** Long-pressing a tile dims other tiles and highlights its matching partners if exposed.
- **Physical ASMR Clacks:** Procedural multi-sample ceramic and melamine impact acoustic synthesis.

---

## 5. Godot 4.6 Technical Architecture

### 5.1 Project Configuration
- **Renderer:** Mobile (Forward+ on Desktop, Mobile/Vulkan on iOS/Android).
- **Target Resolution:** $1080 \times 1920$ (9:16 portrait mobile baseline, auto-expand for tablets and landscape).
- **Stretch Mode:** `canvas_items`, aspect: `expand`.

### 5.2 Directory Structure
```
res://
├── assets/
│   ├── audio/           # ASMR clacks, chimes, ambient music, UI sfx
│   ├── fonts/           # Noto Sans SC / Outfit / Serif fonts
│   ├── textures/        # Tile face SVGs/PNGs, felt textures, UI icons
│   └── shaders/         # Tile bevel, shadow, glow, water flow shaders
├── scenes/
│   ├── main.tscn        # Core game scene orchestrator
│   ├── board.tscn       # Board container and camera controller
│   ├── tile.tscn        # Individual 2.5D tile node
│   ├── ui/
│   │   ├── hud.tscn     # Top bar, flow meter, timer bar, prop buttons
│   │   ├── modal.tscn   # Pause, level clear, game over, boon pick cards
│   │   └── menu.tscn    # Main menu, level select, settings
├── scripts/
│   ├── autoload/
│   │   ├── game_manager.gd   # Game state, mode, scoring, flow logic
│   │   ├── audio_manager.gd  # ASMR audio system & music director
│   │   ├── save_manager.gd   # Encrypted persistence (user://nine_rivers_save.json)
│   │   └── settings_manager.gd# Audio/haptics/motion settings
│   ├── core/
│   │   ├── board_generator.gd# Peel algorithm & layout geometry
│   │   ├── board_controller.gd# Tile matching, selection, cascade logic
│   │   ├── tile_data.gd      # Tile class definition
│   │   └── boon_pool.gd      # Roguelite relics and effect hooks
│   └── ui/
│       ├── camera_controller.gd # Pinch, pan, auto-fit framing
│       └── hud_controller.gd    # Score rolls, flow animations
└── project.godot
```

### 5.3 Mathematical Core: Reverse-Peel Algorithm (`board_generator.gd`)
```gdscript
# Pseudo-structure of the reverse-peel solver:
func generate_solvable_board(positions: Array, sets: Array) -> Array:
    for attempt in range(500):
        var live_positions = positions.duplicate(true)
        var peel_order = []
        var valid = true
        
        for set in sets:
            var free_slots = live_positions.filter(func(p): return is_slot_free(p, live_positions))
            if free_slots.size() < set.size:
                valid = false
                break
            
            # Prioritize higher Z-levels for natural top-down construction
            free_slots.sort_custom(func(a, b): return a.z > b.z)
            var chosen = pick_random_subset(free_slots, set.size)
            peel_order.append(chosen)
            for p in chosen:
                live_positions.erase(p)
                
        if valid and live_positions.is_empty():
            return build_tiles_from_order(peel_order, sets)
            
    # Fallback relaxation solver ensures 100% deal success rate
    return generate_relaxed_fallback_board(positions, sets)
```

---

## 6. Commercialization & Live-Ops Blueprint

1. **Monetization Model (Ethical Hybrid):**
   - **Free-to-Play Core:** All 350 Calm stages, the Daily Tide and the Timed River Run are free.
   - **Single Currency:** Spirit Pearls, earned from stars or bought outright. There is no second currency and no wagering of Pearls.
   - **Cosmetic Customization:** Three purchasable tile sets (Imperial Gold, Obsidian Ink, Cherry Blossom, Rs 99 each) and two backgrounds (Misty Mountain Spring, Sunset Lotus Haven, Rs 49 each). Each is also buyable with Pearls. Deep Indigo is earned at stage 50 and is never sold. Classic Jade and three backgrounds ship free.
   - **Pearl Packs:** Rs 49 / Rs 149 / Rs 399 for 500 / 2,500 / 7,500 Pearls.
   - **One-Time "Remove Ads" IAP (Rs 199):** Removes banners and interstitials permanently, and grants 500 Pearls. It does not unlock themes.
   - **Shop Structure:** Four rows — Tile Sets, Backgrounds, Buy Pearls, Restore Purchases. The Free Rewards screen was cut; the Daily Tide is the free-Pearl surface.
   - **Advertising:** the shipping build has no ad network wired up. AdMob is signed up for and intended, with rewarded video currently having no UI entry point.
2. **Retention Features:**
   - **Daily Tide:** Seeded daily challenge identical for all global players. No leaderboard: the game ships with no online ranking of any kind.
   - **Haptic ASMR Marketing:** Perfect for TikTok / Instagram Reels gameplay videos showcasing satisfying tile clacks, chain reactions, and high-flow clearing combos.
