extends "res://source/match/players/Player.gd"

const Helper = preload("res://source/match/players/human/Helper.gd")
const IdleConstructors = preload("res://source/match/players/human/IdleConstructors.gd")
const HomeGuard = preload("res://source/match/players/human/HomeGuard.gd")


func _ready():
	var helper = Helper.new()
	helper.name = Helper.NODE_NAME
	add_child(helper)
	var idle_constructors = IdleConstructors.new()
	idle_constructors.name = IdleConstructors.NODE_NAME
	add_child(idle_constructors)
	var home_guard = HomeGuard.new()
	home_guard.name = HomeGuard.NODE_NAME
	add_child(home_guard)
