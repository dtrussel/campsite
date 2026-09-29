# Feature 029: Status

**Done.**

## 2026-09-29

- Generated the assets with `art/ui/key_art.py`. The logo was moved off
  Leo's cap into the open sky after the first look.
- Added the boot splash settings and the `LoadingScreen`.
  `GameManager.start_run()` and `continue_run()` now load through it.
- **Validator:** checks that the boot splash file exists and that the
  loading screen builds (`LoadingScreen.preview()`).
- **Screenshots:** a new `01b_loading` shot.
- **End-to-end run under Xvfb** (title → 3 Nights):
  - the overlay appears straight away and `Main` is in after about
    0.3 s under cover;
  - the overlay is gone about 2 s after the click;
  - there are no errors.
- **`tools/check.sh` passes.** The export self-test passes, and the
  Windows zip is built.
- Fixed the title-screen imps (the old "Taunt" clip is replaced with
  `Imp_Idle`).

## 2026-09-29 (feature 030)

- Added three more loading pictures (WebP, 270–360 KB each), each with
  matching tips.
- **Validator:** every picture and tip icon exists, and each picture
  builds.
- **Screenshots:** `01b_loading_0` to `01b_loading_3`. The text reads
  on all four.
- **End-to-end:** two Plays in a row showed different pictures (imp,
  then beast), and the overlay cleared both times. `tools/check.sh`
  passes.
