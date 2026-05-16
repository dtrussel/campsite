extends Node

## Main
##
## Entry point. Phase 0 keeps this minimal: loads the test world and
## HUD as scene instances, and handles the Esc-to-quit input action.


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quit_game"):
		# BuildManager treats Esc as cancel while in build mode; don't
		# also quit the game in that case.
		if BuildManager.is_in_build_mode():
			return
		get_tree().quit()
