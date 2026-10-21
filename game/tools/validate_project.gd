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
## Exits 0 when clean, 1 otherwise.

const SKIP_DIRS: Array[String] = ["res://.godot", "res://addons"]
## The profile check's own file, never the player's profile.
const TEST_PROFILE_PATH: String = "user://validate_profile.json"

var _errors: PackedStringArray = PackedStringArray()


## Feature 029: the boot splash exists and the loading screen builds.
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
	_validate_profile()
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
			# Feature 038: a boss runs BossController and is never farmed.
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
	_validate_perks()
	_validate_hero_perks()
	_validate_perk_problems()
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


## Feature 034: every hero on the select screen is complete, and its
## signature recipe exists.
func _validate_heroes(recipe_ids: Dictionary) -> void:
	var hero_ids: Dictionary = {}
	for hero in HeroRoster.all():
		_check_id(hero.id, hero.resource_path, hero_ids)
		if hero.model_scene == null or hero.stats == null or hero.portrait == null:
			_fail("%s needs a model, stats and a portrait" % hero.resource_path)
		if hero.signature_recipe != &"" and not recipe_ids.has(hero.signature_recipe):
			_fail("%s has unknown signature recipe '%s'" % [hero.resource_path, hero.signature_recipe])
	if HeroRoster.all().size() < 2:
		_fail("the roster needs at least two heroes (a hero and a companion)")


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


## Perk cards 04: each hero has at least two cards of their own, and no
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


## Feature 035: every story beat is complete and readable, each
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


## The siblings' barks (feature 037): known triggers and roles, at least
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


## Profile ticket 01: the profile keeps keys across a reload, records
## bests, loads a missing or corrupt file as empty and deletes cleanly.
## It runs on its own file and points the profile back afterwards.
func _validate_profile() -> void:
	Profile.set_path(TEST_PROFILE_PATH)
	Profile.delete()
	if Profile.has_value("test.missing") or Profile.get_value("test.missing", 7) != 7:
		_fail("Profile: a missing file does not load as empty")
	Profile.set_value("test.word", "moon")
	Profile.set_value("test.count", 3)
	Profile.reload()
	if not Profile.has_value("test.word") or Profile.get_value("test.word", "") != "moon":
		_fail("Profile: a string does not survive a reload")
	if int(Profile.get_value("test.count", 0)) != 3:
		_fail("Profile: a number does not survive a reload")
	if not Profile.record_best("test.best", 5):
		_fail("Profile: a first best is not a record")
	if not Profile.record_best("test.best", 8):
		_fail("Profile: a higher best is not a record")
	if Profile.record_best("test.best", 6) or Profile.record_best("test.best", 8):
		_fail("Profile: a lower or equal best counts as a record")
	Profile.reload()
	if int(Profile.get_value("test.best", 0)) != 8:
		_fail("Profile: the best is not 8 after a reload (%s)" % Profile.get_value("test.best", 0))
	Profile.delete()
	if Profile.has_value("test.word") or FileAccess.file_exists(TEST_PROFILE_PATH):
		_fail("Profile: delete leaves keys or the file behind")
	Profile.reload()
	if Profile.has_value("test.word"):
		_fail("Profile: deleted keys come back after a reload")
	var corrupt: FileAccess = FileAccess.open(TEST_PROFILE_PATH, FileAccess.WRITE)
	corrupt.store_string("{ not json [")
	corrupt.close()
	Profile.reload()
	if Profile.has_value("test.word") or Profile.get_value("test.word", "none") != "none":
		_fail("Profile: a corrupt file does not load as empty")
	Profile.set_value("test.word", "sun")
	Profile.reload()
	if Profile.get_value("test.word", "") != "sun":
		_fail("Profile: a corrupt file is not rewritten on the next write")
	Profile.delete()
	Profile.set_path(Profile.PROFILE_PATH)
