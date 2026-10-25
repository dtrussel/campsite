# 13: Face atlas: blink and expressions

Status: ready-for-agent
Blocked by: 10 (it only orders the rebuilds of the kids' and Mum's models)

**What to build:** the kids blink, and their eyes and mouth show a wince when hit, a beam when cheering and a dazed look while down. Each kid's eyes and mouth become a small painted atlas of states (open, closed, happy, hurt, dazed), painted with the existing face painter so they match today's look. The face shader picks the cell at runtime. Blinks come at random intervals, with an occasional double blink. `hit`, `cheer` and down set the expression for their duration, then it returns to neutral. Mum gets the blink if her head takes it at no extra cost.

- [ ] Leo and Nela each have a face atlas, and their faces still match the turnaround sheets in the neutral state.
- [ ] Unit: the blink scheduler's intervals stay within a set range and sometimes double.
- [ ] Smoke: a hero hit shows the hurt cell and returns to neutral after it. A downed hero shows dazed.
- [ ] The kids stay within the hero triangle and texture budgets.
- [ ] Close-up renders of each cell and in-game captures are under `## Comments` for sign-off.
- [ ] `art/README.md` describes the face atlas.
- [ ] `docs/design/art-direction.md` gains a short "Hero motion" section on each kid's personality in motion, the springs and the faces.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
