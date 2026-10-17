extends Node

## Main
##
## Gameplay scene root: the test world plus HUD and overlays. Once the
## whole scene is in the tree it tells GameManager to start the run, so
## every scene-side listener hears the first day_started. It also adds
## the BarkDirector, so the siblings talk during the run (feature 037).


func _ready() -> void:
	add_child(BarkDirector.new())
	GameManager.on_game_scene_ready.call_deferred()
