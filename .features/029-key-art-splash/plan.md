# Feature 029: Key-art splash and loading screen

The team's painted key art (Leo and Nela at sunset, with the camp, the
Bramble Beast, the Shadow Imp and the Mushroom Gremlin) is shown while
the game starts and while the camp loads. The source is at
`art/ui/source/key_art.png`.

## Scope (the team chose "Splash + loading")

- **Boot splash:** `project.godot`, `application/boot_splash/*`. It
  shows `assets/ui/boot_splash.png` (the key art with the gold
  CAMPSITE logo baked into the sky) full-screen while the engine
  starts.
- **Loading screen:** `scripts/ui/loading_screen.gd`. Play, Continue
  and Again show the key art with "Loading the camp...", a gold
  progress bar and one kid-friendly tip. The camp loads on a background
  thread, instead of the old synchronous scene change that froze.
- The title screen keeps its live 3D camp and menu.
- **Assets:** `art/ui/key_art.py` (Pillow) writes
  `assets/ui/key_art.webp` (1600×900) and `assets/ui/boot_splash.png`
  (1280×720 plus the logo).
