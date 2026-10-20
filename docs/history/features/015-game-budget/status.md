# Feature 015: Status

**Done.**

## Triangles

| | Before | After |
|---|---|---|
| Leo | 114.4k | 35.0k |
| Nela | 119.3k | 35.7k |

## Bake and textures
- Final bake at 1024 with the high-to-low transfer.
- Godot reimported the kids.
- Portraits re-rendered.
- The kids' texture imports now use lossy compression (quality 0.9) instead of lossless.
  - A lossless re-encode of the WebP paint made the pack bigger than the old PNGs did.
  - Imported kid textures went from 11.7 MB to 2.6 MB.

## Verification
- **Clay and silhouette review:** low against dense, front, 3/4, side and back, and a 120 px silhouette. No visible change.
- **Painted heads:** the 4.5k and 19k heads match.
- **`tools/check.sh`:** passes (import, validate, smoke).
- **Screenshots:** day HUD reviewed. The HP bars and the Sibling label sit above the heads, so no height change was needed.
- **Data pack:**
  - Measured with `--export-pack "Windows Desktop"`, zip -9: 26.5 MB (25.3 MiB), under the 30 MiB guideline.
  - Before this feature it was 31.2 MB.
  - The full `tools/export_playtest.sh` needs the Godot export templates, which aren't installed in this environment.
