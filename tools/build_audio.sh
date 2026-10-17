#!/usr/bin/env bash
# Builds the game's procedural sound (see art/audio/): numpy synthesis,
# written as .ogg to game/assets/audio/ (committed, so the game never
# needs Python).
#   tools/build_audio.sh                # everything
#   tools/build_audio.sh sfx hit wood   # just some one-shots
#   tools/build_audio.sh music night    # just loops whose path matches
#   tools/build_audio.sh voice          # TTS voice lines (not in "everything":
#                                       # slow, and downloads a ~350 MB model)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VENV="$ROOT/.venv-audio"
if [[ ! -x "$VENV/bin/python" ]]; then
	python3 -m venv "$VENV"
	"$VENV/bin/pip" install -q --upgrade pip
	"$VENV/bin/pip" install -q "numpy>=1.26" "soundfile>=0.12"
fi
cd "$ROOT/art/audio"
if [[ $# -eq 0 ]]; then
	"$VENV/bin/python" sfx.py
	"$VENV/bin/python" music.py
else
	what="$1"
	shift
	if [[ "$what" == voice ]] && ! "$VENV/bin/python" -c "import kokoro_onnx" 2>/dev/null; then
		"$VENV/bin/pip" install -q "kokoro-onnx>=0.4"
	fi
	"$VENV/bin/python" "$what.py" "$@"
fi
