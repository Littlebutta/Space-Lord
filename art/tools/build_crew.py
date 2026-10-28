"""Human crew member: 1.75 m body (crew_body.py), 11-bone rig and
idle/walk/work loops.

  blender -b --factory-startup --python art/tools/build_crew.py

Every body part is weighted to exactly one bone (rigid skinning), which
keeps the mesh small and cheap to animate for big crews.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import kit  # noqa: E402
from crew_body import BONES, RACES, body, headpiece, race, suit  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))


def rig():
    arm = bpy.data.armatures.new("Rig")
    ob = bpy.data.objects.new("Crew", arm)
    bpy.context.scene.collection.objects.link(ob)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, h, t in BONES:
        b = arm.edit_bones.new(name)
        b.head = (h[0], -h[2], h[1])
        b.tail = (t[0], -t[2], t[1])
        b.roll = 0.0
        if parent:
            b.parent = arm.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


# action: (frames, {bone: [(frame, (x, y, z) degrees)]}, hip bob metres)
def _swing(a, b, n):
    return [(0, a), (n // 2, b), (n, a)]


ANIMS = {
    "carry": (16, {  # walking with a load held at the chest
        "thigh.R": _swing((32, 0, 0), (-32, 0, 0), 16),
        "thigh.L": _swing((-32, 0, 0), (32, 0, 0), 16),
        "shin.R": [(0, (-8, 0, 0)), (4, (-40, 0, 0)), (8, (0, 0, 0)), (16, (-8, 0, 0))],
        "shin.L": [(0, (0, 0, 0)), (8, (-8, 0, 0)), (12, (-40, 0, 0)), (16, (0, 0, 0))],
        "arm.R": _swing((30, 0, 14), (33, 0, 14), 16),
        "arm.L": _swing((33, 0, -14), (30, 0, -14), 16),
        "hand.R": _swing((75, 0, 0), (72, 0, 0), 16),
        "hand.L": _swing((72, 0, 0), (75, 0, 0), 16),
        "spine": _swing((3, 3, 0), (3, -3, 0), 16),
    }, 0.02),
    "float": (72, {  # drifting in a suit, limbs loose, slow sway
        "arm.R": _swing((15, 0, 28), (5, 0, 34), 72),
        "arm.L": _swing((5, 0, -34), (15, 0, -28), 72),
        "hand.R": _swing((25, 0, 0), (40, 0, 0), 72),
        "hand.L": _swing((40, 0, 0), (25, 0, 0), 72),
        "thigh.R": _swing((20, 0, 6), (8, 0, 9), 72),
        "thigh.L": _swing((8, 0, -9), (20, 0, -6), 72),
        "shin.R": _swing((-35, 0, 0), (-20, 0, 0), 72),
        "shin.L": _swing((-20, 0, 0), (-35, 0, 0), 72),
        "spine": _swing((-6, 0, -3), (-2, 0, 3), 72),
        "head": _swing((-8, 6, 0), (-4, -6, 0), 72),
    }, 0.0),
    "idle": (48, {
        "spine": _swing((0, 0, 0), (-2, 0, 0), 48),
        "head": _swing((0, 0, -4), (-2, 0, 4), 48),
        "arm.R": _swing((0, 0, 4), (4, 0, 7), 48),
        "arm.L": _swing((0, 0, -4), (4, 0, -7), 48),
    }, 0.01),
    "walk": (16, {
        "thigh.R": _swing((40, 0, 0), (-40, 0, 0), 16),
        "thigh.L": _swing((-40, 0, 0), (40, 0, 0), 16),
        "shin.R": [(0, (-10, 0, 0)), (4, (-50, 0, 0)), (8, (0, 0, 0)), (16, (-10, 0, 0))],
        "shin.L": [(0, (0, 0, 0)), (8, (-10, 0, 0)), (12, (-50, 0, 0)), (16, (0, 0, 0))],
        "arm.R": _swing((-35, 0, 6), (35, 0, 6), 16),
        "arm.L": _swing((35, 0, -6), (-35, 0, -6), 16),
        "hand.R": _swing((25, 0, 0), (8, 0, 0), 16),
        "hand.L": _swing((8, 0, 0), (25, 0, 0), 16),
        "spine": _swing((-6, 4, 0), (-6, -4, 0), 16),
    }, 0.03),
    "work": (48, {  # typing at a console shelf, now and then a screen tap
        "arm.R": [(0, (28, 0, 10)), (12, (31, 0, 10)), (24, (28, 0, 10)),
                  (30, (55, 0, 6)), (36, (58, 0, 6)), (42, (28, 0, 10)), (48, (28, 0, 10))],
        "hand.R": [(0, (70, 0, 0)), (6, (62, 0, 0)), (12, (72, 0, 0)), (18, (62, 0, 0)),
                   (24, (70, 0, 0)), (30, (40, 0, 0)), (36, (38, 0, 0)), (42, (70, 0, 0)),
                   (48, (70, 0, 0))],
        "arm.L": _swing((30, 0, -10), (27, 0, -10), 48),
        "hand.L": [(k * 6, ((64, 0, 0) if k % 2 else (73, 0, 0))) for k in range(9)],
        "spine": _swing((-7, 0, 0), (-9, 2, 0), 48),
        "head": [(0, (-16, 0, 0)), (24, (-14, 4, 0)), (34, (-4, 6, 0)), (48, (-16, 0, 0))],
    }, 0.0),
}


def animate(ob):
    ob.animation_data_create()
    for name, (n, keys, bob) in ANIMS.items():
        act = bpy.data.actions.new(name)
        ob.animation_data.action = act
        for pb in ob.pose.bones:
            pb.rotation_mode = "XYZ"
            pb.rotation_euler = (0, 0, 0)
            pb.location = (0, 0, 0)
        for bone, frames in keys.items():
            pb = ob.pose.bones[bone]
            for f, rot in frames:
                pb.rotation_euler = [math.radians(r) for r in rot]
                pb.keyframe_insert("rotation_euler", frame=f + 1)
        hips = ob.pose.bones["hips"]
        step = n // 2 if name == "walk" else n
        for f in range(0, n + 1, max(step // 2, 1)):
            hips.location = (0, bob * (0.5 + 0.5 * math.cos(f / step * 2 * math.pi)), 0)
            hips.keyframe_insert("location", frame=f + 1)
        track = ob.animation_data.nla_tracks.new()
        track.name = name
        track.strips.new(name, 1, act)
        ob.animation_data.action = None


def main():
    for name in RACES:
        build(name)


def build(rname):
    """One race's crew model, into that faction's model folder."""
    kit.reset()
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    race(rname)
    mats = kit.materials()
    ob = rig()
    p = kit.Part("CrewBody")
    body(p)
    headpiece(p, rname)
    me_ob = p.build(mats, ob)
    for name, *_ in BONES:
        me_ob.vertex_groups.new(name=name)
    me_ob.modifiers.new("Rig", "ARMATURE").object = ob
    s = kit.Part("CrewSuit")
    suit(s)
    suit_ob = s.build(mats, ob)
    for name, *_ in BONES:
        suit_ob.vertex_groups.new(name=name)
    suit_ob.modifiers.new("Rig", "ARMATURE").object = ob
    animate(ob)
    out = os.path.join(ROOT, "godot", "assets", "models", rname, "crew.glb")
    kit.export(ob, out, export_animations=True,
               export_animation_mode="NLA_TRACKS", export_skins=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "%s_crew.blend" % rname))


main()
