extends Node

## RunSession
##
## One run's lifecycle (run lifecycle spec): start a run from a
## RunConfig, continue one from saved data, reset, and announce when a
## restore has finished. GameManager's start_run / continue_run /
## go_to_title (the title, hero select, pause and end screens) come
## through here; tests call it directly, with open_scene = false when
## they instance the gameplay scene themselves.
##
## A saving system is anything that holds run state. It has:
##   save_state() -> Dictionary  its own keys, at their place in the save
##                               file (the session merges them);
##   load_state(data: Dictionary)  takes the whole save, reads its own
##                               keys and tolerates missing ones;
##   reset()                     back to a fresh run.
## The session walks them in one declared order, saving_systems(): time
## and the run fields, resources, progression, perks, then the world
## objects, then the heroes. Systems not moved over yet are still reset
## by GameManager.reset_autoloads and saved by SaveManager.snapshot /
## apply (tickets 02 and 03 move them over).

## A continued run is fully back: the save is applied and its follow-ups
## (the perk top-up) have run. Not emitted for a new run.
signal restore_finished

## The config of the run in progress (or of the last reset).
var config: RunConfig = null

## A save waiting for the gameplay scene (continue_from), applied by
## restore_pending.
var _pending: Dictionary = {}


## Starts a new run from `run` (RunConfig.current() when null): resets
## every saving system, replaces any autosave and opens the gameplay
## scene, which then starts the clock at day 1.
func start(run: RunConfig = null, open_scene: bool = true) -> void:
	run = run if run != null else RunConfig.current()
	_use_party(run, run.hero_id, run.companion_id, run.nights_to_win)
	_pending = {}
	SaveManager.delete_save()
	get_tree().paused = false
	reset(run)
	if open_scene:
		LoadingScreen.load_scene(GameManager.GAME_SCENE)  # key art while the camp loads (feature 029)


## Continues the run `data` was saved from (SaveManager.load_save or
## parse): the party and run length come from the save, the seeds and
## the auto-pick time from `run` (fresh ones when null). The save is
## applied once the gameplay scene is ready, at the morning after its
## day. False (and nothing changes) when `data` is empty.
func continue_from(data: Dictionary, run: RunConfig = null, open_scene: bool = true) -> bool:
	if data.is_empty():
		return false
	run = run if run != null else RunConfig.current()
	var party: Dictionary = SaveManager.party_of(data)
	_use_party(run, party["hero"], party["companion"], int(data["nights_to_win"]))
	get_tree().paused = false
	reset(run)
	_pending = data
	if open_scene:
		LoadingScreen.load_scene(GameManager.GAME_SCENE)
	return true


## Puts every saving system back to a fresh run, then seeds the perk
## deal and the loot rolls and sets the auto-pick time from `run`
## (fresh seeds when null). Keeps the party and run length.
func reset(run: RunConfig = null) -> void:
	config = run if run != null else RunConfig.current()
	GameManager.reset_autoloads()
	for system in saving_systems():
		system.reset()
	PerkManager.auto_pick_seconds = config.perk_auto_pick_seconds
	PerkManager.rng.seed = config.perk_seed
	GameManager.loot_rng.seed = config.loot_seed


## Every saving system, in the one declared restore order: the autoloads
## first, then the world (whose objects live in the gameplay scene).
func saving_systems() -> Array:
	return _autoload_systems() + _world_systems()


## The run as plain data, for the save file: SaveManager's part, then
## each saving system's own keys. {} when there is no camp to save.
func snapshot() -> Dictionary:
	var data: Dictionary = SaveManager.snapshot()
	if data.is_empty():
		return {}
	for system in saving_systems():
		data.merge(system.save_state(), true)
	return data


## Whether continue_from left a save waiting for the gameplay scene.
func has_pending() -> bool:
	return not _pending.is_empty()


## Called by GameManager once the gameplay scene is ready. Applies the
## waiting save, if any: each saving system in order, then
## SaveManager.apply for the rest, then starts the clock at the morning
## after the saved day, and emits restore_finished once the follow-ups
## have run. False for a new run (nothing waiting).
func restore_pending() -> bool:
	if _pending.is_empty():
		return false
	var data: Dictionary = _pending
	_pending = {}
	for system in saving_systems():
		system.load_state(data)
	# What is not a saving system yet (it comes last in the order: the
	# world, then the heroes).
	SaveManager.apply(data)
	TimeManager.start_run(int(data["day"]) + 1)
	# After the follow-ups SaveManager.apply defers (the perk top-up).
	_finish_restore.call_deferred()
	return true


## Time and the run fields, resources, progression and perks: the
## autoloads that hold run state, in restore order.
func _autoload_systems() -> Array:
	return []


## The world objects (campfire, buildings and blueprints, torches, the
## Moon Lantern), then the heroes, from the gameplay scene, in restore
## order. Empty when there is no gameplay scene.
func _world_systems() -> Array:
	return []


func _use_party(run: RunConfig, hero: StringName, companion: StringName, nights: int) -> void:
	GameManager.nights_to_win = nights
	GameManager.set_party(hero, companion)
	run.hero_id = GameManager.hero_id
	run.companion_id = GameManager.companion_id
	run.nights_to_win = nights


func _finish_restore() -> void:
	restore_finished.emit()
