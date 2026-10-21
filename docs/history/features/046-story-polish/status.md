# Feature 046: Status

**Done.**

- **Canon** (`docs/design/story.md`): sections on the three lights, the creatures as lost things, the places, and a table of Mum's notes. The mystery layers now say where each one reaches the player.
- **Mum's notes:** a `note` speaker shows as "Mum's note", with her face and her words in moonlit quotes, read in her voice. There is one note per dawn: Chapter 1 night 2 and Chapter 2 nights 1–6, 7 in all, using 5 of her 6 faces.
- **Story text:**
  - Chapter 1 ending: the lantern glinted at the trees, cold, its light gone; "We'll keep her lantern safe."
  - Chapter 2 intro: "Mum's lantern hung by the tent, cold and dark."
  - True ending: 3 pages (the Moon-Eater falls apart and the moon floats free; the little golem, "It was just cold. And lonely."; Mum's lantern flickers on and Mum comes home, proud face).
  - Boot prints by the pond.
  - Dawn lines no longer claim the lantern's state.
  - Paintings re-picked per page.
- **Cards:** a story card that is still talking is never cut short. The first-shard card no longer wipes out the dawn card, and the other way round.
- **Barks** (62):
  - "Mum's lantern is waking up!" is now "The moonlight's coming back!";
  - the shared lines are split per hero, and the sunset no longer repeats the banner;
  - lore lines: "It's taking it to the Hollow!", "That old tree woke up angry!", "They just want our warm fire!";
  - new `thief_escaped` lines;
  - `first_beast` barks once per run.
- **World text:**
  - the items name where they come from (Stony Pond, the Fairy Ring, the Old Road), and shards are "bits of moonlight";
  - buildings have a touch of flavour;
  - the Bandage text follows the party;
  - the 4 creatures have a description that shows under their banner the first time each appears in a run (the imp gets a banner just for that, 2.5 s after it appears so "Night 1!" reads first);
  - 5 lore loading tips.
- **Places:** the SE grove is the Fairy Ring (it was "Berry Hollow", and its landmark was an oak in some notes and a stump in others).
- **Voice:** 48 new or changed lines generated (Kokoro stand-ins). All 129 story and bark lines are voiced.
- **Checks:** `tools/check.sh` passes (validate: 23 beats, 67 lines, 62 barks, 129 voiced; smoke PASSED, with the new checks).
