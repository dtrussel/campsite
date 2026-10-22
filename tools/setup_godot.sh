#!/usr/bin/env bash
# Installs the Godot version in tools/godot_version.txt as `godot` on
# PATH (~/.local/bin), the way CI does. A no-op when it is already there.
# Run by the SessionStart hook in cloud sessions; safe to run by hand.
set -euo pipefail

version="$(cat "$(dirname "$0")/godot_version.txt")"   # e.g. 4.3.stable
release="${version%.*}-${version##*.}"                 # 4.3-stable
bin="$HOME/.local/bin/godot"

if command -v godot >/dev/null && [[ "$(godot --version | cut -d. -f1-3)" == "$version" ]]; then
	exit 0
fi

dir="$HOME/godot-$version"
mkdir -p "$dir" "$(dirname "$bin")"
curl -fsSL -o "$dir/godot.zip" \
	"https://github.com/godotengine/godot/releases/download/$release/Godot_v${release}_linux.x86_64.zip"
unzip -qo "$dir/godot.zip" -d "$dir"
rm "$dir/godot.zip"
ln -sf "$dir/Godot_v${release}_linux.x86_64" "$bin"
echo "Installed Godot $("$bin" --version)"
