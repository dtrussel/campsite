extends Node

## GameManager
##
## Top-level coordinator. Owns the run lifecycle (title -> playing ->
## won / lost -> restart), the win and lose rules, the per-run stats
## shown on the end screen, and dispatches companion-task hotkeys.
## Also holds the party: which hero the player plays and
## which one is the AI companion, picked on the hero select screen.
## The run lengths are the story's chapters: 3 nights is
## Chapter 1, 7 nights is Chapter 2, and each opens with its intro.
## Chapter 2's last night lasts until the Moon-Eater is calmed;
## its dawn is the win.

signal day_number_changed(new_day: int)
signal camp_destroyed
signal companion_task_changed(companion: Node, task: int)
signal run_started
signal run_ended(won: bool, reason: String)
## A run stat was recorded or set; `amount` is how much it went up
## (Badges counts and checks on it).
signal stat_recorded(stat: StringName, amount: int)
## This run's DayChest was placed at the map edge (the HUD says so).
## Typed Node3D: an autoload naming DayChest here makes a load cycle.
signal day_chest_placed(chest: Node3D)

enum RunState { MENU, PLAYING, WON, LOST }

const TITLE_SCENE: String = "res://scenes/ui/TitleScreen.tscn"
const GAME_SCENE: String = "res://scenes/main/Main.tscn"
const HERO_SELECT_SCENE: String = "res://scenes/ui/HeroSelect.tscn"

## Surviving this many nights wins the run.
@export var nights_to_win: int = 3
## The chance a run rolls a day chest (RunConfig.roll_day_chest).
@export_range(0.0, 1.0) var day_chest_chance: float = 0.5
## Endless mode (unlocked by the true ending): a Chapter 2 run
## (nights_to_win stays 7, so chapter() and the moon rows still read
## right) that has no win and no Moon-Eater. Kept between runs like the
## run length; the chapter buttons clear it.
var endless: bool = false

var current_day: int = 1
var is_camp_destroyed: bool = false
var run_state: int = RunState.MENU
var end_reason: String = ""
## Which story beat the end screen shows: &"win", &"loss_fire" or
## &"loss_hero".
var end_trigger: StringName = &""
## True when the run that just ended beat the endless record, so the
## end screen says "New record!".
var new_record: bool = false
## Per-run counters for the end screen and the playtest log.
var stats: Dictionary = {}
## The party: the played hero and the companion (HeroRoster ids). The
## last hero picked is also kept in the profile (record_hero_pick), so
## hero select opens on it after a restart too.
var hero_id: StringName = &"leo"
var companion_id: StringName = &"nela"
## Glow Shard drops: kills since each mob type last
## dropped, for the pity rule. Saved, and reset every run.
var loot_misses: Dictionary = {}
var loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The day this run's day chest appears, or 0 for
## none: from the run config, and saved, so a continued run never rolls
## a second one.
var day_chest_day: int = 0


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


func party_hero() -> HeroDefinition:
	return HeroRoster.get_hero(hero_id)


func party_companion() -> HeroDefinition:
	return HeroRoster.get_hero(companion_id)


## Sets the party; unknown ids fall back to Leo with his default
## companion.
func set_party(hero: StringName, companion: StringName = &"") -> void:
	hero_id = hero if HeroRoster.has_hero(hero) else &"leo"
	if companion == &"" or companion == hero_id or not HeroRoster.has_hero(companion):
		companion = HeroRoster.default_companion(hero_id)
	companion_id = companion


## The story chapter of this run: 1 "The Dark Moon" (3 nights) or 2
## "Into the Hollow" (7 nights).
func chapter() -> int:
	return 2 if nights_to_win >= 7 else 1


## The intro pages a new game of `run` (the next run's config when
## null) opens with. Every new game plays them (Esc skips); Continue,
## Restart and endless runs never do.
func intro_pages(run: RunConfig = null) -> Array:
	run = run if run != null else RunConfig.current()
	if not run.plays_intro():
		return []  # endless comes after the story: straight to the camp
	return StoryLibrary.find(&"intro", run.chapter)


## Hero select Go: the chapter intro (StoryBook over the hero select
## screen), then the run.
func begin_chapter(hero: StringName, companion: StringName = &"") -> void:
	set_party(hero, companion)
	record_hero_pick(hero_id)
	var run: RunConfig = RunConfig.current()
	var key: String = "intro.c%d" % run.chapter
	var pages: Array = intro_pages(run)
	if pages.is_empty():
		start_run()
		return
	var book: StoryBook = StoryBook.play(pages, hero_id)
	book.finished.connect(func() -> void:
		StoryLibrary.mark_seen(key)
		PlaytestLog.write("story_intro chapter=%d pages_seen=%d of %d" % [run.chapter, book.page + 1, pages.size()])
		start_run())


## Keeps the hero picked on hero select in the profile, so hero select
## opens on it next time, after a restart too.
func record_hero_pick(hero: StringName) -> void:
	Profile.set_value(Profile.LAST_HERO, String(hero))


## The hero hero select opens on: the last pick kept in the profile,
## else the current party's hero.
func last_hero_pick() -> StringName:
	var last: StringName = StringName(String(Profile.get_value(Profile.LAST_HERO, "")))
	return last if HeroRoster.has_hero(last) else hero_id


## Title screen Play: pick the run length (or Endless, as Chapter 2),
## then the hero.
func open_hero_select(nights: int, endless_run: bool = false) -> void:
	nights_to_win = nights
	endless = endless_run
	get_tree().paused = false
	get_tree().change_scene_to_file(HERO_SELECT_SCENE)


## A new run through the RunSession: resets every autoload and loads
## the gameplay scene. `nights` picks the run length (3 or 7 from the
## title screen); 0 keeps the current one (Again / restart). `hero` sets
## the party (empty keeps it). A new run replaces any autosave.
func start_run(nights: int = 0, hero: StringName = &"", companion: StringName = &"") -> void:
	var run: RunConfig = RunConfig.current()
	if nights > 0:
		run.nights_to_win = nights
	if hero != &"":
		run.hero_id = hero
		run.companion_id = companion
	RunSession.start(run)


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
		PlaytestLog.write("run_continued nights_to_win=%d day=%d" % [nights_to_win, TimeManager.day_number])
	else:
		TimeManager.start_run()
		_give_starting_perk()
		PlaytestLog.write("run_started nights_to_win=%d" % nights_to_win)
	run_started.emit()


## A new run's starting perk: the run config's,
## if a badge has unlocked it.
func _give_starting_perk() -> void:
	var perk: StringName = RunSession.config.starting_perk if RunSession.config != null else &""
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
	stat_recorded.emit(stat, amount)


## Sets a run stat that is a level, not a count (nights survived, the
## fire's lowest HP), and announces how much it went up.
func set_stat(stat: StringName, value: int) -> void:
	var old: int = int(stats.get(stat, 0))
	stats[stat] = value
	stat_recorded.emit(stat, value - old)


## The party a save was made with: {"hero", "companion"} as ids. Saves
## from before hero select have no "party" and are Leo with Nela.
static func party_of(data: Dictionary) -> Dictionary:
	var party: Dictionary = data.get("party", {}) if data.get("party") is Dictionary else {}
	return {
		"hero": StringName(str(party.get("hero", "leo"))),
		"companion": StringName(str(party.get("companion", "nela"))),
	}


## Saving system (RunSession): the run fields. The run's stats, the
## chapter goal and endless flag, the party, the shard pity counter (kills since each
## mob type last dropped; saves from before it start it empty) and the
## day chest's day.
func save_state() -> Dictionary:
	var saved_stats: Dictionary = {}
	for key in stats.keys():
		saved_stats[String(key)] = stats[key]
	var misses: Dictionary = {}
	for id in loot_misses.keys():
		misses[String(id)] = int(loot_misses[id])
	return {
		"nights_to_win": nights_to_win,
		"endless": endless,
		"party": {"hero": String(hero_id), "companion": String(companion_id)},
		"stats": saved_stats,
		"loot_misses": misses,
		"day_chest_day": day_chest_day,
	}


## Saving system: takes the run fields back over a fresh run. Missing
## keys keep the fresh values (and the current party, run length and
## endless flag; saves from before endless mode are story runs, as
## RunSession.continue_from sets them).
func load_state(data: Dictionary) -> void:
	if data.has("nights_to_win"):
		nights_to_win = int(data["nights_to_win"])
	if data.has("endless"):
		endless = bool(data["endless"])
	if data.get("party") is Dictionary:
		var party: Dictionary = party_of(data)
		set_party(party["hero"], party["companion"])
	var saved_stats: Variant = data.get("stats", {})
	if saved_stats is Dictionary:
		for key in (saved_stats as Dictionary).keys():
			stats[StringName(key)] = int(saved_stats[key])
	# Saves from before the day chest have had their chance: none.
	day_chest_day = int(data.get("day_chest_day", 0))
	var misses: Variant = data.get("loot_misses", {})
	if misses is Dictionary:
		for id in (misses as Dictionary).keys():
			loot_misses[StringName(id)] = int(misses[id])


## Saving system: a fresh run's fields. Keeps the party, run length and
## endless flag (the next run starts from them); the loot rolls are
## reshuffled, and RunSession then seeds them from the run config.
func reset() -> void:
	current_day = 1
	is_camp_destroyed = false
	end_reason = ""
	end_trigger = &""
	new_record = false
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
	if won:
		Profile.record_chapter_won(chapter())
	if endless:
		new_record = EndlessRecord.submit(current_day, hero_id)
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
	if is_playing() and day_number == day_chest_day:
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
