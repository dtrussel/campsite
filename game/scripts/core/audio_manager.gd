extends Node

## AudioManager
##
## Plays every sound in the game (feature 016):
## - one-shots via play_sfx(id, position): 3D when a position is given,
##   flat on the UI bus for UI ids; a random variant and a little pitch
##   jitter each time. Fx.burst() calls this, so every particle burst
##   has a matching sound for free.
## - music and ambience: a day and a night "mood", crossfaded when
##   TimeManager changes phase, with win / lose stingers at run end.
## - volume settings (Music, SFX) saved to user://settings.cfg.
## Data lives in res://resources/audio/audio_library.tres.

signal mood_changed(mood: StringName)

const LIBRARY_PATH: String = "res://resources/audio/audio_library.tres"
const SETTINGS_PATH: String = "user://settings.cfg"
const POOL_3D: int = 16
const POOL_2D: int = 6
const CROSSFADE_SECONDS: float = 2.5
const SILENT_DB: float = -60.0
const MUSIC_DB: float = -6.0
const AMBIENCE_DB: float = -10.0
## How far away a one-shot is still heard. The camera (the listener)
## sits about 15 m from the boy.
const UNIT_SIZE: float = 18.0
const MAX_DISTANCE: float = 80.0

var library: AudioLibrary = null
var mood: StringName = &""
var music_volume: float = 0.8
var sfx_volume: float = 1.0

var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
## [music A, music B] and [ambience A, ambience B]; index 0 is "current".
var _music: Array[AudioStreamPlayer] = []
var _ambience: Array[AudioStreamPlayer] = []
var _last_variant: Dictionary = {}  # id -> index, to avoid repeats
var _fades: Dictionary = {}  # AudioStreamPlayer -> Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	library = load(LIBRARY_PATH) as AudioLibrary
	if library == null:
		push_warning("AudioManager: missing %s; the game will be silent" % LIBRARY_PATH)
		library = AudioLibrary.new()
	_ensure_buses()
	for i in POOL_3D:
		var p3: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		p3.bus = &"SFX"
		p3.unit_size = UNIT_SIZE
		p3.max_distance = MAX_DISTANCE
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p3)
		_pool_3d.append(p3)
	for i in POOL_2D:
		var p2: AudioStreamPlayer = AudioStreamPlayer.new()
		p2.bus = &"UI"
		add_child(p2)
		_pool_2d.append(p2)
	for i in 2:
		_music.append(_make_loop_player(&"Music"))
		_ambience.append(_make_loop_player(&"SFX"))
	_load_settings()
	# Only follow the clock during a run: the winning dawn also ends the
	# run, and the stinger must not be buried under the day tune.
	TimeManager.day_started.connect(func(_day: int) -> void: _set_run_mood(&"day"))
	TimeManager.dawn_started.connect(func(_day: int) -> void: _set_run_mood(&"day"))
	TimeManager.night_started.connect(func(_day: int) -> void: _set_run_mood(&"night"))
	TimeManager.sunset_warning.connect(_on_sunset_warning)
	GameManager.run_ended.connect(_on_run_ended)


## Plays a one-shot. With a position it is heard in 3D from there;
## without one (or for UI ids) it plays flat. Unknown ids are ignored,
## so callers never need to check.
func play_sfx(id: StringName, position: Variant = null) -> void:
	if library == null or not library.has_sound(id):
		return
	var streams: Array[AudioStream] = library.streams_for(id)
	if streams.is_empty():
		return
	var stream: AudioStream = streams[_pick_variant(id, streams.size())]
	var pitch: float = 1.0 + randf_range(-library.pitch_jitter, library.pitch_jitter)
	var volume: float = library.volume_db(id)
	if position is Vector3 and not library.ui_ids.has(id):
		var p3: AudioStreamPlayer3D = _take_3d()
		p3.stream = stream
		p3.volume_db = volume
		p3.pitch_scale = pitch
		p3.global_position = position
		p3.play()
	else:
		var p2: AudioStreamPlayer = _take_2d()
		p2.stream = stream
		p2.volume_db = volume
		# Stingers and chimes keep their tuning; clicks and world sounds vary.
		p2.pitch_scale = 1.0 if library.ui_ids.has(id) and id != &"ui_click" else pitch
		p2.bus = &"UI" if library.ui_ids.has(id) else &"SFX"
		p2.play()


## Crossfades music and ambience to a mood: &"day", &"night", or
## &"" (silence).
func set_mood(new_mood: StringName) -> void:
	if new_mood == mood:
		return
	mood = new_mood
	var music_stream: AudioStream = null
	var ambience_stream: AudioStream = null
	match new_mood:
		&"day":
			music_stream = library.music_day
			ambience_stream = library.ambience_day
		&"night":
			music_stream = library.music_night
			ambience_stream = library.ambience_night
	_crossfade(_music, music_stream, MUSIC_DB)
	_crossfade(_ambience, ambience_stream, AMBIENCE_DB)
	mood_changed.emit(new_mood)


## The stream the current music player is playing (null when silent).
func current_music() -> AudioStream:
	return _music[0].stream if _music[0].playing else null


## A looping 3D player for a world object (the campfire uses this).
func make_ambient_emitter(stream: AudioStream, volume: float = 0.0) -> AudioStreamPlayer3D:
	var player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
	player.stream = _looped(stream)
	player.bus = &"SFX"
	player.volume_db = volume
	player.unit_size = 6.0
	player.max_distance = 45.0
	player.autoplay = stream != null
	return player


func set_music_volume(linear: float) -> void:
	music_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(&"Music", music_volume)
	_save_settings()


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clampf(linear, 0.0, 1.0)
	_apply_bus_volume(&"SFX", sfx_volume)
	_save_settings()


func _set_run_mood(new_mood: StringName) -> void:
	if GameManager.is_playing():
		set_mood(new_mood)


func _on_sunset_warning(_seconds: float) -> void:
	play_sfx(&"sunset")
	# Let the day tune sink under the owl so the warning stands out.
	if _music[0].playing:
		_fade(_music[0], MUSIC_DB - 10.0, false, 1.5)


func _on_run_ended(won: bool, _reason: String) -> void:
	set_mood(&"")
	play_sfx(&"win" if won else &"lose")


func _crossfade(pair: Array[AudioStreamPlayer], stream: AudioStream, target_db: float) -> void:
	var old: AudioStreamPlayer = pair[0]
	var incoming: AudioStreamPlayer = pair[1]
	pair.reverse()
	if old.playing:
		_fade(old, SILENT_DB, true)
	if stream == null:
		_kill_fade(incoming)
		incoming.stop()
		return
	incoming.stream = _looped(stream)
	incoming.volume_db = SILENT_DB
	incoming.play()
	_fade(incoming, target_db, false)


## Tweens a player's volume, replacing any fade already running on it
## (so a quick day -> night -> day never stops the wrong track).
func _fade(player: AudioStreamPlayer, to_db: float, stop_after: bool, seconds: float = CROSSFADE_SECONDS) -> void:
	_kill_fade(player)
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, seconds)
	if stop_after:
		tween.tween_callback(player.stop)
	_fades[player] = tween


func _kill_fade(player: AudioStreamPlayer) -> void:
	var running: Tween = _fades.get(player) as Tween
	if running != null and running.is_valid():
		running.kill()
	_fades.erase(player)


func _looped(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _make_loop_player(bus: StringName) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.bus = bus
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func _pick_variant(id: StringName, count: int) -> int:
	if count <= 1:
		return 0
	var index: int = randi() % count
	if index == int(_last_variant.get(id, -1)):
		index = (index + 1) % count
	_last_variant[id] = index
	return index


func _take_3d() -> AudioStreamPlayer3D:
	for i in POOL_3D:
		var candidate: AudioStreamPlayer3D = _pool_3d[(_next_3d + i) % POOL_3D]
		if not candidate.playing:
			_next_3d = (_next_3d + i + 1) % POOL_3D
			return candidate
	var oldest: AudioStreamPlayer3D = _pool_3d[_next_3d]
	_next_3d = (_next_3d + 1) % POOL_3D
	return oldest


func _take_2d() -> AudioStreamPlayer:
	for i in POOL_2D:
		var candidate: AudioStreamPlayer = _pool_2d[(_next_2d + i) % POOL_2D]
		if not candidate.playing:
			_next_2d = (_next_2d + i + 1) % POOL_2D
			return candidate
	var oldest: AudioStreamPlayer = _pool_2d[_next_2d]
	_next_2d = (_next_2d + 1) % POOL_2D
	return oldest


## The buses come from default_bus_layout.tres; this only fills in any
## that are missing, so the game never errors on an old layout.
func _ensure_buses() -> void:
	for bus_name in [&"Music", &"SFX", &"UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			var index: int = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus_name)
			AudioServer.set_bus_send(index, &"SFX" if bus_name == &"UI" else &"Master")


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


func _load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) == OK:
		music_volume = clampf(float(config.get_value("audio", "music", music_volume)), 0.0, 1.0)
		sfx_volume = clampf(float(config.get_value("audio", "sfx", sfx_volume)), 0.0, 1.0)
	_apply_bus_volume(&"Music", music_volume)
	_apply_bus_volume(&"SFX", sfx_volume)


func _save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep any other sections
	config.set_value("audio", "music", music_volume)
	config.set_value("audio", "sfx", sfx_volume)
	config.save(SETTINGS_PATH)
