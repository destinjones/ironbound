extends Node3D

# A lightning bolt in view: a jagged, branching ribbon from the clouds to the ground with a
# short blue-white light where it lands. Atmosphere.gd calls strike() during heavy rain.
# The bolt flickers twice (a return stroke), then fades; nothing runs between strikes.

signal struck(world_position)

const BOLT_TOP = 34.0
const SEGMENTS = 24
const WIDTH = 0.18
const LIFETIME_S = 0.42
const FLICKER_GAP_S = Vector2(0.07, 0.15)
const LIGHT_ENERGY = 9.0
const LIGHT_RANGE = 22.0
const COLOR = Color(0.82, 0.88, 1.0)

var _rng = RandomNumberGenerator.new()
var _age = LIFETIME_S
var _bolt = MeshInstance3D.new()
var _light = OmniLight3D.new()
var _material = StandardMaterial3D.new()


func _ready():
	_rng.randomize()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = COLOR
	_bolt.material_override = _material
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	add_child(_bolt)
	_light.light_color = COLOR
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	_light.visible = false
	add_child(_light)
	set_process(false)


func strike(ground_position: Vector3):
	var camera = get_viewport().get_camera_3d()
	var towards_camera = Vector3.BACK if camera == null else camera.global_transform.basis.z
	_bolt.mesh = _build_bolt(ground_position, towards_camera)
	_light.global_position = ground_position + Vector3(0.0, 3.0, 0.0)
	_age = 0.0
	_bolt.visible = true
	_light.visible = true
	set_process(true)
	struck.emit(ground_position)


func _process(delta):
	_age += delta
	if _age >= LIFETIME_S:
		_bolt.visible = false
		_light.visible = false
		set_process(false)
		return
	# bright, a dark gap, a second stroke, then a fade
	var t = _age / LIFETIME_S
	var gap = t > FLICKER_GAP_S.x / LIFETIME_S and t < FLICKER_GAP_S.y / LIFETIME_S
	var brightness = 0.0 if gap else (1.0 - smoothstep(0.4, 1.0, t))
	_material.albedo_color = Color(COLOR, brightness)
	_light.light_energy = LIGHT_ENERGY * brightness


func _build_bolt(ground, towards_camera):
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var top = ground + Vector3(_rng.randf_range(-6.0, 6.0), BOLT_TOP, _rng.randf_range(-6.0, 6.0))
	var points = _jagged(top, ground, SEGMENTS, 2.6)
	_ribbon(mesh, points, towards_camera, WIDTH)
	for i in range(_rng.randi_range(1, 3)):
		var from_index = _rng.randi_range(2, SEGMENTS / 2)
		var start = points[from_index]
		var away = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0))
		var end = start + away.normalized() * _rng.randf_range(5.0, 10.0) + Vector3.DOWN * 8.0
		_ribbon(mesh, _jagged(start, end, 10, 1.0), towards_camera, WIDTH * 0.5)
	mesh.surface_end()
	return mesh


func _jagged(from, to, segments, spread):
	"""a random walk around the straight line, pulled back to it so the bolt ends on target"""
	var points = [from]
	var drift = Vector3.ZERO
	for i in range(1, segments):
		var step = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * spread
		var pull = 1.0 - float(i) / segments
		drift = (drift + step) * (0.6 + 0.4 * pull)
		points.append(from.lerp(to, float(i) / segments) + drift * pull)
	points.append(to)
	return points


func _ribbon(mesh, points, towards_camera, width):
	"""a strip that faces the camera, a soft wide glow under a thin bright core"""
	for layer in [[width * 7.0, 0.12], [width * 2.5, 0.3], [width, 1.0]]:
		for i in range(points.size() - 1):
			var a = points[i]
			var b = points[i + 1]
			var side = (b - a).cross(towards_camera).normalized() * layer[0] * 0.5
			var color = Color(1.0, 1.0, 1.0, layer[1])
			for vertex in [a - side, a + side, b + side, a - side, b + side, b - side]:
				mesh.surface_set_color(color)
				mesh.surface_add_vertex(vertex)
