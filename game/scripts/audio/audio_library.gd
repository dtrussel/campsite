class_name AudioLibrary
extends Resource

## AudioLibrary
##
## Data for every sound the game plays (feature 016). One-shots are
## found by naming convention: `<sfx_dir>/<id>_<n>.ogg` for n = 1, 2, ...
## (AudioManager picks a random variant), so adding a variant is just
## dropping in a file. This resource holds the tuning: per-id volume,
## which ids are UI sounds, and the music / ambience loops.
## The sounds themselves are built by `art/audio/` (tools/build_audio.sh).

const MAX_VARIANTS: int = 8

@export var sfx_dir: String = "res://assets/audio/sfx"
## id -> volume offset in dB. Every playable one-shot id must be listed.
@export var volumes: Dictionary = {}
## Ids played flat (no 3D position) on the UI bus.
@export var ui_ids: Array[StringName] = []
## Random pitch spread for one-shots (0.08 = +/-8%).
@export var pitch_jitter: float = 0.08
@export var music_day: AudioStream = null
@export var music_night: AudioStream = null
@export var ambience_day: AudioStream = null
@export var ambience_night: AudioStream = null
@export var ambience_campfire: AudioStream = null

var _variants: Dictionary = {}  # StringName -> Array[AudioStream]


func has_sound(id: StringName) -> bool:
	return volumes.has(id)


## Every variant file of a one-shot id (empty if none exist).
func streams_for(id: StringName) -> Array[AudioStream]:
	if _variants.has(id):
		return _variants[id]
	var out: Array[AudioStream] = []
	for n in range(1, MAX_VARIANTS + 1):
		var path: String = "%s/%s_%d.ogg" % [sfx_dir, id, n]
		if not ResourceLoader.exists(path):
			break
		var stream: AudioStream = load(path) as AudioStream
		if stream != null:
			out.append(stream)
	_variants[id] = out
	return out


func volume_db(id: StringName) -> float:
	return float(volumes.get(id, 0.0))
