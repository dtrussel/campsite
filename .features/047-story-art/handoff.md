# Feature 047: Handoff

- **A new or replaced painting:** drop the source in `art/ui/source/story/<page>.webp` (16:9, faces in the top two thirds) and run `.venv-blender/bin/python art/ui/story_art.py`. Raise its `lift` in `PAINTINGS` if the text band hides something.
- **Better kids' faces:** nine of the twelve are cut from the paintings. A painted head replaces one: add `art/ui/source/<hero>_<face>.webp` (1024²), point its `KID_FACES` entry at it (source, centre, side) and run the script.
- **Mum's notebook:**
  - painted sketches can replace the derived ones: `game/assets/ui/story/note_<n>.png`, 512² with alpha, or change `SKETCHES` in `art/ui/notebook_art.py`;
  - 041's journal can use `notebook_page.webp` and the same sketches.
- **Mum's lantern prop:** the sheet is `art/reference/concept-2026-10/17_mum_lantern_sheet.webp`. A later prop could hang by the tent in Chapter 2 and light up in the ending.
- **Tuning:**
  - `MoonLantern.HOUSING_Y`, `CRESCENT_POS` and `_set_glow` (when the crescent wakes);
  - `LittleGolem.curl_up` and its breathing;
  - its size is the model's (rebuild `art/characters/little_golem.py`).
