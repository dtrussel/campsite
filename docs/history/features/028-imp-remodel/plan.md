# Feature 028: Shadow Imp remodel and animations

Reference: [`reference/concept.png`](reference/concept.png) (front 3/4,
side and back views supplied by the team).

## Goal

Make the main night mob read clearly as an imp while staying cheeky and
child-friendly:
- oversized eyes and a cheeky grin;
- pointed bat ears, curved horns and a spiky crest;
- small bat wings and a curling tail;
- bent legs.

Give it its own animations. It was the last mob on the KayKit Skeleton
clips.

## Scope

- **Model** (`art/characters/shadow_imp.py`), in the team's order:
  1. **Silhouette:** big round head, bat ears, horns, crest, wings, a
     long S-curling tail with an arrow tip, and thick thighs with long
     feet.
  2. **Face:** oversized cream-yellow glowing eyes with slit pupils,
     magenta brow markings, a snout with nostrils, and a grin with two
     fangs and a tongue hint.
  3. **Paint:** deep purple with a lavender belly, magenta stripes on
     the limbs and tail, dark chevrons down the back, and cream claws.

  The file keeps the shared rig helpers used by the other creatures.
- **Clips** (`art/characters/imp_anims.py`, using `rig_anims.py`):
  idle, run, attack, hit, spawn and death.
- **Godot:** new clip names in `ShadowImp.tscn` plus footstep dust, a
  re-rendered portrait, a smoke check and an `imp` filmstrip mode. No
  gameplay changes.
