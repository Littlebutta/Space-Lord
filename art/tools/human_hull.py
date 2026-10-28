"""Human hull, armor and storage parts. Each builder gets the Interior
and Exterior Parts plus the centred footprint (metres, front is -z) and
returns its lamps as [(pos, colour)]. Equipment keeps to the module's
blocked cells; see the comment on each builder."""
from human_style import C, FLOOR, ROOF, floor, pipe, vent, bolts, screen


def _outer_edges(pts):
    """Edges not on the bounding box: the slanted outer hull side."""
    xs = [x for x, _ in pts]
    zs = [z for _, z in pts]
    out = []
    for k, a in enumerate(pts):
        b = pts[(k + 1) % len(pts)]
        flat = (a[0] == b[0] and a[0] in (min(xs), max(xs))) or \
               (a[1] == b[1] and a[1] in (min(zs), max(zs)))
        if not flat:
            out.append((a, b))
    return out


def _bulkhead(i, pts, h=0.9):
    """Hull wall with ribs and a porthole along the slanted outer side."""
    for a, b in _outer_edges(pts):
        i.wall(a, b, 0.0, h, 0.16, C["hull"], 0.03)
        i.wall(a, b, 0.0, 0.18, 0.24, C["steel"], 0.02)  # kick plate
        i.wall(a, b, h - 0.1, h, 0.24, C["accent"], 0.02)
        d = ((b[0] - a[0]), (b[1] - a[1]))
        n = max(int((d[0] ** 2 + d[1] ** 2) ** 0.5 / 0.7), 1)
        for k in range(1, n):
            t = k / n
            x, z = a[0] + d[0] * t, a[1] + d[1] * t
            i.box((x, h / 2, z), (0.12, h, 0.12), C["steel"], 0.02)


def hull(i, e, pts):
    floor(i, pts, grates=[(0, 0)] if len(pts) == 4 else [])
    _bulkhead(i, pts)
    if len(pts) == 4:
        vent(e, (0, ROOF + 0.02, 0), 0.7, 0.5)
    return []


def armor(i, e, pts):
    floor(i, pts)
    _bulkhead(i, pts, 1.1)
    for x, z in pts if len(pts) == 4 else []:  # heavy corner braces
        i.box((x * 0.82, 0.5, z * 0.82), (0.25, 1.0, 0.25), C["gun"], 0.04)
        i.box((x * 0.82, 1.02, z * 0.82), (0.3, 0.05, 0.3), C["hazard"], 0.01)
    k = [(x * 0.8, z * 0.8) for x, z in pts]
    e.slab(k, ROOF, ROOF + 0.12, C["steel"], 0.04)
    bolts(e, k, ROOF + 0.12, 0.12)
    return []


def fuel_tank(i, e, pts):
    """Blocked: z in [-1, 2]; crew stand at the valve, z = -1.5."""
    floor(i, pts, grates=[(-1, -2), (0, -2)])
    for z in (-0.6, 1.5):  # cradles
        i.box((0, 0.35, z), (1.8, 0.7, 0.22), C["steel"], 0.04)
        i.box((0, 0.05, z), (1.95, 0.1, 0.4), C["gun"], 0.02)
    rings = []
    for z, r in ((-0.95, 0.35), (-0.85, 0.65), (-0.7, 0.8), (1.6, 0.8), (1.75, 0.65), (1.85, 0.35)):
        rings.append((z, [(r * _c(k), 0.95 + r * _s(k)) for k in range(16)]))
    i.loft(rings, C["hazard"])
    for z in (-0.2, 0.5, 1.2):
        i.cyl((0, 0.95, z), 0.83, 0.1, C["gun"], "z", 16, bevel=0.01)
    pipe(i, (0, 0.95, -0.95), (0, 0.95, -1.1), 0.09)
    pipe(i, (0.55, 0.3, -1.1), (0.55, 1.3, -1.1), 0.06)
    i.cyl((0, 0.95, -1.15), 0.22, 0.05, C["red"], "z", 12, bevel=0.01)  # valve
    screen(i, (-0.6, 1.2, -1.05), 0.35, 0.25, col="amber")
    e.cyl((0, ROOF + 0.1, 0.4), 0.3, 0.2, C["gun"], bevel=0.02)
    e.cyl((0, ROOF + 0.22, 0.4), 0.2, 0.05, C["hazard"], bevel=0.01)
    return [((0, 2.2, -1.4), C["lamp"])]


def ammo_rack(i, e, pts):
    """Blocked: z in [-1, 0]; crew load from z = 0.5."""
    floor(i, pts)
    i.box((0, 0.7, -0.92), (1.9, 1.4, 0.12), C["steel"], 0.03)  # back frame
    for x in (-0.9, 0.0, 0.9):
        i.box((x, 0.7, -0.5), (0.08, 1.4, 0.9), C["gun"], 0.02)
    for y in (0.25, 0.65, 1.05):
        i.box((0, y - 0.12, -0.5), (1.85, 0.04, 0.85), C["steel"], 0.01)
        for k in range(4):
            x = -0.68 + k * 0.45 if k < 2 else -0.68 + k * 0.45 + 0.02
            i.cyl((x * 0.95, y, -0.45), 0.09, 0.6, C["brass"], "z", 10)
            i.cyl((x * 0.95, y, -0.8), 0.09, 0.12, C["red"], "z", 10, r2=0.02)
    i.box((0, 1.45, -0.5), (1.9, 0.06, 0.95), C["hazard"], 0.01)
    e.box((0, ROOF + 0.04, 0), (1.0, 0.08, 1.0), C["gun"], 0.03)
    return []


def cargo_hold(i, e, pts):
    """Blocked: x<-1 with z<0 or z>1; x>1 with z<-1 or z>0."""
    floor(i, pts, grates=[(0, 0), (-1, -1)])
    stacks = [(-1.5, -1.5, 2), (-1.5, -0.5, 1), (-1.5, 1.5, 2), (1.5, -1.5, 2),
              (1.5, 0.5, 1)]
    for x, z, n in stacks:
        for k in range(n):
            _crate(i, x, 0.42 + k * 0.84, z, C["crate"] if (x + k) % 2 else C["crate2"])
    for dx, dz in ((-0.22, -0.22), (0.22, -0.22), (-0.22, 0.22), (0.22, 0.22)):
        i.cyl((1.5 + dx, 0.5, 1.5 + dz), 0.2, 0.9, C["red"], sides=12, bevel=0.015)
        i.cyl((1.5 + dx, 0.6, 1.5 + dz), 0.205, 0.05, C["gun"], sides=12)
    i.box((1.5, 0.03, 1.5), (0.95, 0.06, 0.95), C["crate2"], 0.01)  # pallet
    for x in (-0.6, 0.6):
        i.box((x, FLOOR + 0.004, 0), (0.08, 0.01, 2.0), C["hazard"])
    e.box((0, ROOF + 0.05, 0), (2.6, 0.1, 2.6), C["steel"], 0.04)
    e.box((0, ROOF + 0.11, 0), (0.08, 0.04, 2.5), C["gun"])
    return [((0, 2.2, 0), C["lamp"])]


def _crate(p, x, y, z, col):
    p.box((x, y, z), (0.82, 0.82, 0.82), col, 0.03)
    for dx in (-0.39, 0.39):
        p.box((x + dx, y, z), (0.06, 0.84, 0.84), C["steel"], 0.01)
    p.box((x, y, z - 0.415), (0.3, 0.12, 0.01), C["white"])  # label


def _c(k):
    import math
    return math.cos(k / 16 * 2 * math.pi)


def _s(k):
    import math
    return math.sin(k / 16 * 2 * math.pi)


def airlock(i, e, pts):
    """Blocked: x < 0 (suit lockers), so crew can come in from any other
    side; the floor hatch at x = 0.5 is where they step out."""
    floor(i, pts)
    for z in (-0.5, 0.5):  # suit lockers with hanging EVA suits
        i.box((-0.75, 1.0, z), (0.45, 2.0, 0.9), C["steel"], 0.03)
        i.box((-0.52, 1.0, z), (0.02, 1.85, 0.8), C["gun"])
        i.box((-0.6, 1.15, z), (0.2, 0.6, 0.4), C["white"], 0.06)  # suit
        i.ball((-0.6, 1.6, z), 0.13, C["glass"], 1)  # helmet
        i.box((-0.52, 1.85, z), (0.03, 0.06, 0.5), C["accent"], 0.01)
    i.cyl((0.5, FLOOR + 0.02, 0), 0.55, 0.04, C["hazard"], sides=24, bevel=0.01)
    i.cyl((0.5, FLOOR + 0.04, 0), 0.4, 0.04, C["gun"], sides=24, bevel=0.01)
    for k in range(4):  # hatch dogs
        i.box((0.5 + (-0.3, 0.3, 0, 0)[k], FLOOR + 0.07, (0, 0, -0.3, 0.3)[k]),
              (0.08, 0.03, 0.08), C["metal"], 0.01)
    screen(i, (0.5, 1.2, -0.95), 0.4, 0.3, col="amber")
    e.cyl((0.4, ROOF + 0.06, 0), 0.6, 0.12, C["gun"], sides=24, bevel=0.03)
    e.cyl((0.4, ROOF + 0.13, 0), 0.5, 0.04, C["hazard"], sides=24)
    e.ball((0.7, ROOF + 0.1, -0.7), 0.06, C["amber"], 1, glow=True)
    return [((0.4, 2.1, 0), C["amber"])]
