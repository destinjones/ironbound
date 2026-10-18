extends Node

# Collects per-player numbers during a match for the end screen: a score sample every
# SAMPLE_EVERY_S seconds of match time, plus counters for units built, lost and killed,
# buildings finished, goods delivered, trades and the highest city tier. It also remembers
# where each player's last unit or structure fell, so the ending can show that spot.

const MatchLimits = preload("res://source/match/MatchLimits.gd")
const Structure = preload("res://source/match/units/Structure.gd")

const SAMPLE_EVERY_S = 15.0

var elapsed_s = 0.0
var samples = []  # [{t: seconds, scores: {player instance id: total}}]
var counters = {}  # player instance id -> {built, lost, kills, structures, delivered, trades, tier}

var _owners = {}  # unit instance id -> player, units have left the tree when unit_died fires
var _structure_spots = {}  # structure instance id -> where it stands (structures do not move)
var _last_falls = {}  # player instance id -> {"position": Vector3, "order": int}, its last fall
var _fall_order = 0
var _since_sample_s = 0.0


func _ready():
	process_mode = Node.PROCESS_MODE_PAUSABLE
	MatchSignals.unit_spawned.connect(_on_unit_spawned)
	MatchSignals.setup_and_spawn_unit.connect(
		func(unit, _t, player): _owners[unit.get_instance_id()] = player
	)
	MatchSignals.unit_died.connect(_on_unit_died)
	MatchSignals.unit_production_finished.connect(_on_unit_production_finished)
	MatchSignals.unit_construction_finished.connect(_on_unit_construction_finished)
	MatchSignals.goods_delivered.connect(_on_goods_delivered)
	MatchSignals.trade_completed.connect(_on_trade_completed)
	MatchSignals.tier_reached.connect(_on_tier_reached)
	MatchSignals.match_started.connect(_sample, CONNECT_ONE_SHOT)


func _process(delta):
	elapsed_s += delta
	_since_sample_s += delta
	if _since_sample_s >= SAMPLE_EVERY_S:
		_since_sample_s = 0.0
		_sample()


func finish():
	"""takes a last sample, call when the match ends"""
	_sample()


func counters_of(player):
	var key = player.get_instance_id()
	if not key in counters:
		counters[key] = {
			"built": 0,
			"lost": 0,
			"kills": 0,
			"structures": 0,
			"delivered": 0,
			"trades": 0,
			"tier": 1,
		}
	return counters[key]


func score_of(player):
	var limits = MatchLimits.of(get_tree())
	if limits == null:
		return 0
	return limits.score_of(player)["total"]


func spot_of(unit):
	"""where a unit stands or stood: a structure's stored spot, else its position, which
	is still readable once it has left the tree (unit_died comes after tree_exited)"""
	var stored = _structure_spots.get(unit.get_instance_id())
	if stored != null:
		return stored
	return unit.global_position if unit.is_inside_tree() else unit.position


func last_fall(players):
	"""where the unit or structure that fell last among those of the given players stood,
	or null when none of them lost anything"""
	var best = null
	for player in players:
		if player == null or not is_instance_valid(player):
			continue
		var fall = _last_falls.get(player.get_instance_id())
		if fall != null and (best == null or fall["order"] > best["order"]):
			best = fall
	return best["position"] if best != null else null


func _sample():
	var scores = {}
	for player in get_tree().get_nodes_in_group("players"):
		scores[player.get_instance_id()] = score_of(player)
	samples.append({"t": elapsed_s, "scores": scores})


func _on_unit_spawned(unit):
	if "player" in unit and unit.player != null:
		_owners[unit.get_instance_id()] = unit.player
	if unit is Structure and unit.is_inside_tree():
		_structure_spots[unit.get_instance_id()] = unit.global_position


func _on_unit_died(unit):
	var key = unit.get_instance_id()
	var owner = _owners.get(key)
	if owner == null and "player" in unit:
		owner = unit.player
	_owners.erase(key)
	if owner != null and is_instance_valid(owner):
		counters_of(owner)["lost"] += 1
		_fall_order += 1
		_last_falls[owner.get_instance_id()] = {"position": spot_of(unit), "order": _fall_order}
	_structure_spots.erase(key)
	# the killer gets a kill: units and structures both count, friendly fire does not; units
	# taken away when a player is defeated (CityCentres) never die, so they count for nobody
	var killer = unit.last_attacker_player if "last_attacker_player" in unit else null
	if killer != null and is_instance_valid(killer) and killer != owner:
		counters_of(killer)["kills"] += 1


func _on_unit_production_finished(unit, _producer):
	if unit.player != null:
		_owners[unit.get_instance_id()] = unit.player
		counters_of(unit.player)["built"] += 1


func _on_unit_construction_finished(unit):
	if unit.player != null and unit is Structure:
		counters_of(unit.player)["structures"] += 1


func _on_goods_delivered(player, goods):
	var total = 0.0
	if goods is Dictionary:
		for kind in goods:
			total += float(goods[kind])
	counters_of(player)["delivered"] += total


func _on_trade_completed(proposer, partner, _offered, _requested):
	counters_of(proposer)["trades"] += 1
	counters_of(partner)["trades"] += 1


func _on_tier_reached(player, tier):
	var row = counters_of(player)
	row["tier"] = max(row["tier"], int(tier))
