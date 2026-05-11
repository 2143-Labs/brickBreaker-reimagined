# Lofi Brick Breaker — Developer Context Report
> Generated April 30, 2026. Intended to onboard a new AI agent for feature development.

---

## 1. Project Identity

| Field | Value |
|---|---|
| **Name** | Godot Bricker (Lofi Brick Breaker) |
| **Engine** | Godot 4.6 stable, GL Compatibility renderer, GDScript |
| **Viewport** | 390×844 portrait (mobile-first) |
| **Repo** | github.com/2143-Labs/brickBreaker-reimagined |
| **Local Path** | `C:\Users\Daniel Scarbrough\Documents\Coding\BrickBreaker\godot-bricker` |
| **Developer** | Dsstar |
| **Tooling Note** | All file writes must use UTF-8 **no BOM** (required by Godot). In PowerShell use a Write-NoBom helper. For big changes: full PowerShell rewrite scripts. For small: find/replace instructions. |
| **License** | Godot=MIT, Inter font=SIL OFL, music=Incompetech CC BY (all free commercial) |

---

## 2. High-Level Architecture

### Scene Flow
```
main_menu.tscn  →  main.tscn (game)  ↔  skill_tree.tscn
                               ↕
                        settings_menu.tscn (instanced at runtime inside main.tscn)
```
`main_menu.tscn` is the startup scene (set in `project.godot`). The game scene is `scenes/main.tscn` with `game_manager.gd` as root script.

### Autoloads (Singletons)
| Singleton | Script | Role |
|---|---|---|
| `Progression` | `scripts/progression.gd` | XP, leveling, skill tree, save/load (`user://progression.save`) |
| `MusicManager` | `scripts/music_manager.gd` | Lofi music shuffle, menu/game tracks |
| `UITheme` | `scripts/ui_theme.gd` | Color palette constants + `make_card()` StyleBox factory |

### Key Script Summary
| Script | Size | Role |
|---|---|---|
| `game_manager.gd` | ~2200 lines | **Core game loop** — owns everything: round flow, spawning, aiming, firing, combos, VFX, HUD, powerups, boss system, score |
| `ball.gd` | 144 lines | Ball physics via `CharacterBody2D`, trail rendering, stuck detection, burn stacks |
| `brick.gd` | 244 lines | Normal brick — HP, color tiers, crack overlays, burn fire shader, stacking damage |
| `boss_brick.gd` | 204 lines | Boss brick — multi-cell, shield bar, elite/final flags, movement, guardian spawning |
| `armored_brick.gd` | — | Immune to normal damage, armor stripped by explosions |
| `oil_barrel.gd` | — | 3 HP hazard, explodes on death with 2× radius, chain reactions |
| `rainbow_brick.gd` | — | Shimmer, drops random pickup on death |
| `guardian_brick.gd` | — | 1 HP + 150 shield, spawned by final boss |
| `triangle_brick.gd` | — | Spinning triangle hitbox hazard (max 1 on board) |
| `diagonal_brick.gd` | — | Grid-aligned right-triangle brick, 4 orientation variants |
| `explosive_ball.gd` | — | First-ball powerup; deals area damage on hit with 3-ring falloff |
| `railgun_ball.gd` | — | Pierces all bricks in a line at 1500 px/s; triggers deferred death sequence |
| `burn_ball.gd` | — | Standard ball with `applies_burn = true` (used when burn powerup is round-active) |
| `launcher.gd` | 245 lines | Draws the launcher cannon with 5 visual modes (default/bomb/railgun/burn/nuke), animates aim angle |
| `magazine.gd` | — | Visual pipe that shows ball queue; slides entrance position between rounds |
| `aim_controller.gd` | — | (Possibly legacy; aiming logic lives inline in `game_manager._input()`) |
| `pickup.gd` | — | Floor item collectible (Area2D); 3 types: 2×ammo, 2×dmg, nuke charge |
| `ammo_orb.gd` | — | Collectible orb that adds 1 ammo when touched by a ball |
| `sound_manager.gd` | — | `AudioStreamPlayer` pool; loads .wav/.mp3 from `assets/audio/` by key name |
| `music_manager.gd` | — | Autoload; starts game/menu music tracks, shuffles playlist |
| `progression.gd` | — | Autoload; full talent tree + XP/level persistence |
| `boss_reward.gd` | 229 lines | `CanvasLayer` popup shown after killing a full boss; presents 3 reward cards |
| `powerup_manager.gd` | — | Legacy standalone node (not the active system; powerups live in `game_manager.gd`) |
| `skill_tree_ui.gd` | — | UI for the talent tree, connects to `Progression` autoload |
| `settings_menu.gd` | — | SFX/music toggle, grid toggle, volume sliders; instanced into main scene at runtime |
| `ui_theme.gd` | — | Palette constants + `make_card()` returns a `StyleBoxFlat` |
| `physics_helpers.gd` | — | Utility functions (likely triangle/diagonal collision math) |
| `main_menu.gd` | — | Start button, skill tree button, settings button |

---

## 3. Color Palette (from `UITheme` autoload)

| Constant | Hex / Usage |
|---|---|
| `BG_DEEP` | `#131724` — default clear color, deepest background |
| `BG_CARD` | `#252830` — card/panel background |
| `BG_CARDHI` | hover tint of card |
| `LIME` | `#bdff06` — XP bar, level label, BOMB powerup |
| `CYAN` | `#6cd4ff` — railgun, speed button accent |
| `AMBER` | `#ffc266` — burn powerup, ARMED status |
| `ROSE` | `#ff7a8a` — nuke status, error/off states |
| `TEXT` | `#e8ecf3` — primary text |
| `TEXT_DIM` / `TEXT_MUTE` | secondary/disabled text |
| `LINE` | subtle border |
| `LINE_2` | arena border, slightly brighter |
| `LINE_STRONG` | strong border |
| `LIME_LINE` / `CYAN_LINE` / `AMBER_LINE` / `ROSE_LINE` | per-accent border colors |
| `R_SM` / `R_MD` | border-radius constants for small/medium cards |

**Usage pattern:** Always use `UITheme.CONSTANT` for colors. Never hardcode. Use `UITheme.make_card(bg, border, radius)` to generate `StyleBoxFlat` for buttons/panels.

---

## 4. Arena Grid

```
arena_left  = 13.0  px
arena_right = 377.0 px
arena_top   = 130.0 px
grid_cols   = 7
cell_width  = 52.0  px
cell_height = 38.0  px
max_rows    = 9     (rows 0–8)
death_row   = 8     (row 8 = game over)
launch_point = Vector2(195, arena_top + max_rows * cell_height + 20)
```

Grid is coordinate-based. `get_occupied_cells()` returns an `Array` of `Vector2(col, row)` across all bricks and orbs. Multi-cell bricks (bosses) fill multiple cells.

---

## 5. Game Loop / Round Lifecycle

```
_ready()
  └─ spawn_round_bricks_at_row0()    # initial row
  └─ spawn_ammo_orbs_at_row0()
  └─ start_slide_existing()          # slide all down 1 row (first round only visual shift)

[Player aims & taps] → _input() detects TouchRelease / MouseRelease
  └─ start_firing()
       ├─ If powerup armed → spawn special ball first (BOMB/RAILGUN)
       │    BURN → sets burn_round_active = true, no special ball spawned
       └─ is_spawning = true, balls_to_spawn = total ammo

_physics_process() (each frame)
  ├─ is_spawning loop → do_launch_ball() per spacing check
  ├─ is_sliding loop  → lerp bricks/orbs from slide_from → slide_to (ease_out_cubic)
  └─ is_dropping loop → lerp bricks/orbs down 1 row (quadratic ease)

[Ball returns or times out] → _on_ball_returned()
  └─ balls_in_play -= 1
  └─ if all balls done and no railgun pending → end_round()

end_round()
  ├─ current_round += 1
  ├─ tick_cooldowns()
  ├─ process_burn() on all bricks (damage ticks, halve stacks)
  ├─ reset hit_count on all bricks
  ├─ Progression.add_xp(pending_xp)
  ├─ boss shield regen
  ├─ spawn_guardians_if_needed()
  ├─ apply pending_ammo (bonus_ammo += pending_ammo)
  └─ spawn_round_content()
       ├─ try_spawn_pending_elite()
       ├─ try_spawn_boss()           # every 25 rounds: odd=mini, even=full
       ├─ try_spawn_elite()          # after r75, 12% chance, deferred if no space
       ├─ spawn_round_bricks_at_row0()  # 2–5 normal bricks
       ├─ spawn_ammo_orbs_at_row0()    # 50% skip after round 25
       ├─ try_spawn_special_bricks()   # armored(10%≥r15), triangle(50%), diagonal(60%), barrel(8%≥r10)
       └─ try_spawn_rainbow()          # 5% base, +5% per 10 rounds since last
  └─ start_slide_existing()           # all bricks/orbs slide down 1 row
  └─ [After slide] spawn_and_drop()   # new row-0 items drop to row-1 with dust VFX

[Any brick reaches death_row] → game_over()
```

---

## 6. Ball System

**Normal Ball** (`ball.gd`, `CharacterBody2D`):
- Uses `move_and_collide()` each physics frame
- `direction.bounce(normal)` on collision
- `take_damage(amount, dir)` called on collider if it has that method
- `add_burn_stack()` called on collider if `applies_burn == true`
- `wall_bounce_count` tracked; if >4 wall bounces with no brick hit in 1.5s → `unstick()` (nudges direction)
- Hard 15s timeout → force-return via `ball_landed` + `ball_returned` signals
- Ball returns when `position.y > 540` (just off bottom of arena)
- Trail rendered with fading circles in `_draw()`; color varies by ball type (blue=normal, orange=burn, red=powered)

**Signals:**
- `ball_returned` — `game_manager._on_ball_returned()` decrements `balls_in_play`
- `ball_landed(x_pos)` — first ball to land sets `next_launch_x` for next round

**Ball Types:**
| Scene | Script | Key Behavior |
|---|---|---|
| `ball.tscn` | `ball.gd` | Standard bouncing ball |
| `explosive_ball.tscn` | `explosive_ball.gd` | On brick hit → calls `game_manager.do_explosion(center, radius)` |
| `railgun_ball.tscn` | `railgun_ball.gd` | Pierces all bricks; `railgun_deaths_pending` counter; deferred kill VFX |
| `burn_ball.tscn` | `burn_ball.gd` | Standard ball with `applies_burn = true` |

**Mini-ball / Seeing Double:** Balls can split on hit (50% chance) if `has_seeing_double` boss reward is active. Mini-balls have `is_mini = true` and a limited `collisions_remaining` counter.

**Triple Shot:** If `has_triple_shot` boss reward active, each ammo spawns 3 balls.

---

## 7. Brick Types

All bricks implement:
- `take_damage(amount: int, hit_dir: Vector2, is_special: bool = false)` — `is_special = true` means bomb/railgun (bosses halve this)
- `destroy()` — calls `game_manager.add_score(get_brick_value())`, triggers death VFX
- Optionally: `process_burn()`, `add_burn_stack()`, `apply_explosion_crack(ring)`, `regenerate_shield()`, `strip_armor()`, `should_move_this_turn()`, `should_spawn_guardians()`

| Brick | Scene | HP | Special Behavior |
|---|---|---|---|
| **Normal** | `brick.tscn` | `= current_round` | Color tiers by HP (green→yellow→orange→red→blue→purple). Flash on hit. Cracked (from explosions) = 2× damage taken. |
| **Boss** | `boss_brick.tscn` | Varies by tier (see §9) | Multi-cell (w×h), optional shield bar, elite mode, final boss mode with movement + guardian spawning |
| **Armored** | `armored_brick.tscn` | `= current_round` | Immune to normal ball damage; `strip_armor()` removes immunity (triggered by explosions) |
| **Oil Barrel** | `oil_barrel.tscn` | 3 | On death → `game_manager.do_oil_barrel_explosion()`: 2× radius, strips armor, chain triggers |
| **Rainbow** | `rainbow_brick.tscn` | Normal HP | Shimmer shader animation; on death → random pickup drop (40% 2×ammo / 40% 2×dmg / 20% nuke) |
| **Guardian** | `guardian_brick.tscn` | 1 + 150 shield | Spawned by final boss each turn; absorbs shield damage first |
| **Triangle** | `triangle_brick.tscn` | `= current_round` | Spinning polygon hitbox; max 1 on board at a time; random spin speed/direction |
| **Diagonal** | `diagonal_brick.tscn` | `= current_round` | Grid-aligned right-triangle; 4 orientations; slightly more common than triangle |

**HP Color Tiers for Normal Bricks:**
```
HP ≥ 100 → purple  (0.55, 0.2, 0.7)
HP ≥ 50  → blue    (0.4, 0.55, 0.9)
HP ≥ 20  → orange  (0.95, 0.65, 0.3)
HP ≥ 10  → red     (0.93, 0.5, 0.45)
HP ≥ 5   → yellow  (0.95, 0.85, 0.4)
HP < 5   → green   (0.6, 0.85, 0.55)
```

---

## 8. Powerup System (Active Powerups)

All powerup state lives in `game_manager.gd`. There is no separate active powerup manager.

```gdscript
enum ActivePowerup { NONE, EXPLOSIVE, RAILGUN, BURN }
var active_powerup: int = ActivePowerup.NONE
```

| Powerup | Key | Cooldown | Behavior |
|---|---|---|---|
| **BOMB** | `EXPLOSIVE` | 4 rounds (−1/rank Quick Loader) | First ball replaced with `explosive_ball`. On hit: `do_explosion()` — 3 rings of falloff damage scaling with `ammo count × round`. Bosses take 50% reduced. |
| **RAILGUN** | `RAILGUN` | 8 rounds (−1/rank, currently disabled for testing) | First ball replaced with `railgun_ball` at 1500 px/s. Pierces everything, one-shots normals. Half damage to bosses. Consumes ALL ammo (single shot). Triggers railgun death sequence VFX. |
| **BURN** | `BURN` | 5 rounds | Round modifier — no special ball. Sets `burn_round_active = true`. All balls that round call `add_burn_stack()` on hit. At round end, `process_burn()` ticks DOT and halves stacks. Glowing fire shader on affected bricks. |
| **NUKE** | — (charge-based) | N/A | Charge resource (`nuke_charges`). Instantly destroys all bricks on board with big VFX + shake. Charges gained from pickups and boss rewards. |

**Toggling:** Player taps a powerup button → `toggle_powerup(type)`. If already armed, disarms. Can toggle before or during firing (applies next round for BURN).

**Super Weapons** (boss reward upgrades, booleans on game_manager):
- `super_bomb` — cluster munitions (TODO: define exact behavior)
- `super_railgun` — adjacent chain kills
- `super_burn` — spreads to neighboring bricks
- `super_nuke` — radioactive winter

---

## 9. Boss System

**Schedule (every 25 rounds):**
```
Round 25:   mini-boss 2×2, no shield
Round 50:   full boss 2×3, no shield     → boss reward popup
Round 75:   mini-boss 2×2
Round 100:  full boss 3×3, shield 10     → boss reward popup
Round 125:  mini-boss
Round 150:  full boss 3×4, shield 25     → boss reward popup
Round 200:  full boss 4×4, shield 50     → boss reward popup
Round 300+: final boss every 100 rounds — 7×2, shield 50, HP=1000+(iteration×500), moves every other turn, spawns guardians
```

**HP Formula:** `boss.health = current_round × hp_mult` (hp_mult=2 for scheduled full bosses, 1 for elites)

**Elite Bosses** (after round 75, 12% chance per round):
- Template from any previously killed boss in `boss_schedule` (≥50 rounds ago)
- HP = `current_round`, shield = `current_round` (full HP shield)
- Purple color
- Max 2 elites on board simultaneously
- If no clear footprint: deferred up to 8 rounds, reserves top-row columns
- On kill: drops random pickup (0=2×ammo, 1=2×dmg)

**Mini-Boss** (odd 25-multiples):
- 2×2, HP = `current_round`, no shield, tagged `is_mini_boss`
- On kill: spawns blue ammo orb (+5 ammo)

**Boss Reward Popup (`boss_reward.gd`):**
- Full-screen `CanvasLayer` (layer 100)
- Shows 3 cards picked from eligible pool
- Rewards: `+15 MAX AMMO`, `+1 NUKE CHARGE`, `TRIPLE SHOT`, `SEEING DOUBLE`, `SUPER BOMB`, `SUPER RAILGUN`, `SUPER BURN`, `SUPER NUKE`
- One-time rewards (triple shot, seeing double, supers) removed from pool once owned
- After choice: calls `manager.resume_round_after_reward()` → triggers pending round spawn

---

## 10. Scoring & Combo System

```gdscript
func add_score(points: int):
    var multiplied = points * max(1, combo_count)
    score += multiplied
    pending_xp += multiplied
```

**Combo system:**
- `combo_count` increments when bricks are destroyed within a 1.2s window
- At ≥3 combo: multiplier applies. Score popups color-coded by combo (white→yellow→orange→red)
- Combo bar drawn at top of arena (Node2D in HUD CanvasLayer, z_index=100)
- Sound escalation: `play_combo(combo_count)` pitches up by 1 semitone per additional combo
- Combo resets when window expires

**Score = XP.** `pending_xp` accumulates during firing, previewed on XP bar. Applied to `Progression.add_xp()` at round end.

---

## 11. Progression / Talent Tree (`progression.gd`)

**Save file:** `user://progression.save` (Dictionary via `file.store_var()`)

**XP Curve:**
- Levels 1–10: `50 + lvl × 20` XP per level (linear)
- Levels 10–25: `250 × 1.3^(lvl-10)` (gentle curve)
- Levels 25+: steep exponential `250 × 1.3^15 × 1.8^(lvl-25)`

**Leveling:** Each level awards 1 Skill Point (SP). SP used in talent tree.

**Talent Cost:** rank 1 = 1 SP, rank 2 = 2 SP, etc. (current rank + 1)

**Talents:**
| Key | Name | Max | Effect |
|---|---|---|---|
| `reinforced_balls` | Reinforced Balls | 5 | `+10%` ball damage per rank → `get_damage_multiplier()` |
| `quick_loader` | Quick Loader | 3 | `−1` powerup cooldown per rank → `get_cooldown_reduction()` |
| `bigger_blasts` | Bigger Blasts | 3 | `+15%` explosion radius per rank → `get_explosion_radius_mult()` |
| `burn_mastery` | Burn Mastery | 3 | `+1` burn tick (slower stack halving) → `get_burn_extra_ticks()` |
| `railgun_pierce` | Railgun Pierce | 3 | `+1` wall bounce for railgun → `get_railgun_bounces()` |
| `ammo_magnet` | Ammo Magnet | 5 | `+5%` chance for bonus orb per rank → `get_extra_orb_chance()` |
| `stacking_damage` | Stacking Hits | 5 | +1 dmg per same-brick hit (max = rank) → `get_stacking_damage_max()` |
| `recall` | Recall | 1 | Unlocks early round end button → `has_recall()` |
| `railgun_armor_break` | Armor Piercing | 1 | Railgun strips armor on hit → `has_railgun_armor_break()` |

---

## 12. Physics & Collision Layers

```
Layer 1 = walls + bricks + arena bounds (mask 0)
Layer 2 = balls (mask 1 — hits layer 1)
Layer 4 = orbs/pickups (mask 2 — hit by layer 2 balls)
```
Balls **do not** collide with each other (different layers).
All physics uses `CharacterBody2D` with `move_and_collide()` — no `RigidBody2D`.

---

## 13. Sound System (`sound_manager.gd`)

Each sound key maps to a file in `assets/audio/`:

| Key | File | Trigger |
|---|---|---|
| `hit` | `brickimpact.wav` | Ball hits brick (via wall too) |
| `destroy` / `destroy_alt` | `brickbreak1.wav` / `brickbreak2.wav` | Brick destroyed (alternates) |
| `multi_destroy` | `multibrickbreak.wav` | Multiple railgun kills at once |
| `orb_collect` | `ammoOrbActivate.wav` | Ammo orb collected |
| `explode` | `bomb.wav` | Explosion |
| `nuke` | `nuke.wav` | Nuke used |
| `launch` | `ballshoot.wav` | Ball spawned |
| `railgun` | `railgunshot.mp3` | Railgun fired |
| `reload` | `reload.wav` | Round ready / after drop complete |
| `combo` | `combo.wav` | Combo hit (pitched by semitone) |
| `powerup` | `ammoOrbActivate.mp3` | Powerup armed |
| `menu_select` | `menuselect.wav` | Menu interaction |

`play(key)` creates a **temporary** `AudioStreamPlayer`, plays it, and frees on finish. Volume is read from `settings_menu.get_volume_db(key)`.

---

## 14. HUD Layout (`scenes/main.tscn` → `$HUD` CanvasLayer)

Top bar (from top of screen, y≈0–130):
```
[LevelCard: Lv.N]  [SPLabel: N SP]  [RoundLabel: 02]  [XPBar]  [SpeedButton: 1x]  [GearButton: ⚙]
```

Center HUD (arena bottom, y≈540+):
```
[AmmoLabel: × 49]  ← moves to next_launch_x each round
```

Powerup Bar (bottom of screen):
```
[ExplosiveButton | BOMB  / ARMED/N ROUNDS]
[RailgunButton  | RAILGUN / ARMED/N ROUNDS]
[BurnButton     | BURN   / ARMED/N ROUNDS]
[NukeButton     | NUKE   / × N READY / NO CHARGES]
```

Score + HighScore row:
```
[ScoreLabel: 0000]  [HighScoreLabel: SCORE · BEST N]
```

Combo bar: `Node2D` added to `$HUD` dynamically in `_ready()`, drawn via `_draw_combo_bar()`.
XP Preview fill: separate `ColorRect` overlaid on XP bar during firing to show pending XP gain.

---

## 15. Visual Effects (all procedural, no Particle nodes)

All VFX are done by spawning `ColorRect` nodes into `$ParticleContainer`, tweening position/alpha, then freeing.

| Effect | Trigger | Implementation |
|---|---|---|
| Brick destroy particles | `spawn_brick_particles_directional()` | 8–12 colored rects burst outward in hit direction |
| Explosion | `spawn_explosion_vfx()` | 16 orange/yellow rects radiate outward |
| Oil barrel explosion | `do_oil_barrel_explosion()` | 24 fire + 8 smoke rects, larger radius |
| Railgun trail | `spawn_railgun_trail()` | 4 cyan electric sparks scatter |
| Dust on landing | `spawn_dust()` | 6 gray rects scatter sideways |
| Screen flash | `spawn_screen_flash()` | Full-arena white ColorRect, quick fade |
| Score popups | `spawn_score_popup()` | Floating label, color by combo level |
| Modifier popups | `spawn_modifier_popup()` | Centered label, floats upward |
| Ammo popups | `spawn_ammo_popup()` | Near launch point, size/color by count tier |
| Combo bar | `_draw_combo_bar()` | Custom draw on Node2D in HUD |
| Ball trail | In `ball.gd _draw()` | Fading circles of past positions |
| Burn fire shader | `assets/shaders/burn.gdshader` | Applied to `ColorRect` on each brick with burn stacks |
| Board clear shader | `assets/shaders/board_clear.gdshader` | Used on board clear event |
| Crack overlays | `_draw_cracks()` on `crack_overlay` Node2D | Random seeded lines, 3 levels of intensity |
| Camera shake | `add_shake(amount)` → `position` offset in `_physics_process` | Decays via lerp |

---

## 16. Magazine / Launcher Visual System

**Magazine** (`magazine.gd`, `$Magazine`):
- Drawn procedurally as a pipe at the bottom of the arena
- Ball queue is visualized as circles inside the pipe
- `set_ammo(n)` — reset queue display
- `fire_ball()` — remove one ball from pipe animation
- `return_ball()` — add ball back (for missed/cancelled rounds)
- `add_ball_plop()` — animate a new ball plopping in (bonus ammo gained)
- `shift_entrance_to(x)` — animate pipe entrance sliding to new `next_launch_x`
- `modifier_tint` — colored overlay for 2×ammo (amber) or 2×dmg (red) rounds

**Launcher** (`launcher.gd`, `$Launcher`):
- `Node2D` drawn procedurally using Godot's `_draw()` API
- 5 visual modes matching `LauncherType` enum: DEFAULT, BOMB, RAILGUN, BURN, NUKE
- Each has distinct cannon shape and animations (fuse spark, energy rings, pilot flame)
- Rotates to aim angle when player is aiming
- Railgun mode: charging animation with 3 energy rings that light up sequentially

---

## 17. Settings Menu (`settings_menu.gd`)

Instantiated at startup inside `main.tscn` (not loaded separately). Toggled by GearButton.

Exposes:
- `sfx_enabled: bool`
- `music_enabled: bool`  
- `grid_enabled: bool` — controls whether grid lines draw in arena
- `get_volume_db(sound_key)` — per-category volume levels

`game_manager.refresh_draw()` must be called when `grid_enabled` changes so the arena redraws.

---

## 18. Save / Persist

| File | Content | Script |
|---|---|---|
| `user://progression.save` | `{xp, level, skill_points, total_sp, talents}` Dictionary | `progression.gd` |
| `user://highscore.save` | Single integer high score | `game_manager.gd` |

Both use Godot's `FileAccess` with `store_var()` / `get_var()`.

---

## 19. Known TODOs / Incomplete Systems

From the codebase and comments:

1. **Nuke rework** — Current nuke is instant board clear. Design intent is "aimed Mama Mega shockwave." Not yet implemented.
2. **Super weapon effects** — `super_bomb`, `super_railgun`, `super_burn`, `super_nuke` booleans exist and are labeled in UI but the actual gameplay effects are not fully implemented.
3. **`powerup_manager.gd`** — This standalone script is a separate/older system with a different powerup enum (`PORTAL_SHOT`, `SHUFFLE`, `REWIND`, etc.) that is **not connected** to the active game. The real powerup system is inline in `game_manager.gd`.
4. **`railgun_cooldown_max = 0`** — Set to 0 in code with comment "disabled for testing — railgun has no cooldown." Needs a proper value for production.
5. **Debug prints** — `start_firing()` contains debug `print()` statements for sound debugging. Should be removed.
6. **Recall talent** — Talent exists and unlocks at rank 1, but the UI button to trigger early round end may not be wired in the HUD.
7. **`seeing_double` mini-ball** — The state exists (`is_mini`, `can_split`, `collisions_remaining`) but the actual split spawning logic may need to be confirmed/completed in `ball.gd` or `game_manager.gd`.

---

## 20. Adding New Features — Patterns to Follow

### Adding a New Brick Type
1. Create `scenes/my_brick.tscn` (extend `StaticBody2D`)
2. Create `scripts/my_brick.gd` — implement `take_damage()`, `destroy()`, `get_brick_value()`
3. Preload at top of `game_manager.gd`: `const MY_BRICK_SCENE = preload("res://scenes/my_brick.tscn")`
4. Add spawn logic in `try_spawn_special_bricks()` with chance/round threshold
5. Add to `get_occupied_cells()` if it's a standard 1×1 brick (auto-handled for multi-cell if it has `grid_width`/`grid_height`)

### Adding a New Powerup
1. Add to `enum ActivePowerup` in `game_manager.gd`
2. Add cooldown variable (`my_powerup_cooldown`, `my_powerup_cooldown_max`)
3. Add HUD button nodes to `scenes/main.tscn` under `$HUD/PowerupBar`
4. Wire button in `_ready()`: `my_button.pressed.connect(func(): toggle_powerup(ActivePowerup.MY_POWERUP))`
5. Add to `tick_cooldowns()`, `get_cooldown()`, `set_cooldown()`
6. Handle in `start_firing()` match block (spawn special ball or set round modifier)
7. Add to `update_all_powerup_ui()` and `update_launcher_type()`
8. Add launcher visual mode in `launcher.gd` `LauncherType` enum + `_draw_my_launcher()` function

### Adding a New Talent
1. Add key to `talents` dict in `progression.gd`
2. Add definition to `talent_defs` with `name`, `desc`, `max`, `row`, `col`
3. Add getter function (e.g. `get_my_effect() -> int/float`)
4. Call getter where the effect applies in `game_manager.gd`, `ball.gd`, or brick scripts

### Adding a New Boss Reward
1. Add to `enum Reward` in `boss_reward.gd`
2. Add entry to `REWARD_DATA` dict
3. Add eligibility check in `_build_pool()` (add `if not manager.has_my_reward:`)
4. Add state variable to `game_manager.gd` (e.g. `var has_my_reward: bool = false`)
5. Handle the reward ID in `_apply_reward()` in `boss_reward.gd`

### Interacting with game_manager from a Brick Script
```gdscript
var manager = get_tree().get_first_node_in_group("game_manager")
if manager:
    manager.add_score(points)
    manager.do_explosion(global_position, radius)
    manager.spawn_modifier_popup("TEXT", Color(1, 0.5, 0))
    manager.on_boss_killed(self)
```
`game_manager` registers itself via `add_to_group("game_manager")` in `_ready()`.

---

## 21. File Quick Reference

```
project.godot            ← engine config, autoloads, viewport
scenes/main.tscn         ← main game scene (open in editor to see HUD node tree)
scenes/main_menu.tscn    ← title screen
scenes/skill_tree.tscn   ← talent tree screen
scripts/game_manager.gd  ← MOST IMPORTANT FILE (~2200 lines)
scripts/progression.gd   ← XP/talent autoload
scripts/ui_theme.gd      ← color constants autoload
scripts/ball.gd          ← ball physics
scripts/brick.gd         ← normal brick
scripts/boss_brick.gd    ← boss brick
scripts/boss_reward.gd   ← boss kill reward popup
scripts/sound_manager.gd ← audio system
assets/shaders/burn.gdshader        ← fire VFX on burned bricks
assets/shaders/board_clear.gdshader ← board clear VFX
assets/audio/            ← all .wav / .mp3 sound effects
assets/fonts/            ← Inter.ttf, Rajdhani-Bold.ttf
assets/music/            ← lofi music tracks
export/                  ← web + context-catchup export batches
```

---

*End of report. This document covers the full game state as of April 30, 2026.*
