# 05: Hero core wrap-up

Status: done
Blocked by: 02, 03, 04

**What to build:** the hero refactor is finished and written down. No smoke scenario reads a private hero field, an enum value or a task number. Each role script holds only its role's behaviour. The architecture doc describes the Hero module, the two roles and Party, and the glossary matches. The spec is set to done.

- [x] No smoke scenario reads a private hero field, enum value or task number.
- [x] `docs/architecture/software-architecture.md` describes the Hero module, the roles and Party.
- [x] The spec and every ticket are set to done, with notes under Comments.
- [x] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments

- **2026-10-21, implement:** done. The smoke run (and the screenshot and balance sims) no longer read hero privates, command numbers or task numbers. New small public accessors on the player's hero: `has_command()`, `is_building()`, `build_hits()`, and `try_place_torch()` / `try_eat_berries()` (were `_try_*`); on Hero, `health_bar()`, with the bar's attach moved into Hero (`_attach_health_bar`). Companion tasks are set by `Companion.Task` name. `_is_companion_role()` is no longer a role override: Hero asks `Party.role_of(self) == Party.COMPANION` (the companion joins its group before it reads its attack tuning; the player's hero reads its tuning in `_enter_tree`, where any other answer is right). `docs/architecture/software-architecture.md` now describes the Hero module, the two roles and Party, the hero signals, and the command / task states. `GLOSSARY.md` already matched, so it is unchanged. The spec is set to done.
