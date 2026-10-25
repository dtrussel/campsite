class_name ProfileMemoryStore
extends RefCounted

## ProfileMemoryStore
##
## The unit tests' profile store (Profile.use_memory): the same JSON
## text ProfileFileStore keeps, held in memory and never saved.

var _text: String = ""
var _written: bool = false


## Whether the profile was ever written here (else it is new).
func exists() -> bool:
	return _written


## The text kept, or "" when there is none.
func read() -> String:
	return _text


func write(text: String) -> void:
	_text = text
	_written = true


func remove() -> void:
	_text = ""
	_written = false


## Where it is, for the playtest log.
func where() -> String:
	return "memory"
