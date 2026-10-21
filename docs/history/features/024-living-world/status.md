# Feature 024: Status

**Done.**

## 2026-09-29

- Built the foliage shader and tagging, the WorldAmbience node, and the
  footstep dust.
- **`tools/check.sh` passes.** The smoke test checks:
  - that running kicks up dust;
  - that tree resource nodes use the swaying material;
  - leaves by day and fireflies every night.
- **Screenshots:** fireflies at night, and leaves and pollen by day.
  Trees still render correctly with the new shader.
