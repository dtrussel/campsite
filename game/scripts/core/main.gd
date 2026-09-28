extends Node

## Main
##
## Gameplay scene root: the test world plus HUD and overlays. Once the
## whole scene is in the tree it tells GameManager to start the run, so
## every scene-side listener hears the first day_started.


func _ready() -> void:
	GameManager.on_game_scene_ready.call_deferred()
