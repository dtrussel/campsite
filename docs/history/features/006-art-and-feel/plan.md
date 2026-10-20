# Feature 006 — Art & feel pass

## Goal

Make the playtest build look and feel like a finished stylized game,
in the style of League of Legends:
- readable, saturated 3D characters;
- dramatic lighting;
- juicy combat feedback;
- a hextech-style UI;
- right-click-to-move controls.

## Constraints

- The project has no artists, so we use CC0 KayKit packs (the only
  source reachable from the build environment) and add our own
  shaders, VFX and UI.
- The renderer stays on Compatibility (OpenGL 3) for tester hardware
  and for headless and Xvfb verification.

## Scope

- **In:**
  - models and animation for the characters, mobs, resources,
    buildings and camp;
  - painted ground, grass, forest border and lighting;
  - VFX, health bars and combat text;
  - LoL controls, hover and cursors;
  - HUD, menus, title backdrop and icons.
- **Out:** audio, new gameplay systems, controller support.
