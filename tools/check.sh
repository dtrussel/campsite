#!/usr/bin/env bash
# Headless project checks. Run from anywhere:
#   tools/check.sh            (uses `godot` on PATH, or $GODOT)
#
# 1. Re-imports the project (refreshes the class_name cache).
# 2. Loads every script/scene/resource and validates data integrity.
# 3. Plays a full win run and a loss run headlessly (smoke test).
# Fails on any non-zero exit, timeout, or SCRIPT ERROR in the output.
set -euo pipefail

GODOT="${GODOT:-godot}"
GAME_DIR="$(cd "$(dirname "$0")/../game" && pwd)"
LOG_DIR="$(mktemp -d)"

expected="$(cat "$(dirname "$0")/godot_version.txt")"
actual="$("$GODOT" --version | cut -d. -f1-3)"
if [[ "$actual" != "$expected" ]]; then
	echo "warning: expected Godot $expected, found $actual" >&2
fi

run_scene() {
	local name="$1" scene="$2" log="$LOG_DIR/$1.log" status=0
	echo "== $name"
	timeout 300 "$GODOT" --headless --path "$GAME_DIR" "$scene" >"$log" 2>&1 || status=$?
	if grep -E "SCRIPT ERROR|Parse Error|Failed loading resource" "$log"; then
		echo "FAIL: $name reported script/load errors (log: $log)" >&2
		exit 1
	fi
	if [[ $status -ne 0 ]]; then
		grep -E "^(smoke|validate_project):" "$log" >&2 || tail -40 "$log" >&2
		echo "FAIL: $name exited with $status (log: $log)" >&2
		exit 1
	fi
	grep -E "^(smoke: (PASSED|FAIL)|validate_project:)" "$log" || true
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
run_scene smoke res://tests/automated/smoke_run.tscn
echo "All checks passed."
