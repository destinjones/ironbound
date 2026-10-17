extends Node3D

# Makes the cities look lived in: smoke curls out of house chimneys now and then and pours
# steadily from the workshops, leaning with the wind; townsfolk step out of their doors,
# walk over to a neighbour, the market or the city centre, chat a moment and go inside.
# When shots land nearby they run for the nearest door and the streets stay empty for a while.
#
# Purely a visual: its own random numbers, nothing saved, no effect on the simulation, and
# only buildings the player has seen (CityBuilding.visible) smoke or send anyone out. The
# smoke rises in a vertex shader (chimney_smoke.gdshader) and only takes a new wind and
# strength every REFRESH_S; limbs swing in townsfolk.gdshader, so the script only walks
# each person along a straight path. Both are one MultiMesh each. Numbers: data/city_life.json.

const GameData = preload("res://source/data-model/GameData.gd")
const SmokeShader = preload("res://source/shaders/3d/chimney_smoke.gdshader")
const FolkShader = preload("res://source/shaders/3d/townsfolk.gdshader")

const REFRESH_S = 0.25
const HIDE_ABOVE_CAMERA_SIZE = 40.0  # townsfolk are a few pixels tall beyond this
const SMOKE_PUFFS = 32
const FLOATS_PER_INSTANCE = 16  # a 3x4 transform and the custom data
const FOLK_MESH_HEIGHT_M = 0.36
const BUILDING_BLOCK_M = 0.95  # what a path must keep clear of a city building's centre
const DOOR_OUT_M = 1.2  # where a path leaves a building
const DOOR_IN_M = 0.45  # where a person is out of sight inside it
const STEP_LENGTH_M = 0.16  # one leg cycle covers two steps
const ROBES = [
	Color(0.9, 0.88, 0.82),
	Color(0.2, 0.27, 0.48),
	Color(0.62, 0.36, 0.16),
	Color(0.58, 0.2, 0.15),
	Color(0.32, 0.4, 0.24),
	Color(0.24, 0.22, 0.22),
	Color(0.15, 0.4, 0.42),
	Color(0.5, 0.26, 0.36),
]
const SCARVES = [
	Color(0.93, 0.9, 0.84),
	Color(0.2, 0.19, 0.18),
	Color(0.7, 0.2, 0.18),
	Color(0.24, 0.36, 0.6),
	Color(0.85, 0.66, 0.3),
	Color(0.3, 0.45, 0.35),
	Color(0.55, 0.36, 0.5),
	Color(0.36, 0.25, 0.17),
]


class Person:
	var pos := Vector3.ZERO
	var path: Array = []  # Vector3 points still to walk to; the last is inside a building
	var yaw := 0.0
	var cycle := 0.0
	var speed := 0.0
	var running := false
	var chat_until := -1.0  # pauses at the second-to-last point (the door) until then
	var chatted := false
	var robe := 0.0
	var scarf := 0.0
	var city_id := 0


var _config = {}
var _rng = RandomNumberGenerator.new()
var _time = 0.0
var _since_refresh = REFRESH_S
var _wind = Vector2(2.0, 0.5)
var _rain = 0.0
var _buildings = {}  # instance id -> {node, next_folk_s, chimney}
var _chimneys = []  # {building, offset, seed, soot, base, on, until, strength}
var _people: Array[Person] = []
var _dangers = []  # [Vector3 where, float until]
var _smoke_layer = null
var _smoke_material = null
var _folk_layer = null
var _hidden = false

@onready var _match = find_parent("Match")


func _ready():
	_config = GameData.city_life()
	_rng.randomize()
	_smoke_layer = _make_smoke_layer()
	_folk_layer = _make_folk_layer()
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.camera_shake.connect(_on_blast)


func _process(delta):
	if delta <= 0.0:
		return
	_time += delta
	_since_refresh += delta
	if _since_refresh >= REFRESH_S:
		var step = _since_refresh
		_since_refresh = 0.0
		_read_weather()
		_find_buildings()
		_update_chimneys(step)
		_spawn_townsfolk()
		_hidden = _zoomed_out()
	_walk_townsfolk(delta)


func sightings(kind = "townsfolk"):
	"""where to look for "townsfolk" (walking ones first) or "smoke" (workshops first); for
	the play harness and screenshots"""
	var found = []
	if kind == "smoke":
		for chimney in _chimneys:
			if chimney.strength > 0.3:
				found.append(chimney.building.global_transform * chimney.offset)
		return found
	for person in _people:
		if person.chat_until < 0.0:
			found.push_front(person.pos)
		else:
			found.append(person.pos)
	return found


func _read_weather():
	var atmosphere = get_tree().get_first_node_in_group("atmosphere")
	if atmosphere == null:
		return
	_wind = atmosphere.get_wind()
	_rain = atmosphere.get_rain_intensity()
	_smoke_material.set_shader_parameter("wind", _wind)


func _zoomed_out():
	var camera = get_viewport().get_camera_3d() if is_inside_tree() else null
	return (
		camera != null
		and camera.projection == Camera3D.PROJECTION_ORTHOGONAL
		and camera.size > HIDE_ABOVE_CAMERA_SIZE
	)


# buildings and chimneys


func _find_buildings():
	var seen = {}
	for building in get_tree().get_nodes_in_group("city_buildings"):
		var id = building.get_instance_id()
		seen[id] = true
		if not _buildings.has(id):
			_buildings[id] = {
				"node": building,
				"next_folk_s": _time + _range(_config["townsfolk"]["spawn_every_s"]) * 0.5,
			}
			_add_chimney(building)
	for id in _buildings.keys():
		if not seen.has(id):
			_buildings.erase(id)
	var before = _chimneys.size()
	_chimneys = _chimneys.filter(
		func(chimney):
			return is_instance_valid(chimney.building) and chimney.building.is_inside_tree()
	)
	if _chimneys.size() != before:
		_smoke_layer.multimesh.instance_count = 0


func _add_chimney(building):
	var smoke = _config["smoke"]
	var offset = smoke["chimneys"].get(_model_name(building))
	if offset == null:
		return
	var settings = smoke["workshop" if building.kind == "workshop" else "house"]
	var on = _rng.randf() < float(settings["chance"])
	(
		_chimneys
		. append(
			{
				"building": building,
				"offset": Vector3(offset[0], offset[1], offset[2]),
				"seed": _rng.randf(),
				"soot": float(settings["soot"]) * _rng.randf_range(0.85, 1.0),
				"base": float(settings["strength"]) * _rng.randf_range(0.8, 1.0),
				"settings": settings,
				"on": on,
				"until": _time + _range(settings["on_s" if on else "off_s"]),
				"strength": 0.0,
			}
		)
	)
	_smoke_layer.multimesh.instance_count = 0  # rebuilt with the new chimney below


func _model_name(building):
	var models = Constants.Match.City.BUILDING_MODELS.get(building.kind, [])
	if models.is_empty() or building.variant < 0:
		return ""
	return models[building.variant % models.size()].get_file().get_basename()


func _update_chimneys(step):
	var fade = float(_config["smoke"]["fade_per_s"]) * step
	for chimney in _chimneys:
		if _time >= chimney.until:
			chimney.on = not chimney.on
			chimney.until = _time + _range(chimney.settings["on_s" if chimney.on else "off_s"])
		var target = chimney.base if chimney.on and chimney.building.visible else 0.0
		target *= 1.0 - 0.6 * _rain  # rain damps the fires down
		chimney.strength = move_toward(chimney.strength, target, fade)
	var multimesh = _smoke_layer.multimesh
	if multimesh.instance_count != _chimneys.size():
		multimesh.instance_count = _chimneys.size()
	if _chimneys.is_empty():
		return
	var buffer = PackedFloat32Array()
	buffer.resize(_chimneys.size() * FLOATS_PER_INSTANCE)
	var index = 0
	for chimney in _chimneys:
		var at = chimney.building.global_transform * chimney.offset
		var i = index * FLOATS_PER_INSTANCE
		buffer[i] = 1.0
		buffer[i + 3] = at.x
		buffer[i + 5] = 1.0
		buffer[i + 7] = at.y
		buffer[i + 10] = 1.0
		buffer[i + 11] = at.z
		buffer[i + 12] = chimney.seed
		buffer[i + 13] = chimney.strength
		buffer[i + 14] = chimney.soot
		index += 1
	multimesh.buffer = buffer


# townsfolk


func _spawn_townsfolk():
	var folk = _config["townsfolk"]
	if _hidden or _people.size() >= int(folk["max"]):
		return
	var per_city = {}
	for person in _people:
		per_city[person.city_id] = per_city.get(person.city_id, 0) + 1
	for entry in _buildings.values():
		if _time < entry.next_folk_s:
			continue
		entry.next_folk_s = _time + _range(folk["spawn_every_s"])
		var building = entry.node
		if (
			not is_instance_valid(building)
			or not building.visible
			or _in_danger(building.global_position)
		):
			continue
		var city = building.get_parent()
		var city_id = city.get_instance_id()
		if per_city.get(city_id, 0) >= int(folk["max_per_city"]):
			continue
		var path = _plan_errand(building, city)
		if path.is_empty():
			continue
		var person = Person.new()
		person.pos = path[0]
		person.path = path.slice(1)
		person.speed = float(folk["walk_speed"]) * _rng.randf_range(0.8, 1.15)
		person.robe = _rng.randi_range(0, ROBES.size() - 1) / 8.0
		person.scarf = _rng.randi_range(0, SCARVES.size() - 1) / 8.0
		person.cycle = _rng.randf()
		person.city_id = city_id
		_people.append(person)
		per_city[city_id] = per_city.get(city_id, 0) + 1
		if _people.size() >= int(folk["max"]):
			return


func _plan_errand(building, city):
	"""a walk out of the building's door to a neighbour's, the city centre or just down the
	street and back; empty when every way out is blocked"""
	var home = building.global_position
	var obstacles = _obstacles_near(home)
	var targets = []
	var reach = float(_config["townsfolk"]["reach_m"])
	for other in get_tree().get_nodes_in_group("city_buildings"):
		if other != building and other.visible and other.global_position.distance_to(home) <= reach:
			targets.append([other.global_position, DOOR_OUT_M, DOOR_IN_M, other])
	if city.has_method("get_core"):
		var core = city.get_core()
		if core != null and core.global_position.distance_to(home) <= reach * 1.5:
			var radius = core.radius if core.radius != null else 2.0
			targets.append([core.global_position, radius + 0.25, radius * 0.6, core])
	targets.shuffle()
	if _rng.randf() >= float(_config["townsfolk"]["stroll_chance"]):
		for target in targets:
			var path = _route(home, building, target[0], target[1], target[2], target[3], obstacles)
			if not path.is_empty():
				return path
	# a stroll down the street, then back home
	for attempt in range(6):
		var away = (
			home
			+ Vector3.FORWARD.rotated(Vector3.UP, _rng.randf() * TAU) * _rng.randf_range(2.2, 3.6)
		)
		var door = _door(home, away, DOOR_OUT_M)
		if _clear(door, away, obstacles, [building]):
			return [_door(home, away, DOOR_IN_M), door, away, door, _door(home, away, DOOR_IN_M)]
	return []


func _route(home, building, to, out_m, in_m, target, obstacles):
	var start_in = _door(home, to, DOOR_IN_M)
	var start = _door(home, to, DOOR_OUT_M)
	var end = _door(to, home, out_m)
	var end_in = _door(to, home, in_m)
	var ignore = [building, target]
	if _clear(start, end, obstacles, ignore):
		return [start_in, start, end, end_in]
	# round the obstacle on one side or the other
	var middle = (start + end) * 0.5
	var across = (end - start).cross(Vector3.UP).normalized()
	for side in [2.2, -2.2, 3.4, -3.4]:
		var via = middle + across * side
		var start_via = _door(home, via, DOOR_OUT_M)
		var end_via = _door(to, via, out_m)
		if _clear(start_via, via, obstacles, ignore) and _clear(via, end_via, obstacles, ignore):
			return [_door(home, via, DOOR_IN_M), start_via, via, end_via, _door(to, via, in_m)]
	return []


func _door(center: Vector3, toward: Vector3, distance: float) -> Vector3:
	var direction = toward - center
	direction.y = 0.0
	if direction.length_squared() < 0.0001:
		direction = Vector3.FORWARD
	return center + direction.normalized() * distance


func _obstacles_near(at: Vector3):
	var near = []
	for building in get_tree().get_nodes_in_group("city_buildings"):
		if building.global_position.distance_to(at) < 20.0:
			near.append([building, BUILDING_BLOCK_M])
	for unit in get_tree().get_nodes_in_group("units"):
		if unit.global_position.distance_to(at) < 20.0:
			near.append([unit, (unit.radius if unit.radius != null else 0.6) + 0.2])
	return near


func _clear(from: Vector3, to: Vector3, obstacles, ignore) -> bool:
	var a = Vector2(from.x, from.z)
	var b = Vector2(to.x, to.z)
	for obstacle in obstacles:
		var node = obstacle[0]
		if node in ignore or not is_instance_valid(node):
			continue
		var center = Vector2(node.global_position.x, node.global_position.z)
		var closest = Geometry2D.get_closest_point_to_segment(center, a, b)
		if closest.distance_to(center) < obstacle[1]:
			return false
	return true


func _walk_townsfolk(delta):
	var index = 0
	while index < _people.size():
		var person = _people[index]
		if _step(person, delta):
			index += 1
		else:
			_people.remove_at(index)
	var multimesh = _folk_layer.multimesh
	_folk_layer.visible = not _hidden and not _people.is_empty()
	if not _folk_layer.visible:
		return
	if multimesh.instance_count != _people.size():
		multimesh.instance_count = _people.size()
	var scale = float(_config["townsfolk"]["height_m"]) / FOLK_MESH_HEIGHT_M
	var buffer = PackedFloat32Array()
	buffer.resize(_people.size() * FLOATS_PER_INSTANCE)
	var i = 0
	for person in _people:
		var basis = Basis(Vector3.UP, person.yaw).scaled(Vector3.ONE * scale)
		buffer[i] = basis.x.x
		buffer[i + 1] = basis.y.x
		buffer[i + 2] = basis.z.x
		buffer[i + 3] = person.pos.x
		buffer[i + 4] = basis.x.y
		buffer[i + 5] = basis.y.y
		buffer[i + 6] = basis.z.y
		buffer[i + 7] = person.pos.y
		buffer[i + 8] = basis.x.z
		buffer[i + 9] = basis.y.z
		buffer[i + 10] = basis.z.z
		buffer[i + 11] = person.pos.z
		buffer[i + 12] = person.cycle
		var moving = person.chat_until < 0.0 or _time >= person.chat_until
		buffer[i + 13] = (1.0 if person.running else 0.5) if moving else 0.0
		buffer[i + 14] = person.robe
		buffer[i + 15] = person.scarf
		i += FLOATS_PER_INSTANCE
	multimesh.buffer = buffer


func _step(person: Person, delta) -> bool:
	"""moves a person along their path; false once they are indoors"""
	if person.path.is_empty():
		return false
	if person.chat_until >= 0.0 and _time < person.chat_until:
		return true
	var target: Vector3 = person.path[0]
	var to_target = target - person.pos
	to_target.y = 0.0
	var distance = to_target.length()
	var travel = person.speed * delta
	if distance > 0.001:
		var heading = atan2(to_target.x, to_target.z)
		person.yaw = lerp_angle(person.yaw, heading, minf(1.0, delta * 10.0))
	person.cycle = fmod(person.cycle + travel / (STEP_LENGTH_M * 2.0), 1.0)
	if travel >= distance:
		person.pos = target
		person.path.pop_front()
		# a chat on the doorstep before going in, unless running for cover
		if person.path.size() == 1 and not person.running and not person.chatted:
			person.chatted = true
			person.chat_until = _time + _range(_config["townsfolk"]["chat_s"])
		return not person.path.is_empty()
	person.pos += to_target / distance * travel
	person.pos.y = lerpf(person.pos.y, target.y, minf(1.0, travel / maxf(distance, 0.001)))
	return true


func _on_unit_damaged(unit):
	if is_instance_valid(unit):
		_alarm(unit.global_position)


func _on_blast(strength, at):
	if at is Vector3 and strength > 0.2:
		_alarm(at)


func _alarm(at: Vector3):
	var folk = _config["townsfolk"]
	var radius = float(folk["scare_m"])
	_dangers = _dangers.filter(func(danger): return danger[1] > _time)
	_dangers.append([at, _time + _range(folk["hide_s"])])
	for person in _people:
		if person.running or person.pos.distance_to(at) > radius:
			continue
		var shelter = _nearest_building(person.pos)
		if shelter == null:
			continue
		person.running = true
		person.chat_until = -1.0
		person.speed = float(folk["run_speed"]) * _rng.randf_range(0.85, 1.1)
		var center = shelter.global_position
		person.path = [_door(center, person.pos, DOOR_OUT_M), _door(center, person.pos, DOOR_IN_M)]


func _in_danger(at: Vector3) -> bool:
	var radius = float(_config["townsfolk"]["scare_m"])
	for danger in _dangers:
		if danger[1] > _time and danger[0].distance_to(at) <= radius * 1.5:
			return true
	return false


func _nearest_building(at: Vector3):
	var best = null
	var best_distance = INF
	for building in get_tree().get_nodes_in_group("city_buildings"):
		var distance = building.global_position.distance_to(at)
		if distance < best_distance:
			best = building
			best_distance = distance
	return best


# meshes


func _make_smoke_layer():
	_smoke_material = ShaderMaterial.new()
	_smoke_material.shader = SmokeShader
	_smoke_material.set_shader_parameter(
		"column_height", float(_config["smoke"]["column_height_m"])
	)
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var data = PackedVector2Array()
	var indices = PackedInt32Array()
	for puff in range(SMOKE_PUFFS):
		var puff_data = Vector2(float(puff) / SMOKE_PUFFS, _rng.randf())
		var first = vertices.size()
		for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]:
			vertices.append(Vector3.ZERO)
			uvs.append(corner)
			data.append(puff_data)
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = data
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _smoke_material)
	# the puffs are moved in the shader, so the mesh says how far they can go
	mesh.custom_aabb = AABB(Vector3(-7, -0.5, -7), Vector3(14, 5, 14))
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	var layer = MultiMeshInstance3D.new()
	layer.name = "ChimneySmoke"
	layer.multimesh = multimesh
	layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(layer)
	return layer


func _make_folk_layer():
	var material = ShaderMaterial.new()
	material.shader = FolkShader
	var robes = PackedColorArray(ROBES)
	var scarves = PackedColorArray(SCARVES)
	material.set_shader_parameter("robes", _to_vec3s(robes))
	material.set_shader_parameter("scarves", _to_vec3s(scarves))
	var tool = SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# legs, then arms, robe, head and scarf; UV.x says which part, .y which side
	for side in [0.0, 1.0]:
		var x = -0.022 if side == 0.0 else 0.022
		_add_box(tool, Vector3(x, 0.075, 0.0), Vector3(0.028, 0.15, 0.03), Vector2(0.0, side))
		var arm_x = -0.058 if side == 0.0 else 0.058
		_add_box(tool, Vector3(arm_x, 0.2, 0.0), Vector3(0.024, 0.11, 0.026), Vector2(0.25, side))
	_add_frustum(tool, 0.09, 0.055, 0.035, 0.27, 6, Vector2(0.5, 0.5))
	_add_frustum(tool, 0.268, 0.032, 0.03, 0.335, 6, Vector2(0.75, 0.5))
	_add_frustum(tool, 0.312, 0.037, 0.02, 0.362, 6, Vector2(1.0, 0.5))
	tool.generate_normals()
	var mesh = tool.commit()
	mesh.surface_set_material(0, material)
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	var layer = MultiMeshInstance3D.new()
	layer.name = "Townsfolk"
	layer.multimesh = multimesh
	add_child(layer)
	return layer


func _to_vec3s(colors: PackedColorArray) -> PackedVector3Array:
	var vectors = PackedVector3Array()
	for color in colors:
		vectors.append(Vector3(color.r, color.g, color.b))
	return vectors


func _add_box(tool: SurfaceTool, center: Vector3, size: Vector3, part: Vector2):
	var h = size * 0.5
	var corners = []
	for i in range(8):
		corners.append(
			center + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		)
	# each face counter-clockwise seen from outside
	for face in [
		[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]
	]:
		_add_quad(
			tool, corners[face[0]], corners[face[1]], corners[face[2]], corners[face[3]], part
		)


func _add_frustum(
	tool: SurfaceTool,
	bottom: float,
	r_bottom: float,
	r_top: float,
	top: float,
	sides: int,
	part: Vector2
):
	"""a closed n-sided frustum standing on the y axis"""
	for i in range(sides):
		var a0 = TAU * i / sides
		var a1 = TAU * (i + 1) / sides
		var b0 = Vector3(cos(a0) * r_bottom, bottom, sin(a0) * r_bottom * 0.8)
		var b1 = Vector3(cos(a1) * r_bottom, bottom, sin(a1) * r_bottom * 0.8)
		var t0 = Vector3(cos(a0) * r_top, top, sin(a0) * r_top * 0.8)
		var t1 = Vector3(cos(a1) * r_top, top, sin(a1) * r_top * 0.8)
		_add_quad(tool, b0, t0, t1, b1, part)
		_add_triangle(tool, Vector3(0, top, 0), t1, t0, part)
		_add_triangle(tool, Vector3(0, bottom, 0), b0, b1, part)


func _add_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, part: Vector2):
	_add_triangle(tool, a, b, c, part)
	_add_triangle(tool, a, c, d, part)


func _add_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, part: Vector2):
	for vertex in [a, b, c]:
		tool.set_uv(part)
		tool.add_vertex(vertex)


func _range(pair):
	return _rng.randf_range(float(pair[0]), float(pair[1]))
