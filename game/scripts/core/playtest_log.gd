extends Node

## PlaytestLog
##
## Appends timestamped gameplay events (runs, waves, damage to the
## camp, deaths, crafting) to user://playtest_log.txt so a playtester
## can send the file along with their feedback. Kept deliberately
## small: one line per event, trimmed when it grows past MAX_BYTES.

const LOG_PATH: String = "user://playtest_log.txt"
const MAX_BYTES: int = 512 * 1024

var _file: FileAccess = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var mode: FileAccess.ModeFlags = FileAccess.READ_WRITE
	if not FileAccess.file_exists(LOG_PATH):
		mode = FileAccess.WRITE
	else:
		var existing: FileAccess = FileAccess.open(LOG_PATH, FileAccess.READ)
		if existing != null and existing.get_length() > MAX_BYTES:
			mode = FileAccess.WRITE  # start fresh rather than grow forever
		existing = null
	_file = FileAccess.open(LOG_PATH, mode)
	if _file == null:
		push_warning("PlaytestLog: cannot open %s" % LOG_PATH)
		return
	_file.seek_end()
	write("session_started version=%s os=%s" % [
		ProjectSettings.get_setting("application/config/version", "dev"), OS.get_name()
	])


func write(message: String) -> void:
	if _file == null:
		return
	_file.store_line("%s  %s" % [Time.get_datetime_string_from_system(), message])
	_file.flush()


## Absolute path shown to the tester on the end screen.
func get_absolute_path() -> String:
	return ProjectSettings.globalize_path(LOG_PATH)
