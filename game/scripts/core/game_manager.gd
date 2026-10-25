extends Node

## GameManager
##
## Top-level coordinator. Owns the run lifecycle (title -> playing ->
## won / lost -> restart), the win and lose rules, the per-run stats
## shown on the end screen, and dispatches companion-task hotkeys.
## The run's shape (the chapter or Endless, the run length, the party,
## the day chest) is the run config RunSession holds; the win check and
## the screens ask it.

signal day_number_changed(new_day: int)
signal camp_destroyed
signal companion_task_changed(companion: Node, task: int)
signal run_started
signal run_ended(won: bool, reason: String)
## This run's DayChest was placed at the map edge (the HUD says so).
## Typed Node3D: an autoload naming DayChest here makes a load cycle.
signal day_chest_placed(chest: Node3D)
## A dawn that does not win plays its story beat; Mum's notes on it
## are already found as journal pages, so the HUD only shows the card.
signal dawn_beat_played(beat: StoryBeat)

enum RunState { MENU, PLAYING, WON, LOST }

const TITLE_SCENE: String = "res://scenes/ui/TitleScreen.tscn"
const GAME_SCENE: String = "res://scenes/main/Main.tscn"
const HERO_SELECT_SCENE: String = "res://scenes/ui/HeroSelect.tscn"

var current_day: int = 1
var is_camp_destroyed: bool = false
var run_state: int = RunState.MENU
var end_reason: String = ""
## Which story beat the end screen shows: &"win", &"loss_fire" or
## &"loss_hero".
var end_trigger: StringName = &""
## What the run that just ended opened, as the profile said
## (Profile.record_run_end): the end screen says "New record!" from it.
## Null while a run plays.
var run_end: RunOutcome.Result = null
## Per-run counters for the end screen and the playtest log.
var stats: Dictionary = {}
## Glow Shard drops: kills since each mob type last
## dropped, for the pity rule. Saved, and reset every run.
var loot_misses: Dictionary = {}
var loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.theme = UiKit.theme()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.dawn_started.connect(_on_dawn_started)
	ResourceManager.resource_changed.connect(_on_resource_changed)
	ProgressionManager.xp_gained.connect(_on_xp_gained)
	_reset_stats()
	if "--selftest" in OS.get_cmdline_user_args():
		_run_selftest.call_deferred()


## `Campsite -- --selftest` checks an exported build can load its data
## and gameplay scene from the PCK, prints a summary, and exits.
func _run_selftest() -> void:
	var items: int = ResourceManager.get_definitions().size()
	var buildings: int = BuildManager.get_known_definitions().size()
	var recipes: int = CraftingManager.get_recipes().size()
	var scene: PackedScene = load(GAME_SCENE) as PackedScene
	var instance: Node = scene.instantiate() if scene != null else null
	# Floors, not exact counts: the six gathered resources,
	# the camp's first buildings and a recipe.
	var ok: bool = items >= 6 and buildings >= 2 and recipes >= 1 and instance != null
	print("selftest: items=%d buildings=%d recipes=%d main_scene=%s -> %s" % [
		items, buildings, recipes, instance != null, "OK" if ok else "FAILED"
	])
	if instance != null:
		instance.free()
	get_tree().quit(0 if ok else 1)


func _unhandled_input(event: InputEvent) -> void:
	if run_state != RunState.PLAYING or get_tree().paused:
		return
	if event.is_action_pressed("assign_idle"):
		assign_companion_task(0)
	elif event.is_action_pressed("assign_follow"):
		assign_companion_task(1)
	elif event.is_action_pressed("assign_guard"):
		assign_companion_task(2)
	elif event.is_action_pressed("assign_gather"):
		assign_companion_task(3)
	elif event.is_action_pressed("assign_repair"):
		assign_companion_task(4)
	elif event.is_action_pressed("skip_to_night"):
		if TimeManager.current_phase == TimeManager.Phase.DAY:
			TimeManager.skip_phase()


## The intro pages a new game of `run` opens with. Every new game plays
## them (Esc skips); Continue, Restart and endless runs never do.
func intro_pages(run: RunConfig) -> Array:
	if not run.plays_intro():
		return []  # endless comes after the story: straight to the camp
	return StoryLibrary.find(&"intro", run.chapter)


## Hero select Go: the party and the starting perk go on the draft
## config, then the chapter intro (StoryBook over the hero select
## screen), then the run.
func begin_chapter(hero: StringName, companion: StringName = &"") -> void:
	var run: RunConfig = RunSession.draft
	run.set_party(hero, companion)
	run.starting_perk = StartingPerks.chosen()
	Profile.record_hero_pick(run.hero_id)  # hero select opens on it next time
	var key: String = "intro.c%d" % run.chapter
	var pages: Array = intro_pages(run)
	if pages.is_empty():
		start_run(run)
		return
	var book: StoryBook = StoryBook.play(pages, run.hero_id)
	book.finished.connect(func() -> void:
		StoryLibrary.mark_seen(key)
		PlaytestLog.write("story_intro chapter=%d pages_seen=%d of %d" % [run.chapter, book.page + 1, pages.size()])
		start_run(run))


## The hero hero select opens on: the last pick kept in the profile,
## else the last run's hero.
func last_hero_pick() -> StringName:
	var last: StringName = Profile.last_hero_pick()
	return last if HeroRoster.has_hero(last) else RunSession.config.hero_id


## Title screen Play: `run` is the draft config of the chapter (or
## Endless) picked; hero select then adds the hero.
func open_hero_select(run: RunConfig) -> void:
	RunSession.draft = run
	get_tree().paused = false
	get_tree().change_scene_to_file(HERO_SELECT_SCENE)


## A new run of `run` through the RunSession: resets every autoload and
## loads the gameplay scene. Null is Again (the end screen, the pause
## menu's restart): the last run's config with fresh seeds. A new run
## replaces any autosave.
func start_run(run: RunConfig = null) -> void:
	RunSession.start(run if run != null else RunSession.config.again())


## Resumes the autosaved run at the morning after its last dawn, through
## the RunSession. False if there is no usable save.
func continue_run() -> bool:
	return RunSession.continue_from(SaveManager.load_save())


func go_to_title() -> void:
	get_tree().paused = false
	RunSession.reset()
	run_state = RunState.MENU
	get_tree().change_scene_to_file(TITLE_SCENE)


## Called by Main once the gameplay scene is in the tree.
func on_game_scene_ready() -> void:
	run_state = RunState.PLAYING
	_hook_base_core()
	_hook_player()
	if RunSession.restore_pending():
		PlaytestLog.write("run_continued nights_to_win=%d day=%d" % [RunSession.config.nights_to_win, TimeManager.day_number])
	else:
		TimeManager.start_run()
		_give_starting_perk()
		PlaytestLog.write("run_started nights_to_win=%d" % RunSession.config.nights_to_win)
	run_started.emit()


## A new run's starting perk: the run config's,
## if a badge has unlocked it.
func _give_starting_perk() -> void:
	var perk: StringName = RunSession.config.starting_perk
	if perk != &"" and StartingPerks.is_unlocked(perk):
		PerkManager.take_starting(Party.player_hero(), perk)


## Whether this kill drops the mob's loot: its drop chance, with a
## guaranteed drop after `drop_pity` kills in a row without one.
func roll_loot(definition: MobDefinition) -> bool:
	var misses: int = int(loot_misses.get(definition.id, 0))
	var hit: bool = definition.rolls_drop(misses, loot_rng.randf())
	loot_misses[definition.id] = 0 if hit else misses + 1
	return hit


func is_playing() -> bool:
	return run_state == RunState.PLAYING


func record(stat: StringName, amount: int = 1) -> void:
	stats[stat] = int(stats.get(stat, 0)) + amount
	_tell_profile(stat, amount)


## Sets a run stat that is a level, not a count (nights survived, the
## fire's lowest HP), and announces how much it went up.
func set_stat(stat: StringName, value: int) -> void:
	var old: int = int(stats.get(stat, 0))
	stats[stat] = value
	_tell_profile(stat, value - old)


## Tells the profile a stat went up by `amount`, for its totals and the
## badges. Only play counts: not a save being loaded, nor a menu or end
## screen.
func _tell_profile(stat: StringName, amount: int) -> void:
	if is_playing() and not RunSession.is_restoring():
		Profile.record_stat(stat, amount, RunSession.config, stats)


## The party a save was made with: {"hero", "companion"} as ids. Saves
## from before hero select have no "party" and are Leo with Nela.
static func party_of(data: Dictionary) -> Dictionary:
	var party: Dictionary = data.get("party", {}) if data.get("party") is Dictionary else {}
	return {
		"hero": StringName(str(party.get("hero", "leo"))),
		"companion": StringName(str(party.get("companion", "nela"))),
	}


## Saving system (RunSession): the run's stats and the shard pity
## counter (kills since each mob type last dropped; saves from before it
## start it empty). The run config's keys are the session's own.
func save_state() -> Dictionary:
	var saved_stats: Dictionary = {}
	for key in stats.keys():
		saved_stats[String(key)] = stats[key]
	var misses: Dictionary = {}
	for id in loot_misses.keys():
		misses[String(id)] = int(loot_misses[id])
	return {
		"stats": saved_stats,
		"loot_misses": misses,
	}


## Saving system: takes the stats and pity counter back over a fresh
## run. Missing keys keep the fresh values.
func load_state(data: Dictionary) -> void:
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for key in (saved_stats as Dictionary).keys():
			stats[StringName(key)] = int(saved_stats[key])
	var misses: Variant = data.get("loot_misses", {})
	if misses is Dictionary:
		for id in (misses as Dictionary).keys():
			loot_misses[StringName(id)] = int(misses[id])


## Saving system: a fresh run's fields. The loot rolls are reshuffled,
## and RunSession then seeds them from the run config.
func reset() -> void:
	current_day = 1
	is_camp_destroyed = false
	end_reason = ""
	end_trigger = &""
	run_end = null
	loot_misses = {}
	loot_rng.randomize()
	_reset_stats()


func _reset_stats() -> void:
	stats = {
		&"kills": 0,
		&"gathered": 0,
		&"built": 0,
		&"crafted": 0,
		&"torches_placed": 0,
		&"repairs": 0,
		&"shards": 0,
		&"nights_survived": 0,
		&"gremlins_caught": 0,
		# The campfire's lowest HP this run, in % (Fire Keeper badge).
		&"fire_low_pct": 100,
		# 1 once the Moon Lantern is fully lit (Lantern Lighter badge).
		&"lantern_lit": 0,
	}


func _end_run(won: bool, reason: String, trigger: StringName) -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.WON if won else RunState.LOST
	end_reason = reason
	run_end = Profile.record_run_end(RunOutcome.new(RunSession.config, won, current_day, stats))
	end_trigger = trigger
	TimeManager.stop()
	BuildManager.exit_build_mode()
	PlaytestLog.write("run_ended won=%s reason=\"%s\" day=%d stats=%s" % [won, reason, current_day, stats])
	run_ended.emit(won, reason)
	# Freeze the world behind the end screen.
	get_tree().paused = true


func _on_day_started(day_number: int) -> void:
	current_day = day_number
	day_number_changed.emit(current_day)
	if is_playing() and day_number == RunSession.config.day_chest_day:
		var chest: DayChest = DayChest.place(get_tree(), Journal.next_chest_page())
		if chest != null:
			day_chest_placed.emit(chest)


func _on_dawn_started(day_number: int) -> void:
	if run_state != RunState.PLAYING:
		return
	set_stat(&"nights_survived", day_number)
	PlaytestLog.write("night_survived night=%d" % day_number)
	var run: RunConfig = RunSession.config
	if run.dawn_wins(day_number):
		# Calming the Moon-Eater changes only the message.
		var calmed: bool = int(stats.get(&"boss_calmed", 0)) > 0
		_end_run(true, "You calmed the Moon-Eater!" if calmed else "You survived %d nights!" % run.nights_to_win, &"win")
		return
	# The winning dawn's story is the ending book, not a dawn beat.
	var beat: StoryBeat = StoryLibrary.first(&"dawn", run.chapter, day_number)
	if beat != null:
		Journal.find_notes_on(beat)
		dawn_beat_played.emit(beat)


func _on_resource_changed(_id: StringName, _new_value: int, delta: int) -> void:
	# Only count gathering; crafting outputs are counted separately, and
	# the inventory a save loads back was counted when it was gathered.
	if delta > 0 and run_state == RunState.PLAYING and not CraftingManager.is_crafting and not RunSession.is_restoring():
		record(&"gathered", delta)


func _on_xp_gained(_character: Node, _amount: int, source: StringName) -> void:
	if source == &"build":
		record(&"built")


## Public entry for the HUD's task buttons.
func assign_companion_task(task: int) -> void:
	_assign_to_all_companions(task)
	AudioManager.play_sfx(&"task")


func _assign_to_all_companions(task: int) -> void:
	for companion in get_tree().get_nodes_in_group("companions"):
		if companion.has_method("set_task"):
			companion.set_task(task)
			companion_task_changed.emit(companion, task)


func _hook_base_core() -> void:
	for node in get_tree().get_nodes_in_group("base_core"):
		if node.has_signal("destroyed") and not node.destroyed.is_connected(_on_camp_destroyed):
			node.destroyed.connect(_on_camp_destroyed)
		var fire: BaseCore = node as BaseCore
		if fire != null and not fire.damaged.is_connected(_on_camp_damaged):
			fire.damaged.connect(_on_camp_damaged.bind(fire))


## Keeps the fire's lowest HP this run, in % of its max.
func _on_camp_damaged(hp: int, fire: BaseCore) -> void:
	var pct: int = int(floor(100.0 * hp / maxf(1.0, fire.get_max_hp())))
	if pct < int(stats.get(&"fire_low_pct", 100)):
		set_stat(&"fire_low_pct", pct)


func _hook_player() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player_hero: Hero = node as Hero
		if player_hero != null and not player_hero.down_changed.is_connected(_on_player_down_changed):
			player_hero.down_changed.connect(_on_player_down_changed)


func _on_camp_destroyed() -> void:
	if is_camp_destroyed:
		return
	is_camp_destroyed = true
	camp_destroyed.emit()
	_end_run(false, "The campfire went out.", &"loss_fire")


## The player's hero being down ends the run.
func _on_player_down_changed(is_down: bool) -> void:
	if not is_down:
		return
	_end_run(false, "You were knocked out.", &"loss_hero")
