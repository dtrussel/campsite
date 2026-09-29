# Feature 026: Decisions

- **Stay on the Skeleton Minion rig, with our own clips.** The rig's
  bones drive the skin weights. The forearms are 0.14 m longer and the
  legs stand 0.07 m wider, so the fists hang near the knees and the
  legs read as two trunks. The rig's 95 stock clips are dropped from
  the GLB and replaced by 7 hand-keyed ones (`beast_anims.py`).
- **Poses in rest axes.** Each bone takes a list of (axis, degrees)
  rotations in the rig's rest axes, applied in order, plus a mirror
  helper for walk cycles. This keeps the clips readable and easy to
  tune without a GUI.
- **The face is sculpted, not painted on.** The brow ridge, sockets,
  cheeks and grin are vertex offsets on the dense mesh. The glowing
  eyes sit in the sockets by raycast (they floated in front of the old
  face).
- **Telegraphed slam (chosen by the team).**
  - `MobDefinition.attack_hit_delay` is 0.55 s for the beast and 0 for
    everyone else. Damage lands at the clip's impact.
  - A kid more than `attack_range` + 0.4 m away at impact is not hit.
    Buildings and the campfire are always hit.
  - Damage and cooldown are unchanged.
- **Impact feedback.** A `bramble_slam` burst and sound, plus a small
  camera shake.
- **Roar.** The beast plays a chest-thump roar when its slam flattens a
  building.
- **Death fits the corpse timer.** The collapse takes 1 s, because the
  corpse sinks away after 1.4 s.
