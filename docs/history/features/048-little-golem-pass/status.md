# Feature 048: Status

**Done.**

- **Model:** `art/characters/little_golem.py`, rebuilt after the sheet. About 8k tris (Body 3000, Head 3200, arms 800 each).
  - Head: a rounded face of four upright planks with carved sockets, tall amber eyes, a painted nose and smile, a shingle bob, plank-slice ears, stick pegs and a leafy sprout.
  - Body: a shield-shaped plank trunk around a big window with a wooden rim and a crescent, stone hips and stacked stone legs.
  - Arms: a stone shoulder, a roped plank upper arm, a stone forearm and a round stone hand, hanging to the hips.
- **Measuring:** `MEASURE=1` prints the model's landmarks against the sheet's. All are within about 0.016, except the head depth (see decisions).
- **Godot:** `LittleGolem` glows the new `Body_Moon` brighter than the window. `curl_up` folds the arms forward and in.
- **Moon-Eater:** `carve_eyes` takes the eyes, the front plane and the depths as arguments. Its defaults are unchanged, so the Moon-Eater is not rebuilt.
- **Checks:** `tools/check.sh` passes (validate and smoke, including both golem checks).
