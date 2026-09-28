#!/usr/bin/env bash
# Installs Blender as a Python module (bpy) into .venv-blender/ so the
# procedural art scripts under art/ can run headless. Only needed to
# (re)build art; the game itself uses the committed .glb outputs.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv-blender"
if [[ ! -x "$VENV/bin/python" ]]; then
	python3.11 -m venv "$VENV"
fi
"$VENV/bin/pip" install -q --upgrade pip
"$VENV/bin/pip" install -q "bpy==4.5.4" "scikit-image" "pillow"
"$VENV/bin/python" -c "import bpy; print('bpy', bpy.app.version_string)"
