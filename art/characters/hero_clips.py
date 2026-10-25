"""The heroes' own clips, hand-keyed on the kids' KayKit adventurer rig
with the shared helpers (and the sign cheat-sheet) in rig_anims.py.

    from characters import hero_clips
    record = hero_clips.add_clips(rig, "leo")      # after stretch_rig
    common.export_glb(...)                         # exports them in the GLB
    hero_clips.write_record("leo", record)

`add_clips` keys a kid's clips next to the rig's 76 stock clips, which
stay in the model as the fallback: the hero data's clip mapping
(game/resources/heroes/<kid>.tres) is the switch between the two.

Each kid has a `Style`: knobs (bounce, arm swing, posture) that the
shared clips read, so one clip set gives each kid their own feel. A
kid's own clips (`OWN`) read them too.

An attack clip has a contact frame, where the swing lands. The script
prints its contact time in clip seconds, and `write_record` saves every
clip's length and contact time beside the model
(game/assets/custom/<kid>_clips.json). The hero data's
`attack_contact_time` must match it (validate_project.gd checks), and
the game caps the wind-up: the contact may come at most 0.1 s in at the
companion's 1.45x play speed, so by clip second 0.145 (frame 3 at
24 fps).

Clips are authored at 24 fps from the stock Idle (sampled with
`stock_pose`), so they begin and end where the kid stands: the game
fades an action in over 0.08 s and out over 0.18 s
(CharacterVisual)."""

import json
import os
from dataclasses import dataclass

import bpy  # noqa: F401

from characters.rig_anims import BONES, MOVABLE, P, Pose, action, arms, legs, torso
from lib import common

AUTHORED_FPS = 24.0
# Every key sets the hand slots too: the stock clips key them, and a
# bone a clip leaves out keeps another clip's pose in the game.
HERO_BONES = BONES + ("handslot.l", "handslot.r")


@dataclass(frozen=True)
class Style:
    """Per-kid knobs, 1.0 = neutral. `bounce` scales the hips' dips and
    hops, `arm_swing` the arms' swings and `posture` is a forward lean
    of the spine in degrees (- leans back)."""
    bounce: float = 1.0
    arm_swing: float = 1.0
    posture: float = 0.0


# Leo bouncy and eager; Nela lighter and more careful (the spec).
STYLES = {
    "leo": Style(bounce=1.25, arm_swing=1.15, posture=3.0),
    "nela": Style(bounce=0.8, arm_swing=0.85, posture=-1.0),
}


@dataclass(frozen=True)
class Clip:
    """`keys(rig, style)` returns [(frame at 24 fps, Pose)]; `contact`
    is the contact frame (None for a clip without one)."""
    keys: object
    cyclic: bool = False
    contact: float = None


# ------------------------------------------------------------- poses


def stock_pose(rig, clip, frame):
    """The pose of a stock clip at `frame`, as a Pose in rest axes, so
    hand-made keys can start or end exactly on it or add to it."""
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions[clip]
    bpy.context.scene.frame_set(int(frame))
    bpy.context.view_layer.update()
    pose = Pose()
    for name in HERO_BONES:
        pb = rig.pose.bones.get(name)
        if pb is None:
            continue
        rest = pb.bone.matrix_local.to_quaternion()
        pose.rot[name] = [rest @ pb.rotation_quaternion @ rest.inverted()]
        if name in MOVABLE:
            pose.loc[name] = rest @ pb.location
    rig.animation_data.action = None
    return pose


def lean(style, degrees=0.0):
    """The kid's posture plus `degrees` of forward lean."""
    return P(spine=[("X", style.posture + degrees)])


def hips(style, z=0.0, y=0.0):
    """A hips dip (- down) or hop, scaled by the kid's bounce."""
    return P(loc={"hips": (0, y, z * style.bounce)})


# ------------------------------------------------------------- Leo


def stick_arm(raise_, swing, across, elbow, wrist_x=0.0, wrist_y=0.0, wrist_z=0.0):
    """Leo's right (stick) arm: the upper arm raised by `raise_` (+ up
    from the T-pose, - down), swung by `swing` (- forward when it hangs,
    back when it is raised) and `across` (+ toward his left), the elbow
    bent forward by `elbow`, then the wrist."""
    return P(upperarm_r=[("Y", raise_), ("X", swing), ("Z", across)], lowerarm_r=[("Z", elbow)],
             wrist_r=[("X", wrist_x), ("Y", wrist_y), ("Z", wrist_z)])


# Leo's stick arm on each key of his swing, solved offline for where
# the hand and the stick's tip go (hand height, reach, tip direction:
# see the docstring of leo_attack).
LEO_STICK = {
    "windup": stick_arm(-47.0, -81.8, 15.1, 109.5, -5.2, 35.0, 2.0),
    "contact": stick_arm(-13.1, -39.6, 5.8, 65.6, -23.6, -60.8, -5.5),
    "follow": stick_arm(-65.9, 1.7, -1.0, 81.1, -21.0, -16.4, 1.6),
    "overlap": stick_arm(-66.7, -4.5, 12.3, 45.8, -8.8, -9.6, 1.5),
    "settle": stick_arm(-45.1, 16.2, -0.0, 59.2, -8.0, -23.1, -8.0),
}


def leo_attack_body(style):
    """Everything but the stick arm, per key of leo_attack."""
    swing = style.arm_swing
    return {
        "windup": (torso(spine=-6.0, chest=-2.0, head=-6.0, twist=-28.0, roll=-4.0) + lean(style)
                   + P(head=[("Z", 18.0)])
                   + P(upperarm_l=[("Y", 50.0), ("X", -40.0 * swing)], lowerarm_l=[("Z", -35.0)])
                   + legs(swing_l=12.0, swing_r=-14.0, knee_l=10.0, knee_r=18.0, wide=7.0, foot_l=4.0, foot_r=-6.0)
                   + hips(style, z=-0.02, y=0.02)),
        "contact": (torso(spine=18.0, chest=8.0, head=-14.0, twist=20.0, roll=3.0) + lean(style)
                    + P(head=[("Z", -10.0)])
                    + P(upperarm_l=[("Y", 62.0), ("X", 28.0 * swing)], lowerarm_l=[("Z", -30.0)])
                    + legs(swing_l=26.0, swing_r=-18.0, knee_l=34.0, knee_r=22.0, wide=8.0, foot_l=14.0,
                           foot_r=-10.0)
                    + hips(style, z=-0.07, y=-0.03)),
        "follow": (torso(spine=24.0, chest=10.0, head=-18.0, twist=32.0, roll=4.0) + lean(style)
                   + P(head=[("Z", -16.0)])
                   + P(upperarm_l=[("Y", 66.0), ("X", 34.0 * swing)], lowerarm_l=[("Z", -26.0)])
                   + legs(swing_l=28.0, swing_r=-18.0, knee_l=38.0, knee_r=24.0, wide=8.0, foot_l=16.0, foot_r=-10.0)
                   + hips(style, z=-0.08, y=-0.04)),
        "overlap": (torso(spine=10.0, chest=4.0, head=-16.0, twist=20.0, roll=2.0) + lean(style)
                    + P(head=[("Z", -12.0)])
                    + P(upperarm_l=[("Y", 68.0), ("X", 16.0 * swing)], lowerarm_l=[("Z", -22.0)])
                    + legs(swing_l=16.0, swing_r=-10.0, knee_l=14.0, knee_r=10.0, wide=7.0, foot_l=8.0, foot_r=-6.0)
                    + hips(style, z=0.02, y=-0.02)),
        "settle": (torso(spine=6.0, chest=3.0, head=-8.0, twist=8.0) + lean(style)
                   + P(upperarm_l=[("Y", 70.0), ("X", 6.0 * swing)], lowerarm_l=[("Z", -18.0)])
                   + legs(swing_l=8.0, swing_r=-5.0, knee_l=8.0, knee_r=6.0, wide=6.0, foot_l=4.0, foot_r=-3.0)
                   + hips(style, z=-0.015, y=-0.01)),
    }


LEO_ATTACK_FRAMES = (("windup", 0), ("contact", 3), ("follow", 6), ("overlap", 10), ("settle", 16))


def leo_attack(rig, style):
    """Leo's stick swing: an overhead bonk with his right hand. 25
    frames at 24 fps (the stock chop's 1.04 s, which gameplay plays at
    1.5x for 0.69 s).

    0   wind-up (anticipation): the stick cocked up and back over his
        right shoulder, chest turned away, weight back, left arm out
        front for balance;
    3   contact: the stick strikes down in front at a small mob's
        height, chest turned in, knees dipped (the squash);
    6   follow-through: the stick carries on low and across his body;
    10  overlap: the body comes back up while the head and the stick
        arm lag, with a little hop (Leo's bounce);
    16  settling, the stick swinging back to his side;
    25  the stock Idle, so the game's fade back to locomotion is clean.
    """
    body = leo_attack_body(style)
    keys = [(frame, body[name] + LEO_STICK[name]) for name, frame in LEO_ATTACK_FRAMES]
    return keys + [(25, stock_pose(rig, "Idle", 0))]


# Each kid's own clips (attack, cheer, idle, run where it shows).
OWN = {
    "leo": {"Leo_Attack": Clip(leo_attack, contact=3)},
    "nela": {},
}
# The shared set, keyed once per kid with that kid's Style.
SHARED = {}


# ------------------------------------------------------------ keying


def add_clips(rig, kid, only=None):
    """Keys `kid`'s own and shared clips on the stretched rig, next to
    the stock ones, and returns their record ({name: {seconds,
    contact}}). `only` limits it to some clip names (for review)."""
    style = STYLES[kid]
    clips = dict(SHARED)
    clips.update(OWN[kid])
    keep = rig.animation_data.action if rig.animation_data else None
    record = {}
    for name, clip in clips.items():
        if only and name not in only:
            continue
        if name in bpy.data.actions:
            bpy.data.actions.remove(bpy.data.actions[name])
        keys = clip.keys(rig, style)
        action(rig, name, keys, clip.cyclic, bones=HERO_BONES)
        seconds = keys[-1][0] / AUTHORED_FPS
        record[name] = {"seconds": round(seconds, 4)}
        line = "hero_clips: %s %s, %.3f s" % (kid, name, seconds)
        if clip.contact is not None:
            record[name]["contact"] = round(clip.contact / AUTHORED_FPS, 4)
            line += ", contact %.3f s (frame %g)" % (record[name]["contact"], clip.contact)
        print(line)
    rig.animation_data.action = keep
    return record


def record_path(kid):
    return os.path.join(common.OUT_DIR, kid + "_clips.json")


def write_record(kid, record):
    """Saves the record beside the model, as export_glb saves the model
    (not for draft bakes)."""
    if os.environ.get("BAKE_SIZE") and not os.environ.get("DRAFT_EXPORT"):
        return
    with open(record_path(kid), "w") as out:
        json.dump({"clips": record}, out, indent=1, sort_keys=True)
        out.write("\n")
    print("wrote", os.path.relpath(record_path(kid), common.ROOT))
