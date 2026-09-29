"""Shadow Imp clips (feature 028), keyed by hand on the Skeleton_Minion
rig with the helpers (and sign cheat-sheet) in rig_anims.py.

Everything starts from the concept's crouch: bow legs deeply bent, body
leaning forward, head up (so the big eyes face the camera), arms
forward with the claws out. The game plays attacks and spawns at 1.6x
(mob_controller.gd) and deals the imp's damage at once, so the swipe
connects early (frame 6, ~0.16 s in game)."""

from characters.rig_anims import P, arms, build_actions as _build, legs, torso

# (action, frames) rendered as previews by shadow_imp.py.
PREVIEW_FRAMES = {
    "Imp_Run": (0, 4, 8),
    "Imp_Attack": (3, 6),
    "Imp_Spawn": (0, 14, 22),
    "Imp_Death": (10, 20),
    "Imp_Hit": (3,),
}


def claws_out(amount=20.0):
    """Wrists cocked up so the claws point forward."""
    return P(wrist_l=[("Z", -amount)], wrist_r=[("Z", amount)])


def crouch(spine=20.0, head=-30.0, roll=0.0, twist=0.0, hips_z=-0.1, hips_y=0.0):
    return torso(spine=spine, chest=4.0, head=head, roll=roll, twist=twist, hips_z=hips_z, hips_y=hips_y)


STANCE = (crouch() + arms(down=55.0, swing_l=30.0, swing_r=30.0, elbow_l=50.0, elbow_r=50.0) + claws_out()
          + legs(swing_l=45.0, swing_r=45.0, knee_l=80.0, knee_r=80.0, wide=10.0, foot_l=35.0, foot_r=35.0))


def idle():
    """A bouncy crouch with a cheeky head tilt and flexing claws."""
    dip = P(loc={"hips": (0, 0, -0.04)}) + legs(swing_l=6.0, swing_r=6.0, knee_l=12.0, knee_r=12.0, wide=0.0)
    tilt_l = P(head=[("Y", 12.0), ("Z", 8.0)])
    tilt_r = P(head=[("Y", -12.0), ("Z", -8.0)])
    flex = claws_out(20.0)
    return [(0, STANCE), (9, STANCE + dip + tilt_l + flex), (18, STANCE + tilt_l),
            (27, STANCE + dip + tilt_r + flex), (36, STANCE)]


def run():
    """A springy hop-run: 16 frames, two bounding steps."""
    contact = (crouch(spine=26.0, head=-36.0, roll=-4.0, twist=-6.0, hips_z=-0.13)
               + arms(down=55.0, swing_l=5.0, swing_r=60.0, elbow_l=40.0, elbow_r=60.0) + claws_out()
               + legs(swing_l=62.0, swing_r=5.0, knee_l=60.0, knee_r=95.0, wide=9.0, foot_l=20.0, foot_r=-5.0))
    air = (crouch(spine=24.0, head=-34.0, roll=2.0, hips_z=0.02)
           + arms(down=50.0, swing_l=30.0, swing_r=35.0, elbow_l=55.0, elbow_r=55.0) + claws_out()
           + legs(swing_l=40.0, swing_r=45.0, knee_l=100.0, knee_r=105.0, wide=9.0, foot_l=40.0, foot_r=40.0))
    return [(0, contact), (4, air), (8, contact.mirrored()), (12, air.mirrored()), (16, contact)]


def attack():
    """A quick claw swipe with the right hand, connecting at frame 6."""
    windup = (crouch(spine=12.0, head=-28.0, twist=22.0, hips_z=-0.09)
              + P(upperarm_r=[("Y", -15.0), ("X", 25.0)], lowerarm_r=[("Z", 95.0)])
              + P(upperarm_l=[("Y", 55.0), ("X", -35.0)], lowerarm_l=[("Z", -50.0)]) + claws_out(30.0)
              + legs(swing_l=50.0, swing_r=35.0, knee_l=85.0, knee_r=75.0, wide=11.0, foot_l=35.0, foot_r=30.0))
    slash = (crouch(spine=32.0, head=-36.0, twist=-26.0, hips_z=-0.12)
             + P(upperarm_r=[("Y", -48.0), ("X", -85.0)], lowerarm_r=[("Z", 8.0)])
             + P(upperarm_l=[("Y", 62.0), ("X", -10.0)], lowerarm_l=[("Z", -60.0)]) + claws_out(10.0)
             + legs(swing_l=60.0, swing_r=30.0, knee_l=80.0, knee_r=85.0, wide=11.0, foot_l=30.0, foot_r=35.0))
    follow = (crouch(spine=28.0, head=-34.0, twist=-30.0, hips_z=-0.11)
              + P(upperarm_r=[("Y", -62.0), ("X", -60.0)], lowerarm_r=[("Z", 30.0)])
              + P(upperarm_l=[("Y", 60.0), ("X", -20.0)], lowerarm_l=[("Z", -55.0)]) + claws_out()
              + legs(swing_l=58.0, swing_r=32.0, knee_l=80.0, knee_r=82.0, wide=11.0, foot_l=30.0, foot_r=32.0))
    return [(0, STANCE), (3, windup), (6, slash), (10, follow), (18, STANCE)]


def hit():
    """A flinch back with the arms up."""
    flinch = (crouch(spine=0.0, head=-12.0, hips_z=-0.08, hips_y=0.04) + P(chest=[("X", -12.0)])
              + arms(down=20.0, swing_l=40.0, swing_r=40.0, elbow_l=80.0, elbow_r=80.0) + claws_out(40.0)
              + legs(swing_l=40.0, swing_r=40.0, knee_l=75.0, knee_r=75.0, wide=10.0, foot_l=32.0, foot_r=32.0))
    return [(0, STANCE), (3, flinch), (10, STANCE)]


def spawn():
    """Rises out of the ground, stretches up, and lands in a cheeky
    crouch-bounce (44 frames = 1.8 s at the game's 1.6x)."""
    buried = (crouch(spine=6.0, head=-20.0, hips_z=0.0) + arms(down=-50.0, elbow_l=20.0, elbow_r=20.0)
              + legs(knee_l=30.0, knee_r=30.0, swing_l=15.0, swing_r=15.0) + P(loc={"root": (0, 0, -1.0)}))
    rising = buried + P(loc={"root": (0, 0, 0.5)})
    stretch = (crouch(spine=-12.0, head=-30.0, hips_z=0.02) + arms(down=-60.0, elbow_l=10.0, elbow_r=10.0)
               + legs(swing_l=5.0, swing_r=5.0, knee_l=10.0, knee_r=10.0) + P(loc={"root": (0, 0, 0.06)}))
    land = STANCE + P(loc={"hips": (0, 0, -0.06)})
    bounce = STANCE + P(loc={"hips": (0, 0, 0.03)}) + P(head=[("Y", 14.0)])
    return [(0, buried), (14, rising), (22, stretch), (28, land), (32, bounce), (37, STANCE + P(head=[("Y", -10.0)])),
            (44, STANCE)]


def death():
    """Tumbles backwards and plops onto its back (20 frames, before the
    corpse squash). The last frame is held (play_final)."""
    recoil = STANCE + P(chest=[("X", -16.0)], head=[("X", 12.0)])
    tumble = (torso(spine=-8.0, chest=-6.0, head=-4.0) + arms(down=10.0, swing_l=30.0, swing_r=30.0, elbow_l=30.0, elbow_r=30.0)
              + legs(swing_l=40.0, swing_r=25.0, knee_l=50.0, knee_r=40.0, wide=12.0)
              + P(root=[("X", -45.0)], loc={"root": (0, 0.1, 0.06)}))
    flat = (torso(spine=-4.0, chest=0.0, head=12.0) + arms(down=15.0, swing_l=45.0, swing_r=35.0, elbow_l=40.0, elbow_r=30.0)
            + legs(swing_l=55.0, swing_r=40.0, knee_l=80.0, knee_r=60.0, wide=14.0)
            + P(root=[("X", -86.0)], loc={"root": (0, 0.2, 0.14)}))
    return [(0, STANCE), (3, recoil), (10, tumble), (16, flat + P(loc={"root": (0, 0, 0.05)})), (20, flat)]


CLIPS = {
    "Imp_Idle": (idle, True),
    "Imp_Run": (run, True),
    "Imp_Attack": (attack, False),
    "Imp_Hit": (hit, False),
    "Imp_Spawn": (spawn, False),
    "Imp_Death": (death, False),
}


def build_actions(rig):
    """Removes the rig's stock clips and keys the imp's own."""
    _build(rig, CLIPS, "Imp_Idle")
