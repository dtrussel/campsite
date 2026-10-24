# 02: The run's systems ask the run config

Status: ready-for-agent
Blocked by: 01

**What to build:** the systems that rebuild the run's rules from loose fields ask the run config instead:
- **The mob spawner:** the Moon-Eater's night, the eyes nights (the spawner keeps its own setting for when the eyes start, built on "has a Moon-Eater"), and endless toughness from "nights past the story".
- **The Moon Lantern:** it starts full in an endless run and takes its costs from the config's chapter.
- **The win check:** a winning dawn ends the run, and calming the Moon-Eater changes only the message.
- **The chapter intro:** whether it plays.

Until ticket 03, the run config the run session holds is still filled from the game manager's fields, so play is unchanged.

- [ ] None of these systems infer the chapter from the run length or combine the chapter and endless flags themselves.
- [ ] Smoke: the boss, endless, story and chapter 1 scenarios pass unchanged.
- [ ] `tools/check.sh` passes.

## Comments
