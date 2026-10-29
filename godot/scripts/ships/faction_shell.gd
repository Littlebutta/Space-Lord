class_name FactionShell
extends RefCounted
## Outside hulls for the non-Human factions, built over one theme's
## region of the ship (see HullShell.make):
##   flesh   - Bio: one lumpy, swelling mass that rolls down to the deck.
##   facets  - Crystal: big flat-shaded crystal facets at uneven heights.
##   plates  - Scrap: the Human shell under a pile of mismatched, tilted
##             plates with spikes jutting from the edges.
## Heights fall off only toward the ship's real outer edge, so where two
## factions meet inside the ship both hulls are at full height and blend.

const FLESH_H := 2.7  # a little taller than Human (bigger is fine for crew)
const FACET_H := 2.6


## Mesh for `style` over polygon `region`; `ship` is the whole ship's
## outline (for distance to its edge), y0 the deck top.
static func build(style: StringName, region: PackedVector2Array,
		ship: Array[PackedVector2Array], y0: float, seed: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	match style:
		&"flesh":
			return _field(region, ship, y0, rng, 0.32, FLESH_H, true)
		&"facets":
			return _field(region, ship, y0, rng, 0.9, FACET_H, false)
	return null


## A height field over `region`: Delaunay triangles through jittered
## grid points every `step` metres plus the outline, raised by `top`
## and rounded down near the ship's edge. Smooth (flesh) or faceted.
static func _field(region: PackedVector2Array, ship: Array[PackedVector2Array], y0: float,
		rng: RandomNumberGenerator, step: float, top: float, smooth: bool) -> ArrayMesh:
	var pts := PackedVector2Array()
	for i in region.size():  # the outline, cut into short runs
		var a := region[i]
		var b := region[(i + 1) % region.size()]
		var n := maxi(int(a.distance_to(b) / step), 1)
		for k in n:
			pts.append(a.lerp(b, float(k) / n))
	var box := Rect2(region[0], Vector2.ZERO)
	for v in region:
		box = box.expand(v)
	var y := box.position.y + step * 0.5
	while y < box.end.y:
		var x := box.position.x + step * 0.5
		while x < box.end.x:
			var p := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * step * 0.6
			if Geometry2D.is_point_in_polygon(p, region) and _edge(p, [region]) > step * 0.3:
				pts.append(p)
			x += step
		y += step
	var noise := FastNoiseLite.new()
	noise.seed = rng.randi()
	noise.frequency = 0.22 if smooth else 0.5
	var hs := PackedFloat32Array()
	var ins := PackedFloat32Array()  # 0 where it meets another faction
	for p in pts:
		var e := _edge(p, ship)
		var rise := sqrt(clampf(e / (1.8 if smooth else 1.0), 0.0, 1.0))
		var lump := noise.get_noise_2dv(p) * (0.55 if smooth else 0.5)
		if smooth:  # folds and wrinkles on top of the big swells
			lump += noise.get_noise_2dv(p * 4.3 + Vector2(17, 3)) * 0.12
			lump += absf(noise.get_noise_2dv(p * 9.0 + Vector2(5, 41))) * -0.06
		else:
			lump += rng.randf_range(-0.35, 0.35)
		# meet a neighbouring faction at the Human hull height, swell inside
		var inner := clampf(_edge(p, [region]) / 1.5, 0.0, 1.0)
		ins.append(inner)
		hs.append(y0 + (HullShell.HEIGHT + (top - HullShell.HEIGHT + lump) * inner) * rise)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tri := Geometry2D.triangulate_delaunay(pts)
	for k in range(0, tri.size(), 3):
		var c := (pts[tri[k]] + pts[tri[k + 1]] + pts[tri[k + 2]]) / 3.0
		if not Geometry2D.is_point_in_polygon(c, region):
			continue
		var tint := Color(1, 1, 1).darkened(rng.randf() * 0.25)  # facet shading
		var ids := [tri[k], tri[k + 1], tri[k + 2]]
		var vs: Array[Vector3] = []
		for j in ids:
			vs.append(Vector3(pts[j].x, hs[j], pts[j].y))
		if (vs[1] - vs[0]).cross(vs[2] - vs[0]).y > 0.0:  # face up (Godot winds clockwise)
			vs = [vs[0], vs[2], vs[1]]
			ids = [ids[0], ids[2], ids[1]]
		for j in 3:
			var v := vs[j]
			st.set_color(Color(tint, ins[ids[j]]))  # alpha: how free it is to breathe
			st.set_uv(Vector2(v.x, v.z) * 0.25)
			st.add_vertex(v)
	if smooth:
		st.index()
	st.generate_normals()
	st.generate_tangents()  # for the detail normal maps
	return st.commit()


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
