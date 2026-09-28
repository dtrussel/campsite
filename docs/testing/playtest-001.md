# Playtest 001: first human playtest

> Build: `Campsite-0.3.0-playtest1-windows.zip` (produced by
> `tools/export_playtest.sh`). Target session length: **20–30 minutes**
> (about 10 minutes per run, 2 runs).

## Goals of this playtest

We want to learn, in order of priority:

1. **Can a first-time player understand what to do** without help from
   us? (Goal, day/night rhythm, gathering, building, crafting.)
2. **Is the core loop fun?** Gather → build/craft → defend → level up.
3. **Is the difficulty in the right place?** Target: a first run is a
   close call, and roughly 1 in 3 first runs is lost.
4. **What breaks?** Bugs, soft-locks, confusing UI, performance.

## Facilitator notes

- **Don't coach.** Hand over the zip and `PLAYTEST-README.txt`, then
  watch. Answer questions only when the tester is fully stuck for
  more than a minute, and write down that you did.
- If possible, watch over their shoulder or screen-share, and note
  where they hesitate.
- Ask the tester to **think aloud**.
- Collect `playtest_log.txt` afterwards. The path is shown on the end
  screen.

## Tester setup

1. Unzip, double-click `Campsite.exe`. If you see "Windows protected
   your PC", click **More info → Run anyway**.
2. Read the help screen, then play.

## Guided script

Run 1 is **free play**: no instructions beyond the README.

Run 2 is **guided**. Try each of these at least once and tick what
worked:

- [ ] Right-click the ground to walk; right-click a tree (Wood + Leaves),
      an orange pine (Resin + Wood), a berry bush (Berries + Fiber) and a
      rock (Stone) to walk over and gather.
- [ ] Mouse-wheel zoom in and out.
- [ ] Press **B**, place a Wooden Fence with left click, and rotate
      one with **R** before placing.
- [ ] Press **2** in build mode and place a Watch Post (4 Wood,
      2 Stone, 1 Fiber).
- [ ] Right-click the campfire (or press **C** next to it) and craft a Torch
      (1 Wood, 1 Resin, 1 Leaves).
- [ ] Plant the torch with **Q** somewhere imps will pass.
- [ ] Send the sibling to guard the camp with **G**.
- [ ] Press **N** to call the night early.
- [ ] Right-click an imp to attack it (the boy keeps swinging until it dies); also try **Space**.
- [ ] Eat berries with **R** when hurt.
- [ ] Pause with **Esc** and resume.
- [ ] Finish the run (win or lose) and use **Play again**.

## What to watch for (facilitator)

| Area | Question | Notes |
|------|----------|-------|
| Onboarding | Did they read the help screen? Did they reopen it (H)? | |
| Controls | Did right-click movement feel natural? Did they try WASD? | |
| Look & feel | First reaction to the art, effects and UI? Anything hard to read? | |
| Gathering | Did they find all four resource kinds without being told? | |
| Building | Did they understand why the ghost is red or green? | |
| Crafting | Did they discover crafting on their own? At the campfire? | |
| Night | Did the sunset warning register? Did they go back to the fire? | |
| Combat | Was it clear when they hit an imp, or got hit? | |
| Sibling | Did they use F/G/T/Y? Which task, and why? | |
| Difficulty | Which night was hardest? Did they lose? Why? | |
| Bugs | Anything stuck, glitchy, or crashing? | |

## Questionnaire (tester)

Rate 1 (bad) to 5 (great) and add a sentence where you can.

1. How clear was **what you were supposed to do**? (1–5)
2. How clear were the **controls**? Which one did you forget or
   misuse? (1–5)
3. How **fun** was the day part: gathering, building, crafting? (1–5)
4. How **fun** was the night part: defending the campfire? (1–5)
5. How **hard** was it? (1 = too easy, 3 = just right, 5 = too hard)
6. Did you **win**? How many runs did you play?
7. Did the **torch** feel useful? The **watch post**? The **fences**?
8. Did your **sibling** feel helpful? What did you want them to do?
9. Did you notice **leveling up**? Did it feel like it mattered?
10. What was the **most confusing** moment?
11. What was the **best** moment?
12. How did the game **look and feel** (art, effects, menus)? (1–5)
13. Did anything **break**: bugs, getting stuck, crashes? When?
14. If you could change **one thing**, what would it be?
15. Would you play a longer version? (yes / maybe / no)

Please return: the answers, `playtest_log.txt`, and (optionally)
screenshots or a video of anything odd.
