extends Node

## validate_project.gd
##
## Headless project validator (see docs/testing/test-strategy.md,
## "Data validation"). Runs as a scene so autoloads exist. From the
## repo root:
##
##   godot --headless --path game res://tools/validate_project.tscn
##
## 1. Loads every .gd, .tscn and .tres under res:// and fails on any
##    that does not load (parse errors, broken references, cycles).
## 2. Checks data integrity: ids are set and unique, scene paths
##    resolve, and every cost / recipe input refers to a real item.
## 3. Fails on comments that name work items (feature numbers, tickets,
##    .scratch paths), which docs/architecture/coding-standards.md
##    leaves to the commit log.
## 4. Measures every hero clip as data (tools/clip_checks.gd): a clip
##    for each mapped state, loop wraps, foot slide and action lengths.
##    Checks on "report" print one summary line; `-- --clips` prints
##    every number. Only enforced ones fail.
## Exits 0 when clean, 1 otherwise.

const ClipChecks: GDScript = preload("res://tools/clip_checks.gd")
const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons"]
## Where the issue tracker keeps one folder per feature slug, so "<slug> NN"
## or "<slug> spec" in a comment reads as a work-item reference.
const SCRATCH_DIR: String = "res://../.scratch"
## Work-item references a comment must not carry; a bare zero-padded 0NN
## is a feature number. Case-insensitive, matched over each run of
## consecutive comment lines so a reference wrapped onto two still counts.
const WORK_ITEM_PATTERNS: Array[String] = [
	"\\bfeatures?\\s+\\d{3}\\b",
	"\\btickets?\\s+#?\\d+\\b",
	"\\.scratch/",
	"\\bplaytest[ -]\\d+\\b",
	"\\bPR\\s*#\\d+",
	"(?<![\\w/.])0\\d\\d(?![\\w/-])",
]

var _errors: PackedStringArray = PackedStringArray()


## The boot splash exists and the loading screen builds.
func _validate_key_art() -> void:
	var splash: String = String(ProjectSettings.get_setting("application/boot_splash/image", ""))
	if splash == "" or not FileAccess.file_exists(splash):
		_fail("boot splash image missing: '%s'" % splash)
	for i in LoadingScreen.SCREENS.size():
		var entry: Array = LoadingScreen.SCREENS[i]
		if not ResourceLoader.exists(String(entry[0])):
			_fail("loading screen art missing: %s" % entry[0])
		for tip in entry[1]:
			if String(tip[1]) != "" and not String(tip[1]).begins_with("{") and not ResourceLoader.exists(String(tip[1])):
				_fail("loading tip icon missing: %s" % tip[1])
		var screen: LoadingScreen = LoadingScreen.preview(0.6, i)
		if screen.get_child_count() == 0:
			_fail("LoadingScreen.preview(%d) built nothing" % i)
		screen.free()


## The export presets tools/export_playtest.sh builds carry the
## "playtest" feature tag, so playtest builds open every chapter.
func _validate_export_presets() -> void:
	var presets: ConfigFile = ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		_fail("export_presets.cfg missing or unreadable")
		return
	var found: Dictionary = {}
	for section in presets.get_sections():
		if section.begins_with("preset.") and not section.ends_with(".options"):
			var preset_name: String = String(presets.get_value(section, "name", ""))
			found[preset_name] = true
			var features: PackedStringArray = String(presets.get_value(section, "custom_features", "")).split(",", false)
			if not "playtest" in features:
				_fail("export preset '%s' lacks the playtest feature tag" % preset_name)
	for needed in ["Windows Desktop", "Linux"]:
		if not found.has(needed):
			_fail("export preset '%s' (tools/export_playtest.sh) is missing" % needed)


func _ready() -> void:
	var files: PackedStringArray = PackedStringArray()
	_collect("res://", files)
	for path in files:
		var loaded: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if loaded == null:
			_fail("failed to load %s" % path)
		elif loaded is GDScript and not (loaded as GDScript).can_instantiate():
			_fail("script does not compile: %s" % path)
	_validate_data()
	_validate_key_art()
	_validate_export_presets()
	_validate_saving_systems()
	_validate_run_lifecycle_contract()
	_validate_rebuild_missing_keys()
	_validate_comments(files)
	_validate_hero_clips()
	if _errors.is_empty():
		print("validate_project: OK (%d files checked)" % files.size())
		get_tree().quit(0)
	else:
		for message in _errors:
			printerr("validate_project: " + message)
		printerr("validate_project: FAILED with %d error(s)" % _errors.size())
		get_tree().quit(1)


func _validate_data() -> void:
	var item_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/items/"):
		var item: ResourceDefinition = res as ResourceDefinition
		if item == null:
			_fail("%s is not a ResourceDefinition" % res.resource_path)
			continue
		_check_id(item.id, item.resource_path, item_ids)

	var building_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/buildings/"):
		var building: BuildingDefinition = res as BuildingDefinition
		if building == null:
			_fail("%s is not a BuildingDefinition" % res.resource_path)
			continue
		_check_id(building.id, building.resource_path, building_ids)
		_check_scene(building.scene_path, building.resource_path)
		_check_items(building.cost, item_ids, building.resource_path)

	var mob_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/mobs/"):
		var mob: MobDefinition = res as MobDefinition
		if mob == null:
			_fail("%s is not a MobDefinition" % res.resource_path)
			continue
		_check_id(mob.id, mob.resource_path, mob_ids)
		_check_scene(mob.scene_path, mob.resource_path)
		if mob.drop_item != &"" and not item_ids.has(mob.drop_item):
			_fail("%s drops unknown item '%s'" % [mob.resource_path, mob.drop_item])
		if mob.drop_item != &"" and mob.drop_chance <= 0.0 and mob.drop_pity <= 0:
			_fail("%s has a drop_item but can never drop it" % mob.resource_path)
		if mob.is_boss:
			# A boss runs BossController and is never farmed.
			var boss_scene: PackedScene = mob.get_scene()
			var boss: Node = boss_scene.instantiate() if boss_scene != null else null
			if not boss is BossController:
				_fail("%s is a boss but its scene is not a BossController" % mob.resource_path)
			elif (boss as BossController).summon_definition == null:
				_fail("%s has no summon_definition" % mob.resource_path)
			if mob.drop_item != &"":
				_fail("%s is a boss and must not drop loot" % mob.resource_path)
			if boss != null:
				boss.free()

	var recipe_ids: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		var recipe: CraftingRecipe = res as CraftingRecipe
		if recipe == null:
			_fail("%s is not a CraftingRecipe" % res.resource_path)
			continue
		_check_id(recipe.id, recipe.resource_path, recipe_ids)
		_check_items(recipe.inputs, item_ids, recipe.resource_path)
		if recipe.effect != &"" and not CraftingRecipe.EFFECTS.has(recipe.effect):
			_fail("%s has unknown effect '%s'" % [recipe.resource_path, recipe.effect])
		if recipe.effect == &"" or recipe.output_id != &"":
			if not item_ids.has(recipe.output_id):
				_fail("%s outputs unknown item '%s'" % [recipe.resource_path, recipe.output_id])
		if recipe.result_icon() == null:
			_fail("%s has no result icon (output item icon or icon_name)" % recipe.resource_path)

	_validate_heroes(recipe_ids)
	_validate_hero_contact_times()
	_validate_perks()
	_validate_hero_perks()
	_validate_perk_problems()
	_validate_badges()
	_validate_journal()
	_validate_audio()
	_validate_story()

	# Every item a building or recipe needs must be obtainable somewhere:
	# as a resource node yield/bonus or as a recipe output.
	var obtainable: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		if (res as CraftingRecipe).output_id != &"":
			obtainable[(res as CraftingRecipe).output_id] = true
	for res in DefinitionLoader.load_all("res://resources/mobs/"):
		var drop: StringName = (res as MobDefinition).drop_item
		if drop != &"" and ((res as MobDefinition).drop_chance > 0.0 or (res as MobDefinition).drop_pity > 0):
			obtainable[drop] = true
	var node_scenes: PackedStringArray = PackedStringArray()
	_collect("res://scenes/resources/", node_scenes)
	for scene_path in node_scenes:
		if not scene_path.ends_with(".tscn"):
			continue
		var node: ResourceNode = (load(scene_path) as PackedScene).instantiate() as ResourceNode
		if node == null:
			continue
		if node.definition != null:
			obtainable[node.definition.id] = true
		if node.bonus_definition != null:
			obtainable[node.bonus_definition.id] = true
		node.free()
	var needed: Dictionary = {}
	for res in DefinitionLoader.load_all("res://resources/buildings/"):
		needed.merge((res as BuildingDefinition).cost)
	for res in DefinitionLoader.load_all("res://resources/recipes/"):
		needed.merge((res as CraftingRecipe).inputs)
	for key in needed.keys():
		if not obtainable.has(StringName(key)):
			_fail("item '%s' is needed by a cost/recipe but nothing produces it" % key)


## The audio library: every listed id has at least one variant file,
## every Fx.burst kind has a sound, and the loops are set.
func _validate_audio() -> void:
	var library: AudioLibrary = load("res://resources/audio/audio_library.tres") as AudioLibrary
	if library == null:
		_fail("res://resources/audio/audio_library.tres is missing or not an AudioLibrary")
		return
	for id in library.volumes.keys():
		if library.streams_for(StringName(id)).is_empty():
			_fail("audio id '%s' has no %s/%s_1.ogg" % [id, library.sfx_dir, id])
	for id in library.ui_ids:
		if not library.has_sound(id):
			_fail("audio ui id '%s' is not in volumes" % id)
	for kind in Fx.BURSTS.keys():
		if not library.has_sound(kind) and not Fx.SILENT_BURSTS.has(kind):
			_fail("Fx burst '%s' has no sound in the audio library" % kind)
	for loop_name in ["music_day", "music_night", "music_boss", "ambience_day", "ambience_night", "ambience_campfire"]:
		if library.get(loop_name) == null:
			_fail("audio library has no %s" % loop_name)
	for bus_name in [&"Music", &"SFX", &"UI", &"Voice"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			_fail("audio bus '%s' missing (default_bus_layout.tres)" % bus_name)


func _check_id(id: StringName, path: String, seen: Dictionary) -> void:
	if id == &"":
		_fail("%s has an empty id" % path)
	elif seen.has(id):
		_fail("%s duplicates id '%s' from %s" % [path, id, seen[id]])
	else:
		seen[id] = path


func _check_scene(scene_path: String, owner_path: String) -> void:
	if scene_path == "" or not ResourceLoader.exists(scene_path):
		_fail("%s points at missing scene '%s'" % [owner_path, scene_path])


func _check_items(costs: Dictionary, item_ids: Dictionary, owner_path: String) -> void:
	for key in costs.keys():
		if not item_ids.has(StringName(key)):
			_fail("%s references unknown item '%s'" % [owner_path, key])
		if int(costs[key]) <= 0:
			_fail("%s has non-positive amount for '%s'" % [owner_path, key])


func _collect(dir_path: String, out: PackedStringArray) -> void:
	if dir_path.trim_suffix("/") in SKIP_DIRS:
		return
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				_collect(full, out)
		elif name.ends_with(".gd") or name.ends_with(".tscn") or name.ends_with(".tres"):
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()


func _fail(message: String) -> void:
	_errors.append(message)


## Every hero's clips, measured (ClipChecks). Fails on enforced checks
## over their limit; the reported ones are counted on one line, or all
## printed with `-- --clips`.
func _validate_hero_clips() -> void:
	var rows: Array[Dictionary] = []
	for hero in HeroRoster.all():
		rows.append_array(ClipChecks.check_hero(hero))
	var verbose: bool = OS.get_cmdline_user_args().has("--clips")
	var reported: int = 0
	for row in rows:
		if row.over and row.enforced:
			_fail("clip " + ClipChecks.describe(row))
		elif row.over:
			reported += 1
		if verbose:
			print("validate_project: clip " + ClipChecks.describe(row))
	print("validate_project: hero clips: %d checks, %d over their limit on report (-- --clips lists them)"
		% [rows.size(), reported])


## Every hero on the select screen is complete. Tool tiers:
## each of its tiers points to an existing tool-tier recipe, and every
## tool-tier recipe belongs to exactly one hero's tier.
func _validate_heroes(recipe_ids: Dictionary) -> void:
	var tier_recipes: Dictionary = {}
	var hero_ids: Dictionary = {}
	for hero in HeroRoster.all():
		_check_id(hero.id, hero.resource_path, hero_ids)
		if hero.model_scene == null or hero.stats == null or hero.portrait == null:
			_fail("%s needs a model, stats and a portrait" % hero.resource_path)
		for n in range(1, hero.tier_count() + 1):
			var tier: ToolTier = hero.tier(n)
			if tier == null or tier.recipe == &"":
				_fail("%s: tool tier %d is empty" % [hero.resource_path, n])
				continue
			var recipe: CraftingRecipe = load(recipe_ids[tier.recipe]) as CraftingRecipe if recipe_ids.has(tier.recipe) else null
			if recipe == null:
				_fail("%s: tool tier %d has unknown recipe '%s'" % [hero.resource_path, n, tier.recipe])
			elif recipe.effect != CraftingRecipe.EFFECT_TOOL_TIER:
				_fail("%s: tool tier %d's recipe '%s' needs the tool_tier effect" % [hero.resource_path, n, tier.recipe])
			if tier_recipes.has(tier.recipe):
				_fail("%s: recipe '%s' is already a tool tier of %s" % [hero.resource_path, tier.recipe, tier_recipes[tier.recipe]])
			tier_recipes[tier.recipe] = hero.id
			for effect in tier.effects:
				if not ToolTier.EFFECTS.has(effect):
					_fail("%s: tool tier %d has unknown effect '%s'" % [hero.resource_path, n, effect])
			for problem in tier.problems():
				_fail("%s: tool tier %d %s" % [hero.resource_path, n, problem])
	for id in recipe_ids.keys():
		var recipe: CraftingRecipe = load(recipe_ids[id]) as CraftingRecipe
		if recipe != null and recipe.effect == CraftingRecipe.EFFECT_TOOL_TIER and not tier_recipes.has(id):
			_fail("%s is a tool tier recipe, but no hero's tier names it" % recipe.resource_path)
	if HeroRoster.all().size() < 2:
		_fail("the roster needs at least two heroes (a hero and a companion)")


## Each hero's attack contact frame: inside the attack
## clip, and at most the wind-up cap after the attack starts at play
## speed, in either role (checked at the slower one). 0 is the instant
## hit, always fine.
func _validate_hero_contact_times() -> void:
	var slowest: float = minf(Hero.ATTACK_ANIM_SPEED, Hero.COMPANION_ATTACK_ANIM_SPEED)
	for hero in HeroRoster.all():
		var contact: float = hero.attack_contact_time
		if contact == 0.0:
			continue
		if contact < 0.0:
			_fail("%s: attack_contact_time %.3f is negative" % [hero.resource_path, contact])
			continue
		if contact / slowest > HeroDefinition.WIND_UP_CAP_SECONDS + 0.0001:
			_fail("%s: the attack's contact frame comes %.3f s in at play speed, past the %.2f s wind-up cap"
				% [hero.resource_path, contact / slowest, HeroDefinition.WIND_UP_CAP_SECONDS])
		if hero.model_scene == null:
			continue
		var model: Node = hero.model_scene.instantiate()
		var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip: String = String(hero.clips.get(&"attack", ""))
		if player == null or not player.has_animation(clip):
			_fail("%s: has an attack contact time but no attack clip ('%s')" % [hero.resource_path, clip])
		elif contact >= player.get_animation(clip).length:
			_fail("%s: attack_contact_time %.3f is past the end of '%s' (%.3f s)"
				% [hero.resource_path, contact, clip, player.get_animation(clip).length])
		model.free()


## Camp badges: every badge has an icon, a name,
## how-to-earn text and a known condition (BadgeDefinition.problems),
## ids are unique, and Badges loaded them all.
func _validate_badges() -> void:
	var badge_ids: Dictionary = {}
	var badges: Array[Resource] = DefinitionLoader.load_all(Badges.BADGES_DIR)
	for res in badges:
		var badge: BadgeDefinition = res as BadgeDefinition
		if badge == null:
			_fail("%s is not a BadgeDefinition" % res.resource_path)
			continue
		_check_id(badge.id, badge.resource_path, badge_ids)
		for problem in badge.problems():
			_fail("%s %s" % [badge.resource_path, problem])
	if badges.size() < 12:
		_fail("only %d badges in %s (about 15 planned)" % [badges.size(), Badges.BADGES_DIR])
	for problem in StartingPerks.problems():
		_fail("StartingPerks %s" % problem)
	if badges.size() != Badges.definitions().size():
		_fail("Badges loaded %d badges, %s has %d" % [Badges.definitions().size(), Badges.BADGES_DIR, badges.size()])
	# Every cosmetic tint is unlocked by a real badge.
	for badge_id in Cosmetics.badges_named():
		if not badge_ids.has(badge_id):
			_fail("Cosmetics names unknown badge '%s'" % badge_id)


## Mum's journal has 10-12 sound pages
## (JournalPage.problems) with unique ids, and every note on a dawn
## card is one of them, so it is collected when the card plays.
func _validate_journal() -> void:
	var page_ids: Dictionary = {}
	var files: Array[Resource] = DefinitionLoader.load_all(Journal.PAGES_DIR)
	for res in files:
		var page: JournalPage = res as JournalPage
		if page == null:
			_fail("%s is not a JournalPage" % res.resource_path)
			continue
		_check_id(page.id, page.resource_path, page_ids)
		for problem in page.problems():
			_fail("%s %s" % [page.resource_path, problem])
	if files.size() < 10 or files.size() > 12:
		_fail("Mum's journal has %d pages in %s (10-12 planned)" % [files.size(), Journal.PAGES_DIR])
	if files.size() != Journal.pages().size():
		_fail("Journal loaded %d pages, %s has %d" % [Journal.pages().size(), Journal.PAGES_DIR, files.size()])
	var chest_pages: int = 0
	for page in Journal.pages():
		chest_pages += 1 if page.found_in == &"chest" else 0
	if chest_pages == 0:
		_fail("no journal page is found in a day chest")
	for res in StoryLibrary.all():
		for line in (res as StoryBeat).lines:
			var line_id: String = String((line as Dictionary).get("id", ""))
			if String((line as Dictionary).get("speaker", "")) == "note" and Journal.page_for_note(line_id) == null:
				_fail("Mum's note %s is on no journal page" % line_id)


## Perk cards: every perk has an icon, a name, a line of text and a
## known effect kind (PerkDefinition.problems), and ids are unique.
func _validate_perks() -> void:
	var perk_ids: Dictionary = {}
	var perks: Array[Resource] = DefinitionLoader.load_all(PerkManager.PERKS_DIR)
	for res in perks:
		var perk: PerkDefinition = res as PerkDefinition
		if perk == null:
			_fail("%s is not a PerkDefinition" % res.resource_path)
			continue
		_check_id(perk.id, perk.resource_path, perk_ids)
		for problem in perk.problems():
			_fail("%s %s" % [perk.resource_path, problem])
	if perks.size() != PerkManager.definitions().size():
		_fail("PerkManager loaded %d perks, %s has %d" % [PerkManager.definitions().size(), PerkManager.PERKS_DIR, perks.size()])
	if PerkManager.offer(null, 3).is_empty():
		_fail("no perk is offered to every hero (the shared pool is empty)")


## Each hero has at least two cards of their own, and no
## hero is dealt another hero's, as the player or as the companion.
## Asks PerkManager.offer itself, with a stand-in for each hero, so a
## broken pool filter fails here. As the companion, no player-only card
## is dealt, and there is still a card to draw.
func _validate_hero_perks() -> void:
	var probe_script: GDScript = GDScript.new()
	probe_script.source_code = "extends Node\nvar hero: HeroDefinition\n"
	probe_script.reload()
	for hero in HeroRoster.all():
		var own: int = 0
		for perk in PerkManager.definitions():
			if perk.pool == hero.id:
				own += 1
		if own < 2:
			_fail("%s has %d hero-only perks (needs 2)" % [hero.id, own])
		for as_companion in [false, true]:
			var probe: Node = probe_script.new()
			probe.set("hero", hero)
			if as_companion:
				probe.add_to_group("companions")
			var role: String = "companion" if as_companion else "player"
			var dealt: Array[PerkDefinition] = PerkManager.offer(probe, 999)
			for perk in dealt:
				if perk.pool != &"shared" and perk.pool != &"sibling" and perk.pool != hero.id:
					_fail("%s (%s) is offered %s, another hero's perk" % [hero.id, role, perk.id])
				if as_companion and perk.player_only:
					_fail("%s (companion) is offered %s, a player-only perk" % [hero.id, perk.id])
			if dealt.is_empty():
				_fail("%s (%s) is offered no perk at all" % [hero.id, role])
			probe.free()
	for perk in PerkManager.definitions():
		if perk.pool != &"shared" and perk.pool != &"sibling" and HeroRoster.get_hero(perk.pool) == null:
			_fail("%s is for unknown hero '%s'" % [perk.resource_path, perk.pool])


## PerkDefinition.problems() itself: a card with an unknown flag, or an
## on_hit card that reaches no extra mob, is caught.
func _validate_perk_problems() -> void:
	var bad_flag: PerkDefinition = _probe_perk(&"flag")
	bad_flag.flag = &"no_such_flag"
	if bad_flag.problems().is_empty():
		_fail("PerkDefinition.problems() lets an unknown flag through")
	var no_targets: PerkDefinition = _probe_perk(&"on_hit")
	no_targets.reach = 2.0
	if no_targets.problems().is_empty():
		_fail("PerkDefinition.problems() lets an on_hit perk with no extra targets through")
	var no_reach: PerkDefinition = _probe_perk(&"on_hit")
	no_reach.extra_targets = 1
	if no_reach.problems().is_empty():
		_fail("PerkDefinition.problems() lets an on_hit perk with no reach through")
	var sound: PerkDefinition = _probe_perk(&"on_hit")
	sound.extra_targets = 1
	sound.reach = 2.0
	if not sound.problems().is_empty():
		_fail("PerkDefinition.problems() rejects a sound on_hit perk: %s" % ", ".join(sound.problems()))


func _probe_perk(kind: StringName) -> PerkDefinition:
	var perk: PerkDefinition = PerkDefinition.new()
	perk.id = &"stand_firm"
	perk.display_name = "Probe"
	perk.description = "A probe."
	perk.icon = "stick"
	perk.effect_kind = kind
	return perk


## Every story beat is complete and readable, each
## chapter has its intro, dawn cards and ending, every hero has lines,
## and every voice file belongs to a line. Lines still waiting for a
## recording are counted, not failed.
func _validate_story() -> void:
	var beat_ids: Dictionary = {}
	var line_ids: Dictionary = {}
	var hero_ids: Array[String] = []
	for hero in HeroRoster.all():
		hero_ids.append(String(hero.id))
	for res in StoryLibrary.all():
		var beat: StoryBeat = res as StoryBeat
		if beat == null:
			_fail("%s is not a StoryBeat" % res.resource_path)
			continue
		_check_id(beat.id, beat.resource_path, beat_ids)
		if not StoryBeat.TRIGGERS.has(beat.trigger):
			_fail("%s has unknown trigger '%s'" % [beat.resource_path, beat.trigger])
		if not StoryLibrary.CHAPTER_NAMES.has(beat.chapter) and beat.chapter != 0:
			_fail("%s has unknown chapter %d" % [beat.resource_path, beat.chapter])
		if beat.trigger in [&"intro", &"win"] and beat.painting == null:
			_fail("%s is a storybook page without a painting" % beat.resource_path)
		elif beat.trigger in [&"intro", &"win"] and not beat.painting.resource_path.begins_with("res://assets/ui/story/"):
			_fail("%s uses a placeholder painting (%s), not its own (047)" % [beat.resource_path, beat.painting.resource_path])
		for hero_id in hero_ids:
			if beat.lines_for(StringName(hero_id)).is_empty():
				_fail("%s has no lines when %s is played" % [beat.resource_path, hero_id])
		for value in beat.lines:
			var line: Dictionary = value as Dictionary
			var line_id: String = String(line.get("id", ""))
			var text: String = String(line.get("text", ""))
			_check_id(StringName(line_id), "%s line" % beat.resource_path, line_ids)
			if not StoryBeat.SPEAKERS.has(String(line.get("speaker", ""))) and not hero_ids.has(String(line.get("speaker", ""))):
				_fail("%s line %s has unknown speaker '%s'" % [beat.resource_path, line_id, line.get("speaker", "")])
			var face: String = String(line.get("face", ""))
			var speaker: String = String(line.get("speaker", ""))
			if face != "" and speaker in ["mum", "note"] and not StoryLibrary.MUM_FACES.has(face):
				_fail("%s line %s has face '%s' (Mum's are %s)" % [beat.resource_path, line_id, face, StoryLibrary.MUM_FACES])
			elif face != "" and hero_ids.has(speaker) and not ResourceLoader.exists(StoryLibrary.hero_face_path(speaker, face)):
				_fail("%s line %s has face '%s', but %s has no such portrait" % [beat.resource_path, line_id, face, speaker])
			elif String(line.get("sketch", "")) != "" and (speaker != "note" or not ResourceLoader.exists(String(line["sketch"]))):
				_fail("%s line %s has sketch '%s' (Mum's notes only, and the file must exist)" % [beat.resource_path, line_id, line["sketch"]])
			elif face != "" and speaker == "narrator":
				_fail("%s line %s: the narrator has no face" % [beat.resource_path, line_id])
			var when: String = String(line.get("when", ""))
			if when != "" and not hero_ids.has(when):
				_fail("%s line %s is for unknown hero '%s'" % [beat.resource_path, line_id, when])
			if text == "" or text.length() > 60:
				_fail("%s line %s must be 1-60 characters (%d)" % [beat.resource_path, line_id, text.length()])
			if text.replace("{hero}", "").replace("{companion}", "").contains("{"):
				_fail("%s line %s has an unknown placeholder" % [beat.resource_path, line_id])
	for chapter in StoryLibrary.CHAPTER_NAMES.keys():
		for trigger in [&"intro", &"win"]:
			if StoryLibrary.find(trigger, chapter).is_empty():
				_fail("chapter %d has no %s pages" % [chapter, trigger])
		var nights: int = 3 if chapter == 1 else 7
		for night in range(1, nights):
			if StoryLibrary.first(&"dawn", chapter, night) == null:
				_fail("chapter %d has no dawn card for night %d" % [chapter, night])
	for trigger in [&"shard", &"loss_fire", &"loss_hero"]:
		if StoryLibrary.first(trigger, 1) == null or StoryLibrary.first(trigger, 2) == null:
			_fail("story has no '%s' beat for every chapter" % trigger)
	for face in StoryLibrary.MUM_FACES:
		if StoryLibrary.speaker_portrait("mum", face) != load(StoryLibrary.MUM_PORTRAIT.replace(".png", "_%s.png" % face)):
			_fail("Mum's '%s' portrait is missing (art/ui/story_art.py)" % face)
	if not ResourceLoader.exists(MumArrival.MODEL_PATH):
		_fail("Mum's model is missing: %s (art/characters/mum.py)" % MumArrival.MODEL_PATH)
	var story_lines: int = line_ids.size()
	_validate_barks(line_ids, hero_ids)
	var voiced: int = 0
	for line_id in line_ids.keys():
		if StoryLibrary.voice(String(line_id)) != null:
			voiced += 1
	var dir: DirAccess = DirAccess.open(StoryLibrary.VOICE_DIR)
	if dir != null:
		for file_name in dir.get_files():
			var clean: String = file_name.trim_suffix(".import").trim_suffix(".remap")
			if clean.get_extension() in StoryLibrary.VOICE_EXTENSIONS and not line_ids.has(StringName(clean.get_basename())):
				_fail("voice file %s matches no story line or bark id" % clean)
	print("validate_project: story %d beats, %d lines, %d barks, %d voiced" % [beat_ids.size(), story_lines, line_ids.size() - story_lines, voiced])


## The siblings' barks: known triggers and roles, at least
## two lines per hero for every trigger, lines of 1-30 characters, ids
## unique among all story lines, and no placeholders (barks are voiced).
## `line_ids` gets the bark ids, so voice files can match them.
func _validate_barks(line_ids: Dictionary, hero_ids: Array[String]) -> void:
	var barks: BarkSet = load(BarkLibrary.BARKS_PATH) as BarkSet
	if barks == null:
		_fail("%s is missing or not a BarkSet" % BarkLibrary.BARKS_PATH)
		return
	for trigger in barks.triggers.keys():
		var tuning: Dictionary = barks.triggers[trigger] as Dictionary
		if not BarkSet.ROLES.has(String(tuning.get("role", ""))):
			_fail("bark trigger '%s' has unknown role '%s'" % [trigger, tuning.get("role", "")])
		if not String(tuning.get("once", "")) in ["", "night", "run"]:
			_fail("bark trigger '%s' has unknown once '%s'" % [trigger, tuning.get("once", "")])
		for hero_id in hero_ids:
			for played in hero_ids:
				if BarkLibrary.lines_for(StringName(trigger), StringName(hero_id), StringName(played)).size() < 2:
					_fail("bark trigger '%s' has fewer than 2 lines for %s (%s played)" % [trigger, hero_id, played])
	for value in barks.lines:
		var line: Dictionary = value as Dictionary
		var line_id: String = String(line.get("id", ""))
		var text: String = String(line.get("text", ""))
		_check_id(StringName(line_id), "%s bark" % BarkLibrary.BARKS_PATH, line_ids)
		if not barks.triggers.has(StringName(String(line.get("trigger", "")))):
			_fail("bark %s has unknown trigger '%s'" % [line_id, line.get("trigger", "")])
		if not hero_ids.has(String(line.get("speaker", ""))):
			_fail("bark %s has unknown speaker '%s'" % [line_id, line.get("speaker", "")])
		var when: String = String(line.get("when", ""))
		if when != "" and not hero_ids.has(when):
			_fail("bark %s is for unknown hero '%s'" % [line_id, when])
		if text == "" or text.length() > 30:
			_fail("bark %s must be 1-30 characters (%d)" % [line_id, text.length()])
		if text.contains("{"):
			_fail("bark %s has a placeholder; barks are voiced, write one per hero" % line_id)
	for trigger in [&"low_hp", &"thief", &"thief_caught", &"first_beast", &"level_up", &"sunset", &"night_start",
			&"lantern_stage", &"companion_down", &"companion_up", &"danger_behind", &"boss", &"boss_lantern"]:
		if not barks.triggers.has(trigger):
			_fail("bark trigger '%s' is fired by BarkDirector but has no tuning" % trigger)


## Every autoload saving system saves, resets and
## loads itself, with no gameplay scene. For each: set some state, save
## it, reset (it reads as fresh), load the save (it reads as saved). The
## two heroes are stand-ins in their role groups, registered again after
## the reset as a new camp's heroes would be. The run state that is not
## saved (the perk clock and deal, the crafting flag, the loot rolls)
## must reset too.
func _validate_saving_systems() -> void:
	var systems: Array = RunSession.autoload_systems()
	for system in [TimeManager, GameManager, ResourceManager, ProgressionManager, PerkManager, CraftingManager]:
		if not systems.has(system):
			_fail("RunSession does not list %s as a saving system" % system.name)
	var stats: CharacterStatsDefinition = HeroRoster.get_hero(&"leo").stats
	var hero: Node = Node.new()
	hero.add_to_group("player")
	var sibling: Node = Node.new()
	sibling.add_to_group("companions")
	add_child(hero)
	add_child(sibling)
	var register: Callable = func() -> void:
		ProgressionManager.register_character(hero, stats)
		ProgressionManager.register_character(sibling, stats)
	for system in systems:
		system.reset()
	register.call()
	var fresh: Dictionary = {}
	for system in systems:
		fresh[system] = system.save_state()
	# Some state in every system.
	TimeManager.day_number = 4
	GameManager.record(&"kills", 5)
	GameManager.loot_misses = {&"shadow_imp": 3}
	ResourceManager.add(&"wood", 7)
	ProgressionManager.award_xp(hero, ProgressionManager.get_xp_to_next_level(hero) + 3, &"test")
	ProgressionManager.award_xp(sibling, 4, &"test")
	PerkManager.take(hero, &"stand_firm")
	PerkManager.take(sibling, &"quick_hands")
	PerkManager.clock = 99.0
	var deal_state: int = PerkManager.rng.state
	var loot_state: int = GameManager.loot_rng.state
	CraftingManager.is_crafting = true
	var saved: Dictionary = {}
	for system in systems:
		saved[system] = system.save_state()
		if saved[system] == fresh[system] and system != CraftingManager:
			_fail("%s saves nothing of the state it was given: %s" % [system.name, saved[system]])
	for system in systems:
		system.reset()
	register.call()
	for system in systems:
		if system.save_state() != fresh[system]:
			_fail("%s keeps state across a reset: %s" % [system.name, system.save_state()])
	if PerkManager.clock != 0.0 or PerkManager.rng.state == deal_state:
		_fail("PerkManager: the perk clock or the deal survives a reset")
	if GameManager.loot_rng.state == loot_state:
		_fail("GameManager: the loot rolls survive a reset")
	if CraftingManager.is_crafting:
		_fail("CraftingManager: the crafting state survives a reset")
	var whole: Dictionary = {}
	for system in systems:
		RunSession.merge_state(whole, saved[system])
	for system in systems:
		system.load_state(whole)
	for system in systems:
		if system.save_state() != saved[system]:
			_fail("%s does not load what it saved: %s, not %s" % [system.name, system.save_state(), saved[system]])
	if ProgressionManager.get_level(hero) != 2:
		_fail("ProgressionManager: the loaded XP does not give the level back (%d)" % ProgressionManager.get_level(hero))
	for system in systems:
		system.load_state({})  # missing keys are tolerated
		system.reset()
	hero.free()
	sibling.free()


## The save manager only handles the file, so it names no game system that holds run state,
## and the game manager keeps no reset list of its own (the run
## session resets every saving system).
func _validate_run_lifecycle_contract() -> void:
	var source: String = FileAccess.get_file_as_string("res://scripts/core/save_manager.gd")
	for word in ["BaseCore", "Building", "Torch", "Hero", "Perk", "Party", "TimeManager", "GameManager", "get_first_node_in_group"]:
		if source.contains(word):
			_fail("save_manager.gd names %s; the save manager only handles the file" % word)
	for old in ["reset_autoloads", "_reset_autoloads"]:
		if GameManager.has_method(old):
			_fail("GameManager still has its own reset list (%s)" % old)
	if SaveManager.has_method("snapshot"):
		_fail("SaveManager still gathers the run itself; RunSession.snapshot does")


## A saved building or torch entry with a missing key
## (no position) is skipped on load, not an error.
func _validate_rebuild_missing_keys() -> void:
	if Building.rebuild({"id": "wooden_fence", "hp": 3}, self) != null:
		_fail("Building.rebuild builds an entry with no position")
	if Torch.rebuild({"dawns": 1}, self) != null:
		_fail("Torch.rebuild builds an entry with no position")


func _validate_comments(files: PackedStringArray) -> void:
	var patterns: Array[String] = WORK_ITEM_PATTERNS.duplicate()
	var slugs: PackedStringArray = PackedStringArray()
	for slug in DirAccess.get_directories_at(ProjectSettings.globalize_path(SCRATCH_DIR)):
		slugs.append(slug.replace("-", "[ -]"))
	if not slugs.is_empty():
		patterns.append("\\b(?:%s)\\s+(?:\\d{2}|spec)\\b" % "|".join(slugs))
	var regex: RegEx = RegEx.create_from_string("(?i)(?:%s)" % ")|(?:".join(patterns))
	for path in files:
		if not path.ends_with(".gd"):
			continue
		var comments: Dictionary = _comments_by_line(FileAccess.get_file_as_string(path))
		var block: String = ""
		var starts: Array[int] = []
		var lines: Array[int] = []
		for line in comments.keys() + [-2]:
			if not lines.is_empty() and line != lines[-1] + 1:
				for found in regex.search_all(block):
					var at: int = starts.bsearch(found.get_start(), true)
					if at == starts.size() or starts[at] > found.get_start():
						at -= 1
					_fail("%s:%d: comment names a work item ('%s'); say what the code does or why" % [path.trim_prefix("res://"), lines[at], found.get_string()])
				block = ""
				starts.clear()
				lines.clear()
			if line >= 0:
				starts.append(block.length())
				lines.append(line)
				block += String(comments[line]) + " "


## Each line's comment text (without the leading #s), keyed by its 1-based
## line number in order. A # inside a string literal is not a comment.
func _comments_by_line(source: String) -> Dictionary:
	var comments: Dictionary = {}
	var open_quote: String = ""
	var line_number: int = 0
	for line in source.split("\n"):
		line_number += 1
		if open_quote == "" and not line.contains("#"):
			if not (line.contains("\"\"\"") or line.contains("'''")):
				continue
		var i: int = 0
		while i < line.length():
			var c: String = line[i]
			if open_quote != "":
				if c == "\\":
					i += 2
					continue
				if line.substr(i, open_quote.length()) == open_quote:
					i += open_quote.length()
					open_quote = ""
					continue
				i += 1
			elif c == "#":
				comments[line_number] = line.substr(i).lstrip("#").strip_edges()
				break
			elif c == "\"" or c == "'":
				open_quote = c.repeat(3) if line.substr(i, 3) == c.repeat(3) else c
				i += open_quote.length()
			else:
				i += 1
		if open_quote.length() == 1:
			open_quote = ""
	return comments
