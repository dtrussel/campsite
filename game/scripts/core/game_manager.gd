extends Node

## GameManager
##
## Top-level coordinator. Owns the run lifecycle (title -> playing ->
## won / lost -> restart), the win and lose rules, the per-run stats
## shown on the end screen, and dispatches companion-task hotkeys.
## Also holds the party (feature 034): which hero the player plays and
## which one is the AI companion, picked on the hero select screen.
## The run lengths are the story's chapters (feature 035): 3 nights is
## Chapter 1, 7 nights is Chapter 2, and each opens with its intro.
## Chapter 2's last night lasts until the Moon-Eater is calmed (feature
## 038); its dawn is the win.

signal day_number_changed(new_day: int)
signal camp_destroyed
signal companion_task_changed(companion: Node, task: int)
signal run_started
signal run_ended(won: bool, reason: String)

enum RunState { MENU, PLAYING, WON, LOST }

const TITLE_SCENE: String = "res://scenes/ui/TitleScreen.tscn"
const GAME_SCENE: String = "res://scenes/main/Main.tscn"
const HERO_SELECT_SCENE: String = "res://scenes/ui/HeroSelect.tscn"

## Surviving this many nights wins the run.
@export var nights_to_win: int = 3

var current_day: int = 1
var is_camp_destroyed: bool = false
var run_state: int = RunState.MENU
var end_reason: String = ""
## Which story beat the end screen shows: &"win", &"loss_fire" or
## &"loss_hero".
var end_trigger: StringName = &""
## Per-run counters for the end screen and the playtest log.
var stats: Dictionary = {}
## A save waiting to be applied once the gameplay scene is ready.
var _pending_save: Dictionary = {}
## The party: the played hero and the companion (HeroRoster ids). Kept
## between runs so the hero select screen opens on the last pick.
var hero_id: StringName = &"leo"
var companion_id: StringName = &"nela"
## Glow Shard drops (feature 036): kills since each mob type last
## dropped, for the pity rule. Reset every run.
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
	var ok: bool = items >= 11 and buildings >= 2 and recipes >= 1 and instance != null
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


## The intro pages a new game opens with. Every new game plays them
## (Esc skips); Continue and Restart never do.
func intro_pages() -> Array:
	return StoryLibrary.find(&"intro", chapter())


## Hero select Go: the chapter intro (StoryBook over the hero select
## screen), then the run.
func begin_chapter(hero: StringName, companion: StringName = &"") -> void:
	set_party(hero, companion)
	var key: String = "intro.c%d" % chapter()
	var pages: Array = intro_pages()
	if pages.is_empty():
		start_run()
		return
	var book: StoryBook = StoryBook.play(pages, hero_id)
	book.finished.connect(func() -> void:
		StoryLibrary.mark_seen(key)
		PlaytestLog.write("story_intro chapter=%d pages_seen=%d of %d" % [chapter(), book.page + 1, pages.size()])
		start_run())


## Title screen Play: pick the run length, then the hero.
func open_hero_select(nights: int) -> void:
	nights_to_win = nights
	get_tree().paused = false
	get_tree().change_scene_to_file(HERO_SELECT_SCENE)


## Resets every autoload and loads the gameplay scene. `nights` picks
## the run length (3 or 7 from the title screen); 0 keeps the current
## one (Again / restart). `hero` sets the party (empty keeps it). A new
## run replaces any autosave.
func start_run(nights: int = 0, hero: StringName = &"", companion: StringName = &"") -> void:
	if nights > 0:
		nights_to_win = nights
	if hero != &"":
		set_party(hero, companion)
	_pending_save = {}
	SaveManager.delete_save()
	get_tree().paused = false
	_reset_autoloads()
	LoadingScreen.load_scene(GAME_SCENE)  # key art while the camp loads (feature 029)


## Resumes the autosaved run at the morning after its last dawn.
## False if there is no usable save.
func continue_run() -> bool:
	var data: Dictionary = SaveManager.load_save()
	if data.is_empty():
		return false
	nights_to_win = int(data["nights_to_win"])
	var party: Dictionary = SaveManager.party_of(data)
	set_party(party["hero"], party["companion"])
	get_tree().paused = false
	_reset_autoloads()
	_pending_save = data
	LoadingScreen.load_scene(GAME_SCENE)
	return true


func go_to_title() -> void:
	get_tree().paused = false
	_reset_autoloads()
	run_state = RunState.MENU
	get_tree().change_scene_to_file(TITLE_SCENE)


## Called by Main once the gameplay scene is in the tree.
func on_game_scene_ready() -> void:
	run_state = RunState.PLAYING
	_hook_base_core()
	_hook_player()
	if _pending_save.is_empty():
		TimeManager.start_run()
		PlaytestLog.write("run_started nights_to_win=%d" % nights_to_win)
	else:
		var data: Dictionary = _pending_save
		_pending_save = {}
		SaveManager.apply(data)
		TimeManager.start_run(int(data["day"]) + 1)
		PlaytestLog.write("run_continued nights_to_win=%d day=%d" % [nights_to_win, TimeManager.day_number])
	run_started.emit()


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


func _reset_autoloads() -> void:
	TimeManager.reset()
	BuildManager.exit_build_mode()
	ResourceManager.reset()
	ProgressionManager.reset()
	PerkManager.reset()
	current_day = 1
	is_camp_destroyed = false
	end_reason = ""
	end_trigger = &""
	loot_misses = {}
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
	}


func _end_run(won: bool, reason: String, trigger: StringName) -> void:
	if run_state != RunState.PLAYING:
		return
	run_state = RunState.WON if won else RunState.LOST
	end_reason = reason
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


func _on_dawn_started(day_number: int) -> void:
	if run_state != RunState.PLAYING:
		return
	stats[&"nights_survived"] = day_number
	PlaytestLog.write("night_survived night=%d" % day_number)
	if day_number >= nights_to_win:
		if int(stats.get(&"boss_calmed", 0)) > 0:
			_end_run(true, "You calmed the Moon-Eater!", &"win")
		else:
			_end_run(true, "You survived %d nights!" % nights_to_win, &"win")


func _on_resource_changed(_id: StringName, _new_value: int, delta: int) -> void:
	# Only count gathering; crafting outputs are counted separately.
	if delta > 0 and run_state == RunState.PLAYING and not CraftingManager.is_crafting:
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
