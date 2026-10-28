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
import human_exterior as hx  # noqa: E402
from human_style import poly, ROOF  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "godot", "assets", "models", "human")
CURVE = [(0, 2), (0, 0), (0.61, 0.09), (1.17, 0.34), (1.62, 0.76), (1.91, 1.33), (2, 2)]
SLOPE = [(0, 0), (0, 1), (1, 1)]

# FX markers (empties) the game hangs effects on: muzzles fire forward
# (-z), nozzles blow backward (+z). Turret muzzles ride on its Head.
MARKERS = {
    "cannon": [("Muzzle0", (0, ROOF + 0.35, -3.35))],
    "turret": [("Muzzle0", (-0.45, ROOF + 0.85, -2.7)), ("Muzzle1", (0.45, ROOF + 0.85, -2.7))],
    "engine": [("Nozzle0", (0, ROOF - 0.9, 2.7))],
}

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
    "airlock": ((1, 1), None, hh.airlock),
    "supply_depot": ((2, 2), None, hh.supply_depot),
    "shipdock": ((3, 2), None, hs.shipdock),
    "generator": ((2, 2), None, hs.generator),
    "capacitor": ((1, 1), None, hs.capacitor),
    "wing": ((3, 2), [(0, 0), (0.8, 0), (3, 1.4), (3, 2), (0, 2)], hx.wing),
    "wing_stub": ((2, 1), [(0, 0), (1.2, 0.2), (2, 0.7), (2, 1), (0, 1)], hx.wing_stub),
    "fin": ((1, 2), None, hx.fin),
    "antenna": ((1, 1), None, hx.antenna),
    "sensor_mast": ((1, 1), None, hx.sensor_mast),
}


def build(mid, mats):
    size, outline, fn = PARTS[mid]
    root = kit.empty(mid)
    outside = fn.__module__ == "human_exterior"  # one mesh, shown in both views
    inner, outer = kit.Part("Body" if outside else "Interior"), kit.Part("Exterior")
    lamps = fn(inner, outer, poly(outline, size))
    inner.build(mats, root)
    outer.build(mats, root)
    head = None
    if mid == "turret":
        head = kit.Part("Head")
        hs.turret_head(head)
        head = head.build(mats, root)
    for name, pos in MARKERS.get(mid, []):
        kit.empty(name, pos, head or root)
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
    if not only:  # a partial build would overwrite the full .blend
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "human_modules.blend"))


main()
