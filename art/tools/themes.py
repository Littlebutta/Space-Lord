"""The other factions' looks, built from the same part builders as the
Human set: each swaps the palette and adds its own touches outside.
Bio is grown and organic, Crystal faceted and glowing, Scrap patched
together from salvage. Equal in detail, distinct at a glance."""
import random

PALETTES = {
    "bio": {
        "hull": "#6f7d5c", "steel": "#55604a", "gun": "#3a3f33",
        "dark": ("#24261e", "rubber"), "metal": ("#9a8f70", "metal"),
        "brass": ("#8a6a3a", "metal"), "hazard": "#a9b84a", "red": "#a84a3a",
        "white": "#d8cfb0", "glass": ("#3a5a3a", "glass"), "screen": "#9cf07a",
        "amber": "#e8c05a", "power": "#7af0c0", "lamp": "#e0ffc0",
        "crate": ("#6a5a3e", "crate"), "crate2": ("#4e5a38", "crate"),
        "cloth": ("#5a6650", "fabric"), "sheet": ("#8a8a70", "fabric"),
        "plate": ("#5a5246", "metal"), "grate": ("#3b3530", "metal"),
    },
    "crystal": {
        "hull": "#8a8fb0", "steel": "#6a6f90", "gun": "#3e4060",
        "dark": ("#22223a", "rubber"), "metal": ("#c0c4e0", "metal"),
        "brass": ("#a090d0", "metal"), "hazard": "#b07ae8", "red": "#d04a8a",
        "white": "#e4e4f4", "glass": ("#4a5aa0", "glass"), "screen": "#b48cff",
        "amber": "#ff9ad5", "power": "#9ad8ff", "lamp": "#e0e4ff",
        "crate": ("#5a5a80", "crate"), "crate2": ("#6a5090", "crate"),
        "cloth": ("#50507a", "fabric"), "sheet": ("#9a9ab8", "fabric"),
        "plate": ("#5a5e80", "metal"), "grate": ("#383a55", "metal"),
    },
    "scrap": {
        "hull": "#7a6a5a", "steel": "#6a5a4a", "gun": "#3a342e",
        "dark": ("#262220", "rubber"), "metal": ("#8a7a6a", "metal"),
        "brass": ("#9a6a3a", "metal"), "hazard": "#d09a20", "red": "#a04028",
        "white": "#c8bca0", "glass": ("#3a4a48", "glass"), "screen": "#ffb347",
        "amber": "#ff8a3d", "power": "#ffd27a", "lamp": "#ffd8a0",
        "crate": ("#6a5a3a", "crate"), "crate2": ("#7a4a2a", "crate"),
        "cloth": ("#5a4a3e", "fabric"), "sheet": ("#8a7e6a", "fabric"),
        "plate": ("#5a4e42", "metal"), "grate": ("#352e28", "metal"),
    },
}


def decor(theme, C, roof):
    """A function adding the theme's outside touches to one part."""
    def spots(mid, pts, n):
        rng = random.Random(hash((theme, mid)) & 0xffff)
        xs = [x for x, _ in pts]
        zs = [z for _, z in pts]
        out = []
        for _ in range(n):  # inside the footprint, clear of the chamfer
            out.append((rng.uniform(min(xs) * 0.55, max(xs) * 0.55),
                        rng.uniform(min(zs) * 0.55, max(zs) * 0.55), rng))
        return out

    def bio(mid, e, pts):
        for x, z, rng in spots(mid, pts, 3):  # grown pods and a vein
            r = rng.uniform(0.18, 0.35)
            e.ball((x, roof + r * 0.4, z), r, C["hull"], 2, (1.0, 0.55, 1.2))
            e.ball((x, roof + r * 0.75, z), r * 0.35, C["screen"], 1, glow=True)
        e.cyl((0, roof + 0.05, 0), 0.06, 1.2, C["accent"], "x", 8)

    def crystal(mid, e, pts):
        for x, z, rng in spots(mid, pts, 3):  # crystal spires
            h = rng.uniform(0.4, 1.0)
            r = rng.uniform(0.1, 0.22)
            e.cyl((x, roof + h / 2, z), r, h, C["glass"], sides=6, r2=0.02, smooth=False)
            e.cyl((x, roof + 0.05, z), r * 1.3, 0.1, C["power"], sides=6, glow=True)

    def scrap(mid, e, pts):
        for x, z, rng in spots(mid, pts, 4):  # welded-on patches and pipe
            w, d = rng.uniform(0.3, 0.8), rng.uniform(0.3, 0.7)
            col = C["red"] if rng.random() < 0.3 else C["steel"]
            e.box((x, roof + 0.03, z), (w, 0.05, d), col, 0.01)
            for sx in (-1, 1):
                e.cyl((x + sx * w * 0.4, roof + 0.07, z), 0.03, 0.03, C["metal"], sides=6)
        e.cyl((0.3, roof + 0.12, 0), 0.07, 1.0, C["brass"], "z", 8)

    return {"bio": bio, "crystal": crystal, "scrap": scrap}[theme]
