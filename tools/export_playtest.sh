#!/usr/bin/env bash
# Builds the playtest packages:
#   build/Campsite-<version>-windows.zip  (Campsite.exe + PLAYTEST-README.txt)
#   build/Campsite-<version>-linux.zip    (Campsite.x86_64 + PLAYTEST-README.txt)
# The Linux build is self-tested (it must load its exported data).
#   tools/export_playtest.sh --split   also makes the Windows build as two
#                                      smaller zips (program + data)
#
# Requires Godot export templates for the version in godot_version.txt
# (Editor > Manage Export Templates, or unpack the .tpz into
# ~/.local/share/godot/export_templates/<version>/).
set -euo pipefail

GODOT="${GODOT:-godot}"
MAKE_SPLIT=0
[[ "${1:-}" == "--split" ]] && MAKE_SPLIT=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GAME_DIR="$ROOT/game"
BUILD_DIR="$ROOT/build"
VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$GAME_DIR/project.godot")"

rm -rf "$BUILD_DIR/windows" "$BUILD_DIR/linux"
mkdir -p "$BUILD_DIR/windows" "$BUILD_DIR/linux"

echo "== import"
"$GODOT" --headless --path "$GAME_DIR" --import >/dev/null 2>&1 || true

echo "== export Linux (for self-test)"
"$GODOT" --headless --path "$GAME_DIR" --export-release "Linux" "$BUILD_DIR/linux/Campsite.x86_64" >/dev/null 2>&1
echo "== self-test exported build"
if ! timeout 60 "$BUILD_DIR/linux/Campsite.x86_64" --headless -- --selftest 2>&1 | grep "selftest:.*OK"; then
	echo "FAIL: exported build could not load its data" >&2
	exit 1
fi
cp "$ROOT/docs/testing/PLAYTEST-README.txt" "$BUILD_DIR/linux/PLAYTEST-README.txt"
LINUX_ZIP="$BUILD_DIR/Campsite-$VERSION-linux.zip"
rm -f "$LINUX_ZIP"
(cd "$BUILD_DIR/linux" && zip -q -9 "$LINUX_ZIP" Campsite.x86_64 PLAYTEST-README.txt)
ls -la "$LINUX_ZIP"

echo "== export Windows"
"$GODOT" --headless --path "$GAME_DIR" --export-release "Windows Desktop" "$BUILD_DIR/windows/Campsite.exe" >/dev/null 2>&1
cp "$ROOT/docs/testing/PLAYTEST-README.txt" "$BUILD_DIR/windows/PLAYTEST-README.txt"
ZIP="$BUILD_DIR/Campsite-$VERSION-windows.zip"
rm -f "$ZIP"
(cd "$BUILD_DIR/windows" && zip -q -9 "$ZIP" Campsite.exe PLAYTEST-README.txt)
ls -la "$ZIP"

if [[ $MAKE_SPLIT -eq 1 ]]; then
	# Also ship as two smaller zips (program + data) for channels with an
	# upload size limit: the stock runtime loads Campsite.pck from the
	# exe's folder.
	SPLIT="$BUILD_DIR/split"
	rm -rf "$SPLIT" && mkdir -p "$SPLIT"
	TEMPLATES="${GODOT_TEMPLATES:-$HOME/.local/share/godot/export_templates/$(cat "$(dirname "$0")/godot_version.txt")}"
	cp "$TEMPLATES/windows_release_x86_64.exe" "$SPLIT/Campsite.exe"
	"$GODOT" --headless --path "$GAME_DIR" --export-pack "Windows Desktop" "$SPLIT/Campsite.pck" >/dev/null 2>&1
	cp "$ROOT/docs/testing/PLAYTEST-README.txt" "$SPLIT/"
	(cd "$SPLIT" && zip -q -9 "Campsite-$VERSION-part1-program.zip" Campsite.exe \
		&& zip -q -9 "Campsite-$VERSION-part2-data.zip" Campsite.pck PLAYTEST-README.txt)
	ls -la "$SPLIT"/*.zip
fi
echo "Playtest packages ready: $ZIP and $LINUX_ZIP"
