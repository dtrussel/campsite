# Feature 047: Handoff

- **A new or replaced painting:** drop the source in `art/ui/source/story/<page>.webp` (16:9, faces in the top two thirds) and run `.venv-blender/bin/python art/ui/story_art.py`. Raise its `lift` in `PAINTINGS` if the text band hides something.
- **More kids' faces:**
  - add `art/ui/source/<hero>_<face>.webp` (a 1024² head) and an entry in `KID_FACES` (centre and side, measured on the source), then run the script;
  - set `"face"` on that kid's lines.

  Still wanted: Leo's six faces, and Nela's smile, curious and proud.
- **Mum's notebook art** (the 046 notes) wasn't delivered. It goes with 041's journal.
- **Mum's lantern prop:** the sheet is `art/reference/concept-2026-10/17_mum_lantern_sheet.webp`. A later prop could hang by the tent in Chapter 2 and light up in the ending.
- **Tuning:**
  - `MoonLantern.HOUSING_Y`, `CRESCENT_POS` and `_set_glow` (when the crescent wakes);
  - `LittleGolem.curl_up` and its breathing;
  - its size is the model's (rebuild `art/characters/little_golem.py`).
