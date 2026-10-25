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

The walk and run cycles (`cycle`) are stride-matched: each is
authored for a known stride (the kid's `Style.walk` / `Style.run`),
which the record saves too. The hero data's `walk_reference_speed` and
`reference_speed` must be that stride at the hero's model scale over
the clip's length (the validator checks), and the game scales the
cycle's playback by the hero's real speed, so the feet stay planted.

Each kid has their own idle loop and a few idle fidgets (one-shots the
game plays now and then while the kid stands idle; the hero data lists
them). Both keep the feet planted: the legs are re-solved every frame
to where the stock Idle's first pose stands (`_plant`).

Clips are authored at 24 fps from the stock Idle (sampled with
`stock_pose`), so they begin and end where the kid stands: the game
fades an action in over 0.08 s and out over 0.18 s
(CharacterVisual)."""

import json
import math
import os
from dataclasses import dataclass

import bpy  # noqa: F401
from mathutils import Matrix, Quaternion, Vector

from characters.rig_anims import BONES, MOVABLE, P, Pose, action, arms, legs, torso
from lib import common

AUTHORED_FPS = 24.0
# Every key sets the hand slots too: the stock clips key them, and a
# bone a clip leaves out keeps another clip's pose in the game.
HERO_BONES = BONES + ("handslot.l", "handslot.r")


@dataclass(frozen=True)
class Stride:
    """A walk or run cycle's size: `frames` per cycle (two steps) at 24
    fps, and `stride`, the ground one cycle covers in model metres. The
    cycle is authored for stride / (frames / 24) model metres a second;
    times the hero's model scale, that is the hero data's reference
    speed for it (the validator checks)."""
    frames: int
    stride: float


@dataclass(frozen=True)
class Style:
    """Per-kid knobs, 1.0 = neutral. `bounce` scales the hips' dips and
    hops, `arm_swing` the arms' swings and `posture` is a forward lean
    of the spine in degrees (- leans back). `hand_hold` is how much the
    right hand keeps its Idle angle while the arm swings (0 swings with
    the forearm, 1 holds it), so a held prop hangs. `walk` and `run` size
    the kid's cycles: shorter legs take quicker, shorter steps."""
    bounce: float = 1.0
    arm_swing: float = 1.0
    posture: float = 0.0
    hand_hold: float = 0.0
    walk: Stride = None
    run: Stride = None


# Leo bouncy and eager; Nela lighter and more careful (the spec). Her
# legs are a third shorter than his, so her steps are quicker. Both
# runs are authored for 4 m/s in the game (their move speed), the walks
# for about 1.2 and 1.0 m/s (played faster at the 1.6 m/s walk speed).
STYLES = {
    "leo": Style(bounce=1.25, arm_swing=1.15, posture=3.0, hand_hold=0.5,
                 walk=Stride(16, 1.10), run=Stride(12, 2.86)),
    "nela": Style(bounce=0.8, arm_swing=0.85, posture=-1.0, hand_hold=1.0,
                  walk=Stride(12, 0.80), run=Stride(10, 2.56)),
}


@dataclass(frozen=True)
class Clip:
    """`keys(rig, style)` returns [(frame at 24 fps, Pose)]; `contact`
    is the contact frame (None for a clip without one); `gait` names the
    Style stride ("walk" or "run") a cycle is authored with, recorded
    beside its length."""
    keys: object
    cyclic: bool = False
    contact: float = None
    gait: str = None


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


# ------------------------------------------------------------- Nela


def sling_arms(fork, draw):
    """Nela's two arms on her slingshot: `fork` is her right arm (the
    fork, with her lantern hanging from the same fist) and `draw` her
    left arm (the pouch), both as stick_arm's angles; the left one is
    mirrored, so the same angles make the mirror pose."""
    return stick_arm(*fork) + stick_arm(*draw).mirrored()


# Her arms on each key of her shot, solved offline for where each hand
# goes and for the lantern hanging down from the fork hand (see the
# docstring of nela_attack).
NELA_SLING = {
    "draw": sling_arms((61.5, 60.2, 24.2, 28.2, 23.6, -18.6, 77.2), (-9.2, -17.8, 3.7, 138.5, -4.5, 1.7, 12.8)),
    "release": sling_arms((72.2, 46.5, 21.9, 35.8, 12.3, -27.0, 61.7), (-50.2, 1.4, -52.9, 133.2, -20.7, 34.2, 52.1)),
    "follow": sling_arms((70.3, 41.7, 23.0, 46.3, 11.6, -16.5, 82.2), (-42.0, 29.1, -64.7, 118.6, -16.7, 17.2, 45.6)),
    "watch": sling_arms((66.8, 46.8, 20.0, 64.9, 2.3, -17.4, 53.6), (-40.9, 45.9, -41.1, 108.0, -9.5, 0.3, 27.4)),
    "reload": sling_arms((44.7, 61.0, 8.9, 83.1, -4.9, -10.1, 21.1), (-42.0, 44.4, -22.4, 108.3, -6.4, -4.3, 19.1)),
}


def nela_attack_body(style):
    """Everything but the arms, per key of nela_attack. The chest turns
    to her left (+twist) so the fork shoulder leads."""
    return {
        "draw": (torso(spine=-2.0, chest=2.0, head=-12.0, twist=26.0, roll=-3.0) + lean(style)
                 + P(head=[("Z", -16.0)])
                 + legs(swing_l=-8.0, swing_r=10.0, knee_l=14.0, knee_r=6.0, wide=7.0, foot_l=-4.0, foot_r=6.0)
                 + hips(style, z=-0.03, y=0.03)),
        "release": (torso(spine=3.0, chest=3.0, head=-12.0, twist=22.0, roll=-2.0) + lean(style)
                    + P(head=[("Z", -14.0)])
                    + legs(swing_l=-6.0, swing_r=12.0, knee_l=12.0, knee_r=10.0, wide=7.0, foot_l=-3.0,
                           foot_r=8.0)
                    + hips(style, z=-0.04, y=0.0)),
        "follow": (torso(spine=6.0, chest=4.0, head=-12.0, twist=18.0, roll=-1.0) + lean(style)
                   + P(head=[("Z", -12.0)])
                   + legs(swing_l=-6.0, swing_r=12.0, knee_l=12.0, knee_r=12.0, wide=7.0, foot_l=-3.0, foot_r=8.0)
                   + hips(style, z=-0.045, y=-0.01)),
        "watch": (torso(spine=5.0, chest=3.0, head=-10.0, twist=14.0) + lean(style)
                  + P(head=[("Z", -10.0)])
                  + legs(swing_l=-4.0, swing_r=8.0, knee_l=8.0, knee_r=8.0, wide=6.0, foot_l=-2.0, foot_r=5.0)
                  + hips(style, z=-0.03, y=-0.005)),
        "reload": (torso(spine=10.0, chest=4.0, head=-6.0, twist=4.0, roll=4.0) + lean(style)
                   + P(head=[("Z", 6.0)])
                   + legs(swing_l=-2.0, swing_r=4.0, knee_l=6.0, knee_r=4.0, wide=6.0, foot_l=-1.0, foot_r=2.0)
                   + hips(style, z=-0.02, y=0.0)),
    }


NELA_ATTACK_FRAMES = (("draw", 0), ("release", 3), ("follow", 6), ("watch", 10), ("reload", 15))


def nela_attack(rig, style):
    """Nela's slingshot shot: the fork in her right fist (with her
    lantern hanging below it), the pouch drawn with her left hand. 22
    frames at 24 fps (the stock Spellcast_Shoot's 0.92 s, which gameplay
    plays at 1.5x for 0.61 s). Careful and precise where Leo's swing is
    eager: she aims down her arm and holds still through the shot.

    0   drawn (anticipation): fork arm straight out at the target, the
        pouch pulled back under her chin, chest turned so the fork
        shoulder leads, weight on the back foot, head down on the aim;
    3   contact: she lets go, the pebble flies; the empty draw hand
        flicks back and out, the fork kicks up a touch;
    6   follow-through: the draw hand opens out to the side while the
        fork arm holds the aim;
    10  she watches the shot, the fork arm sinking;
    15  reload: the draw hand dips to the pouch at her hip and the fork
        arm comes down;
    22  the stock Idle, so the game's fade back to locomotion is clean.
    """
    body = nela_attack_body(style)
    keys = [(frame, body[name] + NELA_SLING[name]) for name, frame in NELA_ATTACK_FRAMES]
    return keys + [(22, stock_pose(rig, "Idle", 0))]


# ------------------------------------------------------- walk and run


@dataclass(frozen=True)
class Gait:
    """The shape of a cycle, shared by both kids (their Style scales
    it). `reach` is how much of the leg's length a planted foot sweeps
    under the hips, `lift` how high (share of the leg) the swinging
    ankle rises; `bob` (model m, times bounce) is the hips' rise and
    fall: up over the planted foot in a walk, down into it in a run.
    `lean` (deg) adds to the posture, `arm` (deg, times arm_swing) is
    the arms' swing either way and `elbow` (deg) bends the elbows past
    the Idle's. `twist` (deg) turns the hips toward the leading leg (the
    chest turns back); `sway` (model m) moves the hips over the planted
    foot. `toe_off` and `heel` (deg) tip the swinging foot toe-down as it
    leaves and toe-up before it lands. `ease` is how gently it starts
    forward over the ground once lifted (1 slowest, 0 faster), and
    `plant` the share of the swing at each end where it only rises or
    sets down, so it is clear of the ground before it moves over it."""
    reach: float
    lift: float
    bob: float
    lean: float
    arm: float
    elbow: float
    twist: float
    sway: float
    toe_off: float
    heel: float
    ease: float
    plant: float
    run: bool


WALK = Gait(reach=0.85, lift=0.2, bob=0.022, lean=2.0, arm=20.0, elbow=6.0, twist=6.0, sway=0.012,
            toe_off=16.0, heel=12.0, ease=1.0, plant=0.2, run=False)
RUN = Gait(reach=0.9, lift=0.34, bob=0.035, lean=10.0, arm=38.0, elbow=50.0, twist=8.0, sway=0.0,
           toe_off=35.0, heel=8.0, ease=0.4, plant=0.0, run=True)
# The longest a leg may stretch (share of its length), so the knee never
# locks straight.
LEG_STRETCH = 0.97


def _turn(entries):
    """A Pose rotation list as one Quaternion (as rig_anims.key does)."""
    q = Quaternion()
    for turn in entries:
        if isinstance(turn, Quaternion):
            q = turn @ q
        else:
            vec = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[turn[0]]
            q = Quaternion(vec, math.radians(turn[1])) @ q
    return q


def _world(rig, pose, name):
    """A bone's rotation in armature space (rest axes) under `pose`."""
    bone = rig.data.bones[name]
    own = _turn(pose.rot.get(name, []))
    return _world(rig, pose, bone.parent.name) @ own if bone.parent else own


def _smoother(s):
    """0 to 1 with no speed or acceleration at either end."""
    return s * s * s * (s * (s * 6.0 - 15.0) + 10.0)


def _leg_ik(hip, knee, ankle, target):
    """The upper leg's turn (degrees about X, then Y) and the knee's
    bend (about X) that put the ankle at `target`, relative to the hip
    joint in the hips' frame. `hip`, `knee`, `ankle` are rest
    positions. Solved in the leg's side plane, then refined by Newton
    steps in 3D."""
    thigh, shin = knee - hip, ankle - knee

    def reach(x):
        upper = Quaternion((1, 0, 0), math.radians(x[0])) @ Quaternion((0, 1, 0), math.radians(x[1]))
        return upper @ thigh + upper @ Quaternion((1, 0, 0), math.radians(x[2])) @ shin

    # The side plane: +X turns move the foot back (+Y), the knee bends +X.
    a, b = thigh.length, shin.length
    d = min(max(Vector((target.y, target.z)).length, abs(a - b) + 1e-4), a + b - 1e-4)
    at_knee = math.acos((a * a + b * b - d * d) / (2 * a * b))
    at_hip = math.acos((a * a + d * d - b * b) / (2 * a * d))
    aim = math.atan2(target.y, -target.z)
    x = [math.degrees(aim - at_hip), math.degrees(math.asin(max(-1.0, min(1.0, -target.x / (a + b))))),
         math.degrees(math.pi - at_knee)]
    for _ in range(30):
        miss = target - reach(x)
        if miss.length < 1e-6:
            break
        cols = []
        for i in range(3):
            nudged = list(x)
            nudged[i] += 0.01
            cols.append((reach(nudged) - reach(x)) / 0.01)
        jac = Matrix([[cols[j][i] for j in range(3)] for i in range(3)])
        try:
            step = jac.inverted() @ miss
        except ValueError:
            break
        for i in range(3):
            x[i] += max(-15.0, min(15.0, step[i]))
    if (target - reach(x)).length > 0.002:
        raise ValueError("hero_clips: the leg cannot reach %s (off by %.3f)" % (target, (target - reach(x)).length))
    return x


def cycle(rig, style, stride, gait):
    """A walk or run cycle of `stride.frames` frames whose planted feet
    stay put on the ground while the hero covers `stride.stride` a
    cycle: each foot is placed in model space frame by frame (planted,
    it moves back at the ground's speed; swinging, it lifts and comes
    forward with no speed at either end) and the leg is solved to it.
    The left foot lands at frame 0, the right half a cycle later. Every
    frame is keyed, and the last is the first, so it wraps cleanly."""
    idle = stock_pose(rig, "Idle", 0)
    bones = rig.data.bones
    rest = {name: bones[name].head_local.copy() for name in
            ("hips", "upperleg.l", "lowerleg.l", "foot.l", "upperleg.r", "lowerleg.r", "foot.r")}
    leg = (rest["lowerleg.l"] - rest["upperleg.l"]).length + (rest["foot.l"] - rest["lowerleg.l"]).length
    n = stride.frames
    sweep = gait.reach * leg
    duty = sweep / stride.stride  # the share of a cycle each foot is down
    if not 0.1 <= duty <= 0.7 or (not gait.run and duty <= 0.5):
        raise ValueError("hero_clips: a %s of %.2f m strides has each foot down %.0f%% of the time"
                         % ("run" if gait.run else "walk", stride.stride, duty * 100))
    bob = gait.bob * style.bounce
    twist = gait.twist * style.bounce
    swing = gait.arm * style.arm_swing

    def foot(side, p):
        """Where the ankle goes at cycle phase `p` (model space), the
        foot's pitch (deg, + toes up) and whether it is planted."""
        q = (p + (0.0 if side == "l" else 0.5)) % 1.0
        home = rest["foot." + side]
        if q < duty:
            return Vector((home.x, home.y - sweep / 2 + stride.stride * q, home.z)), 0.0, True
        s = (q - duty) / (1.0 - duty)
        # Forward over the ground once lifted, easing out and in (a run
        # leaves faster); it only rises at first and only sets down last.
        u = min(max((s - gait.plant) / (1.0 - 2.0 * gait.plant), 0.0), 1.0)
        ease = _smoother(u) * gait.ease + (3 - 2 * u) * u * u * (1 - gait.ease)
        y = home.y + sweep / 2 - stride.stride * ease + stride.stride * (1.0 - duty) * s
        z = home.z + gait.lift * leg * math.sin(math.pi * s)
        pitch = -gait.toe_off * math.sin(math.pi * s / 0.5) if s < 0.5 else gait.heel * math.sin(math.pi * (s - 0.5) / 0.5)
        return Vector((home.x, y, z)), pitch, False

    def hips_at(p):
        """The hips' offset (above `base`) and turn at phase `p`."""
        wave = math.cos(4 * math.pi * (p - duty / 2))
        z = (bob if not gait.run else -bob) * wave
        x = gait.sway * math.cos(2 * math.pi * (p - duty / 2))
        yaw = -twist * math.cos(2 * math.pi * p)
        return Vector((x, 0.0, z)), yaw

    def hip_joint(side, offset, yaw):
        turn = Quaternion((0, 0, 1), math.radians(yaw))
        return rest["hips"] + offset + turn @ (rest["upperleg." + side] - rest["hips"])

    # The hips sit as high as the planted legs allow at their longest
    # stretch.
    longest = LEG_STRETCH * leg
    base = 0.0
    for i in range(400):
        offset, yaw = hips_at(i / 400)
        for side in "lr":
            ankle, _, planted = foot(side, i / 400)
            if not planted:
                continue
            joint = hip_joint(side, offset, yaw)
            flat = Vector((joint.x - ankle.x, joint.y - ankle.y)).length
            if flat >= longest:
                raise ValueError("hero_clips: a planted foot sweeps further than the leg reaches")
            base = min(base, ankle.z + math.sqrt(longest ** 2 - flat ** 2) - joint.z)
    base -= 0.005

    idle_wrist = _world(rig, idle, "wrist.r")
    keys = []
    for f in range(n):
        p = f / n
        offset, yaw = hips_at(p)
        offset.z += base
        hips_turn = Quaternion((0, 0, 1), math.radians(yaw))
        pose = Pose(loc={"hips": offset})
        pose.rot["root"] = list(idle.rot.get("root", []))
        pose.rot["hips"] = [hips_turn]
        for side in "lr":
            ankle, pitch, _ = foot(side, p)
            joint = hip_joint(side, offset, yaw)
            # A swinging foot trailing out of reach kicks up behind (the
            # knee folds) instead of stretching the leg.
            flat = Vector((joint.x - ankle.x, joint.y - ankle.y)).length
            if (ankle - joint).length > longest:
                if flat >= longest:
                    raise ValueError("hero_clips: a swinging foot trails further than the leg reaches")
                ankle.z = joint.z - math.sqrt(longest ** 2 - flat ** 2)
            target = hips_turn.inverted() @ (ankle - joint)
            ax, ay, knee = _leg_ik(rest["upperleg." + side], rest["lowerleg." + side], rest["foot." + side], target)
            upper = Quaternion((1, 0, 0), math.radians(ax)) @ Quaternion((0, 1, 0), math.radians(ay))
            lower = Quaternion((1, 0, 0), math.radians(knee))
            # The foot keeps its rest angle in the world, tipped by `pitch`.
            shin = hips_turn @ upper @ lower
            flat = Quaternion((1, 0, 0), math.radians(-pitch))
            pose.rot["upperleg." + side] = [upper]
            pose.rot["lowerleg." + side] = [lower]
            pose.rot["foot." + side] = [shin.inverted() @ flat]
            pose.rot["toes." + side] = list(idle.rot.get("toes." + side, []))
        # The chest turns back against the hips, the head keeps ahead.
        lean_deg = style.posture + gait.lean
        pose.rot["spine"] = list(idle.rot.get("spine", [])) + [("Z", -yaw), ("X", lean_deg)]
        pose.rot["chest"] = list(idle.rot.get("chest", [])) + [("Z", -0.5 * yaw)]
        nod = -bob * 60.0 * math.cos(4 * math.pi * (p - duty / 2)) if gait.run else 0.0
        pose.rot["head"] = list(idle.rot.get("head", [])) + [("Z", 0.5 * yaw), ("X", -0.6 * lean_deg + nod)]
        # Arms swing against the legs, a little behind them (overlap).
        arm = swing * math.cos(2 * math.pi * (p - 0.04))
        for side, fwd in (("l", -arm), ("r", arm)):
            sign = -1.0 if side == "l" else 1.0
            bend = gait.elbow * (1.0 + 0.3 * fwd / max(swing, 1.0))
            pose.rot["upperarm." + side] = list(idle.rot["upperarm." + side]) + [("X", -fwd)]
            pose.rot["lowerarm." + side] = list(idle.rot["lowerarm." + side]) + [("Z", sign * bend)]
            for part in ("wrist.", "hand.", "handslot."):
                pose.rot[part + side] = list(idle.rot.get(part + side, []))
        # The right hand (Leo's stick, Nela's lantern) keeps some of its
        # Idle angle, so the prop hangs instead of swinging stiffly.
        swung = _world(rig, pose, "wrist.r")
        held = swung.slerp(idle_wrist, style.hand_hold)
        pose.rot["wrist.r"] = [_world(rig, pose, "lowerarm.r").inverted() @ held]
        keys.append((f, pose))
    return keys + [(n, keys[0][1])]


def walk(rig, style):
    """The shared walk: heel-to-toe steps under a gently bobbing body,
    arms swinging against the legs. Leo bobs and swings more; Nela is
    lighter and more upright, with quicker, smaller steps."""
    return cycle(rig, style, style.walk, WALK)


def run(rig, style):
    """The shared run: a forward lean, knees driving up, a short flight
    between steps and elbows pumping. Leo leans in and bounces; Nela runs
    lighter and more upright, her lantern held steady."""
    return cycle(rig, style, style.run, RUN)


# ----------------------------------------------------- idles and fidgets
#
# Each kid stands in their own idle loop and now and then plays a
# fidget (the game picks one after a random wait: FidgetScheduler). Both
# start from the stock Idle's first frame, with the legs re-solved every
# frame so the feet stay where that pose plants them; a fidget begins and
# ends on the kid's idle at frame 0, so it fades in and out cleanly.


def _head(rig, pose, name):
    """A bone's head in armature space under `pose`."""
    bone = rig.data.bones[name]
    loc = pose.loc.get(name, Vector()) if name in MOVABLE else Vector()
    if bone.parent is None:
        return bone.head_local + loc
    parent = bone.parent
    return _head(rig, pose, parent.name) + _world(rig, pose, parent.name) @ (bone.head_local - parent.head_local + loc)


def _plant(rig, pose, stand):
    """Re-solves `pose`'s legs so each ankle stays where `stand` has it
    and each foot keeps its angle in the world (feet planted)."""
    hips = _world(rig, pose, "hips")
    bones = rig.data.bones
    for side in "lr":
        ankle = _head(rig, stand, "foot." + side)
        joint = _head(rig, pose, "upperleg." + side)
        ax, ay, knee = _leg_ik(bones["upperleg." + side].head_local, bones["lowerleg." + side].head_local,
                               bones["foot." + side].head_local, hips.inverted() @ (ankle - joint))
        upper = Quaternion((1, 0, 0), math.radians(ax)) @ Quaternion((0, 1, 0), math.radians(ay))
        lower = Quaternion((1, 0, 0), math.radians(knee))
        pose.rot["upperleg." + side] = [upper]
        pose.rot["lowerleg." + side] = [lower]
        pose.rot["foot." + side] = [(hips @ upper @ lower).inverted() @ _world(rig, stand, "foot." + side)]
        pose.rot["toes." + side] = list(stand.rot.get("toes." + side, []))
    return pose


def _arm(side, raise_, swing, across, elbow, wrist_x=0.0, wrist_y=0.0, wrist_z=0.0):
    """stick_arm's angles on either arm (the left one mirrored)."""
    pose = stick_arm(raise_, swing, across, elbow, wrist_x, wrist_y, wrist_z)
    return pose.mirrored() if side == "l" else pose


def _reach(rig, body, side, target, guess=(-60.0, -20.0, 0.0, 60.0)):
    """stick_arm angles (raise, swing, across, elbow) that put `side`'s
    hand at `target` (armature space) on `body`: damped least squares
    from `guess`, so the arm stays close to it."""
    base = Pose(body.rot, body.loc)
    for part in ("upperarm.", "lowerarm.", "wrist."):
        base.rot.pop(part + side, None)
    x = list(guess)

    def hand(v):
        return _head(rig, base + _arm(side, *v), "hand." + side)

    for _ in range(80):
        at = hand(x)
        miss = target - at
        if miss.length < 1e-4:
            break
        cols = []
        for i in range(4):
            nudged = list(x)
            nudged[i] += 0.05
            cols.append((hand(nudged) - at) / 0.05)
        jjt = Matrix(((0.0,) * 3,) * 3)
        for col in cols:
            jjt += Matrix([[col[r] * col[c] for c in range(3)] for r in range(3)])
        for i in range(3):
            jjt[i][i] += 1e-5
        y = jjt.inverted() @ miss
        for i in range(4):
            x[i] += max(-8.0, min(8.0, cols[i].dot(y)))
    if (target - hand(x)).length > 0.01:
        print("hero_clips: the %s hand only gets within %.3f of %s" % (side, (target - hand(x)).length, target))
    return x


def _hold_wrist(rig, pose, stand, side="r"):
    """Keys the wrist so the hand keeps `stand`'s angle in the world
    (Nela's lantern keeps hanging however her arm moves)."""
    pose.rot["wrist." + side] = [_world(rig, pose, "lowerarm." + side).inverted() @ _world(rig, stand, "wrist." + side)]
    return pose


def _aim_slot(rig, pose, direction, roll=0.0, side="r"):
    """Turns the wrist so the hand slot's +X (Leo's stick, down its
    bottom end) points along `direction`, rolled `roll` degrees about it."""
    rest_x = rig.data.bones["handslot." + side].matrix_local.to_3x3().col[0]
    now = _world(rig, pose, "handslot." + side) @ rest_x
    turn = Quaternion(direction.normalized(), math.radians(roll)) @ now.rotation_difference(direction.normalized())
    pose.rot["wrist." + side] = [_world(rig, pose, "lowerarm." + side).inverted() @ turn
                                 @ _world(rig, pose, "wrist." + side)]
    return pose


def _stand(rig, style):
    """The kid's standing pose: the stock Idle's first frame in their
    posture, feet planted where the Idle puts them."""
    idle = stock_pose(rig, "Idle", 0)
    return _plant(rig, idle + lean(style), idle), idle


def _pose_at(rig, act, frame):
    """A Pose sampled from `act` at authored `frame` (24 fps)."""
    rig.animation_data.action = act
    at = frame * bpy.context.scene.render.fps / AUTHORED_FPS
    bpy.context.scene.frame_set(int(at), subframe=at - int(at))
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
    return pose


def _every_frame(rig, keys, idle, hold=False):
    """`keys` eased into a key on every frame (Bezier, as the game
    would play them), with the feet planted on each, and the right hand
    held at its Idle angle with `hold`."""
    act = action(rig, "hero_clips_tmp", keys, bones=HERO_BONES)
    out = []
    for frame in range(int(keys[-1][0]) + 1):
        pose = _plant(rig, _pose_at(rig, act, frame), idle)
        out.append((frame, _hold_wrist(rig, pose, idle) if hold else pose))
    rig.animation_data.action = None
    bpy.data.actions.remove(act)
    return out


def _idle_loop(rig, style, frames, motion, hold=False):
    """An idle of `frames` frames: `motion(p)` gives the Pose added to
    the kid's stand at phase p (0..1), and the hips' move (loc) and turn
    (rot) re-plant the legs. Keyed every frame; the last is the first."""
    stand, idle = _stand(rig, style)
    keys = []
    for f in range(frames):
        pose = _plant(rig, stand + motion(f / frames), idle)
        keys.append((f, _hold_wrist(rig, pose, idle) if hold else pose))
    return keys + [(frames, keys[0][1])]


def _wave(p, cycles=1.0, shift=0.0):
    return math.sin(2 * math.pi * (cycles * p + shift))


def _breath(p, cycles=1.0):
    """0 to 1 and back, once a cycle (in at the top)."""
    return 0.5 - 0.5 * math.cos(2 * math.pi * cycles * p)


def leo_idle_motion(style):
    """Leo can't wait to go: a springy bob twice a breath, his weight
    rocking foot to foot, head up and looking about."""
    def motion(p):
        breath, rock = _breath(p), _wave(p)
        bob = -0.014 * style.bounce * _breath(p, 2.0)
        return (P(hips=[("Y", -1.5 * rock)], loc={"hips": (0.012 * rock, 0.0, bob)})
                + P(spine=[("Y", 2.5 * rock), ("X", 1.0 * _breath(p, 2.0))], chest=[("X", -2.0 * breath)],
                    head=[("X", 1.5 * breath - 2.0), ("Y", -1.0 * rock), ("Z", 4.0 * _wave(p, 1.0, 0.15))])
                + P(upperarm_l=[("X", 2.5 * style.arm_swing * _wave(p, 1.0, 0.2)), ("Y", -1.5 * breath)],
                    upperarm_r=[("X", 1.5 * style.arm_swing * _wave(p, 1.0, 0.2)), ("Y", 1.5 * breath)]))
    return motion


def nela_idle_motion(style):
    """Nela waits quietly: a slow breath, a gentle sway, her head tilted
    as if listening, the lantern hanging still."""
    def motion(p):
        breath, sway = _breath(p), _wave(p)
        return (P(hips=[("Y", -1.0 * sway)], loc={"hips": (0.008 * sway, 0.0, -0.006 * style.bounce * breath)})
                + P(spine=[("Y", 1.5 * sway)], chest=[("X", -2.5 * breath)],
                    head=[("X", 1.5 * breath), ("Y", 4.0 * _wave(p, 1.0, 0.2) + 2.0), ("Z", -3.0 * _wave(p, 1.0, 0.1))])
                + P(upperarm_l=[("Y", -2.0 * breath), ("X", 1.5 * style.arm_swing * _wave(p, 1.0, 0.25))],
                    upperarm_r=[("Y", 2.0 * breath)]))
    return motion


def leo_idle(rig, style):
    """Leo's idle: 32 frames (1.33 s), quick and springy."""
    return _idle_loop(rig, style, 32, leo_idle_motion(style))


def nela_idle(rig, style):
    """Nela's idle: 48 frames (2 s), slow and still."""
    return _idle_loop(rig, style, 48, nela_idle_motion(style), hold=True)


def _fidget(rig, style, motion, keys, hold=False):
    """A fidget from `keys` [(frame, Pose to add to the stand, {side:
    hand target} or None, extra)], `extra(rig, pose)` finishing a key
    (a stick aim); it starts and ends on the idle's first frame."""
    stand, idle = _stand(rig, style)
    start = stand + motion(0.0)
    out = [(0, start)]
    guess = {"l": (-60.0, -20.0, 0.0, 60.0), "r": (-60.0, -20.0, 0.0, 60.0)}
    for frame, add, hands, extra in keys:
        pose = start + add
        for side, target in (hands or {}).items():
            guess[side] = _reach(rig, pose, side, Vector(target), guess[side])
            for part in ("upperarm.", "lowerarm.", "wrist."):
                pose.rot.pop(part + side, None)
            pose = pose + _arm(side, *guess[side])
        if extra is not None:
            pose = extra(rig, pose)
        out.append((frame, _plant(rig, pose, idle)))
    end = out[-1][0] + 8
    return _every_frame(rig, out + [(end, start)], idle, hold)


def leo_look(rig, style):
    """Leo shades his eyes with his left hand and scans left, then
    right, up on his toes with it: 60 frames (2.5 s)."""
    brow = (0.17, -0.34, 1.98)

    def scan(turn, dip=0.0):
        return (P(spine=[("Z", 0.12 * turn), ("X", 2.0)], chest=[("Z", 0.18 * turn)],
                  head=[("Z", 0.7 * turn), ("X", -4.0)]) + hips(style, z=dip))

    return _fidget(rig, style, leo_idle_motion(style), [
        (6, scan(0.0, -0.015), {"l": (0.42, -0.2, 1.4)}, None),
        (12, scan(10.0, 0.005), {"l": brow}, None),
        (22, scan(55.0), {"l": brow}, None),
        (28, scan(58.0), {"l": brow}, None),
        (38, scan(-55.0), {"l": brow}, None),
        (44, scan(-58.0), {"l": brow}, None),
        (52, scan(0.0, -0.01), {"l": (0.45, -0.18, 1.35)}, None),
    ])


def leo_scratch(rig, style):
    """Leo is stumped: his head tips over and he scratches it with his
    left hand: 48 frames (2 s)."""
    puzzled = P(head=[("Y", -9.0), ("X", 4.0), ("Z", -6.0)], spine=[("Y", -2.0)], chest=[("Z", -4.0)])
    keys = [(5, puzzled + hips(style, z=-0.01), {"l": (0.46, -0.1, 1.5)}, None),
            (9, puzzled, {"l": (0.4, -0.04, 1.95)}, None)]
    for i, frame in enumerate(range(12, 34, 3)):
        side = 0.035 if i % 2 else -0.035
        keys.append((frame, puzzled, {"l": (0.25, 0.02 + side, 2.08 + abs(side) * 0.5)}, None))
    keys.append((37, P(head=[("Y", -5.0)]), {"l": (0.46, -0.06, 1.72)}, None))
    keys.append((42, P(head=[("Y", -2.0)]), {"l": (0.5, -0.04, 1.3)}, None))
    return _fidget(rig, style, leo_idle_motion(style), keys)


def leo_stick(rig, style):
    """Leo checks his stick: he lifts it up in front, turns it over to
    look along it, then plants it back with a tap: 56 frames (2.3 s)."""
    look = P(head=[("X", 14.0), ("Z", -12.0)], chest=[("Z", -8.0), ("X", 3.0)])
    hand = (-0.3, -0.38, 1.28)
    tilt = Vector((0.15, -0.45, -0.88))

    def aim(roll):
        return lambda rig, pose: _aim_slot(rig, pose, tilt, roll)

    return _fidget(rig, style, leo_idle_motion(style), [
        (8, look + hips(style, z=-0.012), {"r": (-0.42, -0.25, 1.12)}, aim(0.0)),
        (14, look, {"r": hand}, aim(0.0)),
        (22, look + P(head=[("Y", -6.0)]), {"r": hand}, aim(70.0)),
        (30, look + P(head=[("Y", 5.0)]), {"r": hand}, aim(-60.0)),
        (36, look, {"r": hand}, aim(0.0)),
        (42, hips(style, z=-0.01), {"r": (-0.56, -0.14, 1.14)}, None),
        (45, hips(style, z=-0.016), {"r": (-0.56, -0.13, 1.05)}, None),
    ])


def nela_look(rig, style):
    """Nela lifts her lantern and peers into the dark, left then right:
    64 frames (2.7 s)."""
    lamp = (-0.3, -0.36, 1.02)

    def peer(turn):
        return P(spine=[("X", 6.0), ("Z", 0.3 * turn)], chest=[("Z", 0.3 * turn)], head=[("Z", 0.5 * turn), ("X", 3.0)])

    near = {"r": lamp, "l": (0.3, -0.3, 0.98)}
    return _fidget(rig, style, nela_idle_motion(style), [
        (10, peer(0.0), near, None),
        (20, peer(50.0), near, None),
        (30, peer(52.0), near, None),
        (42, peer(-50.0), near, None),
        (50, peer(-52.0), near, None),
        (58, peer(0.0), {"r": (-0.48, -0.25, 0.9)}, None),
    ], hold=True)


def nela_stretch(rig, style):
    """Nela stretches: her free arm up high, back arched, head tipped
    back, then she settles with a little shake: 56 frames (2.3 s)."""
    up = P(spine=[("X", -8.0)], chest=[("X", -5.0)], head=[("X", -14.0), ("Y", 4.0)])
    return _fidget(rig, style, nela_idle_motion(style), [
        (8, P(spine=[("X", 5.0)], head=[("X", 4.0)]) + hips(style, z=-0.015), {"l": (0.36, -0.2, 1.0)}, None),
        (20, up + hips(style, z=-0.004), {"l": (0.2, 0.0, 1.78), "r": (-0.5, -0.02, 0.98)}, None),
        (30, up + P(spine=[("Y", -3.0)]) + hips(style, z=-0.002), {"l": (0.17, 0.03, 1.8), "r": (-0.5, -0.02, 0.98)},
         None),
        (40, P(spine=[("X", 4.0)], head=[("X", 3.0)]) + hips(style, z=-0.012), {"l": (0.5, -0.05, 1.0)}, None),
        (45, P(spine=[("Y", 2.0)], head=[("Y", -4.0)]), None, None),
        (49, P(spine=[("Y", -2.0)], head=[("Y", 4.0)]), None, None),
    ], hold=True)


def nela_hair(rig, style):
    """Nela tucks her hair behind her left ear, head tipped to it: 48
    frames (2 s)."""
    tip = P(head=[("Y", 8.0), ("Z", 5.0)], spine=[("Y", 1.5)])
    return _fidget(rig, style, nela_idle_motion(style), [
        (8, tip, {"l": (0.36, -0.22, 1.25)}, None),
        (14, tip, {"l": (0.3, -0.16, 1.5)}, None),
        (24, tip + P(head=[("Y", 2.0)]), {"l": (0.31, 0.06, 1.56)}, None),
        (30, tip, {"l": (0.33, 0.04, 1.5)}, None),
        (38, P(head=[("Y", 2.0)]), {"l": (0.5, -0.06, 1.0)}, None),
    ], hold=True)


# Each kid's own clips (attack, cheer, idle, run where it shows).
OWN = {
    "leo": {"Leo_Attack": Clip(leo_attack, contact=3), "Leo_Idle": Clip(leo_idle, cyclic=True),
            "Leo_Look": Clip(leo_look), "Leo_Scratch": Clip(leo_scratch), "Leo_Stick": Clip(leo_stick)},
    "nela": {"Nela_Attack": Clip(nela_attack, contact=3), "Nela_Idle": Clip(nela_idle, cyclic=True),
             "Nela_Look": Clip(nela_look), "Nela_Stretch": Clip(nela_stretch), "Nela_Hair": Clip(nela_hair)},
}
# The shared set, keyed once per kid with that kid's Style.
SHARED = {
    "Hero_Walk": Clip(walk, cyclic=True, gait="walk"),
    "Hero_Run": Clip(run, cyclic=True, gait="run"),
}


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
        if clip.gait is not None:
            stride = getattr(style, clip.gait).stride
            record[name]["stride"] = stride
            line += ", stride %.3f m (%.3f m/s at model scale 1)" % (stride, stride / seconds)
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
