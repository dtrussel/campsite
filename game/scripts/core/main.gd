extends Node

## Main
##
## Entry point. Phase 0 keeps this minimal: loads the test world and
## HUD as scene instances, and handles the Esc-to-quit input action.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		get_tree().quit()
