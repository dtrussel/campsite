"""Bramble Beast clips (feature 026), keyed by hand on the Skeleton_Minion
rig's deform bones with the helpers (and sign cheat-sheet) in
rig_anims.py.

The game plays attacks and spawns at 1.6x speed (mob_controller.gd), so
the slam lands at frame 21 = 0.875 s = 0.55 s in game (MobDefinition
attack_hit_delay)."""

from characters.rig_anims import P, arms, build_actions as _build, legs, torso

# (action, frames) rendered as previews by bramble_beast.py.
PREVIEW_FRAMES = {
    "Beast_Walk": (0, 6, 12),
    "Beast_Slam": (0, 16, 21, 26),
    "Beast_Spawn": (0, 20, 40, 58),
    "Beast_Death": (4, 12, 24),
    "Beast_Roar": (8, 26),
    "Beast_Hit": (3,),
}

STANCE = torso() + arms() + legs()


# ------------------------------------------------------------- clips


def idle():
    """Slow, heavy breathing; the fists sway and the head looks around."""
    inhale = torso(spine=5.0, chest=0.0, head=-12.0, hips_z=0.01) + arms(down=55.0, swing_l=3, swing_r=-2, elbow_l=14, elbow_r=16) + legs()
    look = P(head=[("Z", 10.0)])
    return [(0, STANCE), (18, inhale + look), (36, STANCE + P(head=[("Z", -6.0)])), (48, STANCE)]


def walk():
    """A lumbering stomp: 24 frames, two heavy steps. The body rolls over
    the planted foot and the arms swing against the legs."""
    contact_l = (torso(spine=12.0, chest=2.0, head=-14.0, roll=-5.0, twist=-6.0, hips_z=-0.05, hips_x=0.03)
                 + arms(down=56.0, swing_l=-22.0, swing_r=26.0, elbow_l=12.0, elbow_r=30.0)
                 + legs(swing_l=30.0, swing_r=-22.0, knee_l=6.0, knee_r=18.0, foot_l=22.0, foot_r=-8.0))
    passing_l = (torso(spine=10.0, chest=2.0, head=-12.0, roll=4.0, twist=0.0, hips_z=0.035, hips_x=-0.04)
                 + arms(down=58.0, swing_l=0.0, swing_r=4.0, elbow_l=18.0, elbow_r=20.0)
                 + legs(swing_l=-4.0, swing_r=22.0, knee_l=2.0, knee_r=48.0, foot_l=0.0, foot_r=-6.0))
    contact_r = contact_l.mirrored()
    passing_r = passing_l.mirrored()
    # The hips x offset mirrors with the pose (mirrored() flips x).
    return [(0, contact_l), (6, passing_l), (12, contact_r), (18, passing_r), (24, contact_l)]


def slam():
    """Two-fist overhead hammer: long windup, impact at frame 21."""
    gather = (torso(spine=4.0, chest=-4.0, head=-14.0, hips_z=-0.03)
              + arms(down=40.0, swing_l=30.0, swing_r=30.0, elbow_l=50.0, elbow_r=50.0)
              + legs(swing_l=8.0, swing_r=-6.0, knee_l=14.0, knee_r=14.0, wide=8.0, foot_l=6.0, foot_r=-6.0))
    windup = (torso(spine=-14.0, chest=-12.0, head=-4.0, hips_z=-0.05, hips_y=0.04)
              + arms(down=-15.0, swing_l=60.0, swing_r=60.0, elbow_l=70.0, elbow_r=70.0)
              + legs(swing_l=10.0, swing_r=-8.0, knee_l=20.0, knee_r=20.0, wide=9.0, foot_l=10.0, foot_r=-8.0))
    impact = (torso(spine=34.0, chest=16.0, head=-30.0, hips_z=-0.14, hips_y=-0.05)
              + arms(down=66.0, swing_l=52.0, swing_r=52.0, elbow_l=4.0, elbow_r=4.0)
              + legs(swing_l=26.0, swing_r=-14.0, knee_l=38.0, knee_r=34.0, wide=10.0, foot_l=12.0, foot_r=-14.0))
    settle = (torso(spine=30.0, chest=13.0, head=-28.0, hips_z=-0.12, hips_y=-0.04)
              + arms(down=66.0, swing_l=46.0, swing_r=46.0, elbow_l=10.0, elbow_r=10.0)
              + legs(swing_l=24.0, swing_r=-12.0, knee_l=34.0, knee_r=30.0, wide=10.0, foot_l=10.0, foot_r=-12.0))
    return [(0, STANCE), (8, gather), (18, windup), (21, impact), (26, settle), (40, STANCE)]


def hit():
    """A small, heavy flinch."""
    flinch = (torso(spine=-6.0, chest=-6.0, head=-2.0, hips_z=-0.02, hips_y=0.03)
              + arms(down=58.0, swing_l=-8.0, swing_r=-8.0, elbow_l=26.0, elbow_r=26.0, out_l=6, out_r=6)
              + legs(knee_l=8.0, knee_r=8.0))
    return [(0, STANCE), (3, flinch), (14, STANCE)]


def spawn():
    """It pulls itself out of the ground, shakes, and gives a roar."""
    buried = (torso(spine=26.0, chest=10.0, head=-30.0) + arms(down=10.0, swing_l=50.0, swing_r=50.0, elbow_l=30.0, elbow_r=30.0)
              + legs(knee_l=40.0, knee_r=40.0) + P(loc={"root": (0, 0, -1.25)}))
    push = (torso(spine=34.0, chest=12.0, head=-30.0) + arms(down=62.0, swing_l=40.0, swing_r=40.0, elbow_l=6.0, elbow_r=6.0)
            + legs(knee_l=30.0, knee_r=30.0) + P(loc={"root": (0, 0, -0.7)}))
    heave = (torso(spine=22.0, chest=8.0, head=-22.0, hips_z=-0.06) + arms(down=70.0, swing_l=20.0, swing_r=20.0, elbow_l=10.0, elbow_r=10.0)
             + legs(swing_l=20.0, knee_l=40.0, knee_r=20.0) + P(loc={"root": (0, 0, -0.18)}))
    shake_a = STANCE + torso(spine=0.0, chest=0.0, head=0.0, roll=7.0) + P(head=[("Z", 12.0)])
    shake_b = STANCE + torso(spine=0.0, chest=0.0, head=0.0, roll=-7.0) + P(head=[("Z", -12.0)])
    roar = (torso(spine=-12.0, chest=-12.0, head=-28.0, hips_z=-0.03)
            + arms(down=5.0, swing_l=10.0, swing_r=10.0, elbow_l=30.0, elbow_r=30.0)
            + legs(swing_l=8.0, swing_r=-8.0, knee_l=10.0, knee_r=10.0, wide=10.0))
    return [(0, buried), (14, buried + P(loc={"root": (0, 0, 0.15)})), (22, push), (36, heave), (42, STANCE),
            (46, shake_a), (50, shake_b), (54, STANCE), (58, roar), (68, roar + P(head=[("Z", 6.0)])), (76, STANCE)]


def death():
    """Staggers, drops to its knees and slumps forward onto its fists in
    one second (the corpse sinks away after 1.4 s). The last frame is
    held (play_final)."""
    stagger = (torso(spine=-10.0, chest=-8.0, head=-2.0, hips_y=0.05) + arms(down=55.0, swing_l=-10.0, swing_r=-5.0, elbow_l=30.0, elbow_r=20.0, out_l=8)
               + legs(swing_l=-6.0, swing_r=10.0, knee_l=10.0, knee_r=6.0))
    knees = (torso(spine=18.0, chest=10.0, head=-20.0, hips_z=-0.3, hips_y=-0.02)
             + arms(down=60.0, swing_l=20.0, swing_r=15.0, elbow_l=20.0, elbow_r=24.0)
             + legs(swing_l=60.0, swing_r=55.0, knee_l=125.0, knee_r=120.0, wide=10.0, foot_l=-40.0, foot_r=-40.0))
    slump = (torso(spine=55.0, chest=22.0, head=-6.0, hips_z=-0.36, hips_y=-0.06)
             + arms(down=45.0, swing_l=70.0, swing_r=62.0, elbow_l=20.0, elbow_r=28.0)
             + legs(swing_l=50.0, swing_r=46.0, knee_l=125.0, knee_r=122.0, wide=10.0, foot_l=-50.0, foot_r=-50.0))
    rest = (torso(spine=62.0, chest=24.0, head=8.0, roll=6.0, hips_z=-0.4, hips_y=-0.08)
            + arms(down=40.0, swing_l=72.0, swing_r=66.0, elbow_l=26.0, elbow_r=30.0)
            + legs(swing_l=48.0, swing_r=44.0, knee_l=126.0, knee_r=124.0, wide=10.0, foot_l=-50.0, foot_r=-50.0))
    return [(0, STANCE), (4, stagger), (12, knees), (18, slump), (24, rest)]


def roar():
    """Beats its chest twice and roars (after smashing a building)."""
    fists_in = (torso(spine=2.0, chest=-2.0, head=-10.0) + arms(down=66.0, swing_l=14.0, swing_r=14.0, elbow_l=100.0, elbow_r=100.0)
                + legs(wide=7.0))
    thump = (torso(spine=-4.0, chest=-8.0, head=-14.0) + arms(down=70.0, swing_l=8.0, swing_r=8.0, elbow_l=118.0, elbow_r=118.0)
             + legs(wide=7.0))
    apart = (torso(spine=0.0, chest=-4.0, head=-12.0) + arms(down=58.0, swing_l=18.0, swing_r=18.0, elbow_l=85.0, elbow_r=85.0, out_l=10, out_r=10)
             + legs(wide=7.0))
    bellow = (torso(spine=-14.0, chest=-14.0, head=-30.0, hips_z=-0.03) + arms(down=20.0, swing_l=5.0, swing_r=5.0, elbow_l=40.0, elbow_r=40.0)
              + legs(wide=10.0, knee_l=8, knee_r=8))
    return [(0, STANCE), (6, fists_in), (9, thump), (13, apart), (16, thump), (20, apart), (26, bellow),
            (32, bellow + P(head=[("Z", 5.0)])), (40, STANCE)]


CLIPS = {
    "Beast_Idle": (idle, True),
    "Beast_Walk": (walk, True),
    "Beast_Slam": (slam, False),
    "Beast_Hit": (hit, False),
    "Beast_Spawn": (spawn, False),
    "Beast_Death": (death, False),
    "Beast_Roar": (roar, False),
}


def build_actions(rig):
    """Removes the rig's stock clips and keys the beast's own."""
    _build(rig, CLIPS, "Beast_Idle")
