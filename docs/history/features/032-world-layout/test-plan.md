# Feature 032: Test plan

- [x] `tools/check.sh`: validate OK, smoke PASSED. The smoke test spots (buildings at (12,12), (-14,-4), (14,-4); a beast at (-8,16.5)) do not overlap the new colliders.
- [x] `map_overview.tscn` prints every ResourceNode's zone and its path and lane clearance. All 19 nodes are in their intended zone, none is in a lane, and all are at least 0.9 m from path centre lines.
- [x] Game-camera views over the camp and each grove: nothing tall hides the kids, and no large black shadow lies over the lanes.
- [x] Day, sunset and night screenshots (`screenshots.tscn`) compared with the previous build.
- [ ] Playtest: are the walking distances to wood, stone and berries still comfortable in the first day?
- [ ] Playtest: do mobs on the north-east and east approaches route cleanly past the pond? They should, because the pond is out of the lanes.
