class_name OreLump
extends RefCounted
## Rough lumps of raw metal cut from asteroids: a few lumpy low-poly
## shapes per material, tinted and a little metallic, shared by all chunks.

const SHAPES := 3

static var _meshes := {}  # material -> Array[ArrayMesh]


static func mesh(res: String) -> ArrayMesh:
	if not _meshes.has(res):
		var list: Array[ArrayMesh] = []
		for k in SHAPES:
			list.append(_make(res, k))
		_meshes[res] = list
	return _meshes[res][randi() % SHAPES]


static func _make(res: String, k: int) -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.28
	sm.height = 0.5
	sm.radial_segments = 7
	sm.rings = 4
	var a := sm.get_mesh_arrays()
	var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(res) + k
	var bend := Vector3(rng.randf_range(0.8, 1.3), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.4))
	var cache := {}  # seam vertices share a spot, so dents stay closed
	for i in v.size():
		var key := Vector3i((v[i] * 1000.0).round())
		if not cache.has(key):
			cache[key] = rng.randf_range(0.7, 1.25)
		v[i] = v[i] * bend * cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX]
	for i in idx:
		st.add_vertex(v[i])
	st.generate_normals()  # flat facets read as broken metal
	var m := StandardMaterial3D.new()
	var col: Color = Materials.COLORS.get(res, Color.GRAY)
	m.albedo_color = col
	m.metallic = 0.7
	m.roughness = 0.45
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = 0.15  # just enough to spot them against space
	st.set_material(m)
	return st.commit()
