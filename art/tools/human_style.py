"""Human theme palette and shared detail helpers.

Every module is two meshes: "Interior" (floor plating and equipment on
the game's shared hull deck, which crew walk on) and "Exterior"
(greebles on top of the ship's hull shell, which the game builds as one
continuous piece; see hull_shell.gd). Model origin = top of the deck.
Equipment must stay inside the module's `blocked` areas (module .tres)
so crew never walk through it. Crew are about 1.75 m tall.
"""
FLOOR = 0.03  # top of the floor plating
ROOF = 2.4  # top of the hull shell, where exterior greebles sit (HullShell.HEIGHT)

C = {
    "hull": "#a3a9b1", "steel": "#7c838d", "gun": "#4d525a",
    "dark": ("#2a2c30", "rubber"), "metal": ("#8a8d92", "metal"),
    "brass": ("#9a7448", "metal"), "hazard": "#c9971f", "red": "#9c3328",
    "white": "#cfc9bb", "accent": ("#ffffff", "accent"),
    "glass": ("#28414d", "glass"), "screen": "#3fd6c8", "amber": "#ffab3d",
    "lamp": "#ffe1b0", "power": "#59c8ff", "crate": ("#5f6648", "crate"), "crate2": ("#7a5a3a", "crate"),
    "cloth": ("#59606a", "fabric"), "sheet": ("#9a9a92", "fabric"),
    "plate": ("#6a7078", "metal"), "grate": ("#43474d", "metal"),
}


def poly(outline, size):
    """Outline in cells (or the full rect) -> centred metres (x, z)."""
    sx, sy = size
    if not outline:
        outline = [(0, 0), (sx, 0), (sx, sy), (0, sy)]
    return [((u - sx / 2) * 2, (v - sy / 2) * 2) for u, v in outline]


def floor(p, pts, grates=()):
    """Metre-square deck plates with thin seams; grates are (x, z) tiles
    drawn as slatted grilles instead. Odd shapes get one shaped plate."""
    xs = sorted({x for x, _ in pts})
    zs = sorted({z for _, z in pts})
    if len(pts) != 4:
        p.slab(_shrink(pts, 0.04), 0.0, FLOOR, C["plate"], 0.01)
        return
    for x in range(int(xs[0]), int(xs[-1])):
        for z in range(int(zs[0]), int(zs[-1])):
            c = (x + 0.5, FLOOR / 2, z + 0.5)
            if (x, z) in grates:
                p.box(c, (0.96, FLOOR, 0.96), C["grate"], 0.01)
                for k in range(5):
                    p.box((c[0], FLOOR + 0.005, z + 0.15 + k * 0.175),
                          (0.86, 0.012, 0.06), C["metal"])
            else:
                p.box(c, (0.96, FLOOR, 0.96), C["plate"], 0.012)


def screen(p, c, w, h, face="z", col="screen"):
    """Wall/desk display: dark bezel with a glowing panel facing -face."""
    t = (w, h, 0.06) if face == "z" else (0.06, h, w)
    p.box(c, t, C["gun"], 0.015)
    off = (0, 0, -0.035) if face == "z" else (-0.035, 0, 0)
    g = (w - 0.08, h - 0.08, 0.01) if face == "z" else (0.01, h - 0.08, w - 0.08)
    p.box(tuple(a + b for a, b in zip(c, off)), g, C[col], glow=True)


def pipe(p, a, b, r, col="brass", flanges=True):
    """Straight pipe from a to b (Godot points differing on one axis)."""
    axis = "xyz"[[abs(a[k] - b[k]) > 1e-6 for k in range(3)].index(True)]
    mid = tuple((a[k] + b[k]) / 2 for k in range(3))
    n = abs(a["xyz".index(axis)] - b["xyz".index(axis)])
    p.cyl(mid, r, n, C[col], axis, 10)
    if flanges:
        for e in (a, b):
            p.cyl(e, r * 1.5, 0.05, C["gun"], axis, 10, bevel=0.01)


def vent(p, c, w, d):
    """Floor or roof vent: frame with dark slats, lying flat at c."""
    p.box(c, (w, 0.05, d), C["steel"], 0.015)
    for k in range(int(d / 0.12)):
        z = c[2] - d / 2 + 0.1 + k * 0.12
        p.box((c[0], c[1] + 0.02, z), (w - 0.1, 0.03, 0.05), C["dark"])


def bolts(p, pts, y, inset=0.18):
    """Bolt heads near each corner of a footprint."""
    for x, z in _shrink(pts, inset):
        p.cyl((x, y, z), 0.035, 0.03, C["metal"], sides=6, smooth=False)


def _shrink(pts, d):
    """Moves every point d metres toward the polygon centre."""
    cx = sum(x for x, _ in pts) / len(pts)
    cz = sum(z for _, z in pts) / len(pts)
    out = []
    for x, z in pts:
        dx, dz = cx - x, cz - z
        n = max((dx * dx + dz * dz) ** 0.5, 1e-6)
        out.append((x + dx / n * d, z + dz / n * d))
    return out


def console(p, x, z, to, w=0.6, col="screen"):
    """Standing control desk at (x, z) for a crew member standing on its
    `to` side ((dx, dz) unit step): pedestal, lit keyboard shelf at hand
    height and a screen at eye level. Keep it inside a blocked cell."""
    dx, dz = to
    size = lambda a, h, d: (a, h, d) if dz else (d, h, a)  # noqa: E731
    p.box((x, 0.45, z), size(w, 0.9, 0.32), C["steel"], 0.03)
    p.box((x + dx * 0.1, 0.93, z + dz * 0.1), size(w + 0.04, 0.05, 0.36), C["gun"], 0.015)
    for k in range(4):  # key rows and buttons
        o = -w / 2 + 0.1 + k * (w - 0.2) / 3
        kx, kz = (x + o, z + dz * 0.16) if dz else (x + dx * 0.16, z + o)
        p.box((kx, 0.965, kz), size(0.1, 0.02, 0.06), C[col if k % 2 else "amber"], glow=True)
    sx, sz = x - dx * 0.08, z - dz * 0.08
    p.box((sx, 1.3, sz), size(w - 0.04, 0.42, 0.05), C["gun"], 0.015)
    p.box((sx + dx * 0.03, 1.3, sz + dz * 0.03), size(w - 0.12, 0.34, 0.01), C[col], glow=True)


FILLS = {}  # stock level k (1..4) -> Part, built by build_human.py


def fill(k):
    """Part for stock that shows once storage is about k quarters full:
    the game shows "Fill1".."Fill4" as the hold fills (ShipFx)."""
    import kit
    if k not in FILLS:
        FILLS[k] = kit.Part("Fill%d" % k)
    return FILLS[k]
