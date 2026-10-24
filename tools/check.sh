#!/usr/bin/env bash
# Headless project checks. Run from anywhere:
#   tools/check.sh            (uses `godot` on PATH, or $GODOT)
#
# 1. Re-imports the project (refreshes the class_name cache).
# 2. Loads every script/scene/resource and validates data integrity.
# 3. Runs the unit tests (game/tests/unit/test_*.gd), without the
#    gameplay scene.
# 4. Plays the smoke test's scenarios headlessly, and beside it a second
#    smoke pass that stalls every few frames (below).
# 5. Runs the exported build's selftest from the project (the data and
#    gameplay scene load), so its floors are checked without templates.
# Fails on any non-zero exit, timeout, or SCRIPT ERROR in the output.
#
# The stalled pass blocks SMOKE_FRAME_STALL ms (default 150) on every
# 4th frame. The frame after a stall is long, as a hitch on a slow runner
# makes it, and Godot steps timers before tweens, so a check that races
# a tween with a fixed _wait() goes red here and not only on CI. A
# steady per-frame delay (below) does not catch that.
#
#   SMOKE_FRAME_DELAY=40 tools/check.sh   also plays the smoke test with
#       a 40 ms sleep per frame, as on a slow CI runner, to catch checks
#       that depend on how many frames fit in a wait.
set -euo pipefail

GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "$0")/../game" && pwd)"
LOG_DIR="$(mktemp -d)"
# Each run gets its own user:// (saves, profile), so runs in parallel
# worktrees never read each other's files.
export XDG_DATA_HOME="$LOG_DIR/data"

expected="$(cat "$(dirname "$0")/godot_version.txt")"
actual="$("$GODOT" --version | cut -d. -f1-3)"
if [[ "$actual" != "$expected" ]]; then
	echo "warning: expected Godot $expected, found $actual" >&2
fi

# run_scene <name> <scene> [engine options] [-- scene options]
run_scene() {
	local name="$1" scene="$2" log="$LOG_DIR/$1.log" status=0
	shift 2
	echo "== $name"
	# Its own user:// too, so passes side by side never share files.
	XDG_DATA_HOME="$LOG_DIR/data-$name" timeout 600 "$GODOT" --headless --path "$GAME_DIR" "$scene" "$@" >"$log" 2>&1 || status=$?
	if grep -E "SCRIPT ERROR|Parse Error|Failed loading resource" "$log"; then
		echo "FAIL: $name reported script/load errors (log: $log)" >&2
		exit 1
	fi
	if [[ $status -ne 0 ]]; then
		# Only what failed: the passing "ok" lines would bury it.
		grep -E "^(smoke|unit|validate_project):" "$log" | grep -vE "^(smoke|unit): (ok |---)" >&2 || tail -40 "$log" >&2
		echo "FAIL: $name exited with $status (log: $log)" >&2
		exit 1
	fi
	grep -E "^((smoke|unit): (PASSED|FAIL)|validate_project:)" "$log" || true
}

echo "== import"
timeout 300 "$GODOT" --headless --path "$GAME_DIR" --import >"$LOG_DIR/import.log" 2>&1 || true
# On a fresh checkout (CI, a new worktree) scripts that preload a .glb
# compile before that model is imported, so the first pass reports
# preload errors. A second pass sees the imported models; only its
# errors are real.
if grep -qE "SCRIPT ERROR|Parse Error" "$LOG_DIR/import.log"; then
	timeout 300 "$GODOT" --headless --path "$GAME_DIR" --import >"$LOG_DIR/import.log" 2>&1 || true
fi
if grep -E "SCRIPT ERROR|Parse Error" "$LOG_DIR/import.log"; then
	echo "FAIL: import reported errors (log: $LOG_DIR/import.log)" >&2
	exit 1
fi

run_scene validate res://tools/validate_project.tscn
run_scene unit res://tests/unit/unit_run.tscn
# The stalled pass runs beside the plain one; its report follows it.
run_scene "smoke-stalled" res://tests/automated/smoke_run.tscn -- --frame-stall "${SMOKE_FRAME_STALL:-150}" \
	>"$LOG_DIR/smoke-stalled.out" 2>&1 &
stalled_pid=$!
run_scene smoke res://tests/automated/smoke_run.tscn
stalled_status=0
wait "$stalled_pid" || stalled_status=$?
cat "$LOG_DIR/smoke-stalled.out"
if [[ $stalled_status -ne 0 ]]; then
	exit 1
fi
if [[ -n "${SMOKE_FRAME_DELAY:-}" ]]; then
	run_scene "smoke-slow" res://tests/automated/smoke_run.tscn --frame-delay "$SMOKE_FRAME_DELAY"
fi

echo "== selftest"
timeout 120 "$GODOT" --headless --path "$GAME_DIR" -- --selftest >"$LOG_DIR/selftest.log" 2>&1 || true
if grep -E "SCRIPT ERROR|Parse Error" "$LOG_DIR/selftest.log" || ! grep -E "^selftest:.*OK$" "$LOG_DIR/selftest.log"; then
	grep -E "^selftest:" "$LOG_DIR/selftest.log" >&2 || tail -20 "$LOG_DIR/selftest.log" >&2
	echo "FAIL: the selftest did not pass (log: $LOG_DIR/selftest.log)" >&2
	exit 1
fi
echo "All checks passed."
