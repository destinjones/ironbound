extends Node3D

# A cannon shot: the damage lands at once (shells are hitscan) and the visuals follow a physics
# frame later. ShotEffects draws the one muzzle effect (flash, smoke, recoil) and the tracer;
# none of it hangs off this node, so the node frees itself as soon as they are drawn.

const ShotEffects = preload("res://source/match/units/projectiles/ShotEffects.gd")

var target_unit = null

@onready var _unit = get_parent()


func _ready():
	assert(target_unit != null, "target unit was not provided")
	_draw_shot()
	if not is_instance_valid(target_unit) or not is_instance_valid(_unit):
		return
	target_unit.take_damage(_unit.attack_damage, _unit)


func _draw_shot():
	await get_tree().physics_frame  # wait for rotation to kick in if remote transform is used
	if is_instance_valid(target_unit) and is_instance_valid(_unit):
		var origin = _unit.find_child("ProjectileOrigin")
		var muzzle = _unit.global_transform if origin == null else origin.global_transform
		ShotEffects.cannon_shot(_unit, muzzle, target_unit)
	queue_free()
