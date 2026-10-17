# Feature 043: Handoff

- **Done:** see `status.md`.
- **Rebuild the model:** `tools/build_art.sh characters/mum`. It takes about 2 minutes on CPU. `QUICK=1` previews in about 1 minute.
- **Re-cut the portraits:** `python3 art/ui/story_art.py`. The crop boxes are in `FACES`.
- **Next:**
  - 038 (the Moon-Eater) puts its fight between the last night and `MumArrival`;
  - 041's journal pages can use Mum's expressions;
  - voice lines for Mum's two lines (`intro.c1.3.1`, `win.c2.2.2`).
- **Iterate on the face or hair:** `HEAD_ONLY=1 ART_PREVIEW_DIR=/tmp/x .venv-blender/bin/python art/characters/mum.py` (about 20 s).
- **Open:** her eyes are still a little big for a grown-up next to the kids. That's a matter of taste: `FACE.eye_w`, `eye_h` and `iris_r`.
