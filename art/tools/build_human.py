"""Builds every Human module, exports one .glb each and saves the .blend.

Run from the repo root:
  blender -b --factory-startup --python art/tools/build_human.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import bpy  # noqa: E402
import kit  # noqa: E402
import human_hull as hh  # noqa: E402
import human_systems as hs  # noqa: E402
from human_style import poly  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "models", "human")
CURVE = [(0, 2), (0, 0), (0.61, 0.09), (1.17, 0.34), (1.62, 0.76), (1.91, 1.33), (2, 2)]
SLOPE = [(0, 0), (0, 1), (1, 1)]

# module id: (size in cells, outline or None, builder)
PARTS = {
    "hull": ((1, 1), None, hh.hull),
    "hull_slope": ((1, 1), SLOPE, hh.hull),
    "hull_wedge": ((1, 2), [(0, 0), (0, 2), (1, 2)], hh.hull),
    "hull_curve": ((2, 2), CURVE, hh.hull),
    "armor": ((1, 1), None, hh.armor),
    "armor_slope": ((1, 1), SLOPE, hh.armor),
    "fuel_tank": ((1, 2), None, hh.fuel_tank),
    "ammo_rack": ((1, 1), None, hh.ammo_rack),
    "cargo_hold": ((2, 2), None, hh.cargo_hold),
    "bridge": ((2, 2), None, hs.bridge),
    "cannon": ((1, 3), None, hs.cannon),
    "turret": ((2, 2), None, hs.turret),
    "engine": ((1, 2), None, hs.engine),
    "crew_quarters": ((2, 2), None, hs.crew_quarters),
}


def build(mid, mats):
    size, outline, fn = PARTS[mid]
    root = kit.empty(mid)
    inner, outer = kit.Part("Interior"), kit.Part("Exterior")
    lamps = fn(inner, outer, poly(outline, size))
    inner.build(mats, root)
    outer.build(mats, root)
    if mid == "turret":
        head = kit.Part("Head")
        hs.turret_head(head)
        head.build(mats, root)
    for k, (pos, col) in enumerate(lamps):
        kit.lamp("Lamp%d" % k, pos, col, root)
    return root


def main():
    kit.reset()
    mats = kit.materials()
    os.makedirs(OUT, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    x = 0.0
    for mid in PARTS:
        if only and mid not in only:
            continue
        root = build(mid, mats)
        kit.export(root, os.path.join(OUT, mid + ".glb"))
        root.location.x = x  # spread out in the .blend for browsing
        x += PARTS[mid][0][0] * 2 + 2
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "human_modules.blend"))


main()
