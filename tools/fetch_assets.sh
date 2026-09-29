#!/usr/bin/env bash
# Vendors the CC0 KayKit models and OFL fonts the game uses into
# game/assets/. The results are committed, so this only needs to be
# re-run when the asset list below changes.
#
# Sources (all CC0 1.0, by Kay Lousberg - https://kaylousberg.com):
#   github.com/KayKit-Game-Assets/<pack>, pinned to the commits below.
# Fonts (SIL OFL 1.1): github.com/google/fonts
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/game/assets"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# pack name | pinned commit | folder under game/assets/kaykit | models (basenames)
PACKS=(
	"KayKit-Character-Pack-Adventures-1.0|672074b73ba276876a19e8816ecdc5241817ab47|adventurers|Rogue.glb Mage.glb axe_1handed.gltf wand.gltf"
	"KayKit-Character-Pack-Skeletons-1.0|15b62b9bad122f72926c10fb14d622c73819fa54|skeletons|Skeleton_Minion.glb"
)

for entry in "${PACKS[@]}"; do
	IFS='|' read -r pack commit folder models <<<"$entry"
	echo "== $pack"
	repo="$WORK/$pack"
	git clone -q --filter=blob:none --no-checkout "https://github.com/KayKit-Game-Assets/$pack" "$repo"
	git -C "$repo" checkout -q "$commit" -- LICENSE.txt 2>/dev/null || true
	out="$DEST/kaykit/$folder"
	mkdir -p "$out"
	cp "$repo/LICENSE.txt" "$out/LICENSE.txt" 2>/dev/null || true
	all_files="$(git -C "$repo" ls-tree -r --name-only "$commit" | grep -E '/(gltf|Characters/gltf)/|/gltf/' | grep -v 'fbx')"
	for model in $models; do
		path="$(grep -E "/${model//./\\.}$" <<<"$all_files" | head -1)"
		if [[ -z "$path" ]]; then
			echo "missing: $model" >&2
			exit 1
		fi
		dir="$(dirname "$path")"
		stem="${model%.*}"
		# The model, its buffer (for .gltf) and every texture in its folder.
		wanted=("$path")
		[[ "$model" == *.gltf ]] && wanted+=("$dir/$stem.bin")
		while IFS= read -r tex; do wanted+=("$tex"); done < <(grep -E "^${dir//./\\.}/[^/]+\.png$" <<<"$all_files")
		git -C "$repo" checkout -q "$commit" -- "${wanted[@]}"
		for f in "${wanted[@]}"; do cp "$repo/$f" "$out/"; done
	done
	# Only keep textures a copied model actually references.
	for tex in "$out"/*.png; do
		name="$(basename "$tex")"
		if ! grep -lq "$name" "$out"/*.gltf "$out"/*.glb 2>/dev/null; then
			rm -f "$tex"
		fi
	done
done

echo "== fonts"
mkdir -p "$DEST/fonts"
FONTS=https://raw.githubusercontent.com/google/fonts/main/ofl
curl -sSfL -o "$DEST/fonts/Cinzel.ttf" "$FONTS/cinzel/Cinzel%5Bwght%5D.ttf"
curl -sSfL -o "$DEST/fonts/Cinzel-OFL.txt" "$FONTS/cinzel/OFL.txt"
curl -sSfL -o "$DEST/fonts/NunitoSans.ttf" "$FONTS/nunitosans/NunitoSans%5BYTLC,opsz,wdth,wght%5D.ttf"
curl -sSfL -o "$DEST/fonts/NunitoSans-OFL.txt" "$FONTS/nunitosans/OFL.txt"

du -sh "$DEST/kaykit"/* "$DEST/fonts"
echo "Assets fetched."
