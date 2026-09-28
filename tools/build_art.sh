#!/usr/bin/env bash
# Builds procedural art with Blender's bpy module (see art/).
#   tools/build_art.sh                 # everything
#   tools/build_art.sh nature/rocks    # one script
# Outputs go to game/assets/custom/ (committed). Previews go to
# build/art_previews/ (or $ART_PREVIEW_DIR).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/.venv-blender/bin/python"
[[ -x "$PY" ]] || "$ROOT/tools/setup_blender.sh"
if [[ $# -eq 0 ]]; then
	set -- $(cd "$ROOT/art" && ls nature/*.py props/*.py characters/*.py 2>/dev/null | sed 's/\.py$//')
fi
for script in "$@"; do
	echo "== $script"
	"$PY" "$ROOT/art/$script.py" 2>&1 | grep -vE "^(Info|Read |Fra:|  |$)|Sample|Tiles|Denois|Synchron|Updating|Loading|Rendering|Baking" || true
done
