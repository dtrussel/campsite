# Feature 028: Decisions

- **Order of work, as the team asked:** silhouette first (head, ears,
  horns, wings, tail), then the face sculpt, then the painted colour.
- **The eyes carry the face.** The eyes are big (0.16 radius each,
  wrapped to the head by raycast) with vertical slit pupils glancing
  toward the viewer. The glow is toned down to 1.5 so the eyes stay
  cream-yellow instead of blowing out to white.
  - The first try had deep sockets. They overlapped between the eyes
    and baked a dark, noisy patch, so they are now shallow.
  - The pupils sat inside the larger glow mesh, so they were pushed
    forward.
- **Stripes replace runes.** The feature 022 glowing runes are replaced
  by the concept's magenta stripes, lavender belly and back chevrons.
- **The tail is rigid on the hips.** Its S-curve is modelled, and its
  sway comes from the hip and spine motion in the clips. That keeps
  the rig unchanged.
- **Timings fit the gameplay.**
  - The imp's damage lands at once, so the swipe connects at frame 6
    (about 0.16 s at 1.6×).
  - The spawn is 1.8 s at 1.6×, under the 2 s cap.
  - The death (20 frames, about 0.83 s) lands before the corpse squash.
- **No gameplay changes.** The speed, damage and targeting are
  untouched.
