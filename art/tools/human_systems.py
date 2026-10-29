"""Human crewed systems: bridge, weapons, thruster and quarters. Same
builder signature as human_hull. Crew stand at the module's access
spots, so equipment stays inside its blocked cells."""
import math
from human_style import C, FLOOR, ROOF, floor, pipe, vent, screen, console


def _arc(i, r, a0, a1, n, y0, y1, t, col):
    """Wall segments along a circle arc around the module middle."""
    pts = [(math.cos(math.radians(a0 + (a1 - a0) * k / n)) * r,
            math.sin(math.radians(a0 + (a1 - a0) * k / n)) * r) for k in range(n + 1)]
    for a, b in zip(pts, pts[1:]):
        i.wall(a, b, y0, y1, t, col, 0.03)
    return pts


def bridge(i, e, pts):
    """Blocked: front row z < -1 and the side columns |x| > 1 for z < 1.
    Pilots stand at (-0.5, -0.8) and (0.5, -0.8) at their consoles."""
    floor(i, pts, grates=[(-1, 0), (0, 0)])
    _arc(i, 1.8, 200, 340, 6, 0.0, 0.75, 0.3, C["steel"])  # instrument ring
    _arc(i, 1.8, 202, 338, 6, 0.75, 0.8, 0.34, C["accent"])
    for x in (-0.5, 0.5):
        console(i, x, -1.25, (0, 1), 0.7, "screen" if x < 0 else "amber")
    i.box((0, 1.3, -1.93), (3.6, 1.6, 0.1), C["glass"], 0.02)  # viewport
    for x in (-1.8, 1.8):  # viewport frame ends, inside the blocked row
        i.box((x, 1.3, -1.9), (0.14, 1.7, 0.18), C["gun"], 0.02)
    for s in (-1, 1):  # side stations
        i.box((1.55 * s, 0.45, 0.0), (0.7, 0.9, 1.9), C["steel"], 0.04)
        screen(i, (1.45 * s, 1.1, -0.3), 0.6, 0.4, "x", "screen")
        screen(i, (1.45 * s, 1.1, 0.4), 0.5, 0.35, "x", "amber")
        i.box((1.75 * s, 1.5, 0.0), (0.2, 0.06, 1.9), C["accent"], 0.01)
    _canopy(e)
    e.cyl((1.2, ROOF + 0.45, 1.3), 0.03, 0.9, C["metal"], sides=6)
    e.ball((1.2, ROOF + 0.9, 1.3), 0.07, C["red"], 1, glow=True)
    return [((0, 2.1, 0.3), C["lamp"])]


def cannon(i, e, pts):
    """Blocked: x > 0 along the whole length; crew work the breech from
    the aisle at x = -0.3 (z = 0.5 and 1.5) at consoles on its side."""
    floor(i, pts, grates=[(-1, -2), (-1, 0), (-1, 2)])
    i.box((0.55, 0.75, 1.55), (0.8, 1.5, 2.7), C["gun"], 0.06, seg=2)  # breech
    i.box((0.55, 1.52, 1.55), (0.6, 0.06, 2.3), C["hazard"], 0.01)
    for z in (0.5, 1.5):
        console(i, 0.2, z, (-1, 0), 0.6, "amber" if z < 1 else "screen")
    i.cyl((0.5, 1.0, -1.35), 0.24, 3.1, C["steel"], "z", 14, bevel=0.02)
    for z in (-2.9, -2.0, -0.9, 0.1):
        i.cyl((0.5, 1.0, z), 0.32, 0.16, C["gun"], "z", 14, bevel=0.02)
    i.cyl((0.5, 1.0, -2.95), 0.36, 0.35, C["dark"], "z", 14, bevel=0.02)  # muzzle
    for z in (-2.0, -0.7):
        i.box((0.5, 0.45, z), (0.5, 0.9, 0.25), C["steel"], 0.03)
    pipe(i, (0.82, 1.3, -0.8), (0.82, 1.3, 0.2), 0.06, "metal")  # recoil rams
    pipe(i, (0.18, 1.3, -0.8), (0.18, 1.3, 0.2), 0.06, "metal")
    e.box((0, ROOF + 0.3, 1.6), (1.5, 0.6, 2.4), C["hull"], 0.12, seg=2)
    e.cyl((0, ROOF + 0.35, -1.2), 0.28, 4.0, C["steel"], "z", 16, bevel=0.03)
    e.cyl((0, ROOF + 0.35, -3.1), 0.36, 0.4, C["dark"], "z", 16, bevel=0.03)
    e.box((0, ROOF + 0.62, 1.6), (1.2, 0.06, 1.8), C["accent"], 0.02)
    return [((-0.5, 2.1, 1.0), C["lamp"])]


def turret(i, e, pts):
    """Blocked: front row z < -1 and the back corners; gunners stand at
    (+-0.5, -0.8) at their consoles."""
    floor(i, pts, grates=[(-1, -1), (0, -1)])
    for x in (-0.5, 0.5):
        console(i, x, -1.25, (0, 1), 0.7, "screen" if x < 0 else "amber")
    screen(i, (0, 1.4, -1.85), 2.6, 1.0, col="screen")  # targeting wall
    for x in (-1.5, 1.5):
        i.box((x, 0.6, -1.5), (0.9, 1.2, 0.9), C["steel"], 0.05)
    for x in (-1.5, 1.5):  # capacitor banks
        i.cyl((x, 0.8, 1.5), 0.38, 1.6, C["gun"], sides=14, bevel=0.03)
        for y in (0.4, 0.8, 1.2):
            i.cyl((x, y, 1.5), 0.4, 0.06, C["brass"], sides=14)
        i.cyl((x, 1.62, 1.5), 0.25, 0.06, C["amber"], sides=14, glow=True)
    i.cyl((0, FLOOR + 0.01, 0.2), 1.0, 0.02, C["hazard"], sides=32, smooth=False)
    i.cyl((0, FLOOR + 0.015, 0.2), 0.92, 0.02, C["plate"], sides=32, smooth=False)
    e.cyl((0, ROOF + 0.15, 0), 1.3, 0.3, C["steel"], sides=24, bevel=0.04)
    return [((0, 2.1, 0.2), C["lamp"])]


def turret_head(h):
    """Rotating gun head, its own node so the game can aim it."""
    y = ROOF + 0.3
    h.cyl((0, y + 0.3, 0), 1.2, 0.6, C["hull"], sides=20, bevel=0.06)
    h.box((0, y + 0.55, -0.2), (1.6, 0.6, 1.6), C["hull"], 0.12, seg=2)
    h.box((0, y + 0.87, -0.2), (1.2, 0.05, 1.2), C["accent"], 0.02)
    for x in (-0.45, 0.45):
        h.cyl((x, y + 0.55, -1.6), 0.15, 1.8, C["steel"], "z", 12, bevel=0.02)
        h.cyl((x, y + 0.55, -2.5), 0.2, 0.25, C["gun"], "z", 12, bevel=0.02)
        h.cyl((x, y + 0.55, -2.64), 0.1, 0.03, C["red"], "z", 12, glow=True)


def engine(i, e, pts):
    """Blocked: back half z > 0; one crew at the console, z = -0.2."""
    floor(i, pts, grates=[(-1, -2), (0, -1)])
    i.box((0, 1.0, 1.0), (1.9, 2.0, 1.9), C["gun"], 0.08, seg=2)
    i.cyl((0, 1.0, 1.0), 0.6, 2.1, C["steel"], sides=16, bevel=0.03)
    for y in (0.5, 1.0, 1.5):
        i.cyl((0, y, 1.0), 0.64, 0.08, C["amber"], sides=16, glow=True)
    console(i, 0, 0.2, (0, -1), 0.7, "amber")
    for x in (-0.8, 0.8):
        pipe(i, (x, 0.2, 0.1), (x, 1.8, 0.1), 0.07)
    i.cyl((0, 1.0, 2.15), 0.55, 0.4, C["dark"], "z", 16, r2=0.8, bevel=0.02)
    i.cyl((0, 1.0, 2.0), 0.45, 0.03, C["amber"], "z", 16, glow=True)
    e.box((0, ROOF + 0.2, 0.9), (1.6, 0.4, 2.0), C["hull"], 0.1, seg=2)
    vent(e, (0, ROOF + 0.42, 0.9), 1.0, 1.2)
    e.cyl((0, ROOF - 0.9, 2.3), 0.8, 0.8, C["gun"], "z", 18, r2=1.0, bevel=0.03)
    e.cyl((0, ROOF - 0.9, 2.6), 0.7, 0.04, C["amber"], "z", 18, glow=True)
    return [((0, 1.9, -0.6), C["amber"])]


def crew_quarters(i, e, pts):
    """Blocked: bunks at x < -1 and x > 1 (z < 0), along the back (z > 1,
    x > -1), lockers and desk at x < -1 (z > 0)."""
    floor(i, pts, grates=[(0, -1)])
    for x in (-1.5, 1.5):
        _bunk(i, x, -1.0, "z")
    _bunk(i, 0.5, 1.5, "x")
    for z in (0.3, 0.85):
        i.box((-1.65, 0.95, z), (0.6, 1.9, 0.5), C["steel"], 0.03)
        i.box((-1.34, 1.0, z), (0.02, 1.6, 0.42), C["accent"])
    i.box((-1.5, 0.75, 1.6), (0.8, 0.05, 0.6), C["crate2"], 0.01)  # desk
    i.box((-1.5, 0.37, 1.6), (0.08, 0.74, 0.08), C["gun"])
    screen(i, (-1.5, 1.2, 1.88), 0.5, 0.3, col="screen")
    return [((0, 2.0, -0.2), C["lamp"])]


def _bunk(i, x, z, along):
    """Two stacked berths with frames, mattresses and pillows."""
    s = (1.9, 0.08, 0.85) if along == "x" else (0.85, 0.08, 1.9)
    for y in (0.35, 1.15):
        i.box((x, y, z), s, C["gun"], 0.02)
        i.box((x, y + 0.09, z), (s[0] - 0.08, 0.12, s[2] - 0.08), C["sheet"], 0.04)
        if along == "x":
            i.box((x - s[0] / 2 + 0.25, y + 0.19, z), (0.35, 0.08, 0.5), C["cloth"], 0.03)
        else:
            i.box((x, y + 0.19, z - s[2] / 2 + 0.25), (0.5, 0.08, 0.35), C["cloth"], 0.03)
    for dx in (-1, 1):
        for dz in (-1, 1):
            i.box((x + dx * (s[0] / 2 - 0.04), 0.8, z + dz * (s[2] / 2 - 0.04)),
                  (0.07, 1.6, 0.07), C["steel"], 0.01)

def _canopy(e):
    """Angular command cockpit over the whole bridge, seen in the outside
    view: a faceted frame of square glass panes (the game leaves a hole
    in the hull shell under it, so the crew show through), a metal back
    and a coaming round the opening."""
    lo, hi = ROOF + 0.05, ROOF + 0.6
    base = [(-1.3, -1.95), (1.3, -1.95), (1.95, -1.3), (1.95, 1.95), (-1.95, 1.95), (-1.95, -1.3)]
    top = [(-1.0, -0.9), (1.0, -0.9), (1.3, -0.6), (1.3, 1.4), (-1.3, 1.4), (-1.3, -0.6)]
    B = [(x, lo, z) for x, z in base]
    T = [(x, hi, z) for x, z in top]
    for k in range(6):  # sloped facets round the sides; the back one is metal
        j = (k + 1) % 6
        col = C["steel"] if k == 3 else C["glass"]
        _panes(e, B[k], B[j], T[j], T[k], 2 if k in (0, 2, 4) else 1, col)
    _panes(e, T[0], T[1], T[2], T[5], 2, C["glass"])  # front strip of the roof
    _panes(e, T[5], T[2], T[3], T[4], 2, C["glass"], rows=2)
    for k in range(6):  # frame: base ring, top ring and the corner posts
        e.bar(B[k], B[(k + 1) % 6], 0.05, C["gun"])
        e.bar(T[k], T[(k + 1) % 6], 0.05, C["gun"])
        e.bar(B[k], T[k], 0.05, C["gun"])
    for s in (-1, 1):  # coaming round the opening
        e.wall((-2.0, 1.98 * s), (2.0, 1.98 * s), ROOF - 0.5, lo, 0.08, C["hull"], 0.01)
        e.wall((1.98 * s, -2.0), (1.98 * s, 2.0), ROOF - 0.5, lo, 0.08, C["hull"], 0.01)
    e.cyl((0.9, hi + 0.25, 1.6), 0.03, 0.5, C["metal"], sides=6)
    e.ball((0.9, hi + 0.52, 1.6), 0.06, C["red"], 1, glow=True)


def _panes(e, a, b, c, d, cols, col, rows=1):
    """Quad a-b-c-d (a-b bottom, d-c top) split into cols x rows panes
    with frame bars between them."""
    def lerp(p, q, t):
        return tuple(p[k] + (q[k] - p[k]) * t for k in range(3))
    for r in range(rows):
        for k in range(cols):
            u0, u1, v0, v1 = k / cols, (k + 1) / cols, r / rows, (r + 1) / rows
            pts = [lerp(lerp(a, b, u), lerp(d, c, u), v) for u, v in
                   ((u0, v0), (u1, v0), (u1, v1), (u0, v1))]
            e.quad(pts, col)
            if k:
                e.bar(pts[0], pts[3], 0.035, C["gun"])
            if r:
                e.bar(pts[0], pts[1], 0.035, C["gun"])


def shipdock(i, e, pts):
    """Refit bay. Blocked: the back row z > 1 (fabricator with the two
    crew consoles), the side columns |x| > 2 (crane base, tool racks).
    Crew stand at (-1, 0.7) and (1, 0.7); the middle is a clear cradle."""
    floor(i, pts, grates=[(-1, -1), (0, -1), (-1, 0), (0, 0)])
    i.box((0, 0.9, 1.6), (5.9, 1.8, 0.7), C["gun"], 0.06, seg=2)  # fabricator
    i.box((0, 1.82, 1.6), (5.6, 0.06, 0.5), C["hazard"], 0.01)
    for x in (-2.0, 0.0, 2.0):
        vent(i, (x, 1.86, 1.6), 0.8, 0.4)
    for x in (-1, 1):
        console(i, x, 1.2, (0, -1), 0.8, "screen" if x < 0 else "amber")
    i.box((-2.5, 1.1, -0.5), (0.9, 2.2, 0.9), C["steel"], 0.06, seg=2)  # crane
    i.cyl((-2.5, 2.25, -0.5), 0.35, 0.2, C["gun"], sides=16, bevel=0.03)
    i.bar((-2.5, 2.4, -0.5), (-0.6, 2.4, -0.9), 0.09, C["accent"])  # boom
    i.bar((-0.6, 2.4, -0.9), (-0.2, 1.95, -0.8), 0.06, C["steel"])
    i.box((-0.2, 1.88, -0.8), (0.25, 0.12, 0.25), C["hazard"], 0.02)  # tool head
    i.cyl((-0.2, 1.75, -0.8), 0.04, 0.15, C["amber"], sides=8, glow=True)
    for z in (-1.5, -0.5, 0.5):  # tool and parts racks on the right
        i.box((2.5, 0.05, z), (0.9, 0.1, 0.9), C["gun"], 0.02)
        for y in (0.6, 1.3):
            i.box((2.5, y, z), (0.9, 0.04, 0.85), C["steel"], 0.01)
            i.box((2.45, y + 0.18, z), (0.6, 0.3, 0.6), C["crate"], 0.03)
    for x in (2.05, 2.95):
        i.box((x, 1.0, -0.5), (0.06, 2.0, 2.9), C["steel"], 0.01)
    for a, b in (((-1.8, -1.8), (1.8, -1.8)), ((-1.8, 0.6), (1.8, 0.6)),
                 ((-1.8, -1.8), (-1.8, 0.6)), ((1.8, -1.8), (1.8, 0.6))):
        i.wall(a, b, FLOOR, FLOOR + 0.012, 0.1, C["hazard"], 0.0)  # cradle
    for x in (-2.6, 2.6):  # exterior docking clamps and beacons
        e.box((x * 0.77, ROOF + 0.3, -0.4), (0.5, 0.6, 2.6), C["hull"], 0.08, seg=2)
        e.box((x * 0.7, ROOF + 0.55, -0.4), (0.5, 0.15, 2.2), C["accent"], 0.03)
        e.ball((x * 0.77, ROOF + 0.7, -1.6), 0.08, C["amber"], 1, glow=True)
    e.box((0, ROOF + 0.05, -0.4), (3.0, 0.1, 2.6), C["steel"], 0.04)
    return [((0, 2.1, -0.4), C["lamp"]), ((0, 2.1, 1.0), C["lamp"])]


def generator(i, e, pts):
    """Reactor. Blocked: z < 1 (the core); crew at (-1, 1.5) and (1, 1.5)
    feed it fuel and watch it from two consoles at the back."""
    floor(i, pts, grates=[(-1, 1), (0, 1)])
    i.box((0, 0.15, -0.5), (3.9, 0.3, 2.9), C["gun"], 0.05)  # plinth
    i.cyl((0, 1.25, -0.6), 0.95, 2.0, C["steel"], sides=24, bevel=0.04)
    for y in (0.55, 1.05, 1.55, 2.05):  # containment rings and glow bands
        i.cyl((0, y, -0.6), 1.02, 0.1, C["gun"], sides=24, bevel=0.02)
        i.cyl((0, y + 0.22, -0.6), 0.97, 0.08, C["power"], sides=24, glow=True)
    i.cyl((0, 2.3, -0.6), 0.6, 0.15, C["gun"], sides=16, bevel=0.03)
    for x in (-1.6, 1.6):  # coolant stacks and pipes into the core
        i.cyl((x, 1.0, -1.4), 0.25, 2.0, C["steel"], sides=12, bevel=0.02)
        pipe(i, (x, 1.7, -1.1), (x * 0.6, 1.7, -1.1), 0.07, "metal")
        pipe(i, (x, 0.6, -0.4), (x * 0.6, 0.6, -0.4), 0.09, "brass")
    i.box((1.5, 0.7, 0.3), (0.8, 0.8, 1.0), C["hazard"], 0.04)  # fuel feed hopper
    i.box((1.5, 1.12, 0.3), (0.6, 0.04, 0.8), C["gun"], 0.01)
    for x in (-1, 1):
        console(i, x, 0.75, (0, 1), 0.7, "power" if x < 0 else "amber")
    e.cyl((0, ROOF + 0.15, -0.6), 1.1, 0.3, C["steel"], sides=24, bevel=0.04)
    vent(e, (0, ROOF + 0.32, -0.6), 1.2, 1.2)
    return [((0, 2.2, 0.9), C["power"])]


def capacitor(i, e, pts):
    """Capacitor bank. Blocked: z < 0; crew service it from z = 0.5."""
    floor(i, pts)
    for x in (-0.5, 0.0, 0.5):  # three cells in a rack
        i.cyl((x, 0.75, -0.55), 0.2, 1.4, C["gun"], sides=12, bevel=0.02)
        for y in (0.3, 0.7, 1.1):
            i.cyl((x, y, -0.55), 0.22, 0.05, C["brass"], sides=12)
        i.cyl((x, 1.5, -0.55), 0.12, 0.06, C["power"], sides=12, glow=True)
    i.box((0, 0.06, -0.55), (1.8, 0.12, 0.8), C["steel"], 0.02)
    i.box((0, 1.6, -0.9), (1.8, 0.1, 0.12), C["steel"], 0.02)
    pipe(i, (-0.8, 1.6, -0.55), (0.8, 1.6, -0.55), 0.04, "metal", False)
    screen(i, (0.75, 1.1, -0.15), 0.3, 0.25, col="power")
    e.box((0, ROOF + 0.05, 0), (0.7, 0.1, 0.7), C["gun"], 0.03)
    for x in (-0.5, 0.0, 0.5):
        e.cyl((x * 0.44, ROOF + 0.15, 0), 0.1, 0.12, C["steel"], sides=10, bevel=0.02)
    return []


def mining_laser(i, e, pts):
    """Blocked: the front row z < -1 and the back corners; the operator
    stands at (0, -0.4) at the beam console."""
    floor(i, pts, grates=[(-1, 0), (0, 0)])
    console(i, 0, -1.25, (0, 1), 0.9, "amber")
    for x in (-1.45, 1.45):  # focusing coils either side of the console
        i.cyl((x, 0.8, -1.5), 0.4, 1.6, C["gun"], sides=16, bevel=0.03)
        for y in (0.4, 0.8, 1.2):
            i.cyl((x, y, -1.5), 0.43, 0.08, C["brass"], sides=16)
        i.cyl((x, 1.65, -1.5), 0.25, 0.08, C["amber"], sides=16, glow=True)
    for x in (-1.5, 1.5):  # power conditioners in the back corners
        i.box((x, 0.6, 1.5), (0.8, 1.2, 0.8), C["steel"], 0.05)
        screen(i, (x, 0.9, 1.08), 0.4, 0.25, col="power")
    e.cyl((0, ROOF + 0.12, 0), 1.3, 0.24, C["steel"], sides=24, bevel=0.04)  # ring the head turns on
    return [((0, 2.1, -0.4), C["amber"])]


def mining_head(h):
    """The mining laser's turning head (aimed at the rock by the game)."""
    h.cyl((0, ROOF + 0.45, 0), 1.0, 0.5, C["hull"], sides=20, bevel=0.06)
    h.box((0, ROOF + 0.55, 0.3), (1.6, 0.5, 1.4), C["hull"], 0.1, seg=2)
    h.cyl((0, ROOF + 0.55, -1.2), 0.5, 1.6, C["steel"], "z", 16, r2=0.32, bevel=0.03)
    for z in (-0.7, -1.4):
        h.cyl((0, ROOF + 0.55, z), 0.56, 0.12, C["gun"], "z", 16, bevel=0.02)
    h.cyl((0, ROOF + 0.55, -2.05), 0.3, 0.12, C["amber"], "z", 16, glow=True)
    h.box((0, ROOF + 0.82, 0.3), (1.2, 0.05, 1.0), C["accent"], 0.02)


def repair_bay(i, e, pts):
    """Workshop. Blocked: the front strip z < -0.2 (workbenches); two
    techs work at (-1, 0.1) and (1, 0.1), fixing parts for repairs."""
    floor(i, pts, grates=[(-1, 0), (0, 0)])
    for x in (-1, 1):  # workbench with a vice, a lit panel and tools
        i.box((x, 0.45, -0.6), (1.7, 0.9, 0.7), C["steel"], 0.04)
        i.box((x, 0.92, -0.6), (1.75, 0.05, 0.75), C["crate2"], 0.01)
        console(i, x + 0.45, -0.45, (0, 1), 0.6, "screen" if x < 0 else "amber")
        i.box((x - 0.45, 1.02, -0.55), (0.25, 0.15, 0.2), C["gun"], 0.02)  # vice
        i.box((x - 0.1, 0.99, -0.45), (0.3, 0.06, 0.08), C["red"], 0.01)  # tool
    i.box((0, 1.55, -0.95), (3.9, 1.1, 0.08), C["gun"], 0.02)  # tool wall
    for k in range(9):
        x = -1.8 + k * 0.45
        i.box((x, 1.3 + (k % 3) * 0.25, -0.89), (0.06, 0.22, 0.04), C["metal"])
    i.cyl((1.6, 1.85, -0.75), 0.04, 0.6, C["metal"], sides=6)  # welding arm
    i.box((1.6, 1.55, -0.55), (0.12, 0.12, 0.3), C["hazard"], 0.02)
    i.ball((1.6, 1.5, -0.38), 0.04, C["screen"], 1, glow=True)
    e.box((0, ROOF + 0.06, 0), (2.6, 0.12, 0.7), C["steel"], 0.04)
    e.box((0, ROOF + 0.14, 0), (0.45, 0.06, 0.45), C["hazard"], 0.02)
    return [((0, 2.1, -0.2), C["lamp"])]
