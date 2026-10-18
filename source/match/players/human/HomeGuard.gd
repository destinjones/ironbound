extends Node

# Sends the human player's idle fighting units to answer a hit on one of their own units or
# structures nearby. Before, fifteen tanks stood at the rally point while raiders took the
# mines 20 m away: an idle unit only answers what walks into its own sight (10 m for a tank).
# A unit counts as idle when it waits for targets with nothing to shoot, is not holding
# position and may fire at will; a unit the player sent somewhere is left alone. Responders
# attack-move to the attacker, so they engage whatever they meet on the way, and once the
# fight is over they attack-move back to where they stood, so the army stays together
# between raids instead of being drawn out piece by piece. A spot that was answered a moment
# ago does not pull more units. A responder the player gives any order to (a stop, a
# stance, a move) is theirs again and stays where it is.

const Structure = preload("res://source/match/units/Structure.gd")
const WaitingForTargets = preload("res://source/match/units/actions/WaitingForTargets.gd")
const AttackMoving = preload("res://source/match/units/actions/AttackMoving.gd")
const Stances = preload("res://source/match/units/actions/Stances.gd")
const Diplomacy = preload("res://source/match/diplomacy/Diplomacy.gd")

const NODE_NAME = "HomeGuard"
const RESPONSE_RADIUS_M = 30.0  # idle units this far from the fight go there
const MAX_RESPONDERS = 8  # per hit, the closest first
const ANSWERED_FOR_S = 8.0  # a spot answered this recently pulls no more units
const RETRY_FOR_S = 2.0  # a spot nobody was free for is looked at again this much later
const ANSWERED_CELL_M = 12.0
const POST_CHECK_S = 1.0  # how often responders with nothing left to do are sent back
const BACK_AT_POST_M = 4.0
# a responder that stands idle farther than this from where it was sent did not get there
# on its own account: the player stopped it, or the way was blocked
const ORDER_DONE_M = 8.0
const CALL_UP_META = "home_guard"  # marks the orders this node gave, not the player's

var _answered = {}  # Vector2i cell -> clock until which no more units are sent there
# responder instance id -> {"unit", "at" (where it stood), "sent_to", "returning"}
var _posts = {}
var _clock_s = 0.0
var _since_post_check_s = 0.0

@onready var _player = get_parent()


func _ready():
	MatchSignals.unit_damaged.connect(_on_unit_damaged)
	MatchSignals.unit_command_issued.connect(_on_player_command)


func _process(delta):
	_clock_s += delta
	_since_post_check_s += delta
	if _since_post_check_s >= POST_CHECK_S:
		_since_post_check_s = 0.0
		_send_back_the_idle()


func _on_unit_damaged(unit):
	if not is_instance_valid(unit) or unit.player != _player or not unit.is_inside_tree():
		return
	var attacker = unit.get_meta("last_hit_by", null)
	if (
		attacker == null
		or not is_instance_valid(attacker)
		or not attacker.is_inside_tree()
		or not "player" in attacker
		or attacker.player == _player
		or not Diplomacy.engages_on_sight(_player, attacker.player)
	):
		return
	var spot = attacker.global_position_yless
	var cell = Vector2i(floor(spot.x / ANSWERED_CELL_M), floor(spot.z / ANSWERED_CELL_M))
	if _clock_s < _answered.get(cell, -INF):
		return
	var responders = _idle_fighters_near(spot, attacker)
	# hits come many times a second in a battle; a cell is looked at again only after a
	# while, so this does not scan every unit of the match on each one
	_answered[cell] = _clock_s + (RETRY_FOR_S if responders.is_empty() else ANSWERED_FOR_S)
	for responder in responders:
		var id = responder.get_instance_id()
		if not id in _posts:
			_posts[id] = {"unit": responder, "at": responder.global_position_yless}
		_posts[id]["sent_to"] = spot
		_posts[id]["returning"] = false
		responder.action = _call_up(spot)


func _on_player_command(_command):
	"""any order the player gives to a responder (a stop, a stance, a move) makes it theirs
	again, whatever state it is in; the orders go to the selected units"""
	for unit in get_tree().get_nodes_in_group("selected_units"):
		_posts.erase(unit.get_instance_id())


func _call_up(spot):
	var action = AttackMoving.new(spot)
	action.set_meta(CALL_UP_META, true)
	return action


func _send_back_the_idle():
	"""a responder that got where it was sent and has nothing left to shoot goes back to
	where it stood; one the player has stopped, redirected or told to hold is theirs again"""
	for id in _posts.keys():
		var entry = _posts[id]
		var unit = entry["unit"]
		if not is_instance_valid(unit) or not unit.is_inside_tree():
			_posts.erase(id)
			continue
		if unit.action is AttackMoving and unit.action.has_meta(CALL_UP_META):
			continue  # on the way, fighting, or walking back
		if not unit.action is WaitingForTargets or not _may_be_sent(unit):
			_posts.erase(id)  # a new order or stance from the player
			continue
		if not unit.action.is_idle():
			continue  # shooting what it sees
		_posts.erase(id)
		var here = unit.global_position_yless
		if here.distance_to(entry["sent_to"]) > ORDER_DONE_M:
			continue  # stopped by the player (or the way was blocked): it stays
		if not entry["returning"] and here.distance_to(entry["at"]) > BACK_AT_POST_M:
			entry["returning"] = true
			entry["sent_to"] = entry["at"]
			_posts[id] = entry
			unit.action = _call_up(entry["at"])


func _idle_fighters_near(spot, attacker):
	"""measured from where each unit stood before it was called up, so a unit that has just
	finished one fight is not drawn from there to the next, and the next, across the map"""
	var fighters = []
	for unit in get_tree().get_nodes_in_group("units"):
		if not _is_idle_fighter(unit) or not attacker.movement_domain in unit.attack_domains:
			continue
		if not _can_reach(unit, attacker) or _post_of(unit).distance_to(spot) > RESPONSE_RADIUS_M:
			continue
		fighters.append(unit)
	fighters.sort_custom(
		func(a, b):
			return (
				a.global_position_yless.distance_to(spot)
				< b.global_position_yless.distance_to(spot)
			)
	)
	return fighters.slice(0, MAX_RESPONDERS)


func _post_of(unit):
	var entry = _posts.get(unit.get_instance_id())
	return entry["at"] if entry != null else unit.global_position_yless


func _is_idle_fighter(unit):
	"""an armed, mobile unit of ours that waits with nothing to do and may fire at will"""
	if unit.player != _player or unit is Structure or not unit.is_in_group("controlled_units"):
		return false
	if unit.attack_range == null or unit.movement_speed <= 0.0:
		return false
	if not unit.action is WaitingForTargets or not unit.action.is_idle():
		return false
	return _may_be_sent(unit) and AttackMoving.is_applicable(unit)


static func _may_be_sent(unit):
	"""the stances the player set win: a unit holding position or holding fire stays"""
	return not Stances.holds_position(unit) and Stances.fire_stance(unit) == Stances.Fire.AT_WILL


static func _can_reach(unit, attacker):
	"""a tank does not drive at a boat, nor a boat at a tank inland; aircraft, amphibious
	units and attackers in the air are reachable from anywhere"""
	var air = Constants.Match.Navigation.Domain.AIR
	var amphibious = Constants.Match.Navigation.Domain.AMPHIBIOUS
	if unit.movement_domain == air or attacker.movement_domain == air:
		return true
	if unit.navigation_domain == amphibious or attacker.navigation_domain == amphibious:
		return true
	return unit.navigation_domain == attacker.navigation_domain
