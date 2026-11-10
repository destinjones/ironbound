extends Node3D

# Ball lightning: a pale ball that appears in the sky, hangs there for a few seconds with
# small arcs crawling off it, then bursts in a flash. Atmosphere.gd calls appear() now and
# then under looks that ask for it. Nothing runs between appearances.

signal burst(world_position)  # the moment it goes off

const Lightning = preload("res://source/match/environment/Lightning.gd")

const HANG_S = Vector2(3.5, 6.5)
const GROW_S = 0.7
const BURST_S = 0.5
const RADIUS = 0.55
const HALO_SIZE = 7.0
const ARC_COUNT = 4
const BURST_ARC_COUNT = 7
const ARC_REFRESH_S = 0.07
const ARC_LENGTH = Vector2(1.4, 3.2)
const ARC_WIDTH = 0.07
# thin arcs with a narrow glow: the wide glow of a bolt reads as paper strips this close up
const ARC_LAYERS = [[2.6, 0.22], [1.0, 1.0]]
const BURST_REACH = 2.2  # how much further the burst throws its arcs
const DRIFT_SPEED = 0.7
const LIGHT_ENERGY = 3.0
const BURST_LIGHT_ENERGY = 12.0
const LIGHT_RANGE = 28.0
const COLOR = Color(0.78, 0.88, 1.0)

var _rng = RandomNumberGenerator.new()
var _age = 0.0
var _hang_s = 0.0
var _arc_timer = 0.0
var _drift = Vector3.ZERO
var _has_burst = false
var _core = MeshInstance3D.new()
var _halo = MeshInstance3D.new()
var _arcs = MeshInstance3D.new()
var _light = OmniLight3D.new()
var _core_material = _glowing_material()
var _halo_material = _glowing_material()
var _arc_material = _glowing_material()


func _ready():
	_rng.randomize()
	var ball = SphereMesh.new()
	ball.radius = RADIUS
	ball.height = RADIUS * 2.0
	ball.radial_segments = 16
	ball.rings = 8
	_core.mesh = ball
	_core.material_override = _core_material
	# a soft glow around the ball: a quad that faces the camera, bright in the middle
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 0.55))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var glow = GradientTexture2D.new()
	glow.gradient = gradient
	glow.fill = GradientTexture2D.FILL_RADIAL
	glow.fill_from = Vector2(0.5, 0.5)
	glow.fill_to = Vector2(1.0, 0.5)
	var quad = QuadMesh.new()
	quad.size = Vector2(HALO_SIZE, HALO_SIZE)
	_halo.mesh = quad
	_halo_material.albedo_texture = glow
	_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_halo.material_override = _halo_material
	_arc_material.vertex_color_use_as_albedo = true
	_arcs.material_override = _arc_material
	_light.light_color = COLOR
	_light.omni_range = LIGHT_RANGE
	_light.shadow_enabled = false
	for node in [_core, _halo, _arcs, _light]:
		if node is GeometryInstance3D:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	visible = false
	set_process(false)


func is_active():
	return is_processing()


func appear(sky_position: Vector3):
	global_position = sky_position
	_age = 0.0
	_hang_s = _rng.randf_range(HANG_S.x, HANG_S.y)
	_arc_timer = 0.0
	_has_burst = false
	_drift = Vector3.RIGHT.rotated(Vector3.UP, _rng.randf_range(0.0, TAU)) * DRIFT_SPEED
	_show(0.0, 0.0, 1.0)
	visible = true
	set_process(true)


func _process(delta):
	_age += delta
	if _age >= _hang_s + BURST_S:
		visible = false
		set_process(false)
		return
	if _age < _hang_s:
		# it swells into being, then wanders and flickers
		global_position += (_drift + Vector3.UP * sin(_age * 2.3) * 0.4) * delta
		var grown = smoothstep(0.0, GROW_S, _age)
		var flicker = 0.82 + 0.18 * sin(_age * 31.0) * sin(_age * 17.3)
		_show(
			grown * flicker, LIGHT_ENERGY * grown * flicker, grown * (1.0 + 0.06 * sin(_age * 9.0))
		)
	else:
		if not _has_burst:
			_has_burst = true
			_arc_timer = 0.0
			burst.emit(global_position)
		var t = (_age - _hang_s) / BURST_S
		var fade = 1.0 - smoothstep(0.1, 1.0, t)
		# the ball itself is gone early in the burst; its glow and arcs carry the rest
		_show(fade, BURST_LIGHT_ENERGY * fade, 1.0 + t * 3.0, 1.0 - smoothstep(0.0, 0.4, t))
	_arc_timer -= delta
	if _arc_timer <= 0.0:
		_arc_timer = ARC_REFRESH_S
		_arcs.mesh = _build_arcs()


func _show(brightness, light_energy, size, core = 1.0):
	_core_material.albedo_color = Color(COLOR.lerp(Color.WHITE, 0.6), brightness * core)
	_halo_material.albedo_color = Color(COLOR, brightness)
	_arc_material.albedo_color = Color(COLOR, brightness)
	_light.light_energy = light_energy
	_core.scale = Vector3.ONE * max(size, 0.01)
	_halo.scale = Vector3.ONE * max(size, 0.01)


func _build_arcs():
	"""short jagged arcs from the ball outwards, drawn anew every few frames so they crawl;
	the burst throws more of them further"""
	var camera = get_viewport().get_camera_3d()
	var towards_camera = Vector3.BACK if camera == null else camera.global_transform.basis.z
	# the burst throws its arcs outwards over its first moments
	var burst_t = clamp((_age - _hang_s) / BURST_S, 0.0, 1.0)
	var reach = lerp(1.0, BURST_REACH, smoothstep(0.0, 0.35, burst_t))
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(BURST_ARC_COUNT if _has_burst else ARC_COUNT):
		var direction = Vector3(
			_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 0.6), _rng.randf_range(-1.0, 1.0)
		)
		direction = Vector3.DOWN if direction.length() < 0.2 else direction.normalized()
		var end = direction * _rng.randf_range(ARC_LENGTH.x, ARC_LENGTH.y) * reach
		var points = Lightning.jagged(_rng, direction * RADIUS * 0.5, end, 6, 0.35 * reach)
		Lightning.ribbon(mesh, points, towards_camera, ARC_WIDTH, ARC_LAYERS)
	mesh.surface_end()
	return mesh


static func _glowing_material():
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(COLOR, 0.0)
	return material
