class_name InkContent
extends RefCounted

static var catalog: Dictionary = {}
static func load_catalog() -> Dictionary:
	if catalog.is_empty():
		catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json"))
	return catalog

static func vec(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))

static func material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.3
	if glow > 0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func sphere(parent: Node3D, pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var s = SphereMesh.new()
	s.radius = radius
	s.height = radius * 2
	s.radial_segments = 12
	s.rings = 6
	return mesh(parent, s, pos, mat)
