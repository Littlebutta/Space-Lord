class_name FactionShell
extends RefCounted
## Outside hulls for the non-Human factions, built over one theme's
## region of the ship (see HullShell.make):
##   flesh   - Bio: one lumpy, swelling mass with rounded edges.
##   facets  - Crystal: flat-shaded crystal facets with chamfered edges.
##   plates  - Scrap: salvage plates and spikes on the Human-style shell.
## Heights fall off only toward the ship's real outer edge (and gaps in
## it), so factions meet at full height. Flesh and crystal also creep a
## random, ragged way onto their neighbours' hulls (infected, or grown
## over), different every time the hull is built.

const FLESH_H := 2.7  # a little taller than Human (bigger is fine for crew)
const FACET_H := 2.6
const REACH := 1.6  # how far the creep can spread onto neighbours
const SKIRT := 0.45  # how far the edge rolls down past the deck top


## Mesh for `style` over polygon `region`; `ship` is the whole ship's
## outline, `gaps` empty cells inside it (left open), y0 the deck top.
static func build(style: StringName, region: PackedVector2Array,
		ship: Array[PackedVector2Array], gaps: Array, y0: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var smooth := style == &"flesh"
	var shaped := _shape(ship, smooth)
	var edges: Array = shaped.duplicate()  # distances drop toward these
	for g: Rect2 in gaps:
		edges.append(PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end,
				Vector2(g.position.x, g.end.y)]))
	return _field(region, shaped, edges, gaps, y0, rng, 0.32 if smooth else 0.85,
			FLESH_H if smooth else FACET_H, smooth)


## The ship outline with its corners broken: rounded for flesh,
## chamfered for crystal.
static func _shape(ship: Array[PackedVector2Array], round: bool) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var join := Geometry2D.JOIN_ROUND if round else Geometry2D.JOIN_SQUARE
	for p in ship:
		for q in Geometry2D.offset_polygon(p, -0.7, join):
			for r in Geometry2D.offset_polygon(q, 0.7, join):
				if not Geometry2D.is_polygon_clockwise(r):
					out.append(r)
	return out if not out.is_empty() else ship


static func _field(region: PackedVector2Array, shaped: Array[PackedVector2Array], edges: Array,
		gaps: Array, y0: float, rng: RandomNumberGenerator, step: float, top: float,
		smooth: bool) -> ArrayMesh:
	var mine := _clip(region, shaped)  # this faction's part, corners broken
	var reach := _reach(region, shaped)  # where it may creep onto others
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.22 if smooth else 0.5
	var pts := PackedVector2Array()
	var hs := PackedFloat32Array()
	var ins := PackedFloat32Array()  # 0 where it meets another faction
	var keep := PackedByteArray()  # 1: part of the hull or of the creep
	for poly in mine:  # outlines, cut into short runs
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			for k in maxi(int(a.distance_to(b) / step), 1):
				pts.append(a.lerp(b, float(k) / maxi(int(a.distance_to(b) / step), 1)))
	var box := Rect2(region[0], Vector2.ZERO)
	for v in region:
		box = box.expand(v)
	box = box.grow(REACH)
	var y := box.position.y
	while y < box.end.y:
		var x := box.position.x
		while x < box.end.x:
			var p := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * step * 0.6
			if (_in(p, mine) or _in(p, reach)) and not _in_gap(p, gaps) and _edge(p, mine) > step * 0.3:
				pts.append(p)
			x += step
		y += step
	for p in pts:
		var e := _edge(p, edges)
		var own := _in(p, mine) or _edge(p, mine) < 0.01
		var lump := noise.get_noise_2dv(p) * (0.55 if smooth else 0.5)
		if smooth:  # folds and wrinkles on top of the big swells
			lump += noise.get_noise_2dv(p * 4.3 + Vector2(17, 3)) * 0.12
			lump += absf(noise.get_noise_2dv(p * 9.0 + Vector2(5, 41))) * -0.06
		else:
			lump += rng.randf_range(-0.35, 0.35)
		var rise := sqrt(clampf(e / (1.8 if smooth else 1.0), 0.0, 1.0))
		if own:
			var inner := clampf(_edge(p, [region]) / 1.5, 0.0, 1.0) if _in(p, [region]) else 0.0
			hs.append(y0 - SKIRT * (1.0 - rise) + (HullShell.HEIGHT + SKIRT + (top - HullShell.HEIGHT + lump) * inner) * rise)
			ins.append(inner)
			keep.append(1)
		else:  # the creep: a thin skin over the neighbour, ragged at its edge
			var out := _edge(p, [region]) / REACH
			var bevel := clampf(_edge(p, shaped) / HullShell.BEVEL, 0.0, 1.0)
			hs.append(y0 + HullShell.HEIGHT - HullShell.BEVEL * (1.0 - bevel) + 0.05 + 0.12 * (1.0 - out))
			ins.append(0.0)
			keep.append(int(noise.get_noise_2dv(p * 0.7 + Vector2(91, 7)) * 0.5 + 0.5 > out + 0.15))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_delaunay(pts)
	for k in range(0, tri.size(), 3):
		var ids := [tri[k], tri[k + 1], tri[k + 2]]
		var c := (pts[ids[0]] + pts[ids[1]] + pts[ids[2]]) / 3.0
		if _in_gap(c, gaps) or not (_in(c, mine) or (_in(c, reach) and keep[ids[0]] and keep[ids[1]] and keep[ids[2]])):
			continue
		var tint := Color(1, 1, 1).darkened(rng.randf() * 0.25)  # facet shading
		var vs: Array[Vector3] = []
		for j in ids:
			vs.append(Vector3(pts[j].x, hs[j], pts[j].y))
		if (vs[1] - vs[0]).cross(vs[2] - vs[0]).y > 0.0:  # face up (Godot winds clockwise)
			vs = [vs[0], vs[2], vs[1]]
			ids = [ids[0], ids[2], ids[1]]
		for j in 3:
			st.set_color(Color(tint, ins[ids[j]]))  # alpha: how free it is to breathe
			st.set_uv(Vector2(vs[j].x, vs[j].z) * 0.25)
			st.add_vertex(vs[j])
	if smooth:
		st.index()
	st.generate_normals()
	st.generate_tangents()  # for the detail normal maps
	return st.commit()


## `region` cut to the corner-broken ship outline.
static func _clip(region: PackedVector2Array, shaped: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for s in shaped:
		for q in Geometry2D.intersect_polygons(region, s):
			if not Geometry2D.is_polygon_clockwise(q):
				out.append(q)
	if out.is_empty():  # nothing clipped: keep the whole region
		out.append(region)
	return out


## The band round `region` (inside the ship) that the creep may cover.
static func _reach(region: PackedVector2Array, shaped: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	for grown in Geometry2D.offset_polygon(region, REACH, Geometry2D.JOIN_ROUND):
		for s in shaped:
			for q in Geometry2D.intersect_polygons(grown, s):
				if not Geometry2D.is_polygon_clockwise(q):
					for r in Geometry2D.clip_polygons(q, region):
						if not Geometry2D.is_polygon_clockwise(r):
							out.append(r)
	return out


static func _in(p: Vector2, polys: Array) -> bool:
	for poly: PackedVector2Array in polys:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


static func _in_gap(p: Vector2, gaps: Array) -> bool:
	for g: Rect2 in gaps:
		if g.grow(-0.05).has_point(p):
			return true
	return false


## Shortest distance from `p` to the edges of polygons `polys`.
static func _edge(p: Vector2, polys: Array) -> float:
	var best := INF
	for poly: PackedVector2Array in polys:
		for i in poly.size():
			var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
			best = minf(best, p.distance_to(q))
	return best


## Scrap: tilted, overlapping salvage plates over the region and spikes
## along the ship's outer edge, added as a mesh on the Human-style shell.
static func plates(region: PackedVector2Array, ship: Array[PackedVector2Array],
		top: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var box := Rect2(region[0], Vector2.ZERO)
	for v in region:
		box = box.expand(v)
	var k := 0
	var y := box.position.y + 0.7
	while y < box.end.y:
		var x := box.position.x + 0.7
		while x < box.end.x:
			var c := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 0.6
			if Geometry2D.is_point_in_polygon(c, region) and _edge(c, ship) > 0.9:
				var s := Vector2(rng.randf_range(0.8, 1.6), rng.randf_range(0.6, 1.3))
				var b := Basis.from_euler(Vector3(rng.randf_range(-0.12, 0.12),
						rng.randf() * TAU, rng.randf_range(-0.12, 0.12)))
				var h := top + 0.04 + (k % 5) * 0.025
				_slab(st, Transform3D(b, Vector3(c.x, h, c.y)), Vector3(s.x, 0.05, s.y),
						Color(1, 1, 1).darkened(rng.randf() * 0.4))
				k += 1
			x += 1.4
		y += 1.4
	for poly in ship:  # spikes jutting out and up from the hull's edge
		for i in poly.size():
			var a := poly[i]
			var b := poly[(i + 1) % poly.size()]
			var n := int(a.distance_to(b) / 1.3)
			var out := (b - a).orthogonal().normalized()
			if Geometry2D.is_point_in_polygon((a + b) * 0.5 + out * 0.05, poly):
				out = -out
			for j in n:
				var p := a.lerp(b, (j + 0.5) / n)
				if not Geometry2D.is_point_in_polygon(p - out * 0.3, region):
					continue
				var len := rng.randf_range(0.5, 1.4)
				var dir := Vector3(out.x, rng.randf_range(0.2, 0.7), out.y).normalized()
				_spike(st, Vector3(p.x, top - 0.5, p.y), dir * len, 0.12)
	st.generate_normals()
	return st.commit()


static func _slab(st: SurfaceTool, xf: Transform3D, s: Vector3, tint: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = s
	var a := bm.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for i in idx:
		st.set_color(tint)
		st.set_uv(Vector2(0.5 / 8.0, 1.0))  # painted metal, worn edges
		st.add_vertex(xf * v[i])


## A four-sided spike from `base` along `tip`, `r` wide at the root.
static func _spike(st: SurfaceTool, base: Vector3, tip: Vector3, r: float) -> void:
	var side := tip.cross(Vector3.UP).normalized() * r
	var up := side.cross(tip).normalized() * r
	var ring := [base + side, base + up, base - side, base - up]
	for i in 4:  # both windings, so it shows from every side
		for v in [ring[i], ring[(i + 1) % 4], base + tip, ring[(i + 1) % 4], ring[i], base + tip]:
			st.set_color(Color(0.7, 0.65, 0.6))
			st.set_uv(Vector2(1.5 / 8.0, 1.0))  # bare metal
			st.add_vertex(v)
