"""Human exterior parts that break up the hull's outline: wings, a tail
fin, an antenna and a sensor mast. They stand outside the hull, so each
is one "Body" mesh that shows in both views. Same builder signature as
human_hull (the Exterior Part is unused); model origin is deck level."""
from human_style import C, ROOF


def _wing(b, pts, y, t):
    """Wing of planform pts at height y and thickness t: a chamfered core
    slab, a thinner top skin with a seam, accent along the leading edge."""
    b.slab(pts, y, y + t, C["hull"], 0.06)
    b.slab([(x * 0.92, z * 0.92) for x, z in pts], y + t, y + t + 0.05, C["steel"], 0.02)
    lead = pts[0], pts[1], pts[2]
    for a, c in zip(lead, lead[1:]):
        if a != c and a[1] != c[1]:
            b.wall(a, c, y + t * 0.2, y + t * 0.8, 0.08, C["accent"], 0.01)


def wing(b, e, pts):
    """Swept wing; root against the hull at x = -3, tip at x = 3."""
    y = 0.9
    _wing(b, pts, y, 0.35)
    for x in (-1.5, 0.2):  # weapon pylons under the wing
        b.box((x, y - 0.15, 0.6), (0.2, 0.3, 1.2), C["gun"], 0.03)
        b.cyl((x, y - 0.35, 0.4), 0.13, 1.4, C["steel"], "z", 10, bevel=0.02)
    b.box((2.9, y + 0.2, 1.4), (0.2, 0.45, 1.1), C["gun"], 0.04)  # tip cap
    b.ball((2.95, y + 0.2, 0.9), 0.07, C["red"], 1, glow=True)
    b.box((-2.85, y + 0.17, 0.0), (0.3, 0.6, 3.8), C["steel"], 0.04)  # root
    return []


def wing_stub(b, e, pts):
    """Short winglet with a sensor pod on its tip."""
    y = 0.9
    _wing(b, pts, y, 0.3)
    b.cyl((1.8, y + 0.15, 0.6), 0.18, 0.9, C["steel"], "z", 12, bevel=0.03)
    b.ball((1.8, y + 0.15, 0.1), 0.14, C["glass"], 1)
    b.ball((1.95, y + 0.2, 0.9), 0.06, C["red"], 1, glow=True)
    b.box((-1.85, y + 0.15, 0.0), (0.3, 0.55, 1.9), C["steel"], 0.04)
    return []


def fin(b, e, pts):
    """Tall swept tail fin standing on the deck line, thin in x."""
    prof = [(-2.0, 0.0), (2.0, 0.0), (1.9, 3.2), (0.9, 3.2)]  # (z, y) side view
    _plate(b, prof, -0.13, 0.13, C["hull"])
    _plate(b, [(1.0, 2.6), (1.95, 2.6), (1.9, 3.2), (0.9, 3.2)], -0.15, 0.15, C["accent"])
    b.box((0, 0.2, 0), (0.5, 0.4, 4.0), C["steel"], 0.06)  # root fairing
    b.ball((0, 3.25, 1.4), 0.07, C["lamp"], 1, glow=True)
    return []


def _plate(b, prof, x0, x1, col):
    """Side-view polygon (z, y) extruded across x0..x1."""
    n = len(prof)
    L = [(x0, y, z) for z, y in prof]
    R = [(x1, y, z) for z, y in prof]
    b.quad(L, col)
    b.quad(R[::-1], col)
    for k in range(n):
        j = (k + 1) % n
        b.quad([L[k], R[k], R[j], L[j]], col)


def antenna(b, e, pts):
    """Whip antenna with stays and a blinking tip."""
    b.box((0, 0.15, 0), (0.45, 0.3, 0.45), C["gun"], 0.04)
    b.cyl((0, 1.7, 0), 0.05, 3.0, C["metal"], sides=8)
    for y in (1.2, 2.1):
        b.box((0, y, 0), (0.7, 0.04, 0.04), C["steel"])
        b.box((0, y, 0), (0.04, 0.04, 0.5), C["steel"])
    b.ball((0, 3.25, 0), 0.08, C["red"], 1, glow=True)
    return []


def sensor_mast(b, e, pts):
    """Mast with a radar dish and sensor pods."""
    b.cyl((0, 0.2, 0), 0.4, 0.4, C["gun"], sides=12, bevel=0.03)
    b.cyl((0, 1.0, 0), 0.14, 1.4, C["steel"], sides=10, bevel=0.02)
    b.ball((0, 1.8, -0.05), 0.55, C["hull"], 2, (1.0, 0.35, 1.0))  # dish
    b.cyl((0, 1.85, -0.35), 0.04, 0.5, C["metal"], "z", 6)
    b.ball((0, 1.85, -0.6), 0.07, C["screen"], 1, glow=True)
    for x in (-0.3, 0.3):
        b.box((x, 1.2, 0.15), (0.16, 0.22, 0.3), C["steel"], 0.03)
    return []
