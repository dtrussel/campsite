# Feature 029: Decisions

- **Splash + loading, not the title.** The title keeps its live 3D camp
  (the team's choice). The art frames the start and the load instead.
- **Logo baked into the boot splash.** The engine's boot splash is a
  plain image, so the gold Cinzel CAMPSITE is drawn in with Pillow.
  It sits in the open sky on the right, clear of Leo's cap, with a
  soft dark glow so it reads over the bright clouds.
- **Threaded loading.** `ResourceLoader.load_threaded_request`, then
  `change_scene_to_packed`.
  - If the threaded load fails, it falls back to
    `change_scene_to_file`, so the game still starts.
  - The overlay lives on the root, so it survives the scene change. It
    stays at least 1.2 s so it never just flashes, and fades out two
    frames after the camp is in, once the dressing is built.
  - It swallows clicks.
- **Tips.** Short, simple sentences with an icon where one exists
  (torch, crate, Nela, berries, mushrooms, lantern). One is picked at
  random each time.
- **Formats.** The loading art is a 1600×900 WebP (about 400 KB). The
  boot splash is a PNG (the engine loads it at start-up, before any
  import).
- **Fixed along the way:** the title screen's imps still asked for the
  old KayKit "Taunt" clip, which feature 028 removed, so they stood in
  a T-pose. They now play `Imp_Idle`.

## Follow-up (feature 030): more loading pictures

- The team supplied three more paintings, one per monster: the imp on
  a branch at night, the beast peeking round a tree at sunset, and the
  gremlin by a stream with glowing mushrooms. They join the first
  picture as loading screens; the boot splash stays Leo and Nela.
- **Each picture has its own tips** (`LoadingScreen.SCREENS`): the imp
  gets torch, lantern and fence tips; the beast gets the slam and
  walls; the gremlin gets the storage crate and catching it. The first
  picture keeps the general tips about Nela, berries and the campfire.
- **A random pick that never repeats the last picture**, so Play then
  Again always look different. Only the chosen picture is loaded.
