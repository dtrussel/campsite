class_name StorageCrate
extends Building

## StorageCrate
##
## A big lidded chest (feature 019). Each one standing in the camp
## raises every resource's stash cap by its base amount (see
## ResourceManager.get_cap). Losing it lowers the cap again, but items
## already above the new cap are kept.

func _ready() -> void:
	super()
	if has_meta(&"build_ghost"):
		return
	add_to_group(ResourceManager.STORAGE_GROUP)
	ResourceManager.notify_caps_changed()
	tree_exited.connect(ResourceManager.notify_caps_changed)
