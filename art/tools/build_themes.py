"""Builds the Bio, Crystal and Scrap part sets (one .glb per part in
godot/assets/models/<theme>/) by re-running the Human builders with
each faction's palette and outside touches (themes.py).

  blender -b --factory-startup --python art/tools/build_themes.py [-- bio]
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
import build_human  # noqa: E402
import human_style  # noqa: E402
import themes  # noqa: E402

BASE = dict(human_style.C)
pick = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else list(themes.PALETTES)
for name in pick:
    human_style.C.clear()
    human_style.C.update(BASE)
    human_style.C.update(themes.PALETTES[name])
    out = os.path.join(build_human.ROOT, "godot", "assets", "models", name)
    sys.argv = [a for a in sys.argv if a == "--"]  # build every part
    build_human.main(out, "%s_modules.blend" % name,
                     themes.decor(name, human_style.C, human_style.ROOF))
