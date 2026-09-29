"""Shared helpers for hand-keyed clips on the KayKit Skeleton_Minion rig
(the Bramble Beast, feature 026; the Mushroom Gremlin, feature 027).

Poses are written as rotations in the rig's rest axes (X = the
creature's left, Y = its back, Z = up; it faces -Y). Each bone takes a
list of (axis, degrees) applied in order, so ("Y", 68) then ("X", -20)
means "lower the arm, then swing it forward". Useful signs:
- spine / chest / head:  +X bends forward, +Y leans to its left,
  +Z turns it to its left;
- upperarm.l:  +Y lowers the arm, -X swings a hanging arm forward;
- upperarm.r:  -Y lowers the arm, -X swings it forward;
- lowerarm.l / .r:  -Z / +Z bends the elbow forward;
- upperleg:  -X swings the leg forward;  lowerleg: +X bends the knee.
Locations (hips, root) are offsets in metres in the same axes.

Every clip keys every deform bone, so none inherits another's pose. The
timings are authored at 24 fps and scaled to the scene rate."""

import math

import bpy  # noqa: F401
from mathutils import Quaternion, Vector

BONES = ("root", "hips", "spine", "chest", "head",
         "upperarm.l", "lowerarm.l", "wrist.l", "hand.l", "upperarm.r", "lowerarm.r", "wrist.r", "hand.r",
         "upperleg.l", "lowerleg.l", "foot.l", "toes.l", "upperleg.r", "lowerleg.r", "foot.r", "toes.r")
MOVABLE = ("root", "hips")


# ------------------------------------------------------------- poses


class Pose:
    def __init__(self, rot=None, loc=None):
        self.rot = {b: list(v) for b, v in (rot or {}).items()}
        self.loc = {b: Vector(v) for b, v in (loc or {}).items()}

    def __add__(self, other):
        out = Pose(self.rot, self.loc)
        for b, v in other.rot.items():
            out.rot.setdefault(b, []).extend(v)
        for b, v in other.loc.items():
            out.loc[b] = out.loc.get(b, Vector()) + v
        return out

    def mirrored(self):
        """Left <-> right (reflect across the X = 0 plane)."""
        def swap(name):
            if name.endswith(".l"):
                return name[:-2] + ".r"
            if name.endswith(".r"):
                return name[:-2] + ".l"
            return name
        out = Pose()
        for b, v in self.rot.items():
            out.rot[swap(b)] = [(a, d if a == "X" else -d) for a, d in v]
        for b, v in self.loc.items():
            out.loc[swap(b)] = Vector((-v.x, v.y, v.z))
        return out


def P(loc=None, **rot):
    """P(upperarm_l=[("Y", 68)], loc={"hips": (0, 0, -0.1)})."""
    return Pose({k.replace("_l", ".l").replace("_r", ".r"): v for k, v in rot.items()}, loc)


def arms(down=58.0, swing_l=0.0, swing_r=0.0, elbow_l=18.0, elbow_r=18.0, out_l=0.0, out_r=0.0):
    """Both arms: lowered by `down` (minus `out`), swung forward by
    `swing` (degrees, + = forward), elbows bent forward."""
    return P(upperarm_l=[("Y", down - out_l), ("X", -swing_l)], upperarm_r=[("Y", -(down - out_r)), ("X", -swing_r)],
             lowerarm_l=[("Z", -elbow_l)], lowerarm_r=[("Z", elbow_r)])


def legs(swing_l=0.0, swing_r=0.0, knee_l=0.0, knee_r=0.0, wide=5.0, foot_l=0.0, foot_r=0.0):
    """Legs swung forward by `swing`, knees bent by `knee`; the feet are
    turned back toward flat by `foot` (+ = toes up)."""
    return P(upperleg_l=[("Y", -wide), ("X", -swing_l)], upperleg_r=[("Y", wide), ("X", -swing_r)],
             lowerleg_l=[("X", knee_l)], lowerleg_r=[("X", knee_r)],
             foot_l=[("X", -foot_l)], foot_r=[("X", -foot_r)])


def torso(spine=8.0, chest=4.0, head=-10.0, roll=0.0, twist=0.0, hips_z=0.0, hips_x=0.0, hips_y=0.0):
    """Hunched torso; roll leans to its left (+), twist turns the chest."""
    return P(spine=[("X", spine), ("Y", roll)], chest=[("X", chest), ("Z", twist)], head=[("X", head), ("Y", -roll * 0.6)],
             loc={"hips": (hips_x, hips_y, hips_z)})



# ------------------------------------------------------------ keying


def key(rig, frame, pose, last):
    fps = bpy.context.scene.render.fps
    frame = frame * fps / 24.0
    for name in BONES:
        pb = rig.pose.bones.get(name)
        if pb is None:
            continue
        rest = pb.bone.matrix_local.to_quaternion()
        q = Quaternion()
        for axis, deg in pose.rot.get(name, []):
            vec = {"X": (1, 0, 0), "Y": (0, 1, 0), "Z": (0, 0, 1)}[axis]
            q = Quaternion(vec, math.radians(deg)) @ q
        local = rest.inverted() @ q @ rest
        if name in last and last[name].dot(local) < 0:
            local.negate()
        last[name] = local
        pb.rotation_mode = "QUATERNION"
        pb.rotation_quaternion = local
        pb.keyframe_insert("rotation_quaternion", frame=frame, group=name)
        if name in MOVABLE:
            pb.location = rest.inverted() @ pose.loc.get(name, Vector())
            pb.keyframe_insert("location", frame=frame, group=name)


def action(rig, name, keys, cyclic=False):
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    rig.animation_data_create()
    rig.animation_data.action = action
    last = {}   # keeps quaternions on one hemisphere so curves never flip
    for frame, pose in keys:
        key(rig, frame, pose, last)
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
    if cyclic:
        for fc in action.fcurves:
            fc.modifiers.new("CYCLES")
    return action


def build_actions(rig, clips, default):
    """Removes the rig's stock clips and keys `clips` ({name: (fn,
    cyclic)}), leaving `default` active and the pose at rest."""
    rig.animation_data_create()
    rig.animation_data.action = None
    for old in list(bpy.data.actions):
        bpy.data.actions.remove(old)
    for name, (fn, cyclic) in clips.items():
        action(rig, name, fn(), cyclic)
    rig.animation_data.action = bpy.data.actions[default]
    for pb in rig.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
