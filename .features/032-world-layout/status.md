# Feature 032: Status

**Done.**

- **Layout data:** `WorldLayout` holds it, and the ground shader is driven from it.
- **Resources regrouped:** all 19 nodes are in their groves, with the same counts.
- **Groves and their landmarks:**
  - giant pine;
  - pond (blocks movement, a hole in the nav mesh);
  - woodlot props;
  - old stump with a fairy ring.
- **Plants:** ferns, reeds and lily pads (MultiMeshes).
- **Forest wall:** the species follow each grove, and there are gaps at the lanes.
- **Paths:** footpaths, the old road and the lane trails are painted on the ground. Lantern posts sit at the path heads, and the signpost is at the fork.
- **Removed:** the random toadstool and boulder scatter, and the yard flower bushes that stood in the lanes.
- **Checks:** `tools/check.sh` gives validate OK and smoke PASSED.
- **Screenshots** (day, sunset and night) were reviewed against the previous build.

**Walking distance:** the basic resources sit a little further out than before (average distance from the fire):

| Resource | Before | After |
|---|---|---|
| Wood | 8.3 m | 10.5 m |
| Stone | 7.3 m | 10.9 m |
| Berries | 6.4 m | 10.6 m |
| Resin | 9.5 m | 11 m |

Clay, mushrooms and junk are about the same distance as before.
