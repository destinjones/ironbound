extends Node

# One node decides when every health bar shows: the Options toggle (Globals.options
# .show_health_bars) or the show_health_bars key held (Alt). It polls once a frame and tells
# the bars through MatchSignals.health_bars_forced when the answer changes, so no bar polls
# Input itself. Added to HUD by Match.gd; a bar that starts later reads `forced` from of().

const ACTION = "show_health_bars"

var forced = false

var _bound = false


static func of(tree):
	return tree.get_first_node_in_group("health_bars_control")


func _ready():
	add_to_group("health_bars_control")
	_bound = InputMap.has_action(ACTION)


func _process(_delta):
	var on = Globals.options.show_health_bars or (_bound and Input.is_action_pressed(ACTION))
	if on != forced:
		forced = on
		MatchSignals.health_bars_forced.emit(on)
