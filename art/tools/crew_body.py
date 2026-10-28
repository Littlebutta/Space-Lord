"""Human crew body (about 1.75 m): rig bones and rigidly skinned parts.
The crew faces -z, right is +x. Shirt faces use the "accent" preset,
which the game paints by job."""
import math

C = {"skin": ("#c99a7a", "skin"), "hair": ("#3b2a20", "fabric"),
     "shirt": ("#ffffff", "accent"), "suit": ("#3d4148", "fabric"),
     "gear": ("#26282c", "rubber"), "metal": ("#8a8d92", "metal"),
     "eye": ("#151515", "rubber"), "patch": ("#b8a888", "fabric")}

# name, parent, head, tail (Godot coords)
BONES = [
    ("root", None, (0, 0, 0), (0, 0.15, 0)),
    ("hips", "root", (0, 0.95, 0), (0, 1.05, 0)),
    ("spine", "hips", (0, 1.05, 0), (0, 1.42, 0)),
    ("head", "spine", (0, 1.45, 0), (0, 1.75, 0)),
]
for _s, _x in (("R", 1), ("L", -1)):
    BONES += [
        ("arm." + _s, "spine", (0.2 * _x, 1.4, 0), (0.235 * _x, 1.12, 0)),
        ("hand." + _s, "arm." + _s, (0.235 * _x, 1.12, 0), (0.25 * _x, 0.84, 0)),
        ("thigh." + _s, "hips", (0.1 * _x, 0.95, 0), (0.1 * _x, 0.52, 0)),
        ("shin." + _s, "thigh." + _s, (0.1 * _x, 0.52, 0), (0.1 * _x, 0.08, 0)),
    ]
IDX = {b[0]: k for k, b in enumerate(BONES)}


def _ring(w, d, n=10, dz=0.0):
    return [(w * math.cos(k / n * 2 * math.pi), dz + d * math.sin(k / n * 2 * math.pi))
            for k in range(n)]


def body(p):
    def on(name):
        p.bone(IDX[name])
    on("hips")
    p.loft([(0.86, _ring(0.15, 0.1)), (0.95, _ring(0.165, 0.11)),
            (1.04, _ring(0.16, 0.105))], C["suit"], "y")
    p.cyl((0, 1.0, 0), 0.172, 0.06, C["gear"], sides=12)  # belt
    for x in (-0.12, 0.12):
        p.box((x, 0.98, -0.1), (0.08, 0.09, 0.05), C["gear"], 0.015)
    p.box((0, 1.0, -0.115), (0.07, 0.05, 0.02), C["metal"], 0.008)
    on("spine")
    p.loft([(1.03, _ring(0.158, 0.103)), (1.14, _ring(0.155, 0.1)),
            (1.28, _ring(0.19, 0.12)), (1.39, _ring(0.2, 0.115)),
            (1.46, _ring(0.07, 0.06))], C["shirt"], "y")
    p.box((0, 1.28, -0.11), (0.26, 0.24, 0.05), C["gear"], 0.02)  # vest
    p.box((0, 1.28, 0.115), (0.28, 0.26, 0.04), C["gear"], 0.02)
    p.box((0.07, 1.33, -0.14), (0.07, 0.05, 0.015), C["patch"], 0.005)
    for x in (-0.19, 0.19):
        p.ball((x, 1.39, 0), 0.075, C["gear"], 1, (1.1, 0.7, 1.0))
    on("head")
    p.cyl((0, 1.48, 0), 0.05, 0.08, C["skin"], sides=8)
    p.ball((0, 1.6, -0.01), 0.11, C["skin"], 2, (0.92, 1.12, 1.0))
    p.ball((0, 1.66, 0.015), 0.115, C["hair"], 2, (0.97, 0.75, 1.02))
    for x in (-0.04, 0.04):
        p.ball((x, 1.615, -0.105), 0.012, C["eye"], 1)
    p.box((0, 1.585, -0.115), (0.025, 0.04, 0.03), C["skin"], 0.008)
    for s in (-1, 1):
        p.ball((0.105 * s, 1.6, 0.0), 0.025, C["skin"], 1, (0.5, 1.0, 0.8))
    p.cyl((0.115, 1.6, 0), 0.04, 0.03, C["gear"], "x", 10)  # headset
    p.box((0.1, 1.56, -0.06), (0.012, 0.012, 0.1), C["gear"])
    for s, x in (("R", 1), ("L", -1)):
        on("arm." + s)
        p.cyl((0.218 * x, 1.26, 0), 0.058, 0.3, C["shirt"], sides=10)
        on("hand." + s)
        p.cyl((0.243 * x, 0.99, 0), 0.05, 0.27, C["suit"], sides=10)
        p.cyl((0.245 * x, 1.06, 0), 0.055, 0.06, C["gear"], sides=10)  # cuff
        p.ball((0.25 * x, 0.83, 0), 0.05, C["gear"], 1, (0.8, 1.2, 1.0))
        on("thigh." + s)
        p.cyl((0.1 * x, 0.73, 0), 0.078, 0.44, C["suit"], sides=10, r2=0.068)
        p.box((0.13 * x, 0.75, 0), (0.04, 0.12, 0.1), C["gear"], 0.01)  # pocket
        on("shin." + s)
        p.cyl((0.1 * x, 0.31, 0), 0.063, 0.42, C["suit"], sides=10, r2=0.055)
        p.box((0.1 * x, 0.5, -0.06), (0.1, 0.1, 0.04), C["gear"], 0.015)  # knee
        p.box((0.1 * x, 0.08, -0.035), (0.11, 0.16, 0.25), C["gear"], 0.03)
        p.box((0.1 * x, 0.012, -0.035), (0.12, 0.025, 0.27), C["metal"], 0.006)


def suit(p):
    """Spacesuit worn on spacewalks (its own mesh, shown only outside):
    a glass helmet, a neck ring and a jetpack with four nozzles."""
    def on(name):
        p.bone(IDX[name])
    on("head")
    p.ball((0, 1.6, -0.005), 0.17, ("#9fd4ee", "glass"), 2, (1.0, 1.08, 1.0))
    p.cyl((0, 1.46, 0), 0.13, 0.06, C["metal"], sides=14, bevel=0.01)
    p.box((0, 1.7, -0.14), (0.1, 0.03, 0.04), ("#ffb347", "paint"), glow=True)
    on("spine")
    p.box((0, 1.24, 0.17), (0.3, 0.38, 0.16), ("#d8d4c8", "paint"), 0.04)
    p.box((0, 1.24, 0.255), (0.22, 0.28, 0.02), C["shirt"], 0.01)
    for x in (-0.11, 0.11):
        for y in (1.07, 1.41):
            p.cyl((x, y, 0.2), 0.03, 0.05, C["gear"], sides=8)
    for x in (-0.12, 0.12):  # chest lights
        p.box((x, 1.33, -0.13), (0.03, 0.03, 0.02), ("#59c8ff", "paint"), glow=True)
