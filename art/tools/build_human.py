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
from human_style import poly, ROOF, FILLS  # noqa: E402

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
    "mining_laser": [("Muzzle0", (0, ROOF + 0.55, -2.15))],
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
    "mining_laser": ((2, 2), None, hs.mining_laser),
    "repair_bay": ((2, 1), None, hs.repair_bay),
    "wing": ((3, 2), [(0, 0), (0.8, 0), (3, 1.4), (3, 2), (0, 2)], hx.wing),
    "wing_stub": ((2, 1), [(0, 0), (1.2, 0.2), (2, 0.7), (2, 1), (0, 1)], hx.wing_stub),
    "fin": ((1, 2), None, hx.fin),
    "antenna": ((1, 1), None, hx.antenna),
    "sensor_mast": ((1, 1), None, hx.sensor_mast),
}

# Bigger tiers: the base part stretched over the larger footprint (heights
# kept, so crew fit) under a raised, stepped housing; see build().
TIERS = {t: base for base in ("engine", "fuel_tank", "cargo_hold", "cannon", "turret")
         for t in (base + "_t2", base + "_t3")}
RAISE = {"_t2": 0.45, "_t3": 0.85}  # how much taller the outside housing is
PARTS["teleporter"] = ((2, 2), None, hs.teleporter)
PARTS["breach_pod"] = ((2, 3), None, hs.breach_pod)


def _tres(mid):
    """(size, outline) of a module from its .tres in the game data."""
    path = os.path.join(ROOT, "godot", "data", "modules", mid + ".tres")
    size, outline = (1, 1), None
    for line in open(path):
        if line.startswith("size = Vector2i("):
            size = tuple(int(v) for v in line[16:-2].split(","))
        if line.startswith("outline = PackedVector2Array("):
            v = [float(x) for x in line[29:-2].split(",")]
            outline = list(zip(v[0::2], v[1::2]))
    return size, outline


for _m in ("armor_bevel", "armor_block", "armor_curve", "armor_half", "armor_wedge",
           "armor_wedge_wide"):  # new armor pieces from the game data
    PARTS[_m] = _tres(_m) + (hh.armor,)
for _t, _b in TIERS.items():
    PARTS[_t] = (_tres(_t)[0], None, PARTS[_b][2])


def build(mid, mats, decor=None):
    size, outline, fn = PARTS[mid]
    root = kit.empty(mid)
    key, sx, sz, up = mid, 1.0, 1.0, 0.0
    if mid in TIERS:  # build the base part, then stretch it to this size
        key = TIERS[mid]
        base = PARTS[key][0]
        sx, sz, up = size[0] / base[0], size[1] / base[1], RAISE[mid[-3:]]
        size = base
    outside = fn.__module__ == "human_exterior"  # one mesh, shown in both views
    inner, outer = kit.Part("Body" if outside else "Interior"), kit.Part("Exterior")
    own = decor and decor["replace"] and not outside  # faction's own outside
    lamps = fn(inner, kit.Part("Unused") if own else outer, poly(outline, size))
    if decor and not outside:
        decor["ext"](key, outer, poly(outline, size))
    extras = []
    if decor and decor["extra"]:  # e.g. Bio tentacles, the game animates them
        decor["extra"](key, lambda name: extras.append(kit.Part(name)) or extras[-1])
    for p in [inner] + extras + [FILLS[k] for k in FILLS]:
        p.stretch(sx, sz)
    outer.stretch(sx, sz, up)
    if mid in TIERS and not own:
        _housing(outer, poly(None, PARTS[mid][0]), up)
    for x in extras:
        x.build(mats, root)
    inner.build(mats, root)
    outer.build(mats, root)
    for k in sorted(FILLS):  # stock that shows as storage fills
        FILLS[k].build(mats, root)
    FILLS.clear()
    head = None
    heads = {"turret": hs.turret_head, "mining_laser": hs.mining_head}
    if key in heads:  # a turning head the game aims; markers ride on it
        head = kit.Part("Head")
        if decor and decor["head"]:
            decor["head"](key, head)
        else:
            heads[key](head)
        head.stretch(sx, sz, up)
        head = head.build(mats, root)
    for name, (x, y, z) in MARKERS.get(key, []):
        kit.empty(name, (x * sx, y + up, z * sz), head or root)
    for k, ((x, y, z), col) in enumerate(lamps):
        kit.lamp("Lamp%d" % k, (x * sx, y, z * sz), col, root)
    return root


def _housing(e, pts, up):
    """A bigger tier's raised outside housing: two bevelled steps over the
    hull top, inside its chamfer, so the part stands proud of the ship
    without looking like a box."""
    from human_style import C, ROOF, _shrink
    lo = _shrink(pts, 0.9)
    hi = _shrink(pts, 0.9 + up * 0.8)
    e.slab(lo, ROOF - 0.05, ROOF + up * 0.55, C["hull"], 0.15)
    e.slab(_shrink(lo, 0.05), ROOF + up * 0.45, ROOF + up * 0.5, C["accent"])
    e.slab(hi, ROOF + up * 0.5, ROOF + up, C["steel"], 0.12)


def main(out=OUT, blend="human_modules.blend", decor=None):
    kit.reset()
    mats = kit.materials()
    os.makedirs(out, exist_ok=True)
    only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    x = 0.0
    for mid in PARTS:
        if only and mid not in only:
            continue
        root = build(mid, mats, decor)
        kit.export(root, os.path.join(out, mid + ".glb"))
        root.location.x = x  # spread out in the .blend for browsing
        x += PARTS[mid][0][0] * 2 + 2
    if not only:  # a partial build would overwrite the full .blend
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", blend))


if __name__ == "__main__":
    main()
