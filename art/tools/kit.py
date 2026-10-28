"""Hard-surface modelling kit for Blender 5.x, driven from scripts.

Positions and sizes are written in Godot space (x right, y up, z toward
the back of the ship). Parts are built in a frame where (x, z) is the
floor and Z is up, then mirrored into Blender so the .glb lands in
Godot exactly as written.

Each face carries a colour ("Col" attribute) and a "Data" UV: u picks
the material preset in pbr.gdshaderinc, v marks bevel faces so paint
chips there (v = 1 in Godot; written as 0 because glTF flips v). A colour is a hex string (painted metal) or (hex, preset).
glow=True faces use the "Glow" material and "glass" faces the see-through
"Glass" material instead.
"""
import math
import bmesh
import bpy
from mathutils import Matrix, Vector

PRESET = {"paint": 0, "metal": 1, "rubber": 2, "crate": 3, "fabric": 4,
          "glass": 5, "skin": 6, "accent": 7}


def _g(v):
    """Godot (x, y, z) -> build frame (x, z, y)."""
    return Vector((v[0], v[2], v[1]))


def srgb(h):
    """'#rrggbb' -> linear RGB tuple."""
    c = [int(h[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    return tuple(x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4 for x in c)


class Part:
    """One mesh being built: primitives are added straight into a bmesh."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.float_color.new("Col")
        self.uv = self.bm.loops.layers.uv.new("Data")
        self.dl = None  # deform layer, set by bone()
        self.gi = 0

    def bone(self, k):
        """Weights everything added from now on fully to vertex group k."""
        self.dl = self.bm.verts.layers.deform.verify()
        self.gi = k

    def _finish(self, verts, col, glow, smooth, m=None, edges=()):
        if m is not None:
            bmesh.ops.transform(self.bm, matrix=m, verts=verts)
        hexc, mat = (col, "paint") if isinstance(col, str) else col
        c = srgb(hexc) + (1.0,)
        u = (PRESET[mat] + 0.5) / 8
        edges = set(edges)
        if self.dl is not None:
            for v in verts:
                v[self.dl][self.gi] = 1.0
        for f in {f for v in verts for f in v.link_faces}:
            f.material_index = 1 if glow else 2 if mat == "glass" else 0
            f.smooth = smooth
            for lp in f.loops:
                lp[self.col] = c
                lp[self.uv].uv = (u, 0.0 if f in edges else 1.0)  # glTF flips v
        return verts

    def _bevel(self, verts, edges, off, seg, axis=None):
        """Bevels edges; returns the verts and the new slanted faces. With
        an axis (cylinders), only faces tilted from it count as bevels."""
        g = bmesh.ops.bevel(self.bm, geom=list(verts) + list(edges), offset=off,
                            segments=seg, affect="EDGES", profile=0.5)
        v = [x for x in {x for f in g["faces"] for x in f.verts} | set(verts) if x.is_valid]
        self.bm.normal_update()
        faces = {f for x in v for f in x.link_faces}
        if axis is None:
            ef = [f for f in faces if max(abs(c) for c in f.normal) < 0.97]
        else:
            ef = [f for f in faces if 0.15 < abs(f.normal.z) < 0.97]
        return v, ef

    def box(self, c, s, col, bevel=0.0, glow=False, seg=1):
        """Box centred at c with full size s; bevel chamfers its edges."""
        v = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        bmesh.ops.scale(self.bm, vec=_g(s), verts=v)
        ef = []
        if bevel > 0:
            e = {e for x in v for e in x.link_edges}
            v, ef = self._bevel(v, e, bevel, seg)
        return self._finish(v, col, glow, False, Matrix.Translation(_g(c)), ef)

    def cyl(self, c, r, h, col, axis="y", sides=12, r2=None, glow=False,
            smooth=True, bevel=0.0):
        """Cylinder, or cone when r2 is given, along a Godot axis."""
        v = bmesh.ops.create_cone(self.bm, cap_ends=True, segments=sides,
                                  radius1=r, radius2=r if r2 is None else r2,
                                  depth=h)["verts"]
        self.bm.normal_update()
        rim = [e for x in v for e in x.link_edges if len(e.link_faces) == 2
               and e.link_faces[0].normal.angle(e.link_faces[1].normal, 0) > 0.9]
        ef = []
        if bevel > 0:
            v, ef = self._bevel(v, set(rim), bevel, 1, "z")
        rot = {"y": Matrix.Identity(4),
               "x": Matrix.Rotation(math.pi / 2, 4, "Y"),
               "z": Matrix.Rotation(-math.pi / 2, 4, "X")}[axis]
        self._finish(v, col, glow, smooth, Matrix.Translation(_g(c)) @ rot, ef)
        for f in {f for x in v for f in x.link_faces}:
            if len(f.verts) == sides:
                f.smooth = False
        return v

    def ball(self, c, r, col, sub=2, scale=(1, 1, 1), smooth=True, glow=False):
        v = bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r)["verts"]
        bmesh.ops.scale(self.bm, vec=_g(scale), verts=v)
        return self._finish(v, col, glow, smooth, Matrix.Translation(_g(c)))

    def slab(self, poly, y0, y1, col, chamfer=0.0, glow=False):
        """Polygon [(x, z)...] extruded from y0 to y1; chamfer bevels its top."""
        bm = self.bm
        bot = [bm.verts.new((x, z, y0)) for x, z in poly]
        f = bm.faces.new(bot)
        bm.normal_update()
        if f.normal.z > 0:
            f.normal_flip()
        r = bmesh.ops.extrude_face_region(bm, geom=[f])
        top = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
        for t in top:
            t.co.z = y1
        v, ef = bot + top, []
        if chamfer > 0:
            ts = set(top)
            te = {e for t in top for e in t.link_edges if all(x in ts for x in e.verts)}
            v, ef = self._bevel(v, te, chamfer, 2)
        bm.normal_update()
        return self._finish(v, col, glow, False, None, ef)

    def loft(self, rings, col, axis="z", smooth=True, glow=False):
        """Capped tube through rings [(pos, [(u, w)...])] along a Godot
        axis; each ring is a closed outline across the axis (w is up,
        or z for a vertical loft)."""
        bm, loops = self.bm, []
        for pos, pts in rings:
            ring = []
            for u, w in pts:
                p = {"z": (u, w, pos), "x": (pos, w, u), "y": (u, pos, w)}[axis]
                ring.append(bm.verts.new(_g(p)))
            loops.append(ring)
        n = len(loops[0])
        faces = []
        for a, b in zip(loops, loops[1:]):
            for k in range(n):
                faces.append(bm.faces.new((a[k], a[(k + 1) % n], b[(k + 1) % n], b[k])))
        caps = [bm.faces.new(loops[0]), bm.faces.new(loops[-1])]
        bmesh.ops.recalc_face_normals(bm, faces=faces + caps)
        v = [x for r in loops for x in r]
        self._finish(v, col, glow, smooth)
        for f in caps:
            f.smooth = False
        return v

    def quad(self, pts, col, glow=False):
        """One flat face through four Godot points (glass panes, panels)."""
        v = [self.bm.verts.new(_g(p)) for p in pts]
        self.bm.faces.new(v)
        self.bm.normal_update()
        return self._finish(v, col, glow, False)

    def bar(self, a, b, r, col):
        """Square frame bar of half-width r between Godot points a and b."""
        a, b = _g(a), _g(b)
        v = bmesh.ops.create_cube(self.bm, size=1.0)["verts"]
        bmesh.ops.scale(self.bm, vec=Vector((r * 2, r * 2, (b - a).length + r * 2)), verts=v)
        rot = Vector((0, 0, 1)).rotation_difference(b - a).to_matrix().to_4x4()
        return self._finish(v, col, False, False, Matrix.Translation((a + b) / 2) @ rot)

    def wall(self, a, b, y0, y1, t, col, bevel=0.02):
        """Straight wall of thickness t from floor point a to b (x, z)."""
        a, b = Vector(a), Vector(b)
        d = b - a
        v = self.box((0, 0, 0), (d.length, y1 - y0, t), col, bevel)
        m = (Matrix.Translation(((a.x + b.x) / 2, (a.y + b.y) / 2, (y0 + y1) / 2))
             @ Matrix.Rotation(math.atan2(d.y, d.x), 4, "Z"))
        bmesh.ops.transform(self.bm, matrix=m, verts=v)
        return v

    def build(self, mats, parent=None):
        """Mirrors the build frame (x, z, y) into Blender (x, -z, y),
        which glTF export turns back into Godot (x, y, z)."""
        fix = Matrix.Scale(-1, 4, (0, 1, 0))
        bmesh.ops.transform(self.bm, matrix=fix, verts=self.bm.verts)
        bmesh.ops.reverse_faces(self.bm, faces=self.bm.faces)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.color_attributes.active_color_name = "Col"
        me.color_attributes.render_color_index = 0
        for m in mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = parent
        return ob


def materials():
    """The shared materials: vertex-coloured surface, glowing, glass."""
    out = []
    for name, glow in (("Surface", False), ("Glow", True), ("Glass", False)):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        nt = m.node_tree
        bsdf = nt.nodes.get("Principled BSDF")
        attr = nt.nodes.new("ShaderNodeVertexColor")
        attr.layer_name = "Col"
        sock = "Emission Color" if glow else "Base Color"
        nt.links.new(attr.outputs["Color"], bsdf.inputs[sock])
        if glow:
            bsdf.inputs["Emission Strength"].default_value = 3.0
        out.append(m)
    return out


def lamp(name, pos, col, parent, power=80.0):
    """Point light at Godot position pos; Godot sets range and energy."""
    ld = bpy.data.lights.new(name, "POINT")
    ld.color = srgb(col)
    ld.energy = power
    ob = bpy.data.objects.new(name, ld)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = (pos[0], -pos[2], pos[1])
    return ob


def empty(name, pos=(0, 0, 0), parent=None):
    ob = bpy.data.objects.new(name, None)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = parent
    ob.location = (pos[0], -pos[2], pos[1])
    return ob


def reset():
    """Empties the startup scene."""
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob)


def export(root, path, **extra):
    """Exports root and its children to a .glb at path."""
    opts = dict(export_animations=False)
    opts.update(extra)
    bpy.ops.object.select_all(action="DESELECT")
    for ob in [root] + list(root.children_recursive):
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB",
                              use_selection=True, export_apply=True,
                              export_vertex_color="ACTIVE", export_lights=True,
                              export_yup=True, **opts)
