class_name AsteroidArt
extends RefCounted
## Procedural asteroids: a lumpy, cratered rock of radius r with ore
## veins of its material showing in the vertex colours (iron rust-red,
## copper green-orange, silicon pale and glassy, gold bright metal).

const KINDS := {  # rock colour, vein colour, vein metal (0..1)
	&"iron": [Color(0.2, 0.18, 0.17), Color(0.55, 0.27, 0.16), 0.7],
	&"copper": [Color(0.19, 0.18, 0.16), Color(0.25, 0.62, 0.48), 0.5],
	&"silicon": [Color(0.26, 0.26, 0.28), Color(0.75, 0.8, 0.86), 0.2],
	&"gold": [Color(0.18, 0.17, 0.15), Color(0.95, 0.72, 0.25), 1.0],
}

static var _mat: ShaderMaterial


## A rock mesh; `kind` picks the ore colours (unknown kinds look like iron).
static func mesh(rng: RandomNumberGenerator, r: float, kind := &"iron") -> ArrayMesh:
	var k: Array = KINDS.get(kind, KINDS[&"iron"])
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = clampi(24 + int(r * 2.0), 24, 64)
	sphere.rings = sphere.radial_segments / 2
	var a := sphere.get_mesh_arrays()
	var shape := FastNoiseLite.new()
	shape.seed = rng.randi()
	shape.frequency = 0.9
	shape.fractal_octaves = 4
	var veins := FastNoiseLite.new()
	veins.seed = rng.randi()
	veins.frequency = 2.2
	veins.noise_type = FastNoiseLite.TYPE_CELLULAR
	veins.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_DIV
	var craters: Array[Vector3] = []
	for c in rng.randi_range(3, 7):
		craters.append(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized())
	var stretch := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.6, 0.95), rng.randf_range(0.8, 1.2))
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var cols := PackedColorArray()
	for i in v.size():
		var d := v[i].normalized()
		var h := 1.0 + shape.get_noise_3dv(d * 1.3) * 0.35
		for c in craters:
			var t := d.dot(c)
			h -= smoothstep(0.93, 0.985, t) * 0.12 - smoothstep(0.9, 0.93, t) * 0.03
		v[i] = d * h * r * stretch
		var vein := smoothstep(-0.17, -0.09, veins.get_noise_3dv(d * 2.0))  # cell edges
		var base: Color = k[0].lerp(k[0].darkened(0.3), shape.get_noise_3dv(d * 4.0) * 0.5 + 0.5)
		var col: Color = base.lerp(k[1], vein)
		col.a = vein * k[2]
		cols.append(col)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_COLOR] = cols
	a[Mesh.ARRAY_NORMAL] = null
	a[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var raw := ArrayMesh.new()
	raw.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	st.create_from(raw, 0)
	st.generate_normals()
	st.generate_tangents()
	var out := st.commit()
	out.surface_set_material(0, material())
	return out


static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = preload("res://assets/materials/asteroid.gdshader")
		_mat.set_shader_parameter(&"bump_tex", ModelSkin.noise(true))
	return _mat
