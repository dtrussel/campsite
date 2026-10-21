# 04: Contract and wrap-up

Status: ready-for-agent
Blocked by: 02, 03

**What to build:** the old lifecycle code is gone (contract). The save manager only handles the file: path, version, reading, writing, parse checks and delete; its snapshot is the run session gathering each saving system. The game manager's reset list is deleted. The architecture doc describes saving systems, the run session and the restore order. The spec is set to done.

- [ ] The save manager names no building, torch, hero or perk.
- [ ] The game manager has no reset list of its own.
- [ ] `docs/architecture/software-architecture.md` describes saving systems, the run session and the restore order.
- [ ] The spec and every ticket are set to done, with notes under Comments.
- [ ] `tools/check.sh` reports validate OK and smoke PASSED.

## Comments
