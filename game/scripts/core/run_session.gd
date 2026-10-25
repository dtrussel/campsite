extends Node

## RunSession
##
## One run's lifecycle: start a run from a
## RunConfig, continue one from saved data, reset, and announce when a
## restore has finished. It holds the run config of the run in play
## (and, once it ends, of the last run, for Again) and the draft config
## of the next run, which the title and hero select build. GameManager's start_run / continue_run /
## go_to_title (the title, hero select, pause and end screens) come
## through here; tests call it directly, with open_scene = false when
## they instance the gameplay scene themselves.
##
## A saving system is anything that holds run state. It has:
##   save_state() -> Dictionary  its own keys, at their place in the save
##                               file (the session merges them, and two
##                               systems may share an entry: a hero's
##                               signature and its XP both sit under
##                               "player");
##   load_state(data: Dictionary)  takes the whole save, reads its own
##                               keys and tolerates missing ones;
##   reset()                     back to a fresh run.
## The session walks them in one declared order, saving_systems(): time
## and the run's stats, resources, progression, perks (and the crafting
## state, which only resets), then the world objects, then the heroes.
## A hero's keys sit under "player" / "sibling" (Party.SAVE_KEYS), shared
## by several systems; snapshot merges them key by key (merge_state).
## Build mode is not run state, so it is not a saving system; reset
## leaves it.
##
## The run config is not a saving system: the session writes it into
## the save itself (RunConfig.write_save), and on Continue builds it from
## the save (RunConfig.from_save) before any saving system loads.
##
## The session also keeps the save file in step with the run: it
## autosaves once every dawn handler has run (TimeManager.dawn_settled)
## and deletes the save when a run is won or lost. SaveManager only
## handles the file.

## A continued run is fully back: the save is applied and its follow-ups
## (the perk top-up) have run. Not emitted for a new run.
signal restore_finished

## The config of the run in play, or of the last run once it has
## ended (Again replays it); the run's systems ask it the run's rules.
## Set when a run starts or continues, never changed during the run; a
## fresh Chapter 1 run of Leo with Nela before the first.
var config: RunConfig = null
## The next run's config while it is set up: the title builds it for a
## chapter or Endless (GameManager.open_hero_select), and hero select
## adds the party and the starting perk before the run starts from it.
var draft: RunConfig = null

## A save waiting for the gameplay scene (continue_from), applied by
## restore_pending.
var _pending: Dictionary = {}
## True while restore_pending loads the saving systems.
var _restoring: bool = false


func _init() -> void:
	forget_last_run()


func _ready() -> void:
	TimeManager.dawn_settled.connect(_on_dawn_settled)
	GameManager.run_ended.connect(func(_won: bool, _reason: String) -> void: SaveManager.delete_save())


## Starts a new run from `run` (Again builds one from the last run's
## config): resets every saving system, replaces any autosave and opens
## the gameplay scene, which then starts the clock at day 1.
func start(run: RunConfig, open_scene: bool = true) -> void:
	run.set_party(run.hero_id, run.companion_id)
	_pending = {}
	SaveManager.delete_save()
	get_tree().paused = false
	reset(run)
	if open_scene:
		LoadingScreen.load_scene(GameManager.GAME_SCENE)  # key art while the camp loads


## Continues the run `data` was saved from (SaveManager.load_save or
## parse): the run config is built from the save (the chapter, run
## length, endless flag, party and day chest's day), with the seeds and
## the auto-pick time from `seeds` (fresh ones when null). The save is
## applied once the gameplay scene is ready, at the morning after its
## day. False (and nothing changes) when `data` is empty.
func continue_from(data: Dictionary, seeds: RunConfig = null, open_scene: bool = true) -> bool:
	if data.is_empty():
		return false
	var run: RunConfig = RunConfig.from_save(data)
	# The save holds the hero's starting perk; the config keeps the pick
	# for Again.
	run.starting_perk = StartingPerks.chosen()
	if seeds != null:
		run.take_seeds_of(seeds)
	get_tree().paused = false
	reset(run)
	_pending = data
	if open_scene:
		LoadingScreen.load_scene(GameManager.GAME_SCENE)
	return true


## Puts every saving system back to a fresh run of `run` (the current
## config when null), then seeds the perk deal and the loot rolls and
## sets the auto-pick time from it.
func reset(run: RunConfig = null) -> void:
	if run != null:
		config = run
	BuildManager.exit_build_mode()
	for system in saving_systems():
		system.reset()
	PerkManager.auto_pick_seconds = config.perk_auto_pick_seconds
	PerkManager.rng.seed = config.perk_seed
	GameManager.loot_rng.seed = config.loot_seed


## Forgets the last run, its config and any save waiting to load: the
## run config is a fresh 3-night Chapter 1 run of Leo with Nela, with no
## day chest, and so is the draft (smoke does this between scenarios).
func forget_last_run() -> void:
	config = RunConfig.new()
	draft = RunConfig.for_chapter(1)
	_pending = {}


## Every saving system, in the one declared restore order: the autoloads
## first, then the world (whose objects live in the gameplay scene).
func saving_systems() -> Array:
	return autoload_systems() + _world_systems()


## The run as plain data, for the save file: the version stamp, the run
## config's keys, then each saving system's own keys. {} when there is no camp to save (no
## campfire or a hero missing).
func snapshot() -> Dictionary:
	var tree: SceneTree = get_tree()
	if tree.get_first_node_in_group("base_core") == null \
			or Party.member(Party.PLAYER) == null or Party.member(Party.COMPANION) == null:
		return {}
	var data: Dictionary = {"version": SaveManager.VERSION}
	config.write_save(data)
	for system in saving_systems():
		merge_state(data, system.save_state())
	return data


## Merges one saving system's `part` into the save `into`: a dictionary
## both hold (a hero's "player" entry) is merged key by key, anything
## else is replaced. `part` is copied, never shared.
static func merge_state(into: Dictionary, part: Dictionary) -> void:
	for key in part.keys():
		var value: Variant = part[key]
		if into.get(key) is Dictionary and value is Dictionary:
			merge_state(into[key], value)
		elif value is Dictionary or value is Array:
			into[key] = value.duplicate(true)
		else:
			into[key] = value


## Writes the run to the save file now (the dawn autosave calls this).
## False when there is no camp to save or the file cannot be written.
func save_now() -> bool:
	return SaveManager.write(snapshot())


## Whether a save is being loaded right now: level-ups replayed from it
## still apply their stat bumps, but skip the fanfare and deal no card
## (the perks come from the save; what is still owed is dealt once
## restore_finished fires).
func is_restoring() -> bool:
	return _restoring


## Called by GameManager once the gameplay scene is ready. Applies the
## waiting save, if any: each saving system in order (the autoloads,
## then the world, then the heroes), then starts the clock at the morning
## after the saved day. restore_finished follows (deferred, once the
## scene's run_started has gone out); its listeners are the follow-ups,
## such as the perk top-up. False for a new run (nothing waiting).
func restore_pending() -> bool:
	if _pending.is_empty():
		return false
	var data: Dictionary = _pending
	_pending = {}
	_restoring = true
	for system in saving_systems():
		system.load_state(data)
	_restoring = false
	TimeManager.start_run(TimeManager.day_number + 1)  # the saved day, loaded
	_finish_restore.call_deferred()
	return true


## Time and the run's stats, resources, progression and perks, then the
## crafting state: the autoloads that hold run state, in restore order
## (the validator checks each one on its own).
func autoload_systems() -> Array:
	return [TimeManager, GameManager, ResourceManager, ProgressionManager, PerkManager, CraftingManager]


## The world objects (campfire, buildings and blueprints, torches, the
## Moon Lantern), then the heroes, from the gameplay scene, in restore
## order. Buildings and torches are listed by their own module; the
## rest are the objects themselves, left out when the scene has none.
func _world_systems() -> Array:
	var tree: SceneTree = get_tree()
	var out: Array = []
	var fire: BaseCore = tree.get_first_node_in_group("base_core") as BaseCore
	if fire != null:
		out.append(fire)
	out.append(BuildingSaves.new(tree))
	out.append(TorchSaves.new(tree))
	var lantern: MoonLantern = MoonLantern.find(tree)
	if lantern != null:
		out.append(lantern)
	out.append_array(Party.heroes())
	return out


func _finish_restore() -> void:
	restore_finished.emit()


func _on_dawn_settled(_day: int) -> void:
	# Every dawn handler (the win check, the companion waking up, torches
	# burning out, the night's XP) has run.
	if GameManager.is_playing():
		save_now()
