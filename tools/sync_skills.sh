#!/usr/bin/env bash
# Vendors Matt Pocock's skills (github.com/mattpocock/skills, MIT) into
# .claude/skills/ as project skills, so they load in every session,
# cloud or local, without the plugin. Copies the skills the plugin
# ships (its .claude-plugin/plugin.json), minus the agents/ folders
# (other tools' configs).
#
#   tools/sync_skills.sh            the commit in .claude/skills/UPSTREAM
#   tools/sync_skills.sh <ref>      another commit, tag or branch (e.g. main)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.claude/skills"
REPO="https://github.com/mattpocock/skills"
REF="${1:-$(sed -n 's/^commit: //p' "$DEST/UPSTREAM" 2>/dev/null || true)}"
REF="${REF:-main}"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git clone -q "$REPO" "$TMP/skills"
git -C "$TMP/skills" checkout -q "$REF"
COMMIT="$(git -C "$TMP/skills" rev-parse HEAD)"

# Remove what a previous sync vendored, keeping anything else in DEST.
if [[ -f "$DEST/UPSTREAM" ]]; then
	sed -n 's/^skill: //p' "$DEST/UPSTREAM" | while read -r name; do
		rm -rf "${DEST:?}/$name"
	done
fi
mkdir -p "$DEST"

names=()
for path in $(python3 -c 'import json,sys; print("\n".join(json.load(open(sys.argv[1]))["skills"]))' \
		"$TMP/skills/.claude-plugin/plugin.json"); do
	name="$(basename "$path")"
	cp -R "$TMP/skills/$path" "$DEST/$name"
	rm -rf "$DEST/$name/agents"
	names+=("$name")
done
cp "$TMP/skills/LICENSE" "$DEST/LICENSE-mattpocock-skills"

{
	echo "# Vendored by tools/sync_skills.sh; re-run it to update."
	echo "repo: $REPO"
	echo "commit: $COMMIT"
	for name in "${names[@]}"; do echo "skill: $name"; done
} >"$DEST/UPSTREAM"
echo "Vendored ${#names[@]} skills from $REPO at $COMMIT into $DEST"
