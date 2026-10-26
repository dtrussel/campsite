extends RefCounted

## clip_review_data.gd
##
## The game's numbers the clip review sheets (art/review/clip_sheet.py,
## which runs in Blender and cannot read the game) use: the gameplay
## camera, the walk speed, the build mallet's scale, the walk and run
## play-speed rules, and each hero's clips, speeds and action play
## speeds. They are committed as JSON beside the script; the validator
## fails when the file no longer matches the game, and writes it again
## with `-- --write-clip-review`.

const PATH: String = "res://../art/review/game_numbers.json"
const WRITE_FLAG: String = "--write-clip-review"
const CAMERA_SCENE: String = "res://scenes/world/TestWorld.tscn"
const CAMERA_SCRIPT: String = "res://scripts/utilities/camera_follow.gd"


## The numbers, from the game's own scripts and data.
static func build() -> Dictionary:
	var rig: Node3D = (load(CAMERA_SCRIPT) as GDScript).new() as Node3D
	var pitch: float = float(rig.get("pitch_degrees"))
	rig.free()
	var visual: CharacterVisual = CharacterVisual.new()
	var walk_speed: float = visual.walk_speed
	visual.free()
	var heroes: Dictionary = {}
	for hero in HeroRoster.all():
		heroes[String(hero.id)] = {
			"clips": hero.clips,
			"model_scale": hero.model_scale,
			"move_speed": hero.move_speed,
			"reference_speed": hero.reference_speed,
			"walk_reference_speed": hero.walk_reference_speed,
			"tool_hidden_parts": Array(hero.tool_hidden_parts),
			"play_speeds": hero.action_play_speeds(),
		}
	return {
		"camera": {"pitch_degrees": pitch, "fov_degrees": _camera_fov()},
		"walk_speed": walk_speed,
		"tool_scale": CharacterVisual.TOOL_SCALE,
		"walk_play_speed": {"min": CharacterVisual.WALK_PLAY_MIN, "max": CharacterVisual.WALK_PLAY_MAX},
		"run_play_speed": {"min": CharacterVisual.RUN_PLAY_MIN, "max": CharacterVisual.RUN_PLAY_MAX},
		"heroes": heroes,
	}


## The JSON text the file should hold.
static func text() -> String:
	return JSON.stringify(build(), "  ", true) + "\n"


static func path() -> String:
	return ProjectSettings.globalize_path(PATH).simplify_path()


## "" when the committed file matches the game, else what is wrong.
static func problem() -> String:
	if not FileAccess.file_exists(path()):
		return "%s is missing" % PATH.trim_prefix("res://../")
	if FileAccess.get_file_as_string(path()) != text():
		return "%s no longer matches the game's numbers" % PATH.trim_prefix("res://../")
	return ""


static func write() -> void:
	var file: FileAccess = FileAccess.open(path(), FileAccess.WRITE)
	file.store_string(text())
	file.close()


## The gameplay camera's lens, from the world scene.
static func _camera_fov() -> float:
	var state: SceneState = (load(CAMERA_SCENE) as PackedScene).get_state()
	for node in state.get_node_count():
		if state.get_node_type(node) != &"Camera3D":
			continue
		for i in state.get_node_property_count(node):
			if state.get_node_property_name(node, i) == &"fov":
				return float(state.get_node_property_value(node, i))
	var lens: Camera3D = Camera3D.new()
	var fov: float = lens.fov
	lens.free()
	return fov
