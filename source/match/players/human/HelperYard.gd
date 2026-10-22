extends RefCounted

# The constructor guard's distance check (Helper._threat_near, behind every hold, retreat,
# detour and auto-expand safety question) with the own-yard rule: a neutral's units do not
# count for a spot inside our own yard (Constants.Match.Logistics.YARD_RADIUS_M around one
# of our finished command centres) while we are at peace with them. A neighbour willing to
# start a war is a threat on the way out, so its units keep counting everywhere else, and an
# enemy at war counts everywhere.
# Why: on plain_and_simple the rival city's militia, and before its first wave the rival's
# tanks and raiders, wander through our base at peace; they made every spot in the yard
# dangerous (their hold radius is 17.5 m), held every constructor back from the helper's
# vehicle factory site, pulled the builders away and kept auto-expand from sending anyone
# back, so the site stood unfinished for the whole match in some runs. Static functions on
# the helper, kept apart from Helper.gd, which sits at gdlint's 1000-line limit (as
# HelperArmyPick does for the army's pick).

const CommandCenter = preload("res://source/match/units/CommandCenter.gd")
const Diplomacy = preload("res://source/match/diplomacy/Diplomacy.gd")


static func threat_near(helper, position, extra):
	"""[distance, position, enemy, danger radius] of the closest known threat whose danger
	radius plus 'extra' covers 'position', or null"""
	var spot = position * Vector3(1, 0, 1)
	var in_yard = null  # looked up once, only when a neutral's unit covers the spot
	var best = null
	for enemy in helper._threats:
		var record = helper._threats[enemy]
		var distance = record["position"].distance_to(spot)
		if distance > record["danger"] + extra or (best != null and distance >= best[0]):
			continue
		if _at_peace_with(helper, enemy):
			if in_yard == null:
				in_yard = in_own_yard(helper, spot)
			if in_yard:
				continue
		best = [distance, record["position"], enemy, record["danger"]]
	return best


static func centres_of(mine):
	"""positions of the finished command centres among our units, gathered once per tick
	with them (Helper._gather_units): a detour at peace asks threat_near hundreds of times
	in one tick, so in_own_yard reads this list instead of filtering the units each time"""
	var centres = []
	for unit in mine:
		if unit is CommandCenter and unit.is_constructed():
			centres.append(unit.global_position_yless)
	return centres


static func in_own_yard(helper, spot):
	"""within the yard of one of our finished command centres, as of this tick's gather"""
	for centre in helper._yard:
		if centre.distance_to(spot) <= Constants.Match.Logistics.YARD_RADIUS_M:
			return true
	return false


static func _at_peace_with(helper, enemy):
	"""a neutral's unit: known only because its side is willing to start a war; with no
	diplomacy in the match everybody is at war, as everywhere else in the helper"""
	return (
		is_instance_valid(enemy)
		and Diplomacy.state_between(enemy.player, helper._player) != Diplomacy.State.WAR
	)
