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
    e.cyl((0, ROOF + 0.15, 0), 1.5, 0.3, C["steel"], sides=24, bevel=0.04)
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
