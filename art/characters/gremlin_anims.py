"""Mushroom Gremlin clips (feature 027), keyed by hand on the
Skeleton_Minion rig with the helpers (and sign cheat-sheet) in
rig_anims.py.

Everything starts from a sneaking crouch (the concept's pose): knees
bent, body leaning forward, head up, arms reaching forward with the
claws raised. The gremlin tiptoes to the stash (Gremlin_Sneak, the move
clip), snatches the loot (Gremlin_Grab) and scurries home clutching its
satchel (Gremlin_Flee, swapped in by mob_controller.gd while it flees)."""

from characters.rig_anims import P, arms, build_actions as _build, legs, torso

# (action, frames) rendered as previews by mushroom_gremlin.py.
PREVIEW_FRAMES = {
    "Gremlin_Sneak": (0, 5, 10),
    "Gremlin_Flee": (0, 3),
    "Gremlin_Grab": (4, 11),
    "Gremlin_Spawn": (0, 10, 16),
    "Gremlin_Death": (10, 24),
    "Gremlin_Hit": (3,),
}


def claws_up(amount=30.0):
    """Wrists bent up so the claws point forward."""
    return P(wrist_l=[("Z", -amount)], wrist_r=[("Z", amount)])


def crouch(spine=30.0, head=-52.0, roll=0.0, twist=0.0, hips_z=-0.12):
    return torso(spine=spine, chest=6.0, head=head, roll=roll, twist=twist, hips_z=hips_z)


# Hands droop from the wrists, claws down: tiptoe fingers.
DROOP = -35.0
SNEAK = (crouch() + arms(down=70.0, swing_l=22.0, swing_r=18.0, elbow_l=75.0, elbow_r=80.0) + claws_up(DROOP)
         + legs(swing_l=50.0, swing_r=36.0, knee_l=85.0, knee_r=80.0, wide=8.0, foot_l=35.0, foot_r=40.0))


def idle():
    """Crouched and shifty: glances left, then right, with a small bob."""
    look_l = P(head=[("Z", 24.0)]) + P(chest=[("Z", 6.0)])
    look_r = P(head=[("Z", -24.0)]) + P(chest=[("Z", -6.0)])
    bob = P(loc={"hips": (0, 0, 0.012)})
    return [(0, SNEAK), (8, SNEAK + look_l), (18, SNEAK + look_l + bob), (26, SNEAK),
            (32, SNEAK + look_r), (42, SNEAK + look_r + bob), (48, SNEAK)]


def sneak():
    """Tiptoe sneak: high knees, soft plants, arms bobbing forward."""
    contact = (crouch(roll=-4.0, twist=-4.0, hips_z=-0.13)
               + arms(down=70.0, swing_l=12.0, swing_r=28.0, elbow_l=72.0, elbow_r=84.0) + claws_up(DROOP)
               + legs(swing_l=62.0, swing_r=22.0, knee_l=70.0, knee_r=85.0, wide=8.0, foot_l=25.0, foot_r=10.0))
    passing = (crouch(roll=3.0, hips_z=-0.1)
               + arms(down=70.0, swing_l=20.0, swing_r=20.0, elbow_l=78.0, elbow_r=78.0) + claws_up(DROOP - 8.0)
               + legs(swing_l=40.0, swing_r=66.0, knee_l=85.0, knee_r=120.0, wide=8.0, foot_l=40.0, foot_r=30.0))
    return [(0, contact), (5, passing), (10, contact.mirrored()), (15, passing.mirrored()), (20, contact)]


def flee():
    """A fast, low scurry, one arm clutching the satchel."""
    clutch = P(upperarm_l=[("Y", 70.0), ("X", 10.0)], lowerarm_l=[("Z", -75.0)])
    stride = (crouch(spine=40.0, head=-58.0, roll=-3.0, hips_z=-0.1) + clutch
              + P(upperarm_r=[("Y", -55.0), ("X", -45.0)], lowerarm_r=[("Z", 60.0)])
              + legs(swing_l=55.0, swing_r=-20.0, knee_l=40.0, knee_r=70.0, wide=6.0, foot_l=15.0, foot_r=-20.0))
    push = (crouch(spine=40.0, head=-58.0, roll=3.0, hips_z=-0.06) + clutch
            + P(upperarm_r=[("Y", -60.0), ("X", 25.0)], lowerarm_r=[("Z", 50.0)])
            + legs(swing_l=-20.0, swing_r=55.0, knee_l=70.0, knee_r=40.0, wide=6.0, foot_l=-20.0, foot_r=15.0))
    return [(0, stride), (6, push), (12, stride)]


def grab():
    """Reaches forward, snatches, stuffs the loot in the satchel, giggles."""
    reach = (crouch(spine=34.0, head=-30.0, hips_z=-0.08)
             + arms(down=40.0, swing_l=80.0, swing_r=80.0, elbow_l=8.0, elbow_r=8.0) + claws_up(10.0)
             + legs(swing_l=50.0, swing_r=20.0, knee_l=70.0, knee_r=60.0, wide=8.0, foot_l=30.0, foot_r=20.0))
    snatch = (crouch(spine=30.0, head=-28.0, hips_z=-0.08)
              + arms(down=48.0, swing_l=70.0, swing_r=70.0, elbow_l=70.0, elbow_r=70.0) + claws_up(-20.0)
              + legs(swing_l=46.0, swing_r=24.0, knee_l=70.0, knee_r=62.0, wide=8.0, foot_l=30.0, foot_r=22.0))
    stuff = (crouch(spine=14.0, head=-18.0, twist=12.0, hips_z=-0.06)
             + P(upperarm_l=[("Y", 72.0), ("X", 5.0)], lowerarm_l=[("Z", -60.0)],
                 upperarm_r=[("Y", -55.0), ("X", -40.0)], lowerarm_r=[("Z", 95.0)])
             + legs(swing_l=30.0, swing_r=30.0, knee_l=60.0, knee_r=60.0, wide=7.0, foot_l=28.0, foot_r=28.0))
    giggle = (crouch(spine=8.0, head=-30.0, hips_z=0.04)
              + arms(down=60.0, swing_l=20.0, swing_r=40.0, elbow_l=60.0, elbow_r=70.0) + claws_up()
              + legs(swing_l=20.0, swing_r=20.0, knee_l=30.0, knee_r=30.0, wide=7.0, foot_l=10.0, foot_r=10.0))
    return [(0, SNEAK), (4, reach), (7, snatch), (11, stuff), (13, giggle), (16, SNEAK)]


def hit():
    """A startled flinch."""
    flinch = (crouch(spine=2.0, head=-8.0, hips_z=-0.05) + P(chest=[("X", -10.0)])
              + arms(down=35.0, swing_l=20.0, swing_r=20.0, elbow_l=60.0, elbow_r=60.0) + claws_up(40.0)
              + legs(swing_l=30.0, swing_r=20.0, knee_l=60.0, knee_r=55.0, wide=8.0, foot_l=28.0, foot_r=26.0))
    return [(0, SNEAK), (3, flinch), (10, SNEAK)]


def spawn():
    """Pops up out of the ground, shakes its cap, looks around."""
    buried = (crouch(spine=10.0, head=-20.0) + arms(down=-60.0, swing_l=10.0, swing_r=10.0, elbow_l=20.0, elbow_r=20.0)
              + legs(knee_l=40.0, knee_r=40.0, swing_l=20.0, swing_r=20.0) + P(loc={"root": (0, 0, -0.9)}))
    rising = buried + P(loc={"root": (0, 0, 0.45)})
    hop = (crouch(spine=0.0, head=-20.0, hips_z=0.0) + arms(down=35.0, elbow_l=40.0, elbow_r=40.0)
           + legs(swing_l=10.0, swing_r=10.0, knee_l=20.0, knee_r=20.0) + P(loc={"root": (0, 0, 0.1)}))
    land = SNEAK + P(loc={"hips": (0, 0, -0.04)})
    shake_a = SNEAK + P(head=[("Y", 16.0)])
    shake_b = SNEAK + P(head=[("Y", -16.0)])
    look = SNEAK + P(head=[("Z", 28.0)])
    return [(0, buried), (10, rising), (16, hop), (20, land), (24, shake_a), (27, shake_b), (30, shake_a),
            (33, SNEAK), (37, look), (40, SNEAK)]


def death():
    """Spins, wobbles and plops onto its back with its limbs in the air.
    The last frame is held (play_final); it lands before the corpse sinks."""
    recoil = SNEAK + P(chest=[("X", -14.0)], head=[("X", 10.0)])
    spin = (crouch(spine=0.0, head=-10.0, hips_z=0.0) + arms(down=0.0, elbow_l=10.0, elbow_r=10.0)
            + legs(swing_l=10.0, swing_r=-10.0, knee_l=20.0, knee_r=20.0) + P(root=[("Z", 140.0)]))
    wobble = (torso(spine=-10.0, chest=-6.0, head=-6.0) + arms(down=20.0, swing_l=-20.0, swing_r=-20.0)
              + legs(swing_l=20.0, swing_r=-5.0, knee_l=30.0, knee_r=20.0) + P(root=[("Z", 210.0), ("X", -30.0)]))
    flat = (torso(spine=-6.0, chest=0.0, head=10.0) + arms(down=15.0, swing_l=40.0, swing_r=30.0, elbow_l=30.0, elbow_r=40.0)
            + legs(swing_l=50.0, swing_r=35.0, knee_l=70.0, knee_r=50.0, wide=14.0)
            + P(root=[("Z", 220.0), ("X", -84.0)], loc={"root": (0, 0, 0.12)}))
    return [(0, SNEAK), (3, recoil), (10, spin), (16, wobble), (21, flat + P(loc={"root": (0, 0, 0.05)})), (24, flat)]


CLIPS = {
    "Gremlin_Idle": (idle, True),
    "Gremlin_Sneak": (sneak, True),
    "Gremlin_Flee": (flee, True),
    "Gremlin_Grab": (grab, False),
    "Gremlin_Hit": (hit, False),
    "Gremlin_Spawn": (spawn, False),
    "Gremlin_Death": (death, False),
}


def build_actions(rig):
    """Removes the rig's stock clips and keys the gremlin's own."""
    _build(rig, CLIPS, "Gremlin_Idle")
