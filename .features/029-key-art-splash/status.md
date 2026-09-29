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
