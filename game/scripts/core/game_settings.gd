class_name GameSettings
extends RefCounted

## GameSettings
##
## Gameplay options from the pause menu, saved in user://settings.cfg
## (section "gameplay", next to AudioManager's and PostFx's sections).
## Playtest 1 (feature 044): the hero's auto-attack, on by default.

const SETTINGS_PATH: String = "user://settings.cfg"


static func auto_attack() -> bool:
	var config: ConfigFile = ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return true
	return bool(config.get_value("gameplay", "auto_attack", true))


static func set_auto_attack(enabled: bool) -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(SETTINGS_PATH)  # keep any other sections
	config.set_value("gameplay", "auto_attack", enabled)
	config.save(SETTINGS_PATH)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		for player in tree.get_nodes_in_group("player"):
			player.set("auto_attack", enabled)
