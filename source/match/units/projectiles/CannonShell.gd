extends Node3D

# A cannon shot: the damage lands at once (shells are hitscan) and the visuals follow a physics
# frame later. ShotEffects draws the one muzzle effect (flash, smoke, recoil) and the tracer;
# none of it hangs off this node, so the node frees itself as soon as they are drawn. A killing
# shot is drawn at once instead: its target starts its death explosion in this frame and leaves
# the tree at the end of it. The aim point is taken before the damage, so a shot whose target
# is killed by another shot before the next physics frame still flies to where it was.

const ShotEffects = preload("res://source/match/units/projectiles/ShotEffects.gd")

var target_unit = null

@onready var _unit = get_parent()


func _ready():
	assert(target_unit != null, "target unit was not provided")
	if not is_instance_valid(target_unit) or not is_instance_valid(_unit):
		queue_free()
		return
	var aim_point_before_hit = ShotEffects.aim_point(target_unit)
	target_unit.take_damage(_unit.attack_damage, _unit)
	if not is_instance_valid(target_unit) or target_unit.is_queued_for_deletion():
		ShotEffects.cannon_shot(_unit, ShotEffects.muzzle(_unit), target_unit, aim_point_before_hit)
		queue_free()
		return
	_draw_shot(aim_point_before_hit)


func _draw_shot(aim_point_before_hit):
	await get_tree().physics_frame  # wait for rotation to kick in if remote transform is used
	if is_instance_valid(_unit):
		ShotEffects.cannon_shot(_unit, ShotEffects.muzzle(_unit), target_unit, aim_point_before_hit)
	queue_free()
