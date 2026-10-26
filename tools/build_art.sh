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
	set -- $(cd "$ROOT/art" && ls ground/*.py nature/*.py props/*.py characters/*.py 2>/dev/null | sed 's/\.py$//')
fi
# A builder that fails (a traceback, a bad bake) fails the script, after
# the rest have run. The filter only hides Blender's progress noise; its
# own status is ignored (it finds nothing to print when all is noise).
failed=()
for script in "$@"; do
	echo "== $script"
	status=0
	"$PY" "$ROOT/art/$script.py" 2>&1 \
		| { grep -vE "^(Info|Read |Fra:|  |$)|Sample|Tiles|Denois|Synchron|Updating|Loading|Rendering|Baking" || true; } \
		|| status=$?
	if [[ $status -ne 0 ]]; then
		echo "FAIL: $script exited with $status" >&2
		failed+=("$script")
	fi
done
if [[ ${#failed[@]} -gt 0 ]]; then
	echo "FAIL: ${#failed[@]} builder(s) failed: ${failed[*]}" >&2
	exit 1
fi
