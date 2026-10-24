extends RefCounted

## What every unit test script (tests/unit/test_*.gd) extends: the
## checks and their ok/FAIL reporting. unit_run.gd plays the scripts.
##
## A test script defines methods named test_*, each a few checks on one
## rule through a module's public interface. The runner calls them in
## the order they are written, each on a fresh instance of the script,
## and calls after_each() when each is done. No test needs the gameplay
## scene or a camp; one that needs a file keeps its own under user://.

## The checks failed in the test now running (the runner reads it).
var failures: int = 0


## Runs after every test method; a script overrides it to free what
## its tests made.
func after_each() -> void:
	pass


## Passes when `condition` holds; `what` says what was expected.
func check(condition: bool, what: String) -> void:
	if condition:
		print("unit: ok   %s" % what)
	else:
		failures += 1
		printerr("unit: FAIL %s" % what)


## Passes when `actual` equals `expected` (and is of the same type); a
## failure prints both.
func check_eq(actual: Variant, expected: Variant, what: String) -> void:
	if typeof(actual) == typeof(expected) and actual == expected:
		print("unit: ok   %s" % what)
	else:
		failures += 1
		printerr("unit: FAIL %s (got %s, expected %s)" % [what, var_to_str(actual), var_to_str(expected)])
