extends Node3D

# What the wind (Atmosphere.get_wind) does to the land: trees, palms, reeds, bushes and grass
# of the desert scatter bend and shiver with it, a few tumbleweeds roll across open ground,
# and now and then a dust devil spins up on a clear day and drifts off.
#
# Purely a visual: its own random numbers, nothing saved, no effect on the simulation. The
# plants bend in a vertex shader (foliage_sway.gdshader) that takes the wind once every
# PARAMS_S; dust devils spin in theirs (dust_devil.gdshader); only the tumbleweeds are moved
# by this script, all of them in one MultiMesh. The numbers are in data/wind.json.

const GameData = preload("res://source/data-model/GameData.gd")
const SwayShader = preload("res://source/shaders/3d/foliage_sway.gdshader")
const DevilShader = preload("res://source/shaders/3d/dust_devil.gdshader")

const PARAMS_S = 0.25
const FIND_SCATTER_S = 1.0
const MAP_MARGIN_M = 3.0
const DEVIL_PUFFS = 140
const DEVIL_FADE_S = 3.0
const TUMBLEWEED_TWIGS = 46
const TUMBLEWEED_COLOR = Color(0.62, 0.5, 0.32)
const TUMBLEWEED_CORE_COLOR = Color(0.42, 0.33, 0.21)
const TWIG_WIDTH_M = 0.06
const TUMBLEWEED_MESH_RADIUS = 0.45
const FLOATS_PER_INSTANCE = 12  # a 3x4 transform

var _config = {}
var _rng = RandomNumberGenerator.new()
var _map_size = Vector2(50, 50)
var _obstacles = []  # [Vector2 center, radius] of rock outcrops and forest clumps
var _sway_materials = []
var _scatter_found = false
var _since_params = PARAMS_S
var _since_scatter_search = FIND_SCATTER_S
var _wind = Vector2.ZERO
var _tumbleweeds = []  # {pos: Vector3, velocity: Vector3, spin: Basis, age, life, hop}
var _tumbleweed_layer = null
var _devils = []  # {node, age, life, wander}
var _next_devil_s = 0.0
var _devil_mesh = null
var _time = 0.0

@onready var _match = find_parent("Match")


func _ready():
	_config = GameData.wind()
	_rng.randomize()
	if _match != null and _match.map != null:
		_map_size = _match.map.size
		_index_obstacles(_match.map)
	_tumbleweed_layer = _make_tumbleweed_layer()
	_next_devil_s = _range(_config["dust_devils"]["every_s"]) * 0.5


func _process(delta):
	if delta <= 0.0:
		return
	_time += delta
	_since_params += delta
	if _since_params >= PARAMS_S:
		_since_params = 0.0
		_read_weather()
		for material in _sway_materials:
			material.set_shader_parameter("wind", _wind)
	if not _scatter_found:
		_since_scatter_search += delta
		if _since_scatter_search >= FIND_SCATTER_S:
			_since_scatter_search = 0.0
			_find_scatter()
	_update_tumbleweeds(delta)
	_update_devils(delta)


func _read_weather():
	var atmosphere = get_tree().get_first_node_in_group("atmosphere")
	if atmosphere == null:
		_wind = Vector2(2.5, 0.8)
		return
	_wind = atmosphere.get_wind()


func _calm_enough_for_devils():
	var atmosphere = get_tree().get_first_node_in_group("atmosphere")
	if atmosphere == null:
		return true
	return (
		atmosphere.get_rain_intensity() < 0.05
		and atmosphere.get_dust_intensity() <= float(_config["dust_devils"]["max_dust"])
	)


# plants


func _find_scatter():
	var scatter = _match.find_child("Scatter", true, false) if _match != null else null
	if scatter == null:
		return
	_scatter_found = true
	var sway = _config["sway"]
	for child in scatter.get_children():
		if not child is MultiMeshInstance3D or child.multimesh == null:
			continue
		if not child.name in sway or child.multimesh.mesh == null:
			continue
		child.multimesh.mesh = _swaying(child.multimesh.mesh, float(sway[child.name]))


func _swaying(mesh, bend):
	"""a copy of a flat-coloured prop mesh whose materials bend in the wind"""
	var copy = mesh.duplicate()
	var height = max(mesh.get_aabb().end.y, 0.1)
	for surface in range(copy.get_surface_count()):
		var original = copy.surface_get_material(surface)
		var material = ShaderMaterial.new()
		material.shader = SwayShader
		if original is BaseMaterial3D:
			material.set_shader_parameter("albedo", original.albedo_color)
			material.set_shader_parameter("roughness", original.roughness)
			material.set_shader_parameter("metallic", original.metallic)
			material.set_shader_parameter("specular", original.metallic_specular)
		material.set_shader_parameter("bend", bend)
		material.set_shader_parameter("height", height)
		material.set_shader_parameter("flutter", _rng.randf_range(1.2, 1.9))
		material.set_shader_parameter("wind", _wind)
		copy.surface_set_material(surface, material)
		_sway_materials.append(material)
	return copy


# tumbleweeds


func _tumbleweed_count():
	var tumbleweeds = _config["tumbleweeds"]
	var count = roundi(_map_size.x * _map_size.y / float(tumbleweeds["m2_per_tumbleweed"]))
	return clampi(count, 0, int(tumbleweeds["max"]))


func _update_tumbleweeds(delta):
	var tumbleweeds = _config["tumbleweeds"]
	var speed = _wind.length()
	if speed >= float(tumbleweeds["min_wind_mps"]) and _tumbleweeds.size() < _tumbleweed_count():
		_spawn_tumbleweed()
	var radius = float(tumbleweeds["radius_m"])
	var buffer = PackedFloat32Array()
	buffer.resize(_tumbleweed_layer.multimesh.instance_count * FLOATS_PER_INSTANCE)
	var index = 0
	for weed in _tumbleweeds.duplicate():
		weed["age"] += delta
		var push = Vector3(_wind.x, 0, _wind.y) * float(tumbleweeds["speed_per_wind"])
		push *= 0.7 + 0.5 * sin(_time * 1.3 + weed["phase"])  # gusty
		var flat = Vector3(weed["velocity"].x, 0, weed["velocity"].z)
		flat = flat.lerp(push, 1.0 - exp(-1.5 * delta))
		flat = _deflected(weed["pos"], flat)
		weed["velocity"] = Vector3(flat.x, weed["velocity"].y - 9.0 * delta, flat.z)
		weed["pos"] += weed["velocity"] * delta
		if weed["pos"].y <= 0.0:  # a bounce, now and then a big one
			weed["pos"].y = 0.0
			var hop = 1.6 if _rng.randf() < 0.25 else 0.6
			weed["velocity"].y = hop * clampf(flat.length() / 2.0, 0.3, 1.2)
		var rolled = flat.length() * delta / radius
		if flat.length_squared() > 0.0001:
			var axis = Vector3.UP.cross(flat.normalized())
			weed["spin"] = (Basis(axis, rolled) * weed["spin"]).orthonormalized()
		var gone = weed["age"] > weed["life"] or _off_map(weed["pos"]) or _wet(weed["pos"])
		if gone:
			weed["fade"] = maxf(0.0, weed["fade"] - delta)
			if weed["fade"] <= 0.0:
				_tumbleweeds.erase(weed)
				continue
		else:
			weed["fade"] = minf(1.0, weed["fade"] + delta)
		var scale = radius / TUMBLEWEED_MESH_RADIUS * weed["fade"] * weed["size"]
		var origin = weed["pos"] + Vector3(0, radius * weed["fade"], 0)
		_write_transform(buffer, index, Transform3D(weed["spin"] * scale, origin))
		index += 1
	_tumbleweed_layer.multimesh.buffer = buffer
	_tumbleweed_layer.multimesh.visible_instance_count = index


func _spawn_tumbleweed():
	var tumbleweeds = _config["tumbleweeds"]
	for _i in range(8):
		var spot = Vector3(
			_rng.randf_range(MAP_MARGIN_M, _map_size.x - MAP_MARGIN_M),
			0,
			_rng.randf_range(MAP_MARGIN_M, _map_size.y - MAP_MARGIN_M)
		)
		if _wet(spot) or _in_obstacle(Vector2(spot.x, spot.z), 4.0):
			continue
		(
			_tumbleweeds
			. append(
				{
					"pos": spot,
					"velocity": Vector3.ZERO,
					"spin": Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, 0)),
					"age": 0.0,
					"life": _range(tumbleweeds["life_s"]),
					"fade": 0.0,
					"phase": _rng.randf() * TAU,
					"size": _rng.randf_range(0.8, 1.2),
				}
			)
		)
		return


func _deflected(pos, flat):
	"""rolling around rocks and tree clumps rather than through them"""
	var at = Vector2(pos.x, pos.z)
	for obstacle in _obstacles:
		var away = at - obstacle[0]
		var reach = obstacle[1] + 0.6
		if away.length_squared() > reach * reach or away.length_squared() < 0.0001:
			continue
		var normal = away.normalized()
		var move = Vector2(flat.x, flat.z)
		if move.dot(normal) < 0.0:
			move -= normal * move.dot(normal) * 1.2
		return Vector3(move.x, 0, move.y)
	return flat


func _make_tumbleweed_layer():
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _tumbleweed_shape()
	multimesh.instance_count = max(1, int(_config["tumbleweeds"]["max"]))
	multimesh.visible_instance_count = 0
	var layer = MultiMeshInstance3D.new()
	layer.multimesh = multimesh
	layer.custom_aabb = AABB(Vector3(-10, -2, -10), Vector3(_map_size.x + 20, 8, _map_size.y + 20))
	add_child(layer)
	return layer


func _tumbleweed_shape():
	"""a ball of twigs 1 m across: a dark, tangled core wrapped in arcs of flat strips"""
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape_rng = RandomNumberGenerator.new()
	shape_rng.seed = 7
	var core = SphereMesh.new()
	core.radius = 0.3
	core.height = 0.56
	core.radial_segments = 7
	core.rings = 4
	var core_arrays = core.get_mesh_arrays()
	var core_vertices = core_arrays[Mesh.ARRAY_VERTEX]
	for index in core_arrays[Mesh.ARRAY_INDEX]:
		var vertex = core_vertices[index]
		tool.set_color(TUMBLEWEED_CORE_COLOR)
		tool.add_vertex(vertex * (1.0 + 0.15 * sin(vertex.x * 23.0 + vertex.z * 17.0)))
	for _i in range(TUMBLEWEED_TWIGS):
		var axis = Vector3(
			shape_rng.randf_range(-1, 1), shape_rng.randf_range(-1, 1), shape_rng.randf_range(-1, 1)
		)
		axis = axis.normalized() if axis.length_squared() > 0.01 else Vector3.UP
		var start = axis.cross(Vector3(0.3, 1, 0.2)).normalized()
		var radius = shape_rng.randf_range(0.34, 0.5)
		var arc = shape_rng.randf_range(0.6, 1.6)
		var from_angle = shape_rng.randf() * TAU
		var steps = 3
		for step in range(steps):
			var a = from_angle + arc * step / steps
			var b = from_angle + arc * (step + 1) / steps
			var p = start.rotated(axis, a) * radius
			var q = start.rotated(axis, b) * radius
			var side = axis * TWIG_WIDTH_M / 2.0
			for vertex in [p - side, q - side, q + side, p - side, q + side, p + side]:
				tool.set_color(TUMBLEWEED_COLOR)
				tool.add_vertex(vertex)
	tool.generate_normals()
	var mesh = tool.commit()
	var material = StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


# dust devils


func _update_devils(delta):
	var devils = _config["dust_devils"]
	_next_devil_s -= delta
	if _next_devil_s <= 0.0:
		_next_devil_s = _range(devils["every_s"])
		if _devils.size() < int(devils["max"]) and _calm_enough_for_devils():
			_spawn_devil()
	var calm = _calm_enough_for_devils()
	for devil in _devils.duplicate():
		devil["age"] += delta
		if not calm:
			devil["life"] = min(devil["life"], devil["age"] + DEVIL_FADE_S)
		var node = devil["node"]
		var wander = Vector3(
			cos(_time * 0.4 + devil["wander"]), 0, sin(_time * 0.3 + devil["wander"])
		)
		var drift = Vector3(_wind.x, 0, _wind.y) * float(devils["drift_per_wind"]) + wander * 0.6
		node.position += drift * delta
		var fade_in = clampf(devil["age"] / DEVIL_FADE_S, 0.0, 1.0)
		var fade_out = clampf((devil["life"] - devil["age"]) / DEVIL_FADE_S, 0.0, 1.0)
		if _wet(node.position) or _off_map(node.position):
			devil["life"] = min(devil["life"], devil["age"] + DEVIL_FADE_S)
		node.set_instance_shader_parameter("life", min(fade_in, fade_out))
		if devil["age"] >= devil["life"]:
			node.queue_free()
			_devils.erase(devil)


func _spawn_devil():
	var devils = _config["dust_devils"]
	for _i in range(8):
		var spot = Vector3(
			_rng.randf_range(MAP_MARGIN_M * 3, _map_size.x - MAP_MARGIN_M * 3),
			0,
			_rng.randf_range(MAP_MARGIN_M * 3, _map_size.y - MAP_MARGIN_M * 3)
		)
		if _wet(spot) or _in_obstacle(Vector2(spot.x, spot.z), 3.0):
			continue
		if _devil_mesh == null:
			_devil_mesh = _devil_shape()
		var node = MeshInstance3D.new()
		node.mesh = _devil_mesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, float(devils["height_m"]) + 4, 8))
		var material = ShaderMaterial.new()
		material.shader = DevilShader
		material.set_shader_parameter("column_height", float(devils["height_m"]))
		node.material_override = material
		node.position = spot
		node.set_instance_shader_parameter("life", 0.0)
		add_child(node)
		_devils.append(
			{
				"node": node,
				"age": 0.0,
				"life": _range(devils["life_s"]),
				"wander": _rng.randf() * TAU
			}
		)
		return


func sightings(kind = "dust_devils"):
	"""where to look for "dust_devils" or "tumbleweeds"; for the play harness and screenshots"""
	if kind == "tumbleweeds":
		return _tumbleweeds.map(func(weed): return weed["pos"])
	var youngest_first = _devils.duplicate()
	youngest_first.sort_custom(func(a, b): return a["age"] < b["age"])
	return youngest_first.map(func(devil): return devil["node"].position + Vector3(0, 2.5, 0))


static func _devil_shape():
	"""DEVIL_PUFFS quads all at the origin; COLOR carries each puff's place in the funnel"""
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var shape_rng = RandomNumberGenerator.new()
	shape_rng.seed = 11
	for index in range(DEVIL_PUFFS):
		var puff = Color(
			float(index) / DEVIL_PUFFS, shape_rng.randf(), shape_rng.randf(), shape_rng.randf()
		)
		for corner in [
			Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)
		]:
			tool.set_color(puff)
			tool.set_uv(corner)
			tool.add_vertex(Vector3.ZERO)
	return tool.commit()


# helpers


func _index_obstacles(map):
	if "outcrops" in map:
		for outcrop in map.outcrops:
			_obstacles.append([outcrop.center, float(outcrop.radius)])
	if "forests" in map:
		for forest in map.forests:
			for circle in forest.circles:
				_obstacles.append([circle.center, float(circle.radius)])


func _in_obstacle(at, margin):
	for obstacle in _obstacles:
		if at.distance_to(obstacle[0]) < obstacle[1] + margin:
			return true
	return false


func _wet(pos):
	return _match != null and _match.map != null and _match.map.water_depth_at(pos) != 0


func _off_map(pos):
	return pos.x < 0.0 or pos.z < 0.0 or pos.x > _map_size.x or pos.z > _map_size.y


func _range(pair):
	return _rng.randf_range(float(pair[0]), float(pair[1]))


static func _write_transform(buffer, index, transform):
	var at = index * FLOATS_PER_INSTANCE
	var basis = transform.basis
	buffer[at] = basis.x.x
	buffer[at + 1] = basis.y.x
	buffer[at + 2] = basis.z.x
	buffer[at + 3] = transform.origin.x
	buffer[at + 4] = basis.x.y
	buffer[at + 5] = basis.y.y
	buffer[at + 6] = basis.z.y
	buffer[at + 7] = transform.origin.y
	buffer[at + 8] = basis.x.z
	buffer[at + 9] = basis.y.z
	buffer[at + 10] = basis.z.z
	buffer[at + 11] = transform.origin.z
