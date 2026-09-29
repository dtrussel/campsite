# Feature 029: Handoff

- **New art:** replace `art/ui/source/key_art.png` and run
  `.venv-blender/bin/python art/ui/key_art.py`. Any Python with Pillow
  works.
- **Logo position and size:** `draw_logo()` in `art/ui/key_art.py`.
- **Tips, timings and look:** `game/scripts/ui/loading_screen.gd`
  (`TIPS`, `MIN_SECONDS`, `FADE_IN`, `FADE_OUT`).
- **Use elsewhere:**

  ```
  LoadingScreen.load_scene(path)
  ```

  works for any scene.
