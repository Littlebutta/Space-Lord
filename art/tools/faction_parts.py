"""Outside parts for the non-Human factions, used by build_themes.py.
style(theme) returns {"replace": bool, "ext": fn(mid, e, pts),
"head": fn(mid, h) or None, "extra": fn(mid, new_part) or None}.
`replace` drops the Human outside detail for the faction's own. Model
origin is deck level; hull tops are near human_style.ROOF."""
import math
import random

from human_style import C, ROOF


def _rng(theme, mid):
    return random.Random(sum(map(ord, theme + mid)))


def _spots(rng, pts, n, k=0.6):
    xs = [x for x, _ in pts]
    zs = [z for _, z in pts]
    return [(rng.uniform(min(xs) * k, max(xs) * k), rng.uniform(min(zs) * k, max(zs) * k))
            for _ in range(n)]


# ---- Bio: grown, not built -------------------------------------------------

def _growth(e, x, z, rng, y):
    kind = rng.choice(("pustule", "polyp", "sac", "spines"))
    if kind == "pustule":
        r = rng.uniform(0.25, 0.45)
        e.ball((x, y + r * 0.3, z), r, C["hull"], 2, (1.0, 0.7, 1.0))
        e.ball((x, y + r * 0.8, z), r * 0.4, C["screen"], 1, glow=True)
    elif kind == "polyp":
        h = rng.uniform(0.6, 1.2)
        lx, lz = rng.uniform(-0.4, 0.4), rng.uniform(-0.4, 0.4)
        e.prism((x, y, z), (x + lx, y + h, z + lz), 0.18, C["steel"], 8, 0.05, smooth=True)
        e.ball((x + lx, y + h, z + lz), 0.1, C["amber"], 1, glow=True)
    elif kind == "sac":
        e.ball((x, y + 0.2, z), rng.uniform(0.4, 0.7), C["red"], 2, (1.3, 0.55, 1.0))
    else:
        for k in range(rng.randint(3, 5)):
            a = rng.uniform(0, 2 * math.pi)
            e.prism((x, y, z), (x + math.cos(a) * 0.4, y + rng.uniform(0.5, 0.9),
                                z + math.sin(a) * 0.4), 0.07, C["white"], 6, 0.0)


def _bio_ext(mid, e, pts):
    rng = _rng("bio", mid)
    y = ROOF + 0.1
    if mid == "bridge":  # a great eye
        e.ball((0, y + 0.3, -0.6), 1.0, C["hull"], 2, (1.2, 0.7, 1.0))
        e.ball((0, y + 0.55, -1.25), 0.45, C["white"], 2, (1.0, 1.0, 0.7))
        e.ball((0, y + 0.58, -1.5), 0.22, C["screen"], 2, (1.0, 1.0, 0.5), glow=True)
    elif mid == "cannon":  # a bone spine along the barrel line
        for k in range(8):
            z = -3.0 + k * 0.8
            e.ball((0, y + 0.3, z), 0.32, C["white"], 1, (1.0, 0.8, 1.3))
            e.prism((0, y + 0.4, z), (0, y + 0.9, z + 0.3), 0.08, C["white"], 6, 0.0)
        e.prism((0, y + 0.3, -3.0), (0, y + 0.3, -3.8), 0.3, C["white"], 8, 0.05)
    elif mid in ("generator", "fuel_tank", "supply_depot"):  # swollen organs
        e.ball((0, y + 0.3, 0), 0.9, C["red"], 2, (1.3, 0.6, 1.1))
        e.ball((0, y + 0.75, 0), 0.3, C["power"], 1, glow=True)
    for x, z in _spots(rng, pts, 3 if len(pts) == 4 else 1):
        _growth(e, x, z, rng, y)


def _bio_head(mid, h):
    """Turret or mining head: a muscled pod with bone barrels."""
    y = ROOF + 0.4
    h.ball((0, y + 0.4, 0), 1.0, C["hull"], 2, (1.0, 0.6, 1.1))
    h.ball((0, y + 0.7, 0.2), 0.5, C["red"], 2, (1.0, 0.6, 1.0))
    for x in ((-0.45, 0.45) if mid == "turret" else (0.0,)):
        h.prism((x, y + 0.55, -0.4), (x, y + 0.55, -2.6), 0.2, C["white"], 8, 0.12, smooth=True)
        h.ball((x, y + 0.55, -2.65), 0.14, C["screen"] if mid == "turret" else C["amber"], 1, glow=True)


def _tentacles(mid, new_part):
    """Bio thrusters: tentacles trailing back (+z) from the engine and a
    feeding maw; the game makes them writhe when the engine pushes."""
    if mid != "engine":
        return
    t = new_part("Tentacle")
    for k, (x, y) in enumerate(((-0.4, 1.2), (0.4, 1.2), (0.0, 1.8), (-0.2, 0.7), (0.3, 0.6))):
        rings = []
        for j in range(9):
            s = j / 8
            r = 0.28 * (1 - s) + 0.03
            cx, cy = x * (1 + s * 0.6), y + math.sin(s * 2.5 + k) * 0.25
            rings.append((1.6 + s * 3.2, [(cx + r * math.cos(a / 8 * 2 * math.pi),
                                           cy + r * math.sin(a / 8 * 2 * math.pi)) for a in range(8)]))
        t.loft(rings, C["hull"])
        for j in (1, 3, 5):  # suckers
            s = j / 8
            t.ball((x * (1 + s * 0.6), y + math.sin(s * 2.5 + k) * 0.25 - 0.25 * (1 - s) - 0.03,
                    1.6 + s * 3.2), 0.06, C["red"], 1)
    t.ball((0, 1.2, 1.5), 0.75, C["red"], 2, (1.2, 1.0, 0.7))  # the feeding maw


# ---- Crystal: grown lattice and lances -------------------------------------

def _crystal(e, base, length, r, rng, col=None, lean=0.5):
    x, y, z = base
    tip = (x + rng.uniform(-lean, lean), y + length, z + rng.uniform(-lean, lean))
    mid = tuple(base[k] + (tip[k] - base[k]) * 0.8 for k in range(3))
    e.prism(base, mid, r, col or C["glass"], 6, r * 0.9)
    e.prism(mid, tip, r * 0.9, col or C["glass"], 6, 0.01)


def _crystal_ext(mid, e, pts):
    rng = _rng("crystal", mid)
    y = ROOF + 0.05
    if mid == "bridge":
        e.ball((0, y + 0.4, -0.4), 1.2, C["glass"], 1, (1.1, 0.6, 1.2), smooth=False)
        e.ball((0, y + 0.5, -0.4), 0.4, C["power"], 1, glow=True)
    for x, z in _spots(rng, pts, 4 if len(pts) == 4 else 2):
        for k in range(rng.randint(2, 4)):  # a cluster
            _crystal(e, (x + rng.uniform(-0.3, 0.3), y, z + rng.uniform(-0.3, 0.3)),
                     rng.uniform(0.5, 1.6), rng.uniform(0.1, 0.25), rng)
        e.cyl((x, y + 0.04, z), 0.45, 0.08, C["power"], sides=6, glow=True, smooth=False)


def _crystal_head(mid, h):
    rng = _rng("crystal", mid + "head")
    y = ROOF + 0.4
    h.ball((0, y + 0.35, 0), 0.9, C["steel"], 1, (1.0, 0.6, 1.0), smooth=False)
    for x in ((-0.4, 0.4) if mid == "turret" else (0.0,)):  # crystal lances
        h.prism((x, y + 0.5, 0.2), (x, y + 0.5, -2.0), 0.18, C["glass"], 6, 0.12)
        h.prism((x, y + 0.5, -2.0), (x, y + 0.5, -2.7), 0.12, C["power"], 6, 0.01, glow=True)
    _crystal(h, (0, y + 0.6, 0.3), 0.8, 0.15, rng)


# ---- Scrap: Reaver salvage welded over the Human parts ---------------------

def _scrap_ext(mid, e, pts):
    rng = _rng("scrap", mid)
    y = ROOF + 0.05
    for x, z in _spots(rng, pts, 5, 0.8):  # jagged sheets welded on at angles
        a = (x + rng.uniform(-0.8, 0.8), z + rng.uniform(-0.8, 0.8))
        col = C["red"] if rng.random() < 0.3 else C["steel"]
        e.wall((x, z), a, y, y + rng.uniform(0.1, 0.5), 0.05, col, 0.0)
    for x, z in _spots(rng, pts, 3, 0.7):  # spikes
        e.prism((x, y, z), (x + rng.uniform(-0.5, 0.5), y + rng.uniform(0.7, 1.6),
                            z + rng.uniform(-0.5, 0.5)), 0.08, C["metal"], 4, 0.0)
    for k in range(2):  # exposed girders
        (x0, z0), (x1, z1) = _spots(rng, pts, 2, 0.9)
        e.bar((x0, y + 0.3, z0), (x1, y + 0.6, z1), 0.06, C["gun"])
    if mid == "cannon":  # a ram of welded blades at the muzzle
        for s in (-1, 1):
            e.prism((0, y + 0.3, -3.2), (s * 0.6, y + 0.2, -4.4), 0.12, C["metal"], 4, 0.0)


def style(theme):
    return {
        "bio": {"replace": True, "ext": _bio_ext, "head": _bio_head, "extra": _tentacles},
        "crystal": {"replace": True, "ext": _crystal_ext, "head": _crystal_head, "extra": None},
        "scrap": {"replace": False, "ext": _scrap_ext, "head": None, "extra": None},
    }[theme]
