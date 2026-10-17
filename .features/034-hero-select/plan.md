# Plan: feature 034, "Choose your hero" (character selection)

## Context
The user wants a character selection menu before the game starts, so the player can choose to play **Leo** or **Nela**. The other hero then becomes the AI companion. More heroes may come later, and the player will then also pick a companion, so the design must scale beyond two.

**Decisions taken with the user:**
- **Each hero keeps their playstyle in either role.**
  - Nela, when played, is a ranged slingshot fighter: more reach, less damage and HP.
  - Leo, as companion, is a melee bodyguard.
  - The signature crafts follow the hero: Sturdy Stick for Leo, Slingshot for Nela.
- **The selection is its own screen after Play.** The flow is Title → 3/7 Nights → "Choose your hero" → Loading. Continue skips the screen because the save remembers the party.

**What the code does today.** Each role is wired to one character:
- `PlayerBoy.tscn` (`player_controller.gd`, `leo.glb`) and `Sibling.tscn` (`companion_controller.gd`, `nela.glb`) are fixed instances in `TestWorld.tscn`.
- Names and portraits are hard-coded in the HUD, `ui_kit.gd`, the loading tips and the end screen.
- Crafting gives the stick to the `"player"` group and the slingshot to `"companions"`.
- The save stores `player{stick}` and `sibling{slingshot}`.

## Approach: hero data applied to the two role shells

### 1. Hero data (new)
**`scripts/characters/hero_definition.gd`**, `class_name HeroDefinition`, is a Resource with:
- **Identity:** `id`, `display_name`, `tagline` (for example "Brave stick-fighter" / "Sharp-eyed slinger"), `portrait` (a Texture2D, so `res://assets/icons/portrait_*.png` is reused), `ui_color`.
- **Body:** `model_scene`, `model_scale`, `clips`, `reference_speed`, `step_distance`, `capsule_height`, `hurt_sfx`.
- **Combat:**
  - `stats` (the existing `CharacterStatsDefinition`)
  - `move_speed`
  - `attack_range`
  - `attack_cooldown`
  - `ranged` (a bool; when set, attacks fire a pebble)
- **Signature:** `signature_recipe`, `signature_label` and `signature_icon`, plus `signature_damage_bonus` and `signature_range_factor`.
- **Select screen:** `rating_health`, `rating_power`, `rating_reach` (1–3 pips each).

**`resources/heroes/leo.tres` and `resources/heroes/nela.tres`:**
- **Leo** reuses `player_stats.tres`: 50 HP, 4 attack, range 2.0, melee, Sturdy Stick +2 damage.
- **Nela** reuses `sibling_stats.tres`: 40 HP, 3 attack. Her range is 4.5 when played and 2.0 → 4.0 as companion (today's value), so the definition keeps a separate `companion_attack_range`. She is ranged, and the Slingshot gives her range ×1.6 when played and ×2 as companion. The factor is stored per role, the same way as the range.
- **Display names:** set `display_name` in the stats `.tres` files to "Leo" and "Nela".

**`scripts/characters/hero_roster.gd`** (`class_name HeroRoster`, static) provides:
- `all()`: ordered list of preloaded definitions.
- `get_hero(id)`.
- `default_companion(hero_id)`: the first other hero. This is the hook for a future companion picker.
- `node_for(id)`: looks up the group `"hero_<id>"`.

### 2. Party state (`game_manager.gd`)
- Add `hero_id: StringName = &"leo"` and `companion_id: StringName = &"nela"`, plus `party_hero()` and `party_companion()`. The defaults keep the smoke tests and old saves on Leo + Nela.
- Add `open_hero_select(nights)`: sets `nights_to_win` and changes scene to `HeroSelect.tscn`.
- Change `start_run(nights, hero, companion)`: optional arguments that set the party. "Again" keeps the current party.
- Change `continue_run()`: reads the party from the save before loading.

### 3. Role shells take a hero (no new spawner)
In Godot, a parent's `_enter_tree` runs before its children's `_ready`. So both controllers apply the hero in `_enter_tree()`:
1. Resolve `GameManager.party_hero()` (player) or `party_companion()` (companion), unless the `hero` export is already set.
2. Configure `$Visual` (`model_scene`, `model_scale`, `clips`, speeds) and the collision capsule.
3. Join the group `"hero_<id>"`.

`TestWorld.tscn`, the camera `target_path` and the `"player"` and `"companions"` groups stay as they are.

**`player_controller.gd`:**
- Takes stats, speed, range and cooldown from the hero.
- When `hero.ranged`, `_perform_attack` fires a pebble; the damage lands on impact instead of after the melee wind-up.
- `upgrade_stick` becomes a generic `apply_signature()` with a `has_signature` flag; every call site (crafting, save, tests) is updated.
- The bandage targets the companion by group, and its text uses the companion's name.

**`companion_controller.gd`:**
- Takes stats, move speed, range, clips and hurt sound from the hero.
- `_attack_mob` fires the pebble when the hero is ranged; otherwise it plays a melee hit burst.
- Gets the same `apply_signature()`.
- Keeps `definition` (`CompanionDefinition`) for task tuning. Its `move_speed` and `attack_*` fields are overridden by the hero.

**New `scripts/characters/pebble_shot.gd`:** a tiny Node3D with a small stone mesh in the house style. It tweens an arc from the shooter's hand to the target over about 0.18 s, calls `take_damage` on arrival if the target is still valid, and shows `Fx.burst(&"hit")`.

**Crafting (`crafting_manager.gd`):** `sturdy_stick` and `slingshot` look up `HeroRoster.node_for(&"leo" / &"nela")` and call `apply_signature()`. They are available while that hero has no signature yet, whichever role the hero is in.

### 4. "Choose your hero" screen (new)
**Files:** `scenes/ui/HeroSelect.tscn` and `scripts/ui/hero_select.gd`, built in code with `UiKit` and `HudWidgets` in the campcraft style.

**Backdrop:** reuse `title_backdrop.gd` with a new export, `seat_heroes = false`. A small `hero_stage.gd` stands the roster's models in a row by the fire, with a closer front camera and a slow drift.
- The selected hero plays `cheer` and gets an ember ring decal or light at their feet.
- The others idle, slightly dimmed.

**Layout at 1280×720 base:**
- **Top:** a ribbon title "Choose your hero" and a goal line ("Survive N nights").
- **Bottom:** an HBox of hero cards, one wood plate each, roughly 300×190, built from `HeroRoster.all()` so a third hero simply adds a card. Each card has:
  - the portrait;
  - the name in Cinzel;
  - the tagline;
  - three pip rows (heart = Health, fist/star = Power, target = Reach) using existing `Glyph` kinds;
  - a "Signature: <icon> Slingshot" line.
  - The selected card gets the brass glow from AbilitySlot's highlight and is lifted by 8 px.
- **Under the cards:** a small "Companion: <portrait> Nela" tag showing `default_companion(selected)`. This is where a companion picker step goes later.
- **Buttons:** "Back" (to the title) and "Start" (calls `GameManager.start_run(nights, hero, companion)`).

**Input:**
- Click a card or a model to select.
- ←/→ or A/D cycle through the heroes.
- Enter starts; Esc goes back.
- Focus is set on the Start button for keyboard and gamepad.
- The last pick is remembered in `GameManager.hero_id` and pre-selected.

**Title screen:** the 3/7 Nights buttons call `GameManager.open_hero_select(n)` instead of `start_run`.

### 5. Names and portraits from the party
- **`hud.gd`:**
  - The hero bar shows `party_hero()`'s portrait and name.
  - The companion frame (`_build_sibling_frame`) shows `party_companion()`'s.
  - The bandage tooltip uses the companion's name.
  - The signature slot on the hero bar is the attack slot's sub-icon.
- **`ui_kit.gd`:** the controls and picture-guide rows that name "Nela" and use `portrait_nela` take the companion from the party.
- **`loading_screen.gd`:** the tip uses the companion's name and portrait.
- **`end_screen.gd`:** shows the played hero's portrait.

### 6. Save (`save_manager.gd`)
- Add `"party": {"hero", "companion"}` to the snapshot.
- Change the role entries:
  - `player{xp, signature}`
  - `sibling{xp, signature, task}`
- `apply()` reads `signature`, falling back to the old `stick` and `slingshot` keys. `party` is optional with a Leo/Nela default, so old saves still load without a VERSION bump.
- `continue_run` sets the party from the save.
- The title screen's Continue tooltip shows the hero's name.

### 7. Docs
- `.features/034-hero-select/` with `plan.md`, `status.md`, `decisions.md` and `test-plan.md`.
- `docs/design/game-design-spec.md`: a new section on hero selection, and the companions text updated so heroes can swap roles.
- `docs/requirements/requirements.md`: "One playable boy character" becomes "Playable heroes chosen before a run".
- `docs/roadmap/roadmap.md`: a companion picker step added.

## Critical files
- **New:**
  - `scripts/characters/{hero_definition,hero_roster,pebble_shot}.gd`
  - `resources/heroes/{leo,nela}.tres`
  - `scripts/ui/hero_select.gd`, `scripts/ui/hero_stage.gd`, `scenes/ui/HeroSelect.tscn`
- **Edited:**
  - `scripts/core/game_manager.gd`
  - `scripts/player/player_controller.gd`
  - `scripts/companions/companion_controller.gd`
  - `scripts/core/crafting_manager.gd`
  - `scripts/core/save_manager.gd`
  - `scripts/ui/{title_screen,title_backdrop,hud,ui_kit,loading_screen,end_screen}.gd`
  - `tests/automated/smoke_run.gd`

**Reuse:** `CharacterVisual` exports, `UiKit.panel`, `title`, `label` and `button`, `HudWidgets.icon_button`, `Glyph`, `Portrait`, `AbilitySlot` highlight glow, `Fx.burst` and `float_text`, `HealthBar3D`, and `LoadingScreen.load_scene`.

## Verification
- **Smoke (`tools/check.sh`)**: the existing win, loss and continue scenarios keep passing on the default Leo + Nela party. Add a new **"nela hero" scenario**:
  1. Set the party to nela/leo, then `_start_fresh_run`.
  2. Check that the `"player"` node is in `hero_nela` and the companion is in `hero_leo`.
  3. Check that the player's attack range is greater than 4, and that a pebble kills an imp within range.
  4. Check that crafting the slingshot upgrades the player and the stick upgrades the companion.
  5. Check that the HUD hero name is "Nela".
  6. Check that a save → continue round trip keeps the party.

  Also instantiate `HeroSelect.tscn` once, select through the roster and free it, so script errors fail the check.
- **Screenshots (`$S/shots.sh`):** add a hero-select shot with each hero selected, and a day-HUD shot playing as Nela. Review them at 1600×900 and 1280×720 for overlap and readability.
- **Checks:** `GODOT=$S/godot/godot flock $S/godot.lock tools/check.sh` must report validate OK and smoke PASSED.
- **Commit and report:** commit to `ccr-fe888da3-3beawe`, push, and send the user the screenshots with a short summary.
